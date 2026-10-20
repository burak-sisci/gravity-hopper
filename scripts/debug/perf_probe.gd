class_name PerfProbe
extends Node
## Oyunun içinde performans ölçümü (M3-19, architecture.md §16.1). Yalnızca debug katmanı kurar
## (`-- --perf=6`): efekt kalitesi her evrede sırayla yüksek → orta → düşük olur; her evrenin
## sonunda günlüğe bir "PERF" satırı yazılır: kare süresinin ortalaması, p95'i ve en kötüsü;
## ayrıca çöküş duvarı ekrandayken ve renk dalgası sürerken geçen karelerin ortalaması.
## Takılmalar (SPIKE_MS'den uzun kareler) olduğu anda zamanıyla yazılır: önceki karenin çizimi
## (render), çizimin bitişinden bu kareye kalan süre (ekran takası, fizik, işlem) ve doku
## belleğinin değişimi (yeni doku yaratıldı mı).
## Oyun dünyasını tanımaz: duvarı, dalgayı ve dokunuşları Events'ten izler.
## `--auto-tap=0,5` ile her 0,5 sn'de bir oyun alanına dokunuş gönderilir (oyuncu duvardan duvara
## atlar: iniş kıvılcımı, kıl payı). Yalnızca geliştirici görür; metinler doğrudan yazılır.

## Kalite sırası (yüksekten düşüğe) ve günlükteki adları.
const QUALITY_ORDER: Array[GameTypes.Quality] = [
	GameTypes.Quality.HIGH, GameTypes.Quality.MEDIUM, GameTypes.Quality.LOW,
]
const QUALITY_NAMES: Array[String] = ["low", "medium", "high"]
## Her evrenin başında ölçülmeyen ısınma süresi (sn): kalite değişimi yerine otursun.
const WARMUP_SEC: float = 1.0
const PERCENTILE: float = 0.95
## Bundan uzun kare (ms) takılma sayılır ve zamanıyla günlüğe yazılır (120 Hz'de üç kare).
const SPIKE_MS: float = 25.0
## Otomatik dokunuşun yeri (pencere koordinatı; oyun alanı, debug düğmesinden uzak). Oyuncu
## dokunuşun yerine bakmaz.
const TAP_POINT: Vector2 = Vector2(540, 1700)

## Bir evrenin süresi (sn; ısınma dahil).
var phase_sec: float = 6.0
## Otomatik dokunuş aralığı (sn); 0 ise dokunuş yok.
var tap_interval: float = 0.0

var _phase: int = 0
var _phase_elapsed: float = 0.0
var _tap_elapsed: float = 0.0
var _last_tick_usec: int = 0
var _frames: Array[float] = []
var _wall_frames: Array[float] = []
var _wave_frames: Array[float] = []
var _wall_ratio: float = 0.0
var _wall_peak: float = 0.0
## Renk dalgasının bitmesine kalan süre (sn; sektöre girişte wave_time).
var _wave_left: float = 0.0
var _sector: int = 1
var _flips: int = 0
var _near_misses: int = 0
var _spikes: int = 0
## Son çizimin (RenderingServer.draw) başlangıcı, bitişi (µs) ve süresi (ms).
var _draw_start_usec: int = 0
var _draw_end_usec: int = 0
var _draw_ms: float = 0.0
## Çizimin bitişinden bu karenin ölçümüne kalan süre (ms).
var _after_draw_ms: float = 0.0
var _texture_mb: float = 0.0


func _ready() -> void:
	Events.wall_proximity_changed.connect(func(ratio: float) -> void: _wall_ratio = ratio)
	Events.sector_entered.connect(func(index: int) -> void:
		_sector = index
		_wave_left = Neon.STYLE.wave_time)
	Events.run_started.connect(func(_run_seed: int, start_sector: int) -> void:
		_sector = start_sector
		_wall_ratio = 0.0
		_wave_left = 0.0)
	Events.player_flipped.connect(func() -> void: _flips += 1)
	Events.near_miss.connect(func(_combo: int, _multiplier: int) -> void: _near_misses += 1)
	print("PERF config phase_sec=%.1f auto_tap=%.2f refresh=%.0f viewport=%s" % [
		phase_sec, tap_interval, DisplayServer.screen_get_refresh_rate(),
		str(get_viewport().get_visible_rect().size),
	])
	RenderingServer.frame_pre_draw.connect(func() -> void:
		_draw_start_usec = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void:
		_draw_end_usec = Time.get_ticks_usec()
		_draw_ms = (_draw_end_usec - _draw_start_usec) / 1000.0)
	_texture_mb = _texture_memory_mb()
	_last_tick_usec = Time.get_ticks_usec()
	_start_phase()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	_after_draw_ms = (now - _draw_end_usec) / 1000.0
	tick((now - _last_tick_usec) / 1000.0)
	_last_tick_usec = now


