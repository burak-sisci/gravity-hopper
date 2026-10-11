extends GdUnitTestSuite
## ChunkSpawner (M2-04, architecture.md §8.2): görünür alanın üstünde iki ekran dolu, parçalar
## boşluksuz ve vuruş ızgarasında, tur sırasında düğüm oluşmaz, harita ekran boyuna bağlı değil.

const LIBRARY: ChunkLibrary = preload("res://data/chunks/chunk_library.tres")
const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const SAMPLE_SCENE: PackedScene = preload("res://scenes/levels/chunks/spike_zigzag_01.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/entities/spike.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
## S1 vuruşu: 12 m/sn, 100 BPM → 360 px.
const S1_BEAT_PX: float = 360.0
const HALF_WIDTH: float = 450.0
const VIEW_HEIGHT: float = 1920.0
## 20:9 ekranın görünür boyu.
const TALL_VIEW_HEIGHT: float = 2400.0
## Kameranın oyuncunun üstünde bıraktığı alan (28 m).
const LOOKAHEAD_PX: float = 1400.0
## S1'de bir fizik adımında tırmanılan mesafe.
const STEP_PX: float = 10.0
## Kaydırma denemelerinin boyu (400 m): parçalar defalarca havuza dönüp geri gelir.
const SCROLL_PX: float = 20000.0


func test_first_chunk_starts_on_a_whole_beat() -> void:
	var spawner: ChunkSpawner = _make(LIBRARY, 1)
	_view(spawner, 0.0, VIEW_HEIGHT)
	# 25 m = 1250 px → 4 vuruş = 1440 px.
	assert_float(spawner.placed_bottoms[0]).is_equal_approx(-4.0 * S1_BEAT_PX, 0.01)


func test_fills_two_screens_ahead_without_gaps() -> void:
	var spawner: ChunkSpawner = _make(_two_chunk_library(), 7)
	for climbed: float in [0.0, 5000.0, 12000.0]:
		_view(spawner, climbed, VIEW_HEIGHT)
		var chunks: Array[ChunkInfo] = spawner.active_chunks()
		var view_top: float = -climbed - LOOKAHEAD_PX
		var last: ChunkInfo = chunks[chunks.size() - 1]
		assert_float(last.top_y()).is_less_equal(view_top - 2.0 * VIEW_HEIGHT)
		for i: int in range(1, chunks.size()):
			assert_float(chunks[i].position.y).is_equal_approx(chunks[i - 1].top_y(), 0.01)
		# Ekranın tamamen altına inen parça etkin listede kalmaz.
		assert_float(chunks[0].top_y()).is_less_equal(view_top + VIEW_HEIGHT + 100.0)


func test_no_nodes_created_while_scrolling() -> void:
	var spawner: ChunkSpawner = _make(_two_chunk_library(), 3)
	_view(spawner, 0.0, TALL_VIEW_HEIGHT)
	var start_count: int = _count_nodes(spawner)
	_scroll(spawner, 0.0, SCROLL_PX, TALL_VIEW_HEIGHT)
	assert_int(_count_nodes(spawner)).is_equal(start_count)
	assert_int(spawner.pools_grown()).is_equal(0)
	assert_int(spawner.placed_bottoms.size()).is_greater_equal(8)
	# Etkin olmayan her parça gizli ve işlemsiz.
	var active: Array[ChunkInfo] = spawner.active_chunks()
	for child: Node in spawner.get_children():
		if not active.has(child):
			assert_bool((child as Node2D).visible).is_false()
			assert_int(child.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)


func test_same_seed_gives_same_map_on_any_screen() -> void:
	var library: ChunkLibrary = _two_chunk_library()
	var short_screen: ChunkSpawner = _make(library, 42)
	var tall_screen: ChunkSpawner = _make(library, 42)
	var other_seed: ChunkSpawner = _make(library, 43)
	var climbed: float = 0.0
	while climbed < SCROLL_PX:
		climbed += STEP_PX
		_view(short_screen, climbed, VIEW_HEIGHT)
		_view(tall_screen, climbed, TALL_VIEW_HEIGHT)
		_view(other_seed, climbed, VIEW_HEIGHT)
	var count: int = short_screen.placed_bottoms.size()
	assert_int(count).is_greater_equal(8)
	# Uzun ekran daha önce yerleştirir; ortak kısım aynı olmalı.
	assert_array(tall_screen.placed_bottoms.slice(0, count)).is_equal(short_screen.placed_bottoms)
	assert_array(other_seed.placed_bottoms.slice(0, count)).is_not_equal(
			short_screen.placed_bottoms)


func test_chunks_outside_sector_are_not_chosen() -> void:
	var library: ChunkLibrary = ChunkLibrary.new()
	library.chunks = [SAMPLE_SCENE, _packed_chunk(4, 2)]
	var spawner: ChunkSpawner = _make(library, 9)
	_scroll(spawner, 0.0, SCROLL_PX, VIEW_HEIGHT)
	# S1'de yalnızca örnek parça (8 vuruş) seçilebilir.
	var gaps: Array[float] = _chunk_heights(spawner)
	assert_array(gaps).not_contains([4.0 * S1_BEAT_PX])
	spawner.sector = 2
	_scroll(spawner, SCROLL_PX, SCROLL_PX * 2.0, VIEW_HEIGHT)
	assert_array(_chunk_heights(spawner)).contains([4.0 * S1_BEAT_PX])


func test_wider_corridor_moves_wall_hazards() -> void:
	var spawner: ChunkSpawner = _make(LIBRARY, 1)
	_view(spawner, 0.0, VIEW_HEIGHT)
	spawner.update_view(-LOOKAHEAD_PX, -LOOKAHEAD_PX + VIEW_HEIGHT, 500.0)
	for chunk: ChunkInfo in spawner.active_chunks():
		for item: Node2D in chunk.items():
			assert_float(absf(item.position.x)).is_equal_approx(500.0, 0.01)


func test_run_creates_no_nodes_during_play() -> void:
	var run: Run = auto_free(RUN_SCENE.instantiate()) as Run
	run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	run.run_seed = 2024
	add_child(run)
	# Darbeler yok sayılsın ki oyuncu tırmanmaya devam etsin.
	Events.debug_invincibility_changed.emit(true)
	await _frames(5)
	var start_count: int = _count_nodes(run)
	var start_y: float = (run.get_node("Player") as Node2D).position.y
	await _frames(900)
	Events.debug_invincibility_changed.emit(false)
	assert_float(start_y - (run.get_node("Player") as Node2D).position.y).is_greater(8000.0)
	assert_int(_count_nodes(run)).is_equal(start_count)
	assert_int((run.get_node("%ChunkSpawner") as ChunkSpawner).pools_grown()).is_equal(0)


func _make(library: ChunkLibrary, run_seed: int) -> ChunkSpawner:
	var spawner: ChunkSpawner = auto_free(ChunkSpawner.new()) as ChunkSpawner
	spawner.library = library
	add_child(spawner)
	spawner.setup(RunRng.new(run_seed), _tuning(), 0.0)
	return spawner


## Oyuncu 0'dan climbed kadar tırmanmışken kameranın göreceği alan (Run ile aynı kural).
func _view(spawner: ChunkSpawner, climbed: float, view_height: float) -> void:
	var view_top: float = -climbed - LOOKAHEAD_PX
	spawner.update_view(view_top, view_top + view_height, HALF_WIDTH)


func _scroll(spawner: ChunkSpawner, from: float, to: float, view_height: float) -> void:
	var climbed: float = from
	while climbed < to:
		climbed += STEP_PX
		_view(spawner, climbed, view_height)


func _tuning() -> TuningConfig:
	return ResourceLoader.load(TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig


## Örnek parça (8 vuruş) + 5 vuruşluk bir test parçası: seçim sırası alt kenarlardan okunur.
func _two_chunk_library() -> ChunkLibrary:
	var library: ChunkLibrary = ChunkLibrary.new()
	library.chunks = [SAMPLE_SCENE, _packed_chunk(5, 1)]
	return library


func _packed_chunk(length: int, min_sector: int) -> PackedScene:
	var root: ChunkInfo = ChunkInfo.new()
	root.length_beats = length
	root.min_sector = min_sector
	var spike: Node2D = SPIKE_SCENE.instantiate() as Node2D
	spike.position = Vector2(-450, -100)
	root.add_child(spike)
	spike.owner = root
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _chunk_heights(spawner: ChunkSpawner) -> Array[float]:
	var heights: Array[float] = []
	for i: int in range(1, spawner.placed_bottoms.size()):
		heights.append(snappedf(spawner.placed_bottoms[i - 1] - spawner.placed_bottoms[i], 0.01))
	return heights


func _count_nodes(root: Node) -> int:
	return root.find_children("*", "", true, false).size()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
