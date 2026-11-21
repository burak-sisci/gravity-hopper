extends GdUnitTestSuite
## Ekran oranı matrisi, oyun dünyası (M6-02, architecture.md §3): gerçek tur, matrisin her
## oranındaki tuvalde (stretch `expand`; UI kabulünün `ASPECTS` listesi) kurulur ve ölçülür.
## Adalet: oyuncunun üstündeki görüş her oranda aynıdır (fazla dikey alan altına gider).
## Bütünlük: koridorun iki duvarı yatayda ekrana sığar ve dikeyde görünür alanı boşluksuz kaplar;
## çöküş duvarı ve arka plan ekranın tamamını kaplar. Haritanın ekran boyundan bağımsızlığı
## tests/systems/chunk_spawner_test.gd'de.

const UI := preload("res://tests/ui/ui_acceptance.gd")
const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
## Tur kurulup kamera yerine oturana dek beklenen fizik karesi.
const SETTLE_FRAMES: int = 30
## Konum karşılaştırma payı (px).
const TOLERANCE: float = 0.01


func after_test() -> void:
	Events.debug_invincibility_changed.emit(false)


## Matrisin her oranında: üst görüş sabit, duvarlar ve zeminler ekranı kaplar.
func test_world_fits_every_aspect() -> void:
	var problems: Array[String] = []
	var lookahead_px: float = 0.0
	for aspect: float in UI.ASPECTS:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = UI.canvas_size(aspect)
		add_child(viewport)
		var run: Run = RUN_SCENE.instantiate() as Run
		run.tuning = ResourceLoader.load(
				TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
		run.run_seed = 5
		viewport.add_child(run)
		Events.debug_invincibility_changed.emit(true)
		for i: int in SETTLE_FRAMES:
			await get_tree().physics_frame
		lookahead_px = TuningConfig.to_px(run.tuning.lookahead)
		problems.append_array(_problems(run, Vector2(viewport.size), lookahead_px,
				"%.3f %s" % [aspect, viewport.size]))
		viewport.queue_free()
		await get_tree().process_frame
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## Ölçünün kendisi: dar ve çok uzun tuvalde (koridor sığmaz; 4400 px'lik alanı 10 × 400 px'lik duvar
## halkası kaplayamaz) ve görüş değişince sorun bulunur.
func test_metric_catches_broken_views() -> void:
	var run: Run = RUN_SCENE.instantiate() as Run
	run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(900, 4400)
	add_child(viewport)
	viewport.add_child(run)
	Events.debug_invincibility_changed.emit(true)
	for i: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	var lookahead_px: float = TuningConfig.to_px(run.tuning.lookahead)
	var found: String = "\n".join(_problems(run, Vector2(viewport.size), lookahead_px, "dar"))
	assert_str(found).contains("koridor ekrana sığmıyor")
	assert_str(found).contains("görünür alan duvar halkasından uzun")
	assert_str(found).contains("duvar kaplamıyor")
	found = "\n".join(_problems(run, Vector2(viewport.size), lookahead_px + 50.0, "görüş"))
	assert_str(found).contains("üst görüş")
	viewport.queue_free()


func _problems(run: Run, view: Vector2, lookahead_px: float, label: String) -> Array[String]:
	var problems: Array[String] = []
	var camera: GameCamera = run.get_node("%GameCamera") as GameCamera
	var player: Node2D = run.get_node("%Player") as Node2D
	var top: float = camera.view_top()
	var bottom: float = camera.view_bottom()
	var half: float = view.x * 0.5
	# Adalet: oyuncunun üstündeki görüş her oranda aynı.
	var above: float = player.position.y - top
	if absf(above - lookahead_px) > TOLERANCE:
		problems.append("%s: üst görüş %.2f px (beklenen %.0f)" % [label, above, lookahead_px])
	if view.y > Corridor.MAX_VIEW_HEIGHT:
		problems.append("%s: görünür alan duvar halkasından uzun (%.0f > %.0f)" % [
			label, view.y, Corridor.MAX_VIEW_HEIGHT])
	# Koridor: duvarın dış kenarı ekranda, duvar parçaları görünür alanı dikeyde kaplar.
	var corridor_half: float = TuningConfig.to_px(run.tuning.corridor_width) * 0.5
	if corridor_half + Corridor.WALL_THICKNESS > half + TOLERANCE:
		problems.append("%s: koridor ekrana sığmıyor (%.0f > %.0f)" % [
			label, corridor_half + Corridor.WALL_THICKNESS, half])
	for side: float in [-1.0, 1.0]:
		var spans: Array[Vector2] = []
		for node: Node in (run.get_node("%Corridor") as Node).get_children():
			var segment: Node2D = node as Node2D
			if segment is StaticBody2D and signf(segment.position.x) == side:
				spans.append(Vector2(segment.position.y - Corridor.SEGMENT_HEIGHT * 0.5,
						segment.position.y + Corridor.SEGMENT_HEIGHT * 0.5))
		var hole: float = _first_uncovered(spans, top, bottom)
		if hole < bottom:
			problems.append("%s: %s duvar kaplamıyor (y %.0f, görünür %.0f–%.0f)" % [
				label, "sol" if side < 0.0 else "sağ", hole, top, bottom])
	# Çöküş duvarı ve arka plan bütün genişliği kaplar.
	var wall: CollapseWall = run.get_node("%CollapseWall") as CollapseWall
	var edge: PackedVector2Array = wall.edge_points()
	if edge.is_empty() or edge[0].x > -half or edge[edge.size() - 1].x < half:
		problems.append("%s: çöküş duvarı ekranı kaplamıyor" % label)
	var background_view: Vector2 = (run.get_node("%Background") as Background).get("_view")
	if not background_view.is_equal_approx(view):
		problems.append("%s: arka plan %s, ekran %s" % [label, background_view, view])
	return problems


## Aralıkların [from, to]'yu kaplayamadığı ilk y; kaplıyorsa to.
func _first_uncovered(spans: Array[Vector2], from: float, to: float) -> float:
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var reach: float = from
	for span: Vector2 in spans:
		if span.x > reach + TOLERANCE:
			break
		reach = maxf(reach, span.y)
	return minf(reach, to)