## Bir karenin süresini (ms) işler; testler zamanı bununla sürer.
func tick(frame_ms: float) -> void:
	var sec: float = frame_ms / 1000.0
	_phase_elapsed += sec
	_wave_left = maxf(_wave_left - sec, 0.0)
	if tap_interval > 0.0:
		_tap_elapsed += sec
		if _tap_elapsed >= tap_interval:
			_tap_elapsed = 0.0
			_tap()
	var texture_mb: float = _texture_memory_mb()
	if _phase_elapsed > WARMUP_SEC:
		_frames.append(frame_ms)
		if frame_ms > SPIKE_MS:
			_spikes += 1
			print(("PERF spike ms=%.2f draw_ms=%.2f after_draw_ms=%.2f texture_mb=%+.2f "
					+ "phase=%d sector=%d t=%d") % [
				frame_ms, _draw_ms, _after_draw_ms, texture_mb - _texture_mb, _phase + 1,
				_sector, Time.get_ticks_msec(),
			])
		if _wall_ratio > 0.0:
			_wall_frames.append(frame_ms)
			_wall_peak = maxf(_wall_peak, _wall_ratio)
		if _wave_left > 0.0:
			_wave_frames.append(frame_ms)
	_texture_mb = texture_mb
	if _phase_elapsed >= phase_sec:
		_finish_phase()
		_phase += 1
		_start_phase()


## Evredeki kalite.
func current_quality() -> GameTypes.Quality:
	return QUALITY_ORDER[_phase % QUALITY_ORDER.size()]


## Kare sürelerinin özeti: x = ortalama, y = p95, z = en kötü (boşsa sıfır).
static func summarize(frame_times: Array[float]) -> Vector3:
	if frame_times.is_empty():
		return Vector3.ZERO
	var sorted: Array[float] = frame_times.duplicate()
	sorted.sort()
	var total: float = 0.0
	for ms: float in frame_times:
		total += ms
	var count: int = sorted.size()
	return Vector3(total / count, sorted[mini(int(count * PERCENTILE), count - 1)], sorted[-1])


func _start_phase() -> void:
	_phase_elapsed = 0.0
	_frames.clear()
	_wall_frames.clear()
	_wave_frames.clear()
	_wall_peak = 0.0
	_flips = 0
	_near_misses = 0
	_spikes = 0
	# Main ayar değişikliğini duyunca kaliteyi neon bileşenlerine uygular (kaydedilmez).
	Settings.effect_quality = current_quality()
	Events.settings_changed.emit()


func _finish_phase() -> void:
	var all: Vector3 = summarize(_frames)
	var wall: Vector3 = summarize(_wall_frames)
	var wave: Vector3 = summarize(_wave_frames)
	print(("PERF phase=%d q=%s sector=%d frames=%d avg_ms=%.2f p95_ms=%.2f max_ms=%.2f "
			+ "wall_frames=%d wall_avg_ms=%.2f wall_peak=%.2f wave_frames=%d wave_avg_ms=%.2f "
			+ "flips=%d near=%d spikes=%d t=%d") % [
		_phase + 1, QUALITY_NAMES[current_quality()], _sector, _frames.size(), all.x, all.y,
		all.z, _wall_frames.size(), wall.x, _wall_peak, _wave_frames.size(), wave.x, _flips,
		_near_misses, _spikes, Time.get_ticks_msec(),
	])


static func _texture_memory_mb() -> float:
	return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0


## Telefondaki gibi: dokunuş ve bırakma.
func _tap() -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = TAP_POINT
		touch.pressed = pressed
		Input.parse_input_event(touch)
