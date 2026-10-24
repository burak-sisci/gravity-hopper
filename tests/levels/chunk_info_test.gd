extends GdUnitTestSuite
## Desen parçası biçimi (M2-03, architecture.md §8.2): ChunkInfo değerleri, vuruş ızgarası ve
## tasarımdan dünyaya ölçekleme. Klasördeki her parça ızgara kurallarına uymalı.

const CHUNK_DIR: String = "res://scenes/levels/chunks/"
const SAMPLE_PATH: String = "res://scenes/levels/chunks/spike_zigzag_01.tscn"
const SPIKE_SCENE: PackedScene = preload("res://scenes/entities/spike.tscn")
const LIBRARY: ChunkLibrary = preload("res://data/chunks/chunk_library.tres")
## GDD §12: S1 12 m/sn, 100 BPM; S3 16 m/sn, 120 BPM.
const S1_BEAT_PX: float = 360.0
const S3_BEAT_PX: float = 400.0


func test_sample_chunk_values_are_read() -> void:
	var chunk: ChunkInfo = _load(SAMPLE_PATH)
	assert_int(chunk.difficulty).is_equal(2)
	assert_int(chunk.min_sector).is_equal(1)
	assert_int(chunk.max_sector).is_equal(6)
	assert_int(chunk.length_beats).is_equal(8)
	assert_array(chunk.tags).contains_exactly([&"zigzag"])
	# Üç diken ve bir Glimmer (M2-13).
	assert_int(chunk.items().size()).is_equal(4)


func test_every_chunk_fits_the_grid() -> void:
	var paths: PackedStringArray = _chunk_paths()
	assert_int(paths.size()).is_greater(0)
	for path: String in paths:
		var root: Node = auto_free((load(path) as PackedScene).instantiate()) as Node
		assert_object(root).override_failure_message(
				"%s kökünde ChunkInfo yok" % path).is_instanceof(ChunkInfo)
		if root is ChunkInfo:
			add_child(root)
			var errors: PackedStringArray = (root as ChunkInfo).design_errors()
			assert_array(errors).override_failure_message(
					"%s: %s" % [path, "; ".join(errors)]).is_empty()


func test_every_chunk_is_in_the_library() -> void:
	var listed: PackedStringArray = PackedStringArray()
	for scene: PackedScene in LIBRARY.chunks:
		listed.append(scene.resource_path)
	assert_array(Array(listed)).contains_exactly_in_any_order(Array(_chunk_paths()))


func test_design_errors_catch_rule_breaks() -> void:
	var chunk: ChunkInfo = auto_free(ChunkInfo.new()) as ChunkInfo
	chunk.length_beats = 4
	chunk.min_sector = 3
	chunk.max_sector = 2
	_add_spike(chunk, Vector2(-450, -130), 1.0) # yarım vuruşa oturmuyor
	_add_spike(chunk, Vector2(450, -500), -1.0) # 4 vuruşluk parçanın dışında
	_add_spike(chunk, Vector2(-450, -100), -1.0) # duvara bakıyor
	_add_spike(chunk, Vector2(-425, -200), 1.0) # 1 m adımına oturmuyor
	_add_spike(chunk, Vector2(450, -300), -1.0) # kurala uygun
	add_child(chunk)
	assert_int(chunk.design_errors().size()).is_equal(5)


func test_gap_rules_and_hazard_types() -> void:
	var chunk: ChunkInfo = auto_free(ChunkInfo.new()) as ChunkInfo
	chunk.length_beats = 4
	_add_gap(chunk, Vector2(-300, -100), 100.0) # duvarda değil
	_add_gap(chunk, Vector2(450, -300), 200.0) # parçanın üstünden taşıyor
	_add_gap(chunk, Vector2(-450, -100), 120.0) # boy yarım vuruşun katı değil
	_add_gap(chunk, Vector2(450, -100), 150.0) # kurala uygun
	add_child(chunk)
	assert_int(chunk.design_errors().size()).is_equal(3)
	var mixed: ChunkInfo = _load("res://scenes/levels/chunks/gap_spike_01.tscn")
	assert_array(mixed.hazard_types()).contains_exactly_in_any_order([&"gap", &"spike"])
	var blocks: ChunkInfo = _load("res://scenes/levels/chunks/block_spike_01.tscn")
	assert_array(blocks.hazard_types()).contains_exactly_in_any_order([&"block", &"spike"])
	var lasers: ChunkInfo = _load("res://scenes/levels/chunks/laser_gate_01.tscn")
	assert_array(lasers.hazard_types()).contains_exactly([&"laser"])
	# Boşluğun dünyadaki aralığı vuruşla ölçeklenir (S2: 381,82 px).
	mixed.position = Vector2(0, -1000)
	mixed.layout(381.82, 450.0)
	var span: Vector2 = mixed.gap_range(mixed.gaps()[0])
	assert_vector(span).is_equal_approx(Vector2(-1000 - 3.5 * 381.82, -1000 - 2.0 * 381.82),
			Vector2(0.01, 0.01))


func test_beat_px_follows_speed_and_bpm() -> void:
	assert_float(ChunkInfo.beat_px(12.0, 100.0)).is_equal_approx(S1_BEAT_PX, 0.001)
	assert_float(ChunkInfo.beat_px(16.0, 120.0)).is_equal_approx(S3_BEAT_PX, 0.001)


func test_layout_scales_positions_not_shapes() -> void:
	var chunk: ChunkInfo = _load(SAMPLE_PATH)
	var spike: Node2D = chunk.get_node("SpikeRight4") as Node2D
	chunk.layout(S1_BEAT_PX, 450.0)
	assert_vector(spike.position).is_equal_approx(Vector2(450, -1440), Vector2(0.01, 0.01))
	assert_vector(spike.scale).is_equal(Vector2(-1, 1))
	assert_float(chunk.height_px(S1_BEAT_PX)).is_equal_approx(2880.0, 0.01)
	# İkinci yerleşim tasarımdan hesaplanır, birikmez; koridor genişleyince duvara yapışık kalır.
	chunk.layout(S3_BEAT_PX, 500.0)
	assert_vector(spike.position).is_equal_approx(Vector2(500, -1600), Vector2(0.01, 0.01))
	assert_array(chunk.design_errors()).is_empty()


func test_allows_sector_range() -> void:
	var chunk: ChunkInfo = auto_free(ChunkInfo.new()) as ChunkInfo
	chunk.min_sector = 2
	chunk.max_sector = 3
	assert_bool(chunk.allows_sector(1)).is_false()
	assert_bool(chunk.allows_sector(2)).is_true()
	assert_bool(chunk.allows_sector(3)).is_true()
	assert_bool(chunk.allows_sector(4)).is_false()


func _load(path: String) -> ChunkInfo:
	var chunk: ChunkInfo = auto_free((load(path) as PackedScene).instantiate()) as ChunkInfo
	add_child(chunk)
	return chunk


func _add_gap(chunk: ChunkInfo, at: Vector2, length: float) -> void:
	var gap: WallGap = WallGap.new()
	gap.position = at
	gap.length = length
	chunk.add_child(gap)


func _add_spike(chunk: ChunkInfo, at: Vector2, facing: float) -> void:
	var spike: Node2D = SPIKE_SCENE.instantiate() as Node2D
	spike.position = at
	spike.scale.x = facing
	chunk.add_child(spike)


func _chunk_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(CHUNK_DIR):
		if file.ends_with(".tscn"):
			paths.append(CHUNK_DIR + file)
	return paths
