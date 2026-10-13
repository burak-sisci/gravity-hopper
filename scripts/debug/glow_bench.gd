extends Node2D
## Parlama karşılaştırma tezgâhı (M0-09; S-01, S-02). Yalnızca debug amaçlıdır, oyuncu görmez;
## bu yüzden metinleri tr() ile değil doğrudan yazılır.
## Açılışta her modu sırayla ölçer; sonucu ekrana ve günlüğe ("BENCH" satırları) yazar.
## Ölçüm bitince her dokunuş (PC'de sol tık ya da boşluk) bir sonraki moda geçer.
## PC'de tek modu görmek için: <godot> --path . res://scenes/debug/glow_bench.tscn -- --mode=env
## Şekiller oyunun neon bileşenleridir (NeonLine, NeonShape; M3-01); sahte parlama modları
## efekt kalitesini (Neon.quality) değiştirir.
## Arka plan, oyunun veri ağıdır (Background, M3-07): kaliteyle birlikte değişir (düşükte ve
## WorldEnvironment modunda düz renk), kayar ve vuruşta nabız atar.

enum Mode { OFF, ENV_GLOW, FAKE_GLOW, FAKE_MEDIUM }

const MODE_NAMES: Array[String] = [
	"Parlama yok (düşük kalite)", "WorldEnvironment glow", "Sahte parlama (yüksek kalite)",
	"Sahte parlama (orta kalite)",
]
const MODE_ARGS: Array[String] = ["off", "env", "fake", "medium"]
## Her modda neon bileşenlerinin efekt kalitesi; düşük kalitede sahte parlama yok.
const MODE_QUALITY: Array[GameTypes.Quality] = [
	GameTypes.Quality.LOW, GameTypes.Quality.LOW, GameTypes.Quality.HIGH,
	GameTypes.Quality.MEDIUM,
]
const BENCH_ORDER: Array[Mode] = [
	Mode.OFF, Mode.ENV_GLOW, Mode.FAKE_GLOW, Mode.FAKE_MEDIUM,
	Mode.OFF, Mode.ENV_GLOW, Mode.FAKE_GLOW, Mode.FAKE_MEDIUM,
]
const WARMUP_SEC: float = 1.5
const MEASURE_SEC: float = 4.0
const PERCENTILE: float = 0.95
## Qualcomm GPU doluluk sayacı: "meşgul toplam". Redmi'de (Android 15) uygulama okuyamıyor,
## yalnızca adb kabuğu okuyabiliyor (architecture.md §16); okunamazsa atlanır.
const GPUBUSY_PATH: String = "/sys/class/kgsl/kgsl-3d0/gpubusy"
const GPUBUSY_INTERVAL_SEC: float = 0.1
const DEBUG_MENU_PATH: String = "res://addons/debug_menu/debug_menu.tscn"
const DEBUG_MENU_SCALE: float = 2.0
const DEBUG_MENU_STYLE_COMPACT: int = 1

## S1 tırmanış hızı: 12 m/sn × 50 px/m.
const SCROLL_SPEED: float = 600.0
const RNG_SEED: int = 20261007
const BAND_MARGIN: float = 200.0
const WALL_INSET: float = 60.0
const PLAYER_FILL_ALPHA: float = 0.85
const SPIKE_COUNT: int = 14
const BLOCK_COUNT: int = 8
const GLIMMER_COUNT: int = 20
const TRAIL_STEP: float = 30.0
const TRAIL_POINTS: int = 40
const TRAIL_FLIP_LENGTH: float = 520.0
const TRAIL_WIDTH: float = 16.0
const PLAYER_HEIGHT_RATIO: float = 0.62
## Arka plan ağının nabız temposu (müzik parçalarının aralığında).
const BENCH_BPM: float = 120.0
const SECONDS_PER_MINUTE: float = 60.0

## S1 paleti taslağı; kesin tonlar M3'te seçilecek.
const COLOR_WALL: Color = Color(0.0, 0.9, 1.0)
const COLOR_HAZARD: Color = Color(1.0, 0.22, 0.32)
const COLOR_GLIMMER: Color = Color(0.35, 1.0, 0.5)
const COLOR_PLAYER: Color = Color(1.0, 1.0, 1.0)
const COLOR_ACCENT: Color = Color(0.8, 0.97, 1.0)

