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
## Efektler (M3-15, ADR-059): olay → ses eşlemesi SfxBank'te (data/audio/sfx_bank.tres).
## Havuz sabit sayıda çalardır (SfxBank.voices), oyun açılırken kurulur; tur sırasında düğüm
## oluşturulmaz. Boş çalar yoksa bitmesine en az kalan kesilir. Çalarlar SFX yolundadır.
## Efektler gerçek zamanda çalar: Engine.time_scale'i izlemez (yavaş çekimde ses yavaşlamaz;
## kural yalnızca müziğin vuruş senkronu için, .clauderules §5).
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
const SFX_BANK: SfxBank = preload("res://data/audio/sfx_bank.tres")
const USEC_PER_SEC: float = 1000000.0

## Olay → ses eşlemesi (testler değiştirebilir). Çalar sayısı açılışta bundan kurulur.
var sfx_bank: SfxBank = SFX_BANK

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
var _voices: Array[AudioStreamPlayer] = []
## Her çaların sesinin biteceği gerçek zaman (sn). play()'den hemen sonra `playing` hâlâ false
## olabildiği için doluluk buradan okunur; yoksa aynı karedeki iki efekt aynı çalara düşerdi.
var _voice_ends: PackedFloat64Array = PackedFloat64Array()
var _last_sfx: SfxSound = null
var _sfx_counts: Dictionary[GameTypes.Sfx, int] = {}
## Kombo çarpanı: büyüdüğü kıl payında kombo eşiği sesi çalar.
var _multiplier: int = 1


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	add_child(_music)
	for i: int in sfx_bank.voices:
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
	_voice_ends.resize(_voices.size())
	Events.run_started.connect(_on_run_started)
	Events.player_died.connect(_on_player_died)
	Events.player_flipped.connect(play_sfx.bind(GameTypes.Sfx.FLIP))
	Events.player_landed.connect(play_sfx.bind(GameTypes.Sfx.LAND))
	Events.glimmer_collected.connect(_on_glimmer_collected)
	Events.near_miss.connect(_on_near_miss)
	Events.combo_ended.connect(_on_combo_ended)
	Events.shield_changed.connect(_on_shield_changed)
	Events.sector_entered.connect(_on_sector_entered)
	Events.record_broken.connect(play_sfx.bind(GameTypes.Sfx.RECORD))


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


## Olayın sesini havuzdaki boş bir çalarla çalar; boş yoksa bitmesine en az kalanı keser.
func play_sfx(event: GameTypes.Sfx) -> void:
	var sound: SfxSound = sfx_bank.sound_for(event) if sfx_bank != null else null
	if sound == null or sound.stream == null or _voices.is_empty():
		return
	var now: float = Time.get_ticks_usec() / USEC_PER_SEC
	var index: int = _free_voice(now)
	var voice: AudioStreamPlayer = _voices[index]
	voice.stream = sound.stream
	voice.volume_db = sound.volume_db
	# Kozmetik rastgelelik: oynanışı etkilemez, turun RNG'si kullanılmaz (.clauderules §5).
	voice.pitch_scale = 1.0 + randf_range(-sound.pitch_jitter, sound.pitch_jitter)
	voice.play()
	_voice_ends[index] = now + sound.duration(voice.pitch_scale)
	_last_sfx = sound
	_sfx_counts[event] = _sfx_counts.get(event, 0) + 1


## Son çalınan efekt (testler ve debug).
func last_sfx() -> SfxSound:
	return _last_sfx


## Olayın sesinin oyun açıldığından beri kaç kez çaldığı (testler ve debug).
func sfx_count(event: GameTypes.Sfx) -> int:
	return _sfx_counts.get(event, 0)


## Efekt havuzundaki çalarlar (testler).
func sfx_voices() -> Array[AudioStreamPlayer]:
	return _voices


## Çalan parça (testler ve debug).
func current_track() -> MusicTrack:
	return _track


## Müziğin çalma hızı; Engine.time_scale'i izler (testler ve debug).
func music_pitch() -> float:
	return _music.pitch_scale


## Boş çalar; hepsi doluysa sesinin bitmesine en az kalan.
func _free_voice(now: float) -> int:
	var best: int = 0
	for i: int in _voices.size():
		if _voice_ends[i] <= now:
			return i
		if _voice_ends[i] < _voice_ends[best]:
			best = i
	return best


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
	_multiplier = 1
	_music.stop()
	if OS.is_debug_build():
		print("AUDIO output_latency=%d ms mix_rate=%d" % [
			roundi(AudioServer.get_output_latency() * 1000.0), roundi(AudioServer.get_mix_rate()),
		])


func _on_player_died(_cause: GameTypes.DeathCause) -> void:
	_clock_active = false
	_clock_playing = false
	_music.stop()
	play_sfx(GameTypes.Sfx.DEATH)


func _on_glimmer_collected(_value: int) -> void:
	play_sfx(GameTypes.Sfx.GLIMMER)


## Her kıl payında kıl payı sesi; çarpan büyüdüyse üstüne kombo eşiği sesi.
func _on_near_miss(_combo: int, multiplier: int) -> void:
	play_sfx(GameTypes.Sfx.NEAR_MISS)
	if multiplier > _multiplier:
		play_sfx(GameTypes.Sfx.COMBO_UP)
	_multiplier = multiplier


func _on_combo_ended() -> void:
	_multiplier = 1


## Kalkan yalnızca tükenince kapanır (Shield.consume): kapanış kırılmadır.
func _on_shield_changed(active: bool) -> void:
	if not active:
		play_sfx(GameTypes.Sfx.SHIELD_BREAK)


func _on_sector_entered(_index: int) -> void:
	play_sfx(GameTypes.Sfx.SECTOR)


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
