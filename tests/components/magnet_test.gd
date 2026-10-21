extends GdUnitTestSuite
## Mıknatıs (M4-04, architecture.md §8.6): menzil toplama alanının ötesine eklenir ve seviyeyle
## büyür; menzile giren Glimmer yakalanır, hızlanarak hedefe akar, menzilden çıksa da bırakılmaz.
## Parça havuzdan gelince Glimmer tasarımdaki yerine döner.

const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const GLIMMER_SCENE: PackedScene = preload("res://scenes/entities/glimmer.tscn")
const TUNING: TuningConfig = preload("res://data/tuning/default_tuning.tres")
const STEP: float = 1.0 / 60.0

var _radius: float = 0.0


func test_reach_extends_the_pickup_radius_and_grows_with_level() -> void:
	var def: UpgradeDef = CATALOG.get_def(&"magnet")
	var previous: float = 0.0
	for level: int in range(1, def.max_level() + 1):
		var magnet: Magnet = Magnet.new(TUNING, def.value_at(level))
		var reach: float = magnet.reach_px(18.0)
		assert_float(reach).is_equal_approx(
				TuningConfig.to_px(TUNING.pickup_radius + def.value_at(level)) + 18.0, 0.001)
		assert_float(reach).is_greater(previous)
		previous = reach
	# Sv1 bile toplama alanından (1,5 m + Glimmer) belirgin uzağa uzanır; Sv5 ≈ 6,9 m.
	assert_float(Magnet.new(TUNING, def.value_at(1)).reach_px(18.0)).is_equal_approx(183.0, 0.001)
	assert_float(Magnet.new(TUNING, def.value_at(5)).reach_px(18.0)).is_equal_approx(343.0, 0.001)


func test_pull_starts_at_the_start_speed_then_accelerates() -> void:
	var magnet: Magnet = Magnet.new(TUNING, 1.8)
	var start: float = TuningConfig.to_px(TUNING.magnet_pull_speed)
	assert_float(magnet.pull_speed(0.0, STEP)).is_equal_approx(start, 0.001)
	assert_float(magnet.pull_speed(start, STEP)).is_equal_approx(
			start + TuningConfig.to_px(TUNING.magnet_pull_accel) * STEP, 0.001)


func test_glimmer_in_reach_flows_to_the_target_and_stays_caught() -> void:
	var glimmer: Glimmer = _glimmer(Vector2.ZERO)
	var magnet: Magnet = Magnet.new(TUNING, 1.8)
	var reach: float = magnet.reach_px(_radius)
	# Menzilin hemen dışı: kıpırdamaz.
	var target: Vector2 = Vector2(reach + 1.0, 0.0)
	glimmer.attract(target, magnet, STEP)
	assert_bool(glimmer.is_pulled()).is_false()
	assert_vector(glimmer.global_position).is_equal(Vector2.ZERO)
	# Menzilin içi: yakalanır ve hedefe doğru ilk hızla bir adım gider.
	target = Vector2(reach - 1.0, 0.0)
	glimmer.attract(target, magnet, STEP)
	assert_bool(glimmer.is_pulled()).is_true()
	var first: float = glimmer.global_position.x
	assert_float(first).is_equal_approx(TuningConfig.to_px(TUNING.magnet_pull_speed) * STEP, 0.001)
	# Hedef menzilin çok dışına kaçsa da çekim sürer ve hızlanır.
	target = Vector2(reach * 3.0, 0.0)
	glimmer.attract(target, magnet, STEP)
	assert_float(glimmer.global_position.x - first).is_greater(first)
	# Hedefe varınca orada durur (geçip gitmez).
	for i: int in 120:
		glimmer.attract(target, magnet, STEP)
	assert_vector(glimmer.global_position).is_equal(target)


func test_taken_glimmer_is_not_pulled() -> void:
	var glimmer: Glimmer = _glimmer(Vector2.ZERO)
	glimmer.area_entered.emit(auto_free(Area2D.new()))
	glimmer.attract(Vector2(10.0, 0.0), Magnet.new(TUNING, 5.0), STEP)
	assert_bool(glimmer.is_pulled()).is_false()
	assert_vector(glimmer.global_position).is_equal(Vector2.ZERO)


func test_pooled_chunk_puts_the_glimmer_back() -> void:
	var chunk: ChunkInfo = ChunkInfo.new()
	chunk.length_beats = 4
	var glimmer: Glimmer = GLIMMER_SCENE.instantiate() as Glimmer
	glimmer.position = Vector2(-300.0, -200.0)
	chunk.add_child(glimmer)
	add_child(auto_free(chunk))
	chunk.layout(ChunkInfo.BEAT_GRID_PX, ChunkInfo.DESIGN_HALF_WIDTH)
	var target: Vector2 = glimmer.global_position + Vector2(100.0, 0.0)
	chunk.attract(target, Magnet.new(TUNING, 5.0), STEP)
	assert_bool(glimmer.is_pulled()).is_true()
	assert_vector(glimmer.position).is_not_equal(Vector2(-300.0, -200.0))
	# Havuzdan yeniden gelince (ChunkSpawner: reset + layout) tasarımdaki yerinde, yakalanmamış.
	chunk.reset()
	chunk.layout(ChunkInfo.BEAT_GRID_PX, ChunkInfo.DESIGN_HALF_WIDTH)
	assert_bool(glimmer.is_pulled()).is_false()
	assert_vector(glimmer.position).is_equal(Vector2(-300.0, -200.0))


func _glimmer(at: Vector2) -> Glimmer:
	var glimmer: Glimmer = auto_free(GLIMMER_SCENE.instantiate()) as Glimmer
	glimmer.position = at
	add_child(glimmer)
	_radius = ((glimmer.get_node("Shape") as CollisionShape2D).shape as CircleShape2D).radius
	return glimmer
