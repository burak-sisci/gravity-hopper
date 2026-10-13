extends Node
## Ses yöneticisi: efekt havuzu, müzik çalma ve geçişleri (architecture.md §8.3).
##
## Olayları Events'ten dinler. Engine.time_scale değiştiğinde müziğin pitch_scale
## değerini aynı orana çeker (ritim senkronu, ADR-008).
##
## Müzik (M2-20, ADR-040): turun parçasını (MusicTrack) çalar; M2-07'nin kodla üretilen
## metronomunun yerini aldı. Conductor her fizik adımında sync_beat_clock() ile vuruş saatini
## (turun başından beri geçen oyun zamanı) ve parçayı bildirir. Parça ilk vuruşla başladığı için
## turun 0. vuruşu parçanın 0. saniyesidir; duyulan konum MusicTrack.position_at(vuruş saati)
## olacak şekilde hizalanır. Döngü OGG'nin kendisindedir (loop_offset = loop_start) ve tam ölçü
## olduğu için döngüde vuruş kaymaz.
## Duyulan konum = çalma konumu + son karıştırmadan beri geçen süre − çıkış gecikmesi.
## Tur başlayınca çalar, oyuncu ölünce durur.
##
## Ölçüm karıştırma tamponu kadar titrer (Android'de onlarca ms). Bu yüzden kayma son karelerin
## ortalamasıyla ölçülür ve sınır aşılırsa ölçüde en fazla bir kez yeniden konumlanır. Her karede
## seek (durdur + çal) yapmak Android'de ses iş parçacığını çökertti (M2-07). Gerçek kayma örneği:
## tur başındaki takılmadan sonra fizik kaçırdığı adımları art arda çalıştırır, oyun saati ileri
## atlar; ses geride kalır (PC'de −121 ms ölçüldü) ve bir ölçü sonra yeniden konumlanır.

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
## Ortalama kayma bu sınırı aşarsa parça yeniden konumlanır (S-03, ilk değer).
const DRIFT_LIMIT: float = 0.04
## Kayma ortalaması için kare sayısı (60 Hz'de 0,25 sn).
const DRIFT_WINDOW: int = 15
## Çalmaya başladıktan ya da yeniden konumlandıktan sonra ölçülmeyen süre (konum otursun).
const SETTLE_TIME: float = 0.5
const BEATS_PER_BAR: int = 4
## Debug günlüğünde senkron raporu aralığı (ölçü).
const REPORT_EVERY_BARS: int = 8

var _music: AudioStreamPlayer
## Çalan parça (tur başında sıfırlanır; ilk sync_beat_clock kurar).
var _track: MusicTrack = null
## Tur sürüyor mu (run_started → player_died).
var _clock_active: bool = false
## Parça çalmaya başlatıldı mı. play()'den hemen sonra `playing` hâlâ false olabildiği için
## kendi bayrağımız tutulur; yoksa her karede yeniden play() çağrılır.
var _clock_playing: bool = false
var _last_beat_time: float = 0.0
## Son çalma ya da yeniden konumlamanın oyun zamanı; bekleme ve ölçü sınırı buna göre.
var _placed_at: float = 0.0
var _drift_samples: PackedFloat32Array = PackedFloat32Array()
## Son ölçülen ortalama kayma (rapor için).
var _last_drift: float = 0.0
var _resyncs: int = 0
var _max_drift: float = 0.0
var _reported_bar: int = 0


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	add_child(_music)
	Events.run_started.connect(_on_run_started)
	Events.player_died.connect(_on_player_died)


## Conductor her fizik adımında çağırır: turun parçasını vuruş saatine hizalar.
func sync_beat_clock(beat_time: float, track: MusicTrack) -> void:
	if not _clock_active or track == null or track.stream == null:
		return
	_music.pitch_scale = Engine.time_scale
	if track != _track:
		_set_track(track)
	var bar: float = BEATS_PER_BAR * track.beat_length()
	if not _clock_playing or beat_time < _last_beat_time:
		_place(beat_time)
	elif beat_time - _placed_at >= SETTLE_TIME:
		_measure_drift(beat_time, bar)
	_last_beat_time = beat_time
	_report(beat_time, bar)


