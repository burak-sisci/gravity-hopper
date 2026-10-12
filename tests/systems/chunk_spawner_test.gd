extends GdUnitTestSuite
## ChunkSpawner (M2-04, architecture.md §8.2): görünür alanın üstünde iki ekran dolu, parçalar
## boşluksuz ve vuruş ızgarasında, tur sırasında düğüm oluşmaz, harita ekran boyuna bağlı değil.

const LIBRARY: ChunkLibrary = preload("res://data/chunks/chunk_library.tres")
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
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
	assert_array(_chunk_heights(spawner)).not_contains([4.0 * S1_BEAT_PX])
	# S2'den başlayan turda 4 vuruşluk parça da gelir (S2 vuruşu 381,82 px).
	var in_s2: ChunkSpawner = _make(library, 9, 2)
	_scroll(in_s2, 0.0, SCROLL_PX, VIEW_HEIGHT)
	var s2_four_beats: float = snappedf(4.0 * SECTORS.def_at(2).beat_px(), 0.01)
	assert_array(_chunk_heights(in_s2)).contains([s2_four_beats])


func test_chunks_stop_at_sector_boundary() -> void:
	# Kısa sektörler: S1 ve S2 100'er m. Parça sınırı aşmaz; S2 tam sınırdan, kendi vuruşuyla başlar.
	var sectors: SectorCatalog = _short_sectors(100.0)
	var spawner: ChunkSpawner = auto_free(ChunkSpawner.new()) as ChunkSpawner
	spawner.library = LIBRARY
	add_child(spawner)
	spawner.setup(RunRng.new(5), _tuning(), sectors, 1, 0.0)
	_scroll(spawner, 0.0, SCROLL_PX, VIEW_HEIGHT)
	assert_int(spawner.placement_sector()).is_equal(3)
	var s1_end: float = -TuningConfig.to_px(100.0)
	var s2_end: float = -TuningConfig.to_px(200.0)
	var s2_beat: float = sectors.def_at(2).beat_px()
	# Nefes alma: 2,5 sn × 700 px/sn = 1750 px → 4,58 vuruş → 5 vuruş boş (M2-09).
	var breath_beats: float = ceilf(sectors.def_at(2).climb_px() * 2.5 / s2_beat)
	assert_float(breath_beats).is_equal(5.0)
	var started_s2: bool = false
	for i: int in spawner.placed_bottoms.size():
		var bottom: float = spawner.placed_bottoms[i]
		if bottom > s1_end + 0.01:
			continue
		if not started_s2:
			started_s2 = true
			assert_float(bottom).is_equal_approx(s1_end - breath_beats * s2_beat, 0.01)
		if bottom > s2_end + 0.01:
			# S2'deki her parça S2 ızgarasında ve S2'nin sonunu aşmıyor.
			var beats: float = (s1_end - bottom) / s2_beat
			assert_float(beats).is_equal_approx(roundf(beats), 0.001)
	assert_bool(started_s2).is_true()
	# Hiçbir parça bir sınırın iki yanına taşmaz (üst kenar, parçanın kendi boyundan).
	var lengths: Dictionary[StringName, int] = _library_lengths()
	for i: int in spawner.placed_bottoms.size():
		var bottom: float = spawner.placed_bottoms[i]
		var sector: int = 1 if bottom > s1_end + 0.01 else (2 if bottom > s2_end + 0.01 else 3)
		var top: float = bottom - lengths[spawner.placed_names[i]] * sectors.def_at(sector).beat_px()
		for edge: float in [s1_end, s2_end]:
			assert_bool(bottom > edge + 0.01 and top < edge - 0.01).is_false()


