extends GdUnitTestSuite
## Parça doğrulayıcısı (M2-05, architecture.md §8.2): adil parçayı geçirir, çözülemeyeni,
## fazla sıkışığı ve kenara taşanı yakalar; kamera kuralı ve sektör kapsamı. Tek sektör denemeleri
## M2-20 öncesindeki sektör tempolarıyla (S1 100, S2 110, S3 120 BPM) yapılır. Hareketli tehlikeler
## (M4-10): duvara varan blok ve koridoru kesen çubuk yakalanıyor, gerçek şekilleriyle deneniyor,
## fazla hızlı hareket yakalanıyor.

const SAMPLE_SCENE: PackedScene = preload("res://scenes/levels/chunks/spike_zigzag_01.tscn")
const UNSOLVABLE_SCENE: PackedScene = preload("res://tools/fixtures/chunk_unsolvable.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/entities/spike.tscn")
const LASER_SCENE: PackedScene = preload("res://scenes/entities/laser.tscn")
const GLIMMER_SCENE: PackedScene = preload("res://scenes/entities/glimmer.tscn")
const ROTOR_SCENE: PackedScene = preload("res://scenes/entities/rotor.tscn")
const MOVING_BLOCK_SCENE: PackedScene = preload("res://scenes/entities/moving_block.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
const MUSIC: MusicCatalog = preload("res://data/music/music_catalog.tres")
const LEFT: float = -450.0
const RIGHT: float = 450.0

var _validator: ChunkValidator


func before_test() -> void:
	_validator = ChunkValidator.new(_tuning(), ChunkValidator.player_body_size(), SECTORS, MUSIC)


func test_reads_player_body_from_scene() -> void:
	assert_vector(ChunkValidator.player_body_size()).is_equal(Vector2(60, 80))


func test_sample_chunk_is_fair_in_every_sector() -> void:
	var chunk: ChunkInfo = auto_free(SAMPLE_SCENE.instantiate()) as ChunkInfo
	assert_array(_validator.chunk_errors(chunk)).is_empty()


func test_both_walls_blocked_is_caught() -> void:
	# İki duvar bir vuruş boyunca dikenli: tek geçiş bu kadar uzun havada kalamaz.
	var chunk: ChunkInfo = auto_free(UNSOLVABLE_SCENE.instantiate()) as ChunkInfo
	var errors: PackedStringArray = _validator.chunk_errors(chunk)
	# Katalogdaki her sektörde ve her müzik temposunda geçilemez.
	assert_int(errors.size()).is_equal(SECTORS.count() * MUSIC.tempos().size())
	assert_str(errors[0]).starts_with("S1").contains("geçilemiyor").contains("Spike")


func test_spike_pair_can_be_passed_mid_flip() -> void:
	# Aynı yükseklikte iki duvarda diken: geçişin ortasında aralarından süzülmek mümkün.
	var chunk: ChunkInfo = _chunk(6, [Vector3(LEFT, -300, 1), Vector3(RIGHT, -300, -1)])
	assert_array(_validator.sector_errors(chunk, 3, 120.0)).is_empty()


func test_flips_too_close_fail_at_high_speed() -> void:
	# Yarım vuruşta bir taraf değiştiren dikenler: S3'te (yarım vuruş 0,25 sn) iki çevirme arası
	# geçiş + tepki payından (≈ 0,57 sn) çok kısa; tek geçişin havadaki kısmı da iki dikeni örtmüyor.
	# (Her vuruşta taraf değiştirmek S3'te çözülebiliyor: bazı dikenler havada geçilir.)
	var chunk: ChunkInfo = _chunk(8, [
		Vector3(LEFT, -200, 1), Vector3(RIGHT, -250, -1), Vector3(LEFT, -300, 1),
		Vector3(RIGHT, -350, -1), Vector3(LEFT, -400, 1),
	])
	assert_array(_validator.sector_errors(chunk, 3, 120.0)).is_not_empty()
	# Aynı dikenler iki vuruş arayla her sektörde adil.
	var relaxed: ChunkInfo = _chunk(8, [
		Vector3(LEFT, -200, 1), Vector3(RIGHT, -400, -1), Vector3(LEFT, -600, 1),
	])
	assert_array(_validator.chunk_errors(relaxed)).is_empty()


func test_hazard_right_after_chunk_start_is_unfair() -> void:
	# Önceki parçadan yarım geçişle gelen oyuncu bu dikenden kaçamaz (birleşim yeri kuralı).
	var chunk: ChunkInfo = _chunk(4, [Vector3(LEFT, -50, 1)])
	var errors: PackedStringArray = _validator.sector_errors(chunk, 1, 100.0)
	assert_array(errors).is_not_empty()
	assert_str(errors[0]).contains("Spike0")


func test_hazard_crossing_chunk_edge_is_caught() -> void:
	var chunk: ChunkInfo = _chunk(4, [Vector3(LEFT, 0, 1)])
	assert_str(_validator.sector_errors(chunk, 1, 100.0)[0]).contains("taşıyor")


func test_gaps_on_both_walls_are_caught() -> void:
	# İki duvarda aynı anda 3 vuruşluk boşluk: oyuncu o kadar uzun havada kalamaz.
	var chunk: ChunkInfo = _chunk(8, [])
	chunk.min_sector = 2
	_add_gap(chunk, LEFT, -200, 300.0)
	_add_gap(chunk, RIGHT, -200, 300.0)
	var errors: PackedStringArray = _validator.sector_errors(chunk, 2, 110.0)
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
	assert_array(_validator.sector_errors(lit, 3, 120.0)).is_not_empty()
	var dark: ChunkInfo = _chunk(6, [])
	dark.min_sector = 3
	_add_laser(dark, LEFT, -300, 450.0, 0.5)
	_add_laser(dark, RIGHT, -300, 450.0, 0.5)
	# Yarım vuruşta yanıyor: oyuncu tam vuruşta geçerken kapalı, zararsız (aldatıcı lazer).
	assert_array(_validator.sector_errors(dark, 3, 120.0)).is_empty()


func test_laser_needs_its_sector() -> void:
	var chunk: ChunkInfo = _chunk(6, [])
	chunk.min_sector = 2
	_add_laser(chunk, LEFT, -300, 450.0, 0.0)
	assert_array(Array(_validator.chunk_errors(chunk))).contains(
			["S2: 'laser' bu sektörde izinli değil"])


func test_glimmer_rules() -> void:
	# Üç dikenle çevrili Glimmer'a dokunmadan yaklaşılamaz (toplama yarıçapı 75 px geniş: tek
	# dikenin yanındaki Glimmer geçiş sırasında sıyırarak alınabilir). Tehlikeden uzak Glimmer
	# riskli yolda değil; sağ duvardaki, dikenle aynı vuruştaki Glimmer ikisini de geçer.
	var chunk: ChunkInfo = _chunk(8, [
		Vector3(LEFT, -250, 1), Vector3(LEFT, -300, 1), Vector3(LEFT, -350, 1),
	])
	_add_glimmer(chunk, -450, -300)
	_add_glimmer(chunk, 400, -750)
	_add_glimmer(chunk, 400, -300)
	var errors: PackedStringArray = _validator.sector_errors(chunk, 1, 100.0)
	assert_int(errors.size()).is_equal(2)
	if errors.size() < 2:
		return
	assert_str(errors[0]).contains("Glimmer3").contains("toplanamıyor")
	assert_str(errors[1]).contains("Glimmer4").contains("riskli yolda değil")


func test_view_rule_uses_lookahead() -> void:
	assert_array(_validator.view_errors()).is_empty()
	var short_view: TuningConfig = _tuning()
	short_view.lookahead = 15.0
	var errors: PackedStringArray = ChunkValidator.new(
			short_view, ChunkValidator.player_body_size(), SECTORS, MUSIC).view_errors()
	# 15 m ileri görüş: S1'de 1,20 sn yeter; S2'den itibaren (S2 1,03 sn, S3 0,90 sn, S4 0,80 sn)
	# hiçbir sektörde yetmez.
	assert_int(errors.size()).is_equal(SECTORS.count() - 1)
	assert_str(errors[0]).starts_with("S2")


func test_every_sector_needs_a_chunk() -> void:
	var early: ChunkInfo = _chunk(4, [])
	early.max_sector = 2
	var chunks: Array[ChunkInfo] = [early]
	var errors: PackedStringArray = _validator.coverage_errors(chunks)
	var expected: Array[String] = []
	for sector: int in range(3, SECTORS.count() + 1):
		expected.append("S%d için parça yok" % sector)
	assert_array(Array(errors)).contains_exactly(expected)


func test_moving_block_arriving_at_the_wall_is_caught() -> void:
	# Sol duvar 2.–6. vuruş dikenli: oyuncu sağ duvarda kalmalı. Duvardan duvara giden blok 3.
	# vuruşta sağ duvara varıyor; oyuncu tam o anda bloğun hizasında, geçilemez. Ters evrede blok
	# 3. vuruşta sol duvarda (dikenlerin önünde), oyuncu sağda güvenle geçer. İki parçanın tek farkı
	# bloğun evresi. İleti son kalan yolların çarptığını söyler: bloktan kaçmak için sola geçen yol
	# dikene çarpar.
	var trapped: ChunkInfo = _chunk(8, _left_wall(200, 600))
	_add_moving_block(trapped, -300, true)
	var errors: PackedStringArray = _validator.sector_errors(trapped, 3, 120.0)
	assert_array(errors).is_not_empty()
	if not errors.is_empty():
		assert_str(errors[0]).contains("geçilemiyor")
	var clear: ChunkInfo = _chunk(8, _left_wall(200, 600))
	_add_moving_block(clear, -300, false)
	assert_array(_validator.sector_errors(clear, 3, 120.0)).is_empty()


func test_rotor_across_the_corridor_is_caught() -> void:
	# 850 px'lik çubuk iki duvardaki oyuncuya da uzanır. 3. vuruşta yatay duruyorsa (başlangıç 90°,
	# vuruşta 90°) o hizadan hiçbir yoldan geçilemez; dikey duruyorsa oyuncu duvarda kalarak geçer.
	var blocked: ChunkInfo = _chunk(8, [])
	_add_rotor(blocked, -300, 850.0, 90.0)
	var errors: PackedStringArray = _validator.sector_errors(blocked, 3, 120.0)
	assert_array(errors).is_not_empty()
	if not errors.is_empty():
		assert_str(errors[0]).contains("geçilemiyor").contains("Rotor")
	var open: ChunkInfo = _chunk(8, [])
	_add_rotor(open, -300, 850.0, 0.0)
	assert_array(_validator.sector_errors(open, 3, 120.0)).is_empty()


func test_moving_hazards_are_tried_on_their_real_shape() -> void:
	# 45° eğik çubuğun kutusu oyuncuya değiyor ama kendisi değmiyor: kutuya çevirmek temkinli olurdu.
	var bar: PackedVector2Array = Transform2D(PI * 0.25, Vector2.ZERO) * PackedVector2Array([
		Vector2(-150, -20), Vector2(150, -20), Vector2(150, 20), Vector2(-150, 20),
	])
	var bounds: Rect2 = Rect2(bar[0], Vector2.ZERO)
	for point: Vector2 in bar:
		bounds = bounds.expand(point)
	var corner_box: Rect2 = Rect2(Vector2(70, -110), Vector2(40, 40))
	assert_bool(corner_box.intersects(bounds)).is_true()
	assert_bool(ChunkValidator.Simulation.rect_hits_polygon(corner_box, bar, bounds)).is_false()
	var center_box: Rect2 = Rect2(Vector2(-20, -20), Vector2(40, 40))
	assert_bool(ChunkValidator.Simulation.rect_hits_polygon(center_box, bar, bounds)).is_true()
	# Değmek kesişmek sayılmaz (Rect2.intersects gibi).
	var square: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10),
	])
	var touching: Rect2 = Rect2(Vector2(10, 0), Vector2(5, 5))
	assert_bool(ChunkValidator.Simulation.rect_hits_polygon(
			touching, square, Rect2(0, 0, 10, 10))).is_false()