var _mode: Mode = Mode.OFF
var _glow_environment: Environment
var _scrolling: Array[Node2D] = []
var _band_height: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Sahte kameranın y'si (dünya yukarı doğru akar) ve vuruş sayacı: arka plan ağı için.
var _scroll_y: float = 0.0
var _beat: float = 0.0

var _bench_done: bool = false
var _bench_index: int = 0
var _phase_elapsed: float = 0.0
var _frame_times: Array[float] = []
var _gpu_times: Array[float] = []
var _gpubusy_elapsed: float = 0.0
var _gpubusy_busy: int = 0
var _gpubusy_total: int = 0
var _gpubusy_readable: bool = true
var _last_tick_usec: int = 0
var _results: Array[String] = []

@onready var _world_environment: WorldEnvironment = %WorldEnvironment
@onready var _background: Background = %Background
@onready var _shapes: Node2D = %Shapes
@onready var _mode_label: Label = %ModeLabel
@onready var _results_label: Label = %ResultsLabel


func _ready() -> void:
	_rng.seed = RNG_SEED
	_glow_environment = _world_environment.environment
	_build_world()
	_background.set_colors(COLOR_WALL, COLOR_ACCENT)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_last_tick_usec = Time.get_ticks_usec()

	var forced: int = _forced_mode()
	if forced >= 0:
		_bench_done = true
		_apply_mode(forced as Mode)
		_results_label.text = "Sabit mod (komut satırı)"
		return

	# Ölçüm sırasında dikey eşitleme kapatılmaya çalışılır; böylece kare süresi ekran
	# tazelemesine takılmadan GPU yükünü gösterir. PC'de çalışır, Android'de kapanmıyor.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var config: String = "BENCH config viewport=%s refresh=%.0f vsync_mode=%d gpu=%s" % [
		str(get_viewport_rect().size), DisplayServer.screen_get_refresh_rate(),
		DisplayServer.window_get_vsync_mode(), RenderingServer.get_video_adapter_name(),
	]
	print(config)
	_results.append("Ekran %.0f Hz · dikey eşitleme %s" % [
		DisplayServer.screen_get_refresh_rate(),
		"açık" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "kapalı",
	])
	_start_phase()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = (now - _last_tick_usec) / 1000.0
	_last_tick_usec = now
	if not _bench_done:
		_update_bench(frame_ms)


func _physics_process(delta: float) -> void:
	var view_height: float = get_viewport_rect().size.y
	var step: float = SCROLL_SPEED * delta
	for item: Node2D in _scrolling:
		item.position.y += step
		if item.position.y > view_height + BAND_MARGIN:
			item.position.y -= _band_height
			item.reset_physics_interpolation()
	_scroll_y -= step
	_background.set_scroll(_scroll_y)
	_beat += delta * BENCH_BPM / SECONDS_PER_MINUTE
	_background.set_beat(_beat)


func _unhandled_input(event: InputEvent) -> void:
	if not _bench_done:
		return
	var tapped: bool = false
	if event is InputEventScreenTouch:
		tapped = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		# Dokunuştan türetilen sahte fare olayları yok sayılır, yoksa her dokunuş iki kez sayılır (S-07).
		tapped = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT \
				and mouse.device != InputEvent.DEVICE_ID_EMULATION
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		tapped = key.pressed and not key.echo and key.keycode == KEY_SPACE
	if tapped:
		_apply_mode(wrapi(_mode + 1, 0, Mode.size()) as Mode)
		get_viewport().set_input_as_handled()


func _apply_mode(mode: Mode) -> void:
	_mode = mode
	# Parlama dışındaki modlarda ortam tamamen kaldırılır; böylece taban ölçüm,
	# WorldEnvironment'ı hiç olmayan bir oyunu temsil eder.
	_world_environment.environment = _glow_environment if mode == Mode.ENV_GLOW else null
	Neon.set_quality(MODE_QUALITY[mode], get_tree())
	var prefix: String = "Dokun: sonraki mod"
	if not _bench_done:
		prefix = "Ölçülüyor %d/%d" % [_bench_index + 1, BENCH_ORDER.size()]
	_mode_label.text = "%s\n%s" % [MODE_NAMES[mode], prefix]


