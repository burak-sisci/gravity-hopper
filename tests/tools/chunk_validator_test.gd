extends GdUnitTestSuite
## Parça doğrulayıcısı (M2-05, architecture.md §8.2): adil parçayı geçirir, çözülemeyeni,
## fazla sıkışığı ve kenara taşanı yakalar; kamera kuralı ve sektör kapsamı.

const SAMPLE_SCENE: PackedScene = preload("res://scenes/levels/chunks/spike_zigzag_01.tscn")
const UNSOLVABLE_SCENE: PackedScene = preload("res://tools/fixtures/chunk_unsolvable.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/entities/spike.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const LEFT: float = -450.0
const RIGHT: float = 450.0

var _validator: ChunkValidator


func before_test() -> void:
	_validator = ChunkValidator.new(_tuning(), ChunkValidator.player_body_size())


func test_reads_player_body_from_scene() -> void:
	assert_vector(ChunkValidator.player_body_size()).is_equal(Vector2(60, 80))


func test_sample_chunk_is_fair_in_every_sector() -> void:
	var chunk: ChunkInfo = auto_free(SAMPLE_SCENE.instantiate()) as ChunkInfo
	assert_array(_validator.chunk_errors(chunk)).is_empty()


func test_both_walls_blocked_is_caught() -> void:
	# İki duvar bir vuruş boyunca dikenli: tek geçiş bu kadar uzun havada kalamaz.
	var chunk: ChunkInfo = auto_free(UNSOLVABLE_SCENE.instantiate()) as ChunkInfo
	var errors: PackedStringArray = _validator.chunk_errors(chunk)
	assert_int(errors.size()).is_equal(5)
	assert_str(errors[0]).starts_with("S1").contains("geçilemiyor").contains("Spike")


func test_spike_pair_can_be_passed_mid_flip() -> void:
	# Aynı yükseklikte iki duvarda diken: geçişin ortasında aralarından süzülmek mümkün.
	var chunk: ChunkInfo = _chunk(6, [Vector3(LEFT, -300, 1), Vector3(RIGHT, -300, -1)])
	assert_array(_validator.sector_errors(chunk, 5)).is_empty()


func test_flips_too_close_fail_at_high_speed() -> void:
	# Her vuruşta taraf değiştiren dikenler: S5'te (vuruş 0,43 sn) iki çevirme arası
	# geçiş + tepki payından (≈ 0,57 sn) kısa kalır.
	var chunk: ChunkInfo = _chunk(8, [
		Vector3(LEFT, -200, 1), Vector3(RIGHT, -300, -1), Vector3(LEFT, -400, 1),
		Vector3(RIGHT, -500, -1), Vector3(LEFT, -600, 1),
	])
	assert_array(_validator.sector_errors(chunk, 5)).is_not_empty()
	# Aynı dikenler iki vuruş arayla her sektörde adil.
	var relaxed: ChunkInfo = _chunk(8, [
		Vector3(LEFT, -200, 1), Vector3(RIGHT, -400, -1), Vector3(LEFT, -600, 1),
	])
	assert_array(_validator.chunk_errors(relaxed)).is_empty()


func test_hazard_right_after_chunk_start_is_unfair() -> void:
	# Önceki parçadan yarım geçişle gelen oyuncu bu dikenden kaçamaz (birleşim yeri kuralı).
	var chunk: ChunkInfo = _chunk(4, [Vector3(LEFT, -50, 1)])
	var errors: PackedStringArray = _validator.sector_errors(chunk, 1)
	assert_array(errors).is_not_empty()
	assert_str(errors[0]).contains("Spike0")


func test_hazard_crossing_chunk_edge_is_caught() -> void:
	var chunk: ChunkInfo = _chunk(4, [Vector3(LEFT, 0, 1)])
	assert_str(_validator.sector_errors(chunk, 1)[0]).contains("taşıyor")


func test_view_rule_uses_lookahead() -> void:
	assert_array(_validator.view_errors()).is_empty()
	var short_view: TuningConfig = _tuning()
	short_view.lookahead = 20.0
	var errors: PackedStringArray = ChunkValidator.new(
			short_view, ChunkValidator.player_body_size()).view_errors()
	# 20 m ileri görüş: S1'de 1,62 sn yeter, S4'te 1,08 sn ve S5'te 0,97 sn yetmez.
	assert_int(errors.size()).is_equal(2)
	assert_str(errors[0]).starts_with("S4")


func test_every_sector_needs_a_chunk() -> void:
	var early: ChunkInfo = _chunk(4, [])
	early.max_sector = 2
	var chunks: Array[ChunkInfo] = [early]
	var errors: PackedStringArray = ChunkValidator.coverage_errors(chunks)
	assert_array(Array(errors)).contains_exactly(["S3 için parça yok", "S4 için parça yok",
			"S5 için parça yok"])


## Diken listesinden parça kurar: (x, tasarım y, scale.x).
func _chunk(length: int, spikes: Array[Vector3]) -> ChunkInfo:
	var chunk: ChunkInfo = auto_free(ChunkInfo.new()) as ChunkInfo
	chunk.length_beats = length
	for i: int in spikes.size():
		var spike: Node2D = SPIKE_SCENE.instantiate() as Node2D
		spike.name = "Spike%d" % i
		spike.position = Vector2(spikes[i].x, spikes[i].y)
		spike.scale.x = spikes[i].z
		chunk.add_child(spike)
	return chunk


func _tuning() -> TuningConfig:
	return ResourceLoader.load(TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
