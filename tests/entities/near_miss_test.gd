extends GdUnitTestSuite
## Kıl payı ve kombo (M2-14, architecture.md §8.5). Oyuncu sol duvarda tırmanırken yoluna 40 × 40
## px'lik bir test tehlikesi konur. Çarpışma kutusu ±21 px, kıl payı alanı ±61 px genişliktedir:
## 60 px yanından geçen tehlike kıl payıdır, 130 px'ten geçen değildir, içinden geçen (ölümsüzken)
## değildir. Tur boş bir parça kütüphanesiyle kurulur.
## Yavaş çekim (M3-12): zincirin ilk halkasında ve çarpanın büyüdüğü halkada zaman ölçeği düşer;
## ölümde ve tur yarıda bitince geri verilir.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SETTLE_FRAMES: int = 40

var _run: Run
var _player: Player
var _combos: Array[int] = []
var _multipliers: Array[int] = []
## Her kıl payının yayıldığı andaki zaman ölçeği.
var _scales: Array[float] = []
var _ended: int = 0
var _results: Array[RunResult] = []


func before_test() -> void:
	_combos.clear()
	_multipliers.clear()
	_scales.clear()
	_ended = 0
	_results.clear()
	Events.near_miss.connect(_on_near_miss)
	Events.combo_ended.connect(_on_combo_ended)
	Events.run_ended.connect(_on_run_ended)


func after_test() -> void:
	Events.near_miss.disconnect(_on_near_miss)
	Events.combo_ended.disconnect(_on_combo_ended)
	Events.run_ended.disconnect(_on_run_ended)
	Engine.time_scale = 1.0
	Events.debug_invincibility_changed.emit(false)


func test_close_pass_is_a_near_miss() -> void:
	await _start_run()
	_add_hazard(60.0, 200.0)
	await _frames(60)
	assert_array(_combos).is_equal([1])
	assert_bool(_player.is_alive()).is_true()


func test_far_pass_is_not() -> void:
	await _start_run()
	_add_hazard(130.0, 200.0)
	await _frames(60)
	assert_array(_combos).is_empty()


func test_touching_hazard_is_not() -> void:
	await _start_run()
	Events.debug_invincibility_changed.emit(true)
	_add_hazard(0.0, 200.0)
	await _frames(60)
	assert_array(_combos).is_empty()


func test_combo_grows_multiplies_and_ends() -> void:
	GameManager.begin_run(9, 1)
	await _start_run()
	# Oyuncu 10 px/kare tırmanır: tehlikeler 0,5 sn (300 px) arayla geçer.
	for i: int in 3:
		_add_hazard(60.0, 200.0 + i * 300.0)
	await _frames(130)
	assert_array(_combos).is_equal([1, 2, 3])
	assert_array(_multipliers).is_equal([1, 1, 2])
	# Yavaş çekim ilk halkada ve ×2 eşiğinde; arada değil.
	assert_array(_scales).is_equal([0.5, 1.0, 0.5])
	assert_int(_run.stats.multiplier).is_equal(2)
	assert_int(_run.stats.near_misses).is_equal(3)
	# Son kıl payından 2,5 sn sonra zincir biter, çarpan döner.
	await _frames(170)
	assert_int(_ended).is_equal(1)
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_int(_run.stats.multiplier).is_equal(1)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_int(_results.size()).is_equal(1)
	assert_int(_results[0].near_misses).is_equal(3)


func test_slow_motion_lasts_a_quarter_second_of_real_time() -> void:
	await _start_run()
	_add_hazard(60.0, 200.0)
	var waited: int = 0
	while _combos.is_empty() and waited < 60:
		await _frames(1)
		waited += 1
	assert_array(_combos).is_equal([1])
	var slow_frames: int = 0
	for i: int in 30:
		if Engine.time_scale < 1.0:
			slow_frames += 1
		await _frames(1)
	assert_int(slow_frames).is_between(14, 16)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_death_and_restart_give_time_back() -> void:
	await _start_run()
	_add_hazard(60.0, 200.0)
	while _combos.is_empty():
		await _frames(1)
	assert_float(Engine.time_scale).is_less(1.0)
	_player.die(GameTypes.DeathCause.HAZARD)
	await _frames(1)
	assert_float(Engine.time_scale).override_failure_message(
			"Ölümde zaman ölçeği dönmeli").is_equal(1.0)
	_run.free()
	await _start_run()
	_add_hazard(60.0, 200.0)
	_combos.clear()
	while _combos.is_empty():
		await _frames(1)
	assert_float(Engine.time_scale).is_less(1.0)
	_run.free()
	assert_float(Engine.time_scale).override_failure_message(
			"Tur yarıda bitince zaman ölçeği dönmeli").is_equal(1.0)


func _start_run() -> void:
	_run = auto_free(RUN_SCENE.instantiate()) as Run
	_run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	_run.run_seed = 6
	var library: ChunkLibrary = ChunkLibrary.new()
	library.chunks = [_empty_chunk()]
	(_run.get_node("%ChunkSpawner") as ChunkSpawner).library = library
	add_child(_run)
	_player = _run.get_node("%Player") as Player
	await _frames(SETTLE_FRAMES)


## Oyuncunun önüne (ahead px yukarıya), duvardaki konumundan dx sağa bir test tehlikesi koyar.
func _add_hazard(dx: float, ahead: float) -> void:
	var hazard: Area2D = Area2D.new()
	hazard.collision_layer = 4
	hazard.collision_mask = 0
	hazard.monitoring = false
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	hazard.add_child(shape)
	hazard.position = _player.position + Vector2(dx, -ahead)
	_run.add_child(hazard)


func _empty_chunk() -> PackedScene:
	var root: ChunkInfo = ChunkInfo.new()
	root.length_beats = 6
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _on_near_miss(combo: int, multiplier: int) -> void:
	_combos.append(combo)
	_multipliers.append(multiplier)
	_scales.append(Engine.time_scale)


func _on_combo_ended() -> void:
	_ended += 1


func _on_run_ended(result: RunResult) -> void:
	_results.append(result)