func _start_phase() -> void:
	_phase_elapsed = 0.0
	_frame_times.clear()
	_gpu_times.clear()
	_gpubusy_elapsed = 0.0
	_gpubusy_busy = 0
	_gpubusy_total = 0
	_apply_mode(BENCH_ORDER[_bench_index])


func _update_bench(frame_ms: float) -> void:
	_phase_elapsed += frame_ms / 1000.0
	if _phase_elapsed < WARMUP_SEC:
		return
	_frame_times.append(frame_ms)
	var viewport_rid: RID = get_viewport().get_viewport_rid()
	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	if gpu_ms > 0.0:
		_gpu_times.append(gpu_ms)
	_gpubusy_elapsed += frame_ms / 1000.0
	if _gpubusy_elapsed >= GPUBUSY_INTERVAL_SEC:
		_gpubusy_elapsed = 0.0
		_sample_gpubusy()
	if _phase_elapsed >= WARMUP_SEC + MEASURE_SEC:
		_finish_phase()


func _finish_phase() -> void:
	var count: int = _frame_times.size()
	var sorted: Array[float] = _frame_times.duplicate()
	sorted.sort()
	var avg_ms: float = _sum(_frame_times) / count
	var p95_ms: float = sorted[mini(int(count * PERCENTILE), count - 1)]
	var max_ms: float = sorted[count - 1]
	var gpu_ms: float = _sum(_gpu_times) / _gpu_times.size() if not _gpu_times.is_empty() else -1.0
	var busy_pct: float = 100.0 * _gpubusy_busy / _gpubusy_total if _gpubusy_total > 0 else -1.0
	var mode: Mode = BENCH_ORDER[_bench_index]
	var line: String = "BENCH mode=%s run=%d frames=%d avg_ms=%.2f p95_ms=%.2f max_ms=%.2f" % [
		MODE_ARGS[mode], _bench_index + 1, count, avg_ms, p95_ms, max_ms,
	]
	print(line + " fps=%.1f gpu_ms=%.2f gpu_busy=%.1f" % [1000.0 / avg_ms, gpu_ms, busy_pct])
	var gpu_text: String = " · GPU %%%.0f" % busy_pct if busy_pct >= 0.0 else ""
	_results.append("%d %s: %.2f ms (p95 %.2f) · %.0f FPS%s" % [
		_bench_index + 1, MODE_NAMES[mode], avg_ms, p95_ms, 1000.0 / avg_ms, gpu_text,
	])
	_results_label.text = "\n".join(_results)
	_bench_index += 1
	if _bench_index < BENCH_ORDER.size():
		_start_phase()
	else:
		_end_bench()


func _end_bench() -> void:
	_bench_done = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	print("BENCH done")
	_add_debug_menu()
	_apply_mode(Mode.FAKE_GLOW)


func _sample_gpubusy() -> void:
	if not _gpubusy_readable:
		return
	var file: FileAccess = FileAccess.open(GPUBUSY_PATH, FileAccess.READ)
	if file == null:
		_gpubusy_readable = false
		return
	var parts: PackedStringArray = file.get_line().strip_edges().split(" ", false)
	if parts.size() >= 2:
		_gpubusy_busy += parts[0].to_int()
		_gpubusy_total += parts[1].to_int()


func _add_debug_menu() -> void:
	if not OS.is_debug_build() or not ResourceLoader.exists(DEBUG_MENU_PATH):
		return
	var menu: CanvasLayer = (load(DEBUG_MENU_PATH) as PackedScene).instantiate() as CanvasLayer
	add_child(menu)
	# Menü sağ üste yaslıdır; büyütünce ekrandan taşmasın diye sola kaydırılır.
	menu.scale = Vector2(DEBUG_MENU_SCALE, DEBUG_MENU_SCALE)
	menu.offset = Vector2(-get_viewport_rect().size.x * (DEBUG_MENU_SCALE - 1.0), 0.0)
	menu.set(&"style", DEBUG_MENU_STYLE_COMPACT)


func _forced_mode() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			return MODE_ARGS.find(arg.trim_prefix("--mode="))
	return -1


