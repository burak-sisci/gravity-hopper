extends GdUnitTestSuite
## Kamera sarsıntısı ve ölümde donma (M3-10, architecture.md §9): travma en çok 1, söner;
## sarsıntı yalnızca yatayda ve travma² ile sınırlı; gerçek turda ölümden sonra dünya
## death_freeze boyunca donuyor (vuruş saati, iz), ardından kamera sarsılıyor ve oyuncunun
## üstünde görünen mesafe değişmiyor; kalkan kırılınca hafif sarsıntı.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const FPS: float = 60.0


func test_trauma_shakes_sideways_and_fades() -> void:
	var tuning: TuningConfig = _tuning()
	var camera: GameCamera = auto_free(GameCamera.new()) as GameCamera
	camera.tuning = tuning
	add_child(camera)
	camera.add_trauma(0.7)
	camera.add_trauma(0.7)
	assert_float(camera.trauma()).is_equal(1.0)
	var limit: float = TuningConfig.to_px(tuning.shake_offset)
	var last: float = camera.trauma()
	var moved: int = 0
	for i: int in ceili(FPS / tuning.shake_decay) + 5:
		await get_tree().physics_frame
		var trauma: float = camera.trauma()
		assert_float(camera.offset.y).is_equal(0.0)
		assert_float(trauma).is_less_equal(last)
		assert_float(absf(camera.offset.x)).is_less_equal(limit * trauma * trauma + 0.001)
		if absf(camera.offset.x) > 1.0:
			moved += 1
		last = trauma
	assert_int(moved).is_greater(5)
	assert_float(camera.trauma()).is_equal(0.0)
	await get_tree().physics_frame
	assert_vector(camera.offset).is_equal(Vector2.ZERO)


## Gürültü -1–1 arasında; düğümlerde sırayla sola ve sağa, hiçbiri sönük değil.
func test_shake_noise_alternates_and_stays_in_range() -> void:
	var camera: GameCamera = auto_free(GameCamera.new()) as GameCamera
	for key: int in 2 * GameCamera.NOISE_KEYS:
		var value: float = camera.shake_noise(float(key))
		assert_float(absf(value)).is_between(GameCamera.NOISE_MIN, 1.0)
		assert_float(signf(value)).is_equal(1.0 if key % 2 == 0 else -1.0)
		assert_float(absf(camera.shake_noise(key + 0.37))).is_less_equal(1.0)


func test_death_freezes_world_then_shakes_sideways() -> void:
	var run: Run = _start(-1.0)
	var player: Player = run.get_node("%Player") as Player
	var camera: GameCamera = run.get_node("%GameCamera") as GameCamera
	var conductor: Conductor = run.get_node("%Conductor") as Conductor
	var trail: Node = player.get_node("Trail")
	await _frames(30)
	player.die(GameTypes.DeathCause.HAZARD)
	await _frames(1)
	var beat: float = conductor.beat_time()
	var freeze_frames: int = roundi(run.tuning.death_freeze * FPS)
	# Donma: vuruş saati ilerlemiyor, iz yerinde, kamera henüz sarsılmıyor.
	for i: int in freeze_frames - 2:
		await get_tree().physics_frame
		assert_float(conductor.beat_time()).is_equal(beat)
		assert_bool(trail.is_processing()).is_false()
		assert_float(camera.trauma()).is_equal(0.0)
	await _frames(3)
	assert_float(conductor.beat_time()).is_greater(beat)
	assert_bool(trail.is_processing()).is_true()
	assert_float(camera.trauma()).is_greater(0.0)
	# Sarsıntı yalnızca yatayda: oyuncunun üstünde görünen mesafe aynı.
	var lookahead: float = TuningConfig.to_px(run.tuning.lookahead)
	var half_height: float = camera.get_viewport_rect().size.y * 0.5
	var moved: bool = false
	for i: int in 20:
		await get_tree().process_frame
		var center: Vector2 = camera.get_screen_center_position()
		assert_float(player.position.y - (center.y - half_height)).is_equal_approx(lookahead, 0.01)
		if absf(center.x) > 1.0:
			moved = true
	assert_bool(moved).is_true()


func test_no_freeze_shakes_at_once() -> void:
	var run: Run = _start(0.0)
	var player: Player = run.get_node("%Player") as Player
	var camera: GameCamera = run.get_node("%GameCamera") as GameCamera
	var conductor: Conductor = run.get_node("%Conductor") as Conductor
	await _frames(30)
	player.die(GameTypes.DeathCause.HAZARD)
	await _frames(1)
	var beat: float = conductor.beat_time()
	assert_float(camera.trauma()).is_greater(0.0)
	await _frames(1)
	assert_float(conductor.beat_time()).is_greater(beat)


func test_shield_break_shakes_lightly_during_play() -> void:
	var run: Run = _start(-1.0)
	var player: Player = run.get_node("%Player") as Player
	var camera: GameCamera = run.get_node("%GameCamera") as GameCamera
	await _frames(30)
	player.shield_broken.emit()
	assert_float(camera.trauma()).is_equal(run.tuning.shield_trauma)
	assert_float(run.tuning.shield_trauma).is_less(run.tuning.death_trauma)
	for i: int in 10:
		await get_tree().process_frame
		assert_float(camera.offset.y).is_equal(0.0)
	assert_bool(player.is_alive()).is_true()


func _tuning() -> TuningConfig:
	return ResourceLoader.load(TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig


## Gerçek tur; freeze 0 ya da üstüyse ölüm donması o değer, eksiyse ayardaki değer.
func _start(freeze: float) -> Run:
	var run: Run = auto_free(RUN_SCENE.instantiate()) as Run
	run.tuning = _tuning()
	if freeze >= 0.0:
		run.tuning.death_freeze = freeze
	run.run_seed = 5
	add_child(run)
	return run


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
