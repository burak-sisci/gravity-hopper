extends GdUnitTestSuite
## Lazer (M2-12, architecture.md §8.2): vuruşla yanıp söner; açıkken çarpışır, kapalıyken
## çarpışmaz. Gerçek turda Events.beat ile aynı adımda yanar. Görüntüsü (M3-06) çarpışmayla aynı
## adımda yanar; yanmadan önce sönük ray uyarı ışımasıyla kalınlaşır.

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
	assert_bool(laser.is_lit()).is_false()
	assert_bool((laser.get_node("Rail") as CanvasItem).visible).is_true()
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
		if laser != null:
			assert_bool(laser.is_lit()).override_failure_message(
					"%d. karede görüntü çarpışmadan farklı" % frame).is_equal(laser.is_on())
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


func test_look_follows_collision_on_every_step() -> void:
	var laser: Laser = auto_free(LASER_SCENE.instantiate()) as Laser
	add_child(laser)
	var shape: CollisionShape2D = laser.get_node("Shape") as CollisionShape2D
	var rail: CanvasItem = laser.get_node("Rail") as CanvasItem
	for on_phase: float in [0.0, 0.5]:
		laser.on_phase = on_phase
		# 120 Hz adımlarıyla 4 vuruş (128 BPM'de vuruş ≈ 56 adım).
		for step: int in 225:
			var beat: float = step / 56.25
			laser.set_beat(beat)
			var on: bool = laser.is_on_at(beat)
			var message: String = "vuruş %s (evre %s)" % [beat, on_phase]
			assert_bool(laser.is_lit()).override_failure_message(message).is_equal(on)
			assert_bool(shape.disabled).override_failure_message(message).is_equal(not on)
			assert_bool(rail.visible).override_failure_message(message).is_equal(not on)


func test_warning_glow_rises_before_lighting() -> void:
	var laser: Laser = auto_free(LASER_SCENE.instantiate()) as Laser
	add_child(laser)
	var style: NeonStyle = Neon.STYLE
	var rail: NeonLine = laser.get_node("Rail") as NeonLine
	# on_phase 0: 0,25'te söner, 0,75'te yanar; uyarı 0,75 − laser_warn_beats'te başlar.
	var warn_start: float = 0.75 - style.laser_warn_beats
	assert_float(laser.warning_at(0.0)).is_equal(0.0)
	assert_float(laser.warning_at(warn_start - 0.01)).is_equal(0.0)
	var half_way: float = warn_start + style.laser_warn_beats * 0.5
	assert_float(laser.warning_at(half_way)).is_equal_approx(0.5, 0.001)
	laser.set_beat(0.3)
	assert_float(rail.width).is_equal_approx(style.laser_off_width, 0.001)
	assert_float(rail.modulate.a).is_equal_approx(style.laser_off_alpha, 0.001)
	var brightest: float = 0.0
	var previous: float = rail.width
	for i: int in 10:
		laser.set_beat(warn_start + style.laser_warn_beats * (i + 1) * 0.099)
		assert_float(rail.width).is_greater_equal(previous)
		previous = rail.width
		brightest = maxf(brightest, rail.modulate.a)
	assert_float(previous).is_greater(style.laser_off_width)
	assert_float(brightest).is_greater(style.laser_off_alpha)
	assert_bool(laser.is_lit()).is_false()
	laser.set_beat(0.75)
	assert_bool(laser.is_lit()).is_true()


func test_blade_is_red_pointed_and_covers_the_collision_box() -> void:
	var laser: Laser = auto_free(LASER_SCENE.instantiate()) as Laser
	laser.length = 300.0
	add_child(laser)
	var blade: NeonLine = laser.get_node("Blade") as NeonLine
	var red: Color = Neon.STYLE.hazard_color
	assert_object(blade.shown_color()).is_equal(red)
	assert_object((laser.get_node("Rail") as NeonLine).shown_color()).is_equal(red)
	var box: Rect2 = laser.beam_rect()
	# Görüntü kutuyu tam kalınlıkta kaplar; uç kutudan taşıp sivrilir (oyuncunun aleyhine değil).
	assert_float(blade.width).is_equal(box.size.y)
	assert_vector(blade.points[0]).is_equal(Vector2.ZERO)
	assert_float(blade.points[1].x).is_equal(box.end.x)
	var tip: Polygon2D = laser.get_node("Blade/Tip") as Polygon2D
	assert_object(tip.color).is_equal(red)
	var tip_box: Rect2 = Rect2(tip.polygon[0], Vector2.ZERO)
	for point: Vector2 in tip.polygon:
		tip_box = tip_box.expand(point)
	assert_float(tip_box.position.x).is_equal(box.end.x)
	assert_float(tip_box.end.x).is_equal_approx(box.end.x + Neon.STYLE.laser_tip_px, 0.001)
	assert_float(tip_box.size.y).is_equal(box.size.y)


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
