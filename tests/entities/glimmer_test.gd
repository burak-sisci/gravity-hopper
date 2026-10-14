extends GdUnitTestSuite
## Glimmer (M2-13, architecture.md §8.6): oyuncunun toplama alanı değince toplanır; değer
## RunStats'tan Events.glimmer_collected ile duyurulur, tur sonunda RunResult.glimmers'a yazılır.
## Parça havuzdan gelince yeniden etkinleşir. Görünüşü (M3-06) çarpışma yarıçapında yeşil neon
## daire; vuruşta büyüyüp söner.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const GLIMMER_SCENE: PackedScene = preload("res://scenes/entities/glimmer.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"

var _values: Array[int] = []
var _results: Array[RunResult] = []


func before_test() -> void:
	_values.clear()
	_results.clear()
	Events.glimmer_collected.connect(_on_glimmer_collected)
	Events.run_ended.connect(_on_run_ended)


func after_test() -> void:
	Events.glimmer_collected.disconnect(_on_glimmer_collected)
	Events.run_ended.disconnect(_on_run_ended)


func test_collected_on_the_way_and_counted_in_result() -> void:
	GameManager.begin_run(5, 1)
	var run: Run = auto_free(RUN_SCENE.instantiate()) as Run
	run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	run.run_seed = 5
	var library: ChunkLibrary = ChunkLibrary.new()
	library.chunks = [_glimmer_chunk()]
	(run.get_node("%ChunkSpawner") as ChunkSpawner).library = library
	add_child(run)
	# Oyuncu sol duvarda tırmanır; her parçada sol duvarda iki Glimmer var.
	for frame: int in 400:
		await get_tree().physics_frame
	assert_int(_values.size()).is_greater_equal(2)
	assert_array(_values).contains_same([1, 1])
	assert_int(run.stats.glimmers).is_equal(_values.size())
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_int(_results.size()).is_equal(1)
	assert_int(_results[0].glimmers).is_equal(_values.size())


func test_reset_brings_glimmer_back() -> void:
	var chunk: ChunkInfo = auto_free(_glimmer_chunk().instantiate()) as ChunkInfo
	add_child(chunk)
	var glimmer: Glimmer = chunk.items()[0] as Glimmer
	var values: Array[int] = []
	chunk.glimmer_collected.connect(func(value: int, _at: Vector2) -> void: values.append(value))
	glimmer.area_entered.emit(auto_free(Area2D.new()))
	assert_bool(glimmer.is_taken()).is_true()
	assert_bool(glimmer.visible).is_false()
	# İkinci değme sayılmaz.
	glimmer.area_entered.emit(auto_free(Area2D.new()))
	assert_array(values).is_equal([1])
	chunk.reset()
	assert_bool(glimmer.is_taken()).is_false()
	assert_bool(glimmer.visible).is_true()


func test_round_green_shape_follows_collision_radius() -> void:
	var glimmer: Glimmer = auto_free(GLIMMER_SCENE.instantiate()) as Glimmer
	add_child(glimmer)
	var radius: float = ((glimmer.get_node("Shape") as CollisionShape2D).shape as CircleShape2D).radius
	var visual: NeonShape = glimmer.get_node("Visual") as NeonShape
	assert_object(visual.shown_color()).is_equal(Neon.STYLE.glimmer_color)
	assert_bool(visual.sharp).is_false()
	assert_int(visual.polygon.size()).is_equal(Neon.STYLE.glimmer_segments)
	for point: Vector2 in visual.polygon:
		assert_float(point.length()).is_equal_approx(radius, 0.001)


func test_sparkles_on_the_beat() -> void:
	var chunk: ChunkInfo = auto_free(_glimmer_chunk().instantiate()) as ChunkInfo
	add_child(chunk)
	var visual: Node2D = chunk.items()[0].get_node("Visual") as Node2D
	chunk.set_beat(3.0)
	assert_float(visual.scale.x).is_equal_approx(1.0 + Neon.STYLE.glimmer_pulse_scale, 0.001)
	chunk.set_beat(3.9)
	assert_float(visual.scale.x).is_equal_approx(1.0, 0.001)


func test_stats_apply_multiplier() -> void:
	var stats: RunStats = RunStats.new()
	assert_int(stats.add_glimmer(1)).is_equal(1)
	stats.multiplier = 3
	assert_int(stats.add_glimmer(1)).is_equal(3)
	assert_int(stats.glimmers).is_equal(4)


## Sol duvarda (oyuncunun yolunda) 2. ve 5. vuruşta Glimmer olan 6 vuruşluk parça.
func _glimmer_chunk() -> PackedScene:
	var root: ChunkInfo = ChunkInfo.new()
	root.length_beats = 6
	for beat: int in [2, 5]:
		var glimmer: Glimmer = GLIMMER_SCENE.instantiate() as Glimmer
		glimmer.position = Vector2(-400, -beat * 100)
		root.add_child(glimmer)
		glimmer.owner = root
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _on_glimmer_collected(value: int) -> void:
	_values.append(value)


func _on_run_ended(result: RunResult) -> void:
	_results.append(result)
