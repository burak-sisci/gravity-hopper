extends GdUnitTestSuite
## Kuşanılan iz turda (M4-08, GDD §11): yükteki iz oyuncunun izine verilir ve sektör değişse de
## kendi renklerinde kalır; varsayılan iz sektörün çevre rengini izler; çekirdek her izde beyaz,
## izin düğüm sayısı aynı. Main, kuşanılan izi sonraki turun yüküne koyar.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const TRAILS: TrailCatalog = preload("res://data/trails/trail_catalog.tres")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const GOLD: StringName = &"trail_gold"


func before_test() -> void:
	Progression.reset()


func after_test() -> void:
	GameManager.change_state(GameManager.AppState.BOOT)
	Progression.reset()


func test_equipped_trail_keeps_its_colors_in_every_sector() -> void:
	var gold: TrailDef = TRAILS.get_def(GOLD)
	var tail: Color = Color(gold.colors[gold.colors.size() - 1], 0.0)
	var plain: int = -1
	for sector: int in [1, 2]:
		var run: Run = _start(gold, sector)
		var trail: Trail = _trail(run)
		await _frames(5)
		assert_object(trail.trail_def()).is_same(gold)
		var last: int = trail.gradient.get_point_count() - 1
		assert_bool(trail.gradient.get_color(last).is_equal_approx(tail)).is_true()
		assert_bool(trail.glow_color.is_equal_approx(gold.glow_color)).is_true()
		_assert_white_core(run)
		if plain < 0:
			plain = trail.get_child_count()
		assert_int(trail.get_child_count()).is_equal(plain)
		_free(run)


func test_default_trail_follows_the_sector_color() -> void:
	for sector: int in [1, 2]:
		var run: Run = _start(null, sector)
		var trail: Trail = _trail(run)
		await _frames(5)
		var ambient: Color = run.sectors.def_at(sector).palette.ambient
		assert_bool(trail.gradient.get_color(1).is_equal_approx(Color(ambient, 0.0))).is_true()
		assert_bool(trail.glow_color.is_equal_approx(ambient)).is_true()
		assert_float(trail.width).is_equal(Neon.STYLE.trail_width)
		_assert_white_core(run)
		_free(run)


func test_main_gives_the_equipped_trail_to_the_next_run() -> void:
	Progression.grant_trail(GOLD)
	Progression.equip_trail(GOLD)
	var main: Node = auto_free(MAIN_SCENE.instantiate()) as Node
	add_child(main)
	await _frames(2)
	var run: Run = main.get_node("%World").get_child(0) as Run
	assert_object(run.loadout.trail).is_same(TRAILS.get_def(GOLD))
	assert_object(_trail(run).trail_def()).is_same(TRAILS.get_def(GOLD))


func _start(def: TrailDef, sector: int) -> Run:
	var run: Run = RUN_SCENE.instantiate() as Run
	run.tuning = ResourceLoader.load(TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	run.run_seed = 3
	run.start_sector = sector
	run.loadout.trail = def
	add_child(run)
	return run


func _trail(run: Run) -> Trail:
	return run.get_node("%Player/Trail") as Trail


func _assert_white_core(run: Run) -> void:
	var core: NeonShape = run.get_node("%Player/Visual") as NeonShape
	assert_bool(core.shown_color().is_equal_approx(Neon.STYLE.player_color)).is_true()


func _free(run: Run) -> void:
	remove_child(run)
	run.free()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