func test_difficulty_rises_through_sector() -> void:
	# S1: hedef zorluk 1 → 3. Beş tohumda S1'in ilk ve son üçte birindeki parçalar karşılaştırılır.
	var s1_px: float = TuningConfig.to_px(SECTORS.def_at(1).length)
	var early: Array[int] = []
	var late: Array[int] = []
	for run_seed: int in [11, 22, 33, 44, 55]:
		var spawner: ChunkSpawner = _make(LIBRARY, run_seed)
		_scroll(spawner, 0.0, s1_px, VIEW_HEIGHT)
		var previous_target: float = 0.0
		for i: int in spawner.placed_bottoms.size():
			var climbed: float = -spawner.placed_bottoms[i]
			if climbed >= s1_px:
				break
			assert_float(spawner.placed_targets[i]).is_greater_equal(previous_target)
			previous_target = spawner.placed_targets[i]
			if climbed < s1_px / 3.0:
				early.append(spawner.placed_difficulties[i])
			elif climbed > s1_px * 2.0 / 3.0:
				late.append(spawner.placed_difficulties[i])
	var early_mean: float = _mean(early)
	var late_mean: float = _mean(late)
	assert_float(late_mean - early_mean).override_failure_message(
			"Sektör başı %.2f, sonu %.2f" % [early_mean, late_mean]).is_greater_equal(1.0)


func test_recent_chunks_are_not_repeated() -> void:
	var spawner: ChunkSpawner = _make(LIBRARY, 8)
	var s1_px: float = TuningConfig.to_px(SECTORS.def_at(1).length)
	_scroll(spawner, 0.0, s1_px, VIEW_HEIGHT)
	var names: Array[StringName] = spawner.placed_names
	for i: int in names.size():
		# Sektörün son 4000 px'inde sığan parça azalır; orada kural esneyebilir.
		if -spawner.placed_bottoms[i] > s1_px - 4000.0:
			break
		var recent: Array[StringName] = names.slice(maxi(0, i - 3), i)
		assert_bool(recent.has(names[i])).override_failure_message(
				"%d. parça %s son üç parçada var: %s" % [i, names[i], recent]).is_false()


func test_wider_corridor_moves_wall_hazards() -> void:
	var spawner: ChunkSpawner = _make(LIBRARY, 1)
	_view(spawner, 0.0, VIEW_HEIGHT)
	spawner.update_view(-LOOKAHEAD_PX, -LOOKAHEAD_PX + VIEW_HEIGHT, 500.0)
	for chunk: ChunkInfo in spawner.active_chunks():
		for item: Node2D in chunk.items():
			# Duvardaki öğeler duvarda kalır (Glimmer'lar koridorun içinde orantılı kayar).
			if is_equal_approx(absf(chunk.design_position(item).x), ChunkInfo.DESIGN_HALF_WIDTH):
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


func _make(library: ChunkLibrary, run_seed: int, sector: int = 1) -> ChunkSpawner:
	var spawner: ChunkSpawner = auto_free(ChunkSpawner.new()) as ChunkSpawner
	spawner.library = library
	add_child(spawner)
	spawner.setup(RunRng.new(run_seed), _tuning(), SECTORS, sector, 0.0)
	return spawner


## Kütüphanedeki parçaların boyu (vuruş), dosya adına göre.
func _library_lengths() -> Dictionary[StringName, int]:
	var lengths: Dictionary[StringName, int] = {}
	for scene: PackedScene in LIBRARY.chunks:
		var info: ChunkInfo = scene.instantiate() as ChunkInfo
		lengths[StringName(scene.resource_path.get_file().get_basename())] = info.length_beats
		info.free()
	return lengths


## Gerçek S1–S3'ün kısa kopyası (hız ve tempo aynı, boylar kısa).
func _short_sectors(length: float) -> SectorCatalog:
	var sectors: SectorCatalog = SectorCatalog.new()
	for i: int in SECTORS.count():
		var def: SectorDef = SECTORS.def_at(i + 1).duplicate() as SectorDef
		def.length = length
		sectors.sectors.append(def)
	return sectors


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


func _mean(values: Array[int]) -> float:
	var total: float = 0.0
	for value: int in values:
		total += value
	return total / maxi(values.size(), 1)


func _count_nodes(root: Node) -> int:
	return root.find_children("*", "", true, false).size()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
