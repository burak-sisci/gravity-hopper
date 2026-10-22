extends GdUnitTestSuite
## Hareketli tehlikeler (M4-10, architecture.md §8.2): dönen şekil (Rotor) ve hareketli blok
## (MovingBlock). Görüntü ve çarpışma her 120 Hz adımında aynı yerde (fizik sunucusundaki şekil
## dahil) ve doğrulayıcının hesabıyla aynı; ritim vuruşa oturuyor; hareket bir fizik adımında
## oyuncunun içinden atlayacak kadar hızlı değil; parça vuruşu ve koridor ölçeğini iletiyor;
## hareket koridordan taşamıyor. Gerçek turda da her adımda görüntü çarpışmayla aynı.

const ROTOR_SCENE: PackedScene = preload("res://scenes/entities/rotor.tscn")
const MOVING_BLOCK_SCENE: PackedScene = preload("res://scenes/entities/moving_block.tscn")
const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const MUSIC: MusicCatalog = preload("res://data/music/music_catalog.tres")
const TUNING: TuningConfig = preload("res://data/tuning/default_tuning.tres")
## Telefon ekranının yenilenme adımı (120 Hz) ve oyunun fizik adımı (60 Hz).
const SCREEN_STEP: float = 1.0 / 120.0
const PHYSICS_STEP: float = 1.0 / 60.0
const SECONDS_PER_MINUTE: float = 60.0
const TESTED_BEATS: float = 4.0
## Köşelerin karşılaştırma payı (px).
const EPSILON: float = 0.01


func test_look_and_collision_match_on_every_120hz_step() -> void:
	for hazard: MovingHazard in _variants():
		add_child(hazard)
		var shape: CollisionPolygon2D = hazard.get_node("Shape") as CollisionPolygon2D
		var visual: NeonShape = hazard.get_node("Visual") as NeonShape
		for bpm: float in MUSIC.tempos():
			var steps: int = ceili(TESTED_BEATS * SECONDS_PER_MINUTE / bpm / SCREEN_STEP)
			for step: int in steps + 1:
				var beat: float = step * SCREEN_STEP * bpm / SECONDS_PER_MINUTE
				hazard.set_beat(beat)
				var expected: PackedVector2Array = hazard.polygon_at(beat, hazard.x_scale)
				var where: String = "%s %s BPM, %s. vuruş" % [hazard.name, bpm, beat]
				var server: Transform2D = PhysicsServer2D.area_get_shape_transform(hazard.get_rid(), 0)
				if not _same(shape.transform * shape.polygon, expected, where + ": çarpışma"):
					return
				if not _same(visual.transform * visual.polygon, expected, where + ": görüntü"):
					return
				if not _same(server * shape.polygon, expected, where + ": fizik sunucusu"):
					return


func test_rotor_turns_a_step_on_every_beat() -> void:
	var rotor: Rotor = auto_free(ROTOR_SCENE.instantiate()) as Rotor
	# Varsayılan: her vuruşta 90° saat yönünde; vuruşun ilk yarısında durur, ikincisinde döner.
	for beat: int in 6:
		_assert_angle(rotor.angle_at(beat), 90.0 * beat, "%d. vuruş" % beat)
		_assert_angle(rotor.angle_at(beat + 0.25), 90.0 * beat, "%d,25. vuruş" % beat)
		_assert_angle(rotor.angle_at(beat + 0.5), 90.0 * beat, "%d,5. vuruş" % beat)
		_assert_angle(rotor.angle_at(beat + 0.75), 90.0 * beat + 45.0, "%d,75. vuruş" % beat)
	rotor.clockwise = false
	_assert_angle(rotor.angle_at(1.0), -90.0, "ters yön")
	rotor.clockwise = true
	rotor.phase = 0.5
	rotor.start_degrees = 45.0
	_assert_angle(rotor.angle_at(1.5), 135.0, "yarım vuruş evresi")
	_assert_angle(rotor.angle_at(1.0), 45.0, "yarım vuruş evresi, adım başlıyor")


func test_moving_block_reaches_a_wall_on_every_beat() -> void:
	var block: MovingBlock = auto_free(MOVING_BLOCK_SCENE.instantiate()) as MovingBlock
	var half: float = block.size.x * 0.5
	# Varsayılan yol duvardan duvara: her vuruşta bloğun kenarı bir duvarda (±450).
	for beat: int in 6:
		var wall: float = -1.0 if beat % 2 == 0 else 1.0
		var edge: float = block.offset_at(beat) + wall * half
		assert_float(edge).override_failure_message("%d. vuruş" % beat).is_equal_approx(
				wall * ChunkInfo.DESIGN_HALF_WIDTH, EPSILON)
	# Sahnede hiç durmaz: yarım vuruşta yolun ortasından geçer.
	assert_float(block.offset_at(0.5)).is_equal_approx(0.0, EPSILON)
	block.starts_left = false
	assert_float(block.offset_at(0.0)).is_equal_approx(block.travel, EPSILON)
	assert_float(block.offset_at(1.0)).is_equal_approx(-block.travel, EPSILON)