func test_too_fast_motion_is_caught() -> void:
	# 600 px'lik çubuk yarım vuruşta 180° dönüyor: 120 BPM'de ucu bir adımda oyuncunun içinden
	# atlayacak kadar yol alır (≈ 94 px > 40 + 42 px).
	var chunk: ChunkInfo = _chunk(8, [])
	var rotor: Rotor = _add_rotor(chunk, -400, 600.0, 0.0)
	rotor.turn_degrees = 180.0
	var errors: PackedStringArray = _validator.sector_errors(chunk, 3, 120.0)
	assert_int(errors.size()).is_equal(1)
	if not errors.is_empty():
		assert_str(errors[0]).contains("Rotor").contains("çok hızlı")
	rotor.turn_degrees = 90.0
	assert_array(_validator.sector_errors(chunk, 3, 120.0)).is_empty()


func test_moving_hazards_need_their_sector() -> void:
	# Dönen şekil ve hareketli blok S4'ten önce izinli değil (SectorDef.allowed_hazards, M4-11).
	var chunk: ChunkInfo = _chunk(8, [])
	chunk.min_sector = 3
	_add_rotor(chunk, -300, 300.0, 0.0)
	_add_moving_block(chunk, -600, true)
	var errors: Array = Array(_validator.chunk_errors(chunk))
	assert_array(errors).contains(["S3: 'rotor' bu sektörde izinli değil"])
	assert_array(errors).contains(["S3: 'moving_block' bu sektörde izinli değil"])


