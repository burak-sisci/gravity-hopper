extends Node
## Ses yöneticisi: efekt havuzu, müzik çalma ve geçişleri (architecture.md §8.3).
##
## Olayları Events'ten dinler. Engine.time_scale değiştiğinde müziğin pitch_scale
## değerini aynı orana çeker (ritim senkronu, ADR-008).
##
## M2-07: müzik gelene kadar (M3) kodla üretilen bir ölçülük metronom döngüsü çalar. Conductor
## her fizik adımında sync_beat_clock() ile vuruş saatini (tempo ızgarasının başından beri geçen
## oyun zamanı) bildirir; döngü, duyulan konumu bu saate eşit olacak şekilde hizalanır. Müzik de
## aynı yolu kullanacak. Sektör değişince tempo ve saat yeniden başlar; döngü yeniden kurulur.
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
## Ortalama kayma bu sınırı aşarsa döngü yeniden konumlanır (S-03, ilk değer).
const DRIFT_LIMIT: float = 0.04
## Kayma ortalaması için kare sayısı (60 Hz'de 0,25 sn).
const DRIFT_WINDOW: int = 15
## Çalmaya başladıktan ya da yeniden konumlandıktan sonra ölçülmeyen süre (konum otursun).
const SETTLE_TIME: float = 0.5
## Metronom: bir ölçü 4 vuruş; ilk vuruş vurgulu (daha tiz).
const BEATS_PER_BAR: int = 4
const MIX_RATE: int = 44100
const CLICK_LENGTH: float = 0.05
const CLICK_HZ: float = 1000.0
const ACCENT_HZ: float = 1500.0
const CLICK_DECAY: float = 60.0
const CLICK_VOLUME: float = 0.5
## Döngü sonundan sonra bırakılan sessiz örnekler. Hiç çalınmaz; karıştırıcı döngü sonunda
## enterpolasyon için verinin ötesini okuyor. Pay yokken Redmi'de (karıştırma hızı = akış hızı)
## döngü sonunda ses iş parçacığı çöktü (SIGSEGV, M2-07).
const LOOP_TAIL_SAMPLES: int = 64
## Debug günlüğünde senkron raporu aralığı (ölçü).
const REPORT_EVERY_BARS: int = 8

var _metronome: AudioStreamPlayer
var _metronome_bpm: float = 0.0
## Tur sürüyor mu (run_started → player_died).
var _clock_active: bool = false
## Döngü çalmaya başlatıldı mı. play()'den hemen sonra `playing` hâlâ false olabildiği için
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
	_metronome = AudioStreamPlayer.new()
	_metronome.bus = MUSIC_BUS
	add_child(_metronome)
	Events.run_started.connect(_on_run_started)
	Events.player_died.connect(_on_player_died)


## Conductor her fizik adımında çağırır: metronom döngüsünü vuruş saatine hizalar.
func sync_beat_clock(beat_time: float, bpm: float) -> void:
	if not _clock_active:
		return
	_metronome.pitch_scale = Engine.time_scale
	if not is_equal_approx(bpm, _metronome_bpm):
		_metronome_bpm = bpm
		_metronome.stop()
		_metronome.stream = make_metronome(bpm)
		_clock_playing = false
	var bar: float = BEATS_PER_BAR * Conductor.SECONDS_PER_MINUTE / bpm
	if not _clock_playing or beat_time < _last_beat_time:
		_place_clock(beat_time, bar)
	elif beat_time - _placed_at >= SETTLE_TIME:
		_measure_drift(beat_time, bar)
	_last_beat_time = beat_time
	_report(beat_time, bar)


## Bir ölçülük metronom: her vuruşta sönen kısa bir sinüs tıkı. Dış ses dosyası yoktur.
static func make_metronome(bpm: float) -> AudioStreamWAV:
	var beat_samples: int = roundi(MIX_RATE * Conductor.SECONDS_PER_MINUTE / bpm)
	var click_samples: int = roundi(MIX_RATE * CLICK_LENGTH)
	var data: PackedByteArray = PackedByteArray()
	data.resize((beat_samples * BEATS_PER_BAR + LOOP_TAIL_SAMPLES) * 2)
	for beat: int in BEATS_PER_BAR:
		var hz: float = ACCENT_HZ if beat == 0 else CLICK_HZ
		for i: int in click_samples:
			var t: float = float(i) / MIX_RATE
			var value: float = sin(TAU * hz * t) * exp(-CLICK_DECAY * t) * CLICK_VOLUME
			data.encode_s16((beat * beat_samples + i) * 2, roundi(value * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = beat_samples * BEATS_PER_BAR
	return stream


## Döngüyü, duyulan konumu vuruş saatine denk gelecek yerden çalar.
func _place_clock(beat_time: float, bar: float) -> void:
	var latency: float = AudioServer.get_output_latency() * Engine.time_scale
	_metronome.play(fposmod(beat_time + latency, bar))
	_clock_playing = true
	_placed_at = beat_time
	_drift_samples.clear()


## Kaymayı pencere ortalamasıyla ölçer; sınır aşılırsa (ölçüde en fazla bir kez) yeniden konumlar.
func _measure_drift(beat_time: float, bar: float) -> void:
	var latency: float = AudioServer.get_output_latency() * Engine.time_scale
	var heard: float = _metronome.get_playback_position() \
			+ AudioServer.get_time_since_last_mix() * Engine.time_scale - latency
	_drift_samples.append(wrapf(heard - beat_time, -bar * 0.5, bar * 0.5))
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
		_place_clock(beat_time, bar)


func _on_run_started(_run_seed: int, _start_sector: int) -> void:
	_clock_active = true
	_clock_playing = false
	_last_beat_time = 0.0
	_resyncs = 0
	_max_drift = 0.0
	_reported_bar = 0
	_metronome.stop()
	if OS.is_debug_build():
		print("AUDIO output_latency=%d ms mix_rate=%d" % [
			roundi(AudioServer.get_output_latency() * 1000.0), roundi(AudioServer.get_mix_rate()),
		])


func _on_player_died(_cause: GameTypes.DeathCause) -> void:
	_clock_active = false
	_clock_playing = false
	_metronome.stop()


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
