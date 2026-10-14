extends GdUnitTestSuite
## Turlar arasında korunan parça havuzları (M3-10, ADR-054, architecture.md §8.7): sonraki tur
## aynı parça düğümlerini ödünç alır, yeni düğüm oluşmaz; tur bitince parçalar gizli ve
## bağlantısız havuza döner; Glimmer bağlantısı yalnızca etkin parçalarda. Main havuzu her tura
## verir ve çizim sırası korunur (koridor < parçalar < çöküş duvarı, oyuncu).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")


func test_next_run_borrows_the_same_chunk_nodes() -> void:
	var pools: ChunkPools = auto_free(ChunkPools.new()) as ChunkPools
	add_child(pools)
	var first: Run = _add_run(pools)
	await _frames(30)
	var nodes: Array[Node] = pools.get_children()
	assert_int(nodes.size()).is_greater(0)
	assert_int(first.get_node("%ChunkSpawner").get_child_count()).is_equal(0)
	remove_child(first)
	first.free()
	for node: Node in nodes:
		assert_bool((node as CanvasItem).visible).is_false()
		assert_int((node as ChunkInfo).glimmer_collected.get_connections().size()).is_equal(0)
	var second: Run = _add_run(pools)
	await _frames(30)
	assert_array(pools.get_children()).contains_exactly(nodes)
	var spawner: ChunkSpawner = second.get_node("%ChunkSpawner") as ChunkSpawner
	var active: Array[ChunkInfo] = spawner.active_chunks()
	assert_int(active.size()).is_greater(0)
	for node: Node in nodes:
		var chunk: ChunkInfo = node as ChunkInfo
		var shown: bool = active.has(chunk)
		assert_bool(chunk.visible).is_equal(shown)
		assert_int(chunk.glimmer_collected.get_connections().size()).is_equal(1 if shown else 0)
	assert_int(spawner.pools_grown()).is_equal(0)
	# Tur havuzdan önce silinir (oyunda da World, ChunkPools'tan önce gelir).
	remove_child(second)
	second.free()


func test_main_lends_pools_and_keeps_draw_order() -> void:
	var main: Node = auto_free(MAIN_SCENE.instantiate()) as Node
	add_child(main)
	await _frames(5)
	var pools: ChunkPools = main.get_node("%ChunkPools") as ChunkPools
	var run: Run = main.get_node("%World").get_child(0) as Run
	assert_int(pools.get_child_count()).is_greater(0)
	assert_int(run.get_node("%ChunkSpawner").get_child_count()).is_equal(0)
	assert_int((run.get_node("%Corridor") as CanvasItem).z_index).is_less(pools.z_index)
	for path: String in ["%CollapseWall", "%Player"]:
		assert_int(pools.z_index).is_less((run.get_node(path) as CanvasItem).z_index)


func _add_run(pools: ChunkPools) -> Run:
	var run: Run = RUN_SCENE.instantiate() as Run
	run.run_seed = 5
	run.chunk_pools = pools
	add_child(run)
	return run


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