func _add_moving_block(chunk: ChunkInfo, y: float, starts_left: bool) -> MovingBlock:
	var block: MovingBlock = MOVING_BLOCK_SCENE.instantiate() as MovingBlock
	block.name = "MovingBlock%d" % chunk.get_child_count()
	block.position = Vector2(0, y)
	block.starts_left = starts_left
	chunk.add_child(block)
	return block


func _add_rotor(chunk: ChunkInfo, y: float, length: float, start: float) -> Rotor:
	var rotor: Rotor = ROTOR_SCENE.instantiate() as Rotor
	rotor.name = "Rotor%d" % chunk.get_child_count()
	rotor.position = Vector2(0, y)
	rotor.length = length
	rotor.start_degrees = start
	chunk.add_child(rotor)
	return rotor


## Sol duvarı from'dan to'ya (tasarım y, aşağıdan yukarı) yarım vuruşta bir dikenle kapatır.
func _left_wall(from: int, to: int) -> Array[Vector3]:
	var spikes: Array[Vector3] = []
	for y: int in range(from, to + 1, 50):
		spikes.append(Vector3(LEFT, -y, 1))
	return spikes


func _add_glimmer(chunk: ChunkInfo, x: float, y: float) -> void:
	var glimmer: Glimmer = GLIMMER_SCENE.instantiate() as Glimmer
	glimmer.name = "Glimmer%d" % chunk.get_child_count()
	glimmer.position = Vector2(x, y)
	chunk.add_child(glimmer)


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
