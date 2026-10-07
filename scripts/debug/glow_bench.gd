extends Node2D
## Parlama karşılaştırma tezgâhı (M0-09; S-01, S-02). Yalnızca debug amaçlıdır, oyuncu görmez;
## bu yüzden metinleri tr() ile değil doğrudan yazılır.
## Açılışta her modu sırayla ölçer; sonucu ekrana ve günlüğe ("BENCH" satırları) yazar.
## Ölçüm bitince her dokunuş (PC'de sol tık ya da boşluk) bir sonraki moda geçer.
## PC'de tek modu görmek için: <godot> --path . res://scenes/debug/glow_bench.tscn -- --mode=env

enum Mode { OFF, ENV_GLOW, FAKE_GLOW }

const MODE_NAMES: Array[String] = ["Parlama yok", "WorldEnvironment glow", "Sahte parlama"]
const MODE_ARGS: Array[String] = ["off", "env", "fake"]
const BENCH_ORDER: Array[Mode] = [
	Mode.OFF, Mode.ENV_GLOW, Mode.FAKE_GLOW, Mode.OFF, Mode.ENV_GLOW, Mode.FAKE_GLOW,
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
const GRID_CELL: float = 120.0
const GRID_WIDTH: float = 2.0
const LINE_WIDTH: float = 6.0
## Çizgiler (duvar, iz) için sahte parlama katmanları: x = genişlik (px), y = yoğunluk.
const HALO_LAYERS: Array[Vector2] = [Vector2(64.0, 0.35), Vector2(26.0, 0.7)]
## Kapalı şekiller için ışık lekesi: şeklin sınır kutusuna göre büyüklük ve yoğunluk.
const BLOB_SCALE: float = 2.6
const BLOB_PADDING: float = 40.0
const BLOB_INTENSITY: float = 0.65
const BLOB_TEXTURE_SIZE: int = 128
const FILL_ALPHA: float = 0.18
const PLAYER_FILL_ALPHA: float = 0.85
const SPIKE_COUNT: int = 14
const BLOCK_COUNT: int = 8
const GLIMMER_COUNT: int = 20
const TRAIL_STEP: float = 30.0
const TRAIL_POINTS: int = 40
const TRAIL_FLIP_LENGTH: float = 520.0
const TRAIL_WIDTH: float = 16.0
const PLAYER_HEIGHT_RATIO: float = 0.62

## S1 paleti taslağı; kesin tonlar M3'te seçilecek.
const COLOR_WALL: Color = Color(0.0, 0.9, 1.0)
const COLOR_HAZARD: Color = Color(1.0, 0.22, 0.32)
const COLOR_GLIMMER: Color = Color(0.35, 1.0, 0.5)
const COLOR_PLAYER: Color = Color(1.0, 1.0, 1.0)
const COLOR_GRID: Color = Color(0.1, 0.16, 0.36)

var _mode: Mode = Mode.OFF
var _glow_environment: Environment
var _halo_texture: GradientTexture2D
var _blob_texture: GradientTexture2D
var _halo_material: CanvasItemMaterial
var _halos: Array[CanvasItem] = []
var _scrolling: Array[Node2D] = []
var _band_height: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

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
@onready var _grid: Node2D = %Grid
@onready var _shapes: Node2D = %Shapes
@onready var _mode_label: Label = %ModeLabel
@onready var _results_label: Label = %ResultsLabel


func _ready() -> void:
	_rng.seed = RNG_SEED
	_glow_environment = _world_environment.environment
	_halo_texture = _make_halo_texture()
	_blob_texture = _make_blob_texture()
	_halo_material = CanvasItemMaterial.new()
	_halo_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_build_world()
	_grid.draw.connect(_draw_grid)
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
	_grid.position.y += step
	if _grid.position.y >= GRID_CELL:
		_grid.position.y -= GRID_CELL
		_grid.reset_physics_interpolation()


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
	for halo: CanvasItem in _halos:
		halo.visible = mode == Mode.FAKE_GLOW
	var prefix: String = "Ölçülüyor %d/%d" % [_bench_index + 1, BENCH_ORDER.size()] if not _bench_done else "Dokun: sonraki mod"
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
	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
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
	print("BENCH mode=%s run=%d frames=%d avg_ms=%.2f p95_ms=%.2f max_ms=%.2f fps=%.1f gpu_ms=%.2f gpu_busy=%.1f" % [
		MODE_ARGS[mode], _bench_index + 1, count, avg_ms, p95_ms, max_ms, 1000.0 / avg_ms, gpu_ms, busy_pct,
	])
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
	_apply_mode(Mode.ENV_GLOW)


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
	_add_neon(_shapes, PackedVector2Array([Vector2(left_x, -BAND_MARGIN), Vector2(left_x, view.y + BAND_MARGIN)]), COLOR_WALL, false, FILL_ALPHA)
	_add_neon(_shapes, PackedVector2Array([Vector2(right_x, -BAND_MARGIN), Vector2(right_x, view.y + BAND_MARGIN)]), COLOR_WALL, false, FILL_ALPHA)

	# Duvar dikenleri (kırmızı)
	for i: int in SPIKE_COUNT:
		var on_left: bool = i % 2 == 0
		var wall_x: float = left_x if on_left else right_x
		var dir: float = 1.0 if on_left else -1.0
		var spike: PackedVector2Array = PackedVector2Array([
			Vector2(wall_x, -35.0), Vector2(wall_x + dir * 60.0, 0.0), Vector2(wall_x, 35.0),
		])
		_add_neon(_add_scroller(), spike, COLOR_HAZARD, true, FILL_ALPHA)

	# Veri blokları (kırmızı)
	for i: int in BLOCK_COUNT:
		var block_x: float = _rng.randf_range(left_x + 120.0, right_x - 270.0)
		var block: PackedVector2Array = PackedVector2Array([
			Vector2(block_x, -30.0), Vector2(block_x + 150.0, -30.0),
			Vector2(block_x + 150.0, 30.0), Vector2(block_x, 30.0),
		])
		_add_neon(_add_scroller(), block, COLOR_HAZARD, true, FILL_ALPHA, true)

	# Glimmer'lar (yeşil)
	for i: int in GLIMMER_COUNT:
		var gx: float = _rng.randf_range(left_x + 80.0, right_x - 80.0)
		var glimmer: PackedVector2Array = PackedVector2Array([
			Vector2(gx, -22.0), Vector2(gx + 16.0, 0.0), Vector2(gx, 22.0), Vector2(gx - 16.0, 0.0),
		])
		_add_neon(_add_scroller(), glimmer, COLOR_GLIMMER, true, FILL_ALPHA)

	# Oyuncu: sol duvara tutunmuş beyaz çekirdek ve sağ duvardan gelen iz
	var player_pos: Vector2 = Vector2(left_x + 40.0, view.y * PLAYER_HEIGHT_RATIO)
	_add_trail(player_pos, right_x - 40.0)
	var player: PackedVector2Array = PackedVector2Array([
		player_pos + Vector2(0.0, -48.0), player_pos + Vector2(30.0, 0.0),
		player_pos + Vector2(0.0, 48.0), player_pos + Vector2(-30.0, 0.0),
	])
	_add_neon(_shapes, player, COLOR_PLAYER, true, PLAYER_FILL_ALPHA)


## Kaydırılan (aşağı akan) bir kap ekler ve bandın içinde rastgele bir yüksekliğe koyar.
func _add_scroller() -> Node2D:
	var item: Node2D = Node2D.new()
	item.position.y = _rng.randf_range(-BAND_MARGIN, _band_height - BAND_MARGIN)
	_shapes.add_child(item)
	_scrolling.append(item)
	return item


## Neon şekil: sahte parlama (yalnızca sahte modda görünür) + dolgu + parlak çizgi.
## Çizgilerde ve geniş açılı şekillerde (blok) parlama, çizginin enine yumuşak bir kopyasıdır.
## Küçük, sivri köşeli şekillerde ise arkadaki bir ışık lekesidir; çizgi kopyası sivri
## köşelerde ve kapanma noktasında yay izi bırakıyor.
func _add_neon(parent: Node2D, points: PackedVector2Array, color: Color, closed: bool, fill_alpha: float, line_halo: bool = false) -> void:
	if closed and not line_halo:
		var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
		for point: Vector2 in points:
			bounds = bounds.expand(point)
		var blob: Sprite2D = Sprite2D.new()
		blob.texture = _blob_texture
		blob.position = bounds.get_center()
		blob.scale = (bounds.size * BLOB_SCALE + Vector2(BLOB_PADDING, BLOB_PADDING)) / BLOB_TEXTURE_SIZE
		blob.modulate = Color(color, BLOB_INTENSITY)
		blob.material = _halo_material
		blob.visible = false
		parent.add_child(blob)
		_halos.append(blob)
	else:
		for halo_layer: Vector2 in HALO_LAYERS:
			var halo: Line2D = _make_line(points, color, halo_layer.x, closed)
			halo.default_color = Color(color, halo_layer.y)
			halo.texture = _halo_texture
			halo.texture_mode = Line2D.LINE_TEXTURE_STRETCH
			halo.material = _halo_material
			halo.visible = false
			parent.add_child(halo)
			_halos.append(halo)
	if closed:
		var fill: Polygon2D = Polygon2D.new()
		fill.polygon = points
		fill.color = Color(color, fill_alpha)
		parent.add_child(fill)
	parent.add_child(_make_line(points, color, LINE_WIDTH, closed))


func _add_trail(player_pos: Vector2, from_x: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in TRAIL_POINTS:
		var dist: float = i * TRAIL_STEP
		var t: float = smoothstep(0.0, 1.0, clampf(dist / TRAIL_FLIP_LENGTH, 0.0, 1.0))
		points.append(Vector2(lerpf(player_pos.x, from_x, t), player_pos.y + dist))
	var taper: Curve = Curve.new()
	taper.add_point(Vector2(0.0, 1.0))
	taper.add_point(Vector2(1.0, 0.0))
	for halo_layer: Vector2 in HALO_LAYERS:
		var halo: Line2D = _make_line(points, COLOR_WALL, halo_layer.x, false)
		halo.default_color = Color(COLOR_WALL, halo_layer.y)
		halo.width_curve = taper
		halo.texture = _halo_texture
		halo.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		halo.material = _halo_material
		halo.visible = false
		_shapes.add_child(halo)
		_halos.append(halo)
	var trail: Line2D = _make_line(points, COLOR_PLAYER, TRAIL_WIDTH, false)
	trail.width_curve = taper
	var fade: Gradient = Gradient.new()
	fade.set_color(0, COLOR_PLAYER)
	fade.set_color(1, Color(COLOR_WALL, 0.0))
	trail.gradient = fade
	_shapes.add_child(trail)


func _make_line(points: PackedVector2Array, color: Color, line_width: float, closed: bool) -> Line2D:
	var line: Line2D = Line2D.new()
	line.points = points
	line.closed = closed
	line.width = line_width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	return line


## Çizginin enine yumuşak sönümlü doku: ortada tam, kenarlarda sıfır.
func _make_halo_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.38, 0.5, 0.62, 0.8, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.35), Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.0),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 64
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	return texture


## Merkezde tam, kenara doğru sönen dairesel ışık lekesi dokusu.
func _make_blob_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = BLOB_TEXTURE_SIZE
	texture.height = BLOB_TEXTURE_SIZE
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _draw_grid() -> void:
	var view: Vector2 = get_viewport_rect().size
	var x: float = 0.0
	while x <= view.x:
		_grid.draw_line(Vector2(x, -GRID_CELL), Vector2(x, view.y + GRID_CELL), COLOR_GRID, GRID_WIDTH)
		x += GRID_CELL
	var y: float = -GRID_CELL
	while y <= view.y + GRID_CELL:
		_grid.draw_line(Vector2(0.0, y), Vector2(view.x, y), COLOR_GRID, GRID_WIDTH)
		y += GRID_CELL


func _sum(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total