## Çalan parça (testler ve debug).
func current_track() -> MusicTrack:
	return _track


## Parçayı çalara koyar; döngü dosyanın loop_start anından başlar.
func _set_track(track: MusicTrack) -> void:
	_track = track
	_music.stop()
	var ogg: AudioStreamOggVorbis = track.stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
		ogg.loop_offset = track.loop_start
	_music.stream = track.stream
	_music.volume_db = track.volume_db
	_clock_playing = false
	if OS.is_debug_build():
		print("AUDIO music=%s bpm=%s loop_start=%.2f length=%.2f" % [
			track.id, String.num(track.bpm), track.loop_start, track.length(),
		])


## Parçayı, duyulan konumu vuruş saatine denk gelecek yerden çalar.
func _place(beat_time: float) -> void:
	var latency: float = AudioServer.get_output_latency() * Engine.time_scale
	_music.play(_track.position_at(beat_time + latency))
	_clock_playing = true
	_placed_at = beat_time
	_drift_samples.clear()


## Kaymayı pencere ortalamasıyla ölçer; sınır aşılırsa (ölçüde en fazla bir kez) yeniden konumlar.
func _measure_drift(beat_time: float, bar: float) -> void:
	var latency: float = AudioServer.get_output_latency() * Engine.time_scale
	var heard: float = _music.get_playback_position() \
			+ AudioServer.get_time_since_last_mix() * Engine.time_scale - latency
	var drift: float = heard - _track.position_at(beat_time)
	# Döngü dikişinin iki yanındaki ölçüm bir döngü boyu farklı görünür.
	var loop_length: float = _track.length() - _track.loop_start
	if loop_length > 0.0:
		drift = wrapf(drift, -loop_length * 0.5, loop_length * 0.5)
	_drift_samples.append(drift)
	if _drift_samples.size() < DRIFT_WINDOW:
		return
	var average: float = 0.0
	for sample: float in _drift_samples:
		average += sample
	average /= _drift_samples.size()
	_drift_samples.clear()
	_last_drift = average
	_max_drift = maxf(_max_drift, absf(average))
	# Turun ilk düzeltmesi hemen (başlangıç takılması), sonrakiler ölçüde en fazla bir kez.
	if absf(average) > DRIFT_LIMIT and (_resyncs == 0 or beat_time - _placed_at >= bar):
		_resyncs += 1
		if OS.is_debug_build():
			print("AUDIO resync drift=%d ms" % roundi(average * 1000.0))
		_place(beat_time)


func _on_run_started(_run_seed: int, _start_sector: int) -> void:
	_clock_active = true
	_clock_playing = false
	_track = null
	_last_beat_time = 0.0
	_resyncs = 0
	_max_drift = 0.0
	_reported_bar = 0
	_music.stop()
	if OS.is_debug_build():
		print("AUDIO output_latency=%d ms mix_rate=%d" % [
			roundi(AudioServer.get_output_latency() * 1000.0), roundi(AudioServer.get_mix_rate()),
		])


func _on_player_died(_cause: GameTypes.DeathCause) -> void:
	_clock_active = false
	_clock_playing = false
	_music.stop()


## Debug build'de birkaç ölçüde bir senkron raporu (S-03 ölçümü).
func _report(beat_time: float, bar: float) -> void:
	if not OS.is_debug_build():
		return
	var bar_index: int = floori(beat_time / bar)
	if bar_index < _reported_bar + REPORT_EVERY_BARS:
		return
	_reported_bar = bar_index
	print("AUDIO sync bar=%d drift=%d ms max_drift=%d ms resyncs=%d latency=%d ms" % [
		bar_index, roundi(_last_drift * 1000.0), roundi(_max_drift * 1000.0), _resyncs,
		roundi(AudioServer.get_output_latency() * 1000.0),
	])
	_max_drift = 0.0