func test_motion_never_jumps_past_the_player() -> void:
	# Bir fizik adımında hiçbir köşe "tehlikenin kalınlığı + oyuncu çarpışma kutusunun dar kenarı"
	# kadar yer değiştirmez; yoksa adımlar arasında oyuncunun içinden geçip değmeyebilirdi (oyun da
	# doğrulayıcı da kare kare bakar). En hızlı tempoda ölçülür.
	var hurt: Vector2 = ChunkValidator.player_body_size() * TUNING.hurtbox_scale
	var fastest: float = 0.0
	for bpm: float in MUSIC.tempos():
		fastest = maxf(fastest, bpm)
	var beat_step: float = PHYSICS_STEP * fastest / SECONDS_PER_MINUTE
	for hazard: MovingHazard in _variants():
		var rest: PackedVector2Array = hazard.rest_polygon()
		var box: Rect2 = Rect2(rest[0], Vector2.ZERO)
		for point: Vector2 in rest:
			box = box.expand(point)
		var limit: float = minf(box.size.x, box.size.y) + minf(hurt.x, hurt.y)
		var worst: float = 0.0
		for step: int in ceili(TESTED_BEATS / beat_step):
			var current: PackedVector2Array = hazard.polygon_at(step * beat_step, 1.0)
			var following: PackedVector2Array = hazard.polygon_at((step + 1) * beat_step, 1.0)
			for i: int in current.size():
				worst = maxf(worst, current[i].distance_to(following[i]))
		assert_float(worst).override_failure_message("%s adımda %.1f px (sınır %.1f)" % [
			hazard.name, worst, limit]).is_less(limit)


func test_chunk_passes_the_beat_and_corridor_scale() -> void:
	var chunk: ChunkInfo = auto_free(ChunkInfo.new()) as ChunkInfo
	chunk.length_beats = 6
	var rotor: Rotor = ROTOR_SCENE.instantiate() as Rotor
	rotor.position = Vector2(0, -300)
	chunk.add_child(rotor)
	var block: MovingBlock = MOVING_BLOCK_SCENE.instantiate() as MovingBlock
	block.position = Vector2(0, -150)
	chunk.add_child(block)
	add_child(chunk)
	# Koridor tasarımın 0,9'u: yatay yol da 0,9 ile ölçeklenir, dönüş ölçeklenmez.
	chunk.layout(400.0, ChunkInfo.DESIGN_HALF_WIDTH * 0.9)
	chunk.set_beat(3.0)
	var block_shape: CollisionPolygon2D = block.get_node("Shape") as CollisionPolygon2D
	assert_float(block_shape.position.x).is_equal_approx(block.travel * 0.9, EPSILON)
	assert_float(block.position.x).is_equal_approx(0.0, EPSILON)
	_same(block_shape.transform * block_shape.polygon, block.polygon_at(3.0, 0.9), "blok")
	var rotor_shape: CollisionPolygon2D = rotor.get_node("Shape") as CollisionPolygon2D
	_assert_angle(rotor_shape.rotation, 270.0, "çubuk")
	# Şerit yeni ölçekte bloğun yolunu kaplar.
	var lane: Polygon2D = block.get_node("Lane") as Polygon2D
	var lane_box: Rect2 = Rect2(lane.polygon[0], Vector2.ZERO)
	for point: Vector2 in lane.polygon:
		lane_box = lane_box.expand(point)
	assert_float(lane_box.end.x).is_equal_approx(block.travel * 0.9 + block.size.x * 0.5, EPSILON)


func test_motion_must_stay_inside_the_corridor() -> void:
	var chunk: ChunkInfo = auto_free(ChunkInfo.new()) as ChunkInfo
	chunk.length_beats = 8
	var block: MovingBlock = MOVING_BLOCK_SCENE.instantiate() as MovingBlock
	block.name = "MovingBlock2"
	block.position = Vector2(0, -200)
	chunk.add_child(block)
	var rotor: Rotor = ROTOR_SCENE.instantiate() as Rotor
	rotor.name = "Rotor5"
	rotor.length = 900.0
	rotor.position = Vector2(0, -500)
	chunk.add_child(rotor)
	# Duvardan duvara blok ve koridor genişliğinde çubuk ortadayken sığar.
	assert_array(chunk.design_errors()).is_empty()
	block.position.x = 50.0
	rotor.position.x = -50.0
	var errors: PackedStringArray = chunk.design_errors()
	assert_int(errors.size()).is_equal(2)
	assert_str(" ".join(errors)).contains("MovingBlock2: hareketi koridordan taşıyor").contains(
			"Rotor5: hareketi koridordan taşıyor")