func _build_world() -> void:
	var view: Vector2 = get_viewport_rect().size
	_band_height = view.y + 2.0 * BAND_MARGIN
	var left_x: float = WALL_INSET
	var right_x: float = view.x - WALL_INSET

	# Duvarlar
	var top: float = -BAND_MARGIN
	var bottom: float = view.y + BAND_MARGIN
	for wall_x: float in [left_x, right_x]:
		var wall: NeonLine = NeonLine.new()
		wall.points = PackedVector2Array([Vector2(wall_x, top), Vector2(wall_x, bottom)])
		wall.color = COLOR_WALL
		_shapes.add_child(wall)

	# Duvar dikenleri (kırmızı)
	for i: int in SPIKE_COUNT:
		var on_left: bool = i % 2 == 0
		var wall_x: float = left_x if on_left else right_x
		var dir: float = 1.0 if on_left else -1.0
		_add_shape(_add_scroller(), PackedVector2Array([
			Vector2(wall_x, -35.0), Vector2(wall_x + dir * 60.0, 0.0), Vector2(wall_x, 35.0),
		]), COLOR_HAZARD)

	# Veri blokları (kırmızı)
	for i: int in BLOCK_COUNT:
		var block_x: float = _rng.randf_range(left_x + 120.0, right_x - 270.0)
		var block: NeonShape = _add_shape(_add_scroller(), PackedVector2Array([
			Vector2(block_x, -30.0), Vector2(block_x + 150.0, -30.0),
			Vector2(block_x + 150.0, 30.0), Vector2(block_x, 30.0),
		]), COLOR_HAZARD)
		block.glow = NeonShape.Glow.LINE

	# Glimmer'lar (yeşil)
	for i: int in GLIMMER_COUNT:
		var gx: float = _rng.randf_range(left_x + 80.0, right_x - 80.0)
		_add_shape(_add_scroller(), PackedVector2Array([
			Vector2(gx, -22.0), Vector2(gx + 16.0, 0.0), Vector2(gx, 22.0), Vector2(gx - 16.0, 0.0),
		]), COLOR_GLIMMER)

	# Oyuncu: sol duvara tutunmuş beyaz çekirdek ve sağ duvardan gelen iz
	var player_pos: Vector2 = Vector2(left_x + 40.0, view.y * PLAYER_HEIGHT_RATIO)
	_add_trail(player_pos, right_x - 40.0)
	var player: NeonShape = _add_shape(_shapes, PackedVector2Array([
		player_pos + Vector2(0.0, -48.0), player_pos + Vector2(30.0, 0.0),
		player_pos + Vector2(0.0, 48.0), player_pos + Vector2(-30.0, 0.0),
	]), COLOR_PLAYER)
	player.fill_alpha = PLAYER_FILL_ALPHA


## Kaydırılan (aşağı akan) bir kap ekler ve bandın içinde rastgele bir yüksekliğe koyar.
func _add_scroller() -> Node2D:
	var item: Node2D = Node2D.new()
	item.position.y = _rng.randf_range(-BAND_MARGIN, _band_height - BAND_MARGIN)
	_shapes.add_child(item)
	_scrolling.append(item)
	return item


func _add_shape(parent: Node2D, polygon: PackedVector2Array, color: Color) -> NeonShape:
	var shape: NeonShape = NeonShape.new()
	shape.polygon = polygon
	shape.color = color
	parent.add_child(shape)
	return shape


func _add_trail(player_pos: Vector2, from_x: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in TRAIL_POINTS:
		var dist: float = i * TRAIL_STEP
		var t: float = smoothstep(0.0, 1.0, clampf(dist / TRAIL_FLIP_LENGTH, 0.0, 1.0))
		points.append(Vector2(lerpf(player_pos.x, from_x, t), player_pos.y + dist))
	var taper: Curve = Curve.new()
	taper.add_point(Vector2(0.0, 1.0))
	taper.add_point(Vector2(1.0, 0.0))
	var fade: Gradient = Gradient.new()
	fade.set_color(0, COLOR_PLAYER)
	fade.set_color(1, Color(COLOR_WALL, 0.0))
	var trail: NeonLine = NeonLine.new()
	trail.points = points
	trail.color = COLOR_PLAYER
	trail.glow_color = COLOR_WALL
	trail.width = TRAIL_WIDTH
	trail.width_curve = taper
	trail.gradient = fade
	_shapes.add_child(trail)


func _sum(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total
