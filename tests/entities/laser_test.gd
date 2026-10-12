extends GdUnitTestSuite
## Lazer (M2-12, architecture.md §8.2): vuruşla yanıp söner; açıkken çarpışır, kapalıyken
## çarpışmaz. Gerçek turda Events.beat ile aynı adımda yanar.

const LASER_SCENE: PackedScene = preload("res://scenes/entities/laser.tscn")
const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")

var _beat_frames: Array[int] = []
var _frame: int = 0


func test_on_around_each_beat() -> void:
	var laser: Laser = auto_free(LASER_SCENE.instantiate()) as Laser
	# Açık pencere vuruşa ortalı: [k − 0,25, k + 0,25).
	for beat: float in [0.0, 0.2, 0.8, 7.0, 6.76]:
		assert_bool(laser.is_on_at(beat)).override_failure_message("%s açık olmalı" % beat).is_true()
	for beat: float in [0.3, 0.5, 0.7, 7.5]:
		assert_bool(laser.is_on_at(beat)).override_failure_message("%s kapalı olmalı" % beat).is_false()
	laser.on_phase = 0.5
	assert_bool(laser.is_on_at(0.0)).is_false()
	assert_bool(laser.is_on_at(0.5)).is_true()


func test_set_beat_toggles_collision_and_look() -> void:
	var laser: Laser = auto_free(LASER_SCENE.instantiate()) as Laser
	laser.length = 300.0
	add_child(laser)
	var shape: CollisionShape2D = laser.get_node("Shape") as CollisionShape2D
	assert_vector((shape.shape as RectangleShape2D).size).is_equal(Vector2(300, Laser.THICKNESS))
	laser.set_beat(1.7)
	assert_bool(laser.is_on()).is_false()
	assert_bool(shape.disabled).is_true()
	assert_float((laser.get_node("Visual") as Polygon2D).modulate.a).is_less(1.0)
	laser.set_beat(2.0)
	assert_bool(laser.is_on()).is_true()
	assert_bool(shape.disabled).is_false()


func test_lasers_light_up_on_the_beat_in_a_run() -> void:
	var run: Run = auto_free(RUN_SCENE.instantiate()) as Run
	run.run_seed = 3
	var library: ChunkLibrary = ChunkLibrary.new()
	library.chunks = [_laser_chunk()]
	(run.get_node("%ChunkSpawner") as ChunkSpawner).library = library
	Events.beat.connect(_on_beat)
	add_child(run)
	var spawner: ChunkSpawner = run.get_node("%ChunkSpawner") as ChunkSpawner
	var lit: Array[bool] = []
	for frame: int in 240:
		await get_tree().physics_frame
		_frame = frame
		var laser: Laser = _first_laser(spawner)
		lit.append(laser != null and laser.is_on())
	Events.beat.disconnect(_on_beat)
	# await adımdan önce döner: vuruş adımının sonucu bir sonraki turda görülür (_on_beat +1).
	# 100 BPM: vuruş 36 kare; vuruşta açık, yarım vuruşta (18 kare sonra) kapalı.
	assert_int(_beat_frames.size()).is_greater(3)
	for frame: int in _beat_frames:
		if frame >= lit.size():
			continue
		assert_bool(lit[frame]).override_failure_message("%d. karedeki vuruşta kapalı" % frame).is_true()
		if frame + 18 < lit.size():
			assert_bool(lit[frame + 18]).override_failure_message(
					"%d. karedeki yarım vuruşta açık" % (frame + 18)).is_false()


## Sol duvardan yarım koridor uzanan tek lazerli parça (testte S1'de izinli).
func _laser_chunk() -> PackedScene:
	var root: ChunkInfo = ChunkInfo.new()
	root.length_beats = 6
	var laser: Laser = LASER_SCENE.instantiate() as Laser
	laser.position = Vector2(-450, -300)
	root.add_child(laser)
	laser.owner = root
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _first_laser(spawner: ChunkSpawner) -> Laser:
	for chunk: ChunkInfo in spawner.active_chunks():
		for item: Node2D in chunk.items():
			if item is Laser:
				return item as Laser
	return null


func _on_beat(_index: int) -> void:
	_beat_frames.append(_frame + 1)
