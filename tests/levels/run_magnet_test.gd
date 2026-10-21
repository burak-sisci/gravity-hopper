extends GdUnitTestSuite
## Mıknatıs turda (M4-04, architecture.md §8.6): seviye arttıkça oyuncunun yolundan daha uzaktaki
## Glimmer toplanır; mıknatıs haritayı değiştirmez ve tur sırasında düğüm oluşturmaz
## (.clauderules §6).

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const GLIMMER_SCENE: PackedScene = preload("res://scenes/entities/glimmer.tscn")
const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
## Duvarın iç kenarı (koridor 18 m → 450 px); oyuncunun merkezi bundan gövdenin yarısı içeride.
const WALL_EDGE_X: float = 450.0
## Glimmer'ların oyuncunun yolundan yatay uzaklığı (m): 4 m Sv3'ten, 6,5 m yalnızca Sv5'te
## menzilde (menzil = 1,5 m toplama + mıknatıs + Glimmer yarıçapı).
const NEAR_M: float = 4.0
const FAR_M: float = 6.5
const MAP_FRAMES: int = 900
const MAP_SEED: int = 4242
const SETTLE_FRAMES: int = 40
## Parçanın üstünden bu kadar sonra (px) parçadaki toplama bitmiştir.
const PASS_MARGIN: float = 400.0
const MAX_FRAMES: int = 1200

var _run: Run
var _player: Player


func after_test() -> void:
	Events.debug_invincibility_changed.emit(false)


func test_higher_level_collects_farther_glimmers() -> void:
	assert_array(await _taken_at_level(0)).is_equal([false, false])
	assert_array(await _taken_at_level(1)).is_equal([false, false])
	assert_array(await _taken_at_level(3)).is_equal([true, false])
	assert_array(await _taken_at_level(5)).is_equal([true, true])


func test_map_unchanged_and_no_nodes_created() -> void:
	await _start(0.0, null)
	await _frames(MAP_FRAMES)
	var plain: Array[StringName] = _spawner().placed_names.duplicate()
	var plain_glimmers: int = _run.stats.glimmers
	_free_run()
	var pools: ChunkPools = auto_free(ChunkPools.new()) as ChunkPools
	add_child(pools)
	await _start(CATALOG.get_def(&"magnet").value_at(5), pools)
	var nodes: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	await _frames(MAP_FRAMES)
	assert_float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)).is_equal(nodes)
	assert_int(_spawner().pools_grown()).is_equal(0)
	assert_array(_spawner().placed_names).is_equal(plain)
	assert_int(plain.size()).is_greater_equal(4)
	# Mıknatıs gerçekten çalıştı: aynı haritada daha çok Glimmer.
	assert_int(_run.stats.glimmers).is_greater(plain_glimmers)
	# Tur havuzdan önce silinir (oyunda da World, ChunkPools'tan önce gelir).
	_free_run()


## Sol duvarda tırmanan oyuncunun yolundan NEAR_M ve FAR_M uzaktaki iki Glimmer'lık parça;
## oyuncu ilk parçayı geçince hangilerinin toplandığı.
func _taken_at_level(level: int) -> Array[bool]:
	var range_m: float = CATALOG.get_def(&"magnet").value_at(level)
	_run = auto_free(_make_run(range_m)) as Run
	var half_body: float = ((_player.get_node("Body") as CollisionShape2D).shape \
			as RectangleShape2D).size.x * 0.5
	var lane_x: float = -WALL_EDGE_X + half_body
	var root: ChunkInfo = ChunkInfo.new()
	root.length_beats = 6
	for pair: Vector2 in [Vector2(NEAR_M, 2.0), Vector2(FAR_M, 5.0)]:
		var glimmer: Glimmer = GLIMMER_SCENE.instantiate() as Glimmer
		glimmer.position = Vector2(lane_x + TuningConfig.to_px(pair.x), -pair.y * 100.0)
		root.add_child(glimmer)
		glimmer.owner = root
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	var library: ChunkLibrary = ChunkLibrary.new()
	library.chunks = [scene]
	(_run.get_node("%ChunkSpawner") as ChunkSpawner).library = library
	add_child(_run)
	Events.debug_invincibility_changed.emit(true)
	var first: ChunkInfo = (_run.get_node("%ChunkSpawner") as ChunkSpawner).active_chunks()[0]
	var frames: int = 0
	while _player.position.y > first.top_y() - PASS_MARGIN and frames < MAX_FRAMES:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES)
	var taken: Array[bool] = []
	for item: Node2D in first.items():
		taken.append((item as Glimmer).is_taken())
	remove_child(_run)
	return taken


## Ölümsüz, dokunuşsuz bir tur başlatır (gerçek parça kütüphanesi, sabit tohum).
func _start(range_m: float, pools: ChunkPools) -> void:
	_run = _make_run(range_m)
	_run.run_seed = MAP_SEED
	_run.chunk_pools = pools
	add_child(_run)
	Events.debug_invincibility_changed.emit(true)
	await _frames(SETTLE_FRAMES)


func _spawner() -> ChunkSpawner:
	return _run.get_node("%ChunkSpawner") as ChunkSpawner


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _make_run(range_m: float) -> Run:
	var run: Run = RUN_SCENE.instantiate() as Run
	run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	run.run_seed = 12345
	var loadout: RunLoadout = RunLoadout.new()
	loadout.magnet_m = range_m
	run.loadout = loadout
	_player = run.get_node("Player") as Player
	return run


func _free_run() -> void:
	remove_child(_run)
	_run.free()
