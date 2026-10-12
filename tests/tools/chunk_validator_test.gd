extends GdUnitTestSuite
## Parça doğrulayıcısı (M2-05, architecture.md §8.2): adil parçayı geçirir, çözülemeyeni,
## fazla sıkışığı ve kenara taşanı yakalar; kamera kuralı ve sektör kapsamı.

const SAMPLE_SCENE: PackedScene = preload("res://scenes/levels/chunks/spike_zigzag_01.tscn")
const UNSOLVABLE_SCENE: PackedScene = preload("res://tools/fixtures/chunk_unsolvable.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/entities/spike.tscn")
const LASER_SCENE: PackedScene = preload("res://scenes/entities/laser.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
const LEFT: float = -450.0
const RIGHT: float = 450.0

var _validator: ChunkValidator


func before_test() -> void:
	_validator = ChunkValidator.new(_tuning(), ChunkValidator.player_body_size(), SECTORS)


func test_reads_player_body_from_scene() -> void:
	assert_vector(ChunkValidator.player_body_size()).is_equal(Vector2(60, 80))


func test_sample_chunk_is_fair_in_every_sector() -> void:
	var chunk: ChunkInfo = auto_free(SAMPLE_SCENE.instantiate()) as ChunkInfo
	assert_array(_validator.chunk_errors(chunk)).is_empty()


func test_both_walls_blocked_is_caught() -> void:
	# İki duvar bir vuruş boyunca dikenli: tek geçiş bu kadar uzun havada kalamaz.
	var chunk: ChunkInfo = auto_free(UNSOLVABLE_SCENE.instantiate()) as ChunkInfo
	var errors: PackedStringArray = _validator.chunk_errors(chunk)
	# Katalogdaki her sektörde (S1–S3) geçilemez.
	assert_int(errors.size()).is_equal(3)
	assert_str(errors[0]).starts_with("S1").contains("geçilemiyor").contains("Spike")


func test_spike_pair_can_be_passed_mid_flip() -> void:
	# Aynı yükseklikte iki duvarda diken: geçişin ortasında aralarından süzülmek mümkün.
	var chunk: ChunkInfo = _chunk(6, [Vector3(LEFT, -300, 1), Vector3(RIGHT, -300, -1)])
	assert_array(_validator.sector_errors(chunk, 3)).is_empty()


func test_flips_too_close_fail_at_high_speed() -> void:
	# Yarım vuruşta bir taraf değiştiren dikenler: S3'te (yarım vuruş 0,25 sn) iki çevirme arası
	# geçiş + tepki payından (≈ 0,57 sn) çok kısa; tek geçişin havadaki kısmı da iki dikeni örtmüyor.
	# (Her vuruşta taraf değiştirmek S3'te çözülebiliyor: bazı dikenler havada geçilir.)
	var chunk: ChunkInfo = _chunk(8, [
		Vector3(LEFT, -200, 1), Vector3(RIGHT, -250, -1), Vector3(LEFT, -300, 1),
		Vector3(RIGHT, -350, -1), Vector3(LEFT, -400, 1),
	])
	assert_array(_validator.sector_errors(chunk, 3)).is_not_empty()
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


func test_gaps_on_both_walls_are_caught() -> void:
	# İki duvarda aynı anda 3 vuruşluk boşluk: oyuncu o kadar uzun havada kalamaz.
	var chunk: ChunkInfo = _chunk(8, [])
	chunk.min_sector = 2
	_add_gap(chunk, LEFT, -200, 300.0)
	_add_gap(chunk, RIGHT, -200, 300.0)
	var errors: PackedStringArray = _validator.sector_errors(chunk, 2)
	assert_array(errors).is_not_empty()
	assert_str(errors[0]).contains("Gap")


func test_single_gap_is_fair_and_needs_its_sector() -> void:
	var chunk: ChunkInfo = _chunk(6, [])
	_add_gap(chunk, LEFT, -200, 150.0)
	# Boşluk S2'den önce izinli değil (SectorDef.allowed_hazards).
	var errors: PackedStringArray = _validator.chunk_errors(chunk)
	assert_array(Array(errors)).contains(["S1: 'gap' bu sektörde izinli değil"])
	chunk.min_sector = 2
	assert_array(_validator.chunk_errors(chunk)).is_empty()


func test_closed_laser_gate_depends_on_phase() -> void:
	# İki duvardan koridoru tamamen kapatan ışınlar, 3. vuruşta.
	var lit: ChunkInfo = _chunk(6, [])
	lit.min_sector = 3
	_add_laser(lit, LEFT, -300, 450.0, 0.0)
	_add_laser(lit, RIGHT, -300, 450.0, 0.0)
	# Vuruşta yanıyor: oyuncu geçerken açık, geçilemez.
	assert_array(_validator.sector_errors(lit, 3)).is_not_empty()
	var dark: ChunkInfo = _chunk(6, [])
	dark.min_sector = 3
	_add_laser(dark, LEFT, -300, 450.0, 0.5)
	_add_laser(dark, RIGHT, -300, 450.0, 0.5)
	# Yarım vuruşta yanıyor: oyuncu tam vuruşta geçerken kapalı, zararsız (aldatıcı lazer).
	assert_array(_validator.sector_errors(dark, 3)).is_empty()


func test_laser_needs_its_sector() -> void:
	var chunk: ChunkInfo = _chunk(6, [])
	chunk.min_sector = 2
	_add_laser(chunk, LEFT, -300, 450.0, 0.0)
	assert_array(Array(_validator.chunk_errors(chunk))).contains(
			["S2: 'laser' bu sektörde izinli değil"])


func test_view_rule_uses_lookahead() -> void:
	assert_array(_validator.view_errors()).is_empty()
	var short_view: TuningConfig = _tuning()
	short_view.lookahead = 15.0
	var errors: PackedStringArray = ChunkValidator.new(
			short_view, ChunkValidator.player_body_size(), SECTORS).view_errors()
	# 15 m ileri görüş: S1'de 1,20 sn yeter, S2'de 1,03 sn ve S3'te 0,90 sn yetmez.
	assert_int(errors.size()).is_equal(2)
	assert_str(errors[0]).starts_with("S2")


func test_every_sector_needs_a_chunk() -> void:
	var early: ChunkInfo = _chunk(4, [])
	early.max_sector = 2
	var chunks: Array[ChunkInfo] = [early]
	var errors: PackedStringArray = _validator.coverage_errors(chunks)
	assert_array(Array(errors)).contains_exactly(["S3 için parça yok"])


func _add_laser(chunk: ChunkInfo, x: float, y: float, length: float, phase: float) -> void:
	var laser: Laser = LASER_SCENE.instantiate() as Laser
	laser.name = "Laser%d" % chunk.get_child_count()
	laser.position = Vector2(x, y)
	laser.scale.x = 1.0 if x < 0.0 else -1.0
	laser.length = length
	laser.on_phase = phase
	chunk.add_child(laser)


func _add_gap(chunk: ChunkInfo, x: float, y: float, length: float) -> void:
	var gap: WallGap = WallGap.new()
	gap.name = "Gap%d" % chunk.get_child_count()
	gap.position = Vector2(x, y)
	gap.length = length
	chunk.add_child(gap)


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