func test_hazards_are_red_and_sharp() -> void:
	var hazards: Array[MovingHazard] = [
		ROTOR_SCENE.instantiate() as MovingHazard, MOVING_BLOCK_SCENE.instantiate() as MovingHazard,
	]
	for hazard: MovingHazard in hazards:
		auto_free(hazard)
		add_child(hazard)
		var visual: NeonShape = hazard.get_node("Visual") as NeonShape
		assert_object(visual.shown_color()).is_equal(Neon.STYLE.hazard_color)
		assert_bool(visual.sharp).is_true()
		# Şekil dili (GDD §6): tehlike köşeli; en sivri köşe en çok 90°.
		assert_float(_sharpest_corner(hazard.rest_polygon())).is_less_equal(90.01)
		assert_int(hazard.collision_layer).is_equal(ChunkInfo.HAZARD_LAYER)


func test_moving_hazards_follow_the_beat_in_a_run() -> void:
	var run: Run = auto_free(RUN_SCENE.instantiate()) as Run
	run.run_seed = 3
	var library: ChunkLibrary = ChunkLibrary.new()
	library.chunks = [_moving_chunk()]
	(run.get_node("%ChunkSpawner") as ChunkSpawner).library = library
	add_child(run)
	var spawner: ChunkSpawner = run.get_node("%ChunkSpawner") as ChunkSpawner
	var poses: Dictionary[String, bool] = {}
	var checked: int = 0
	for frame: int in 180:
		await get_tree().physics_frame
		for chunk: ChunkInfo in spawner.active_chunks():
			for item: Node2D in chunk.items():
				if not item is MovingHazard:
					continue
				var shape: CollisionPolygon2D = item.get_node("Shape") as CollisionPolygon2D
				var visual: Node2D = item.get_node("Visual") as Node2D
				var server: Transform2D = PhysicsServer2D.area_get_shape_transform(
						(item as Area2D).get_rid(), 0)
				assert_object(visual.transform).override_failure_message(
						"%d. karede görüntü çarpışmadan farklı" % frame).is_equal(shape.transform)
				assert_object(server).override_failure_message(
						"%d. karede fizik sunucusu geride" % frame).is_equal(shape.transform)
				poses[str(shape.transform)] = true
				checked += 1
	assert_int(checked).is_greater(100)
	# Gerçekten hareket ediyorlar.
	assert_int(poses.size()).is_greater(20)


## Denenen biçimler: varsayılanlar ve ayarları değişmiş birer kopya.
func _variants() -> Array[MovingHazard]:
	var rotor: Rotor = auto_free(ROTOR_SCENE.instantiate()) as Rotor
	rotor.name = "Rotor"
	var spun: Rotor = auto_free(ROTOR_SCENE.instantiate()) as Rotor
	spun.name = "RotorTers"
	spun.clockwise = false
	spun.length = 600.0
	spun.turn_degrees = 45.0
	spun.phase = 0.5
	var block: MovingBlock = auto_free(MOVING_BLOCK_SCENE.instantiate()) as MovingBlock
	block.name = "MovingBlock"
	var quick: MovingBlock = auto_free(MOVING_BLOCK_SCENE.instantiate()) as MovingBlock
	quick.name = "MovingBlockKisa"
	quick.starts_left = false
	quick.move_beats = 0.5
	quick.travel = 200.0
	quick.x_scale = 0.9
	return [rotor, spun, block, quick]


## Çubuk ve bloklu parça (testte S1'de izinli).
func _moving_chunk() -> PackedScene:
	var root: ChunkInfo = ChunkInfo.new()
	root.length_beats = 6
	var rotor: Rotor = ROTOR_SCENE.instantiate() as Rotor
	rotor.position = Vector2(0, -400)
	root.add_child(rotor)
	rotor.owner = root
	var block: MovingBlock = MOVING_BLOCK_SCENE.instantiate() as MovingBlock
	block.position = Vector2(0, -200)
	root.add_child(block)
	block.owner = root
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _same(actual: PackedVector2Array, expected: PackedVector2Array, where: String) -> bool:
	assert_int(actual.size()).override_failure_message(where).is_equal(expected.size())
	for i: int in mini(actual.size(), expected.size()):
		if actual[i].distance_to(expected[i]) > EPSILON:
			assert_vector(actual[i]).override_failure_message("%s: %d. köşe %s, beklenen %s" % [
				where, i, actual[i], expected[i]]).is_equal(expected[i])
			return false
	return actual.size() == expected.size()


func _assert_angle(radians: float, degrees: float, where: String) -> void:
	var off: float = absf(angle_difference(radians, deg_to_rad(degrees)))
	assert_float(off).override_failure_message("%s: %.2f°, beklenen %.2f°" % [
		where, rad_to_deg(radians), degrees]).is_less(0.001)


## Çokgenin en dar iç açısı (derece).
func _sharpest_corner(polygon: PackedVector2Array) -> float:
	var sharpest: float = 180.0
	var count: int = polygon.size()
	for i: int in count:
		var to_previous: Vector2 = polygon[(i + count - 1) % count] - polygon[i]
		var to_next: Vector2 = polygon[(i + 1) % count] - polygon[i]
		sharpest = minf(sharpest, rad_to_deg(absf(to_previous.angle_to(to_next))))
	return sharpest
