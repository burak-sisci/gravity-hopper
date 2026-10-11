extends GdUnitTestSuite
## Diken, çarpışma kutusu ve ölüm akışı (M1-07, M1-12; architecture.md §7.3). Diken pasiftir;
## oyuncu yalnızca Events.player_died yayar. Geçici deneme betiklerinden taşındı (M2-02).

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SPIKE_SCENE: PackedScene = preload("res://scenes/entities/spike.tscn")
const SETTLE_FRAMES: int = 40
## Duvarın iç kenarı (koridor 18 m → yarısı 9 m = 450 px).
const WALL_EDGE_X: float = 450.0

var _run: Run
var _player: Player
var _deaths: Array[GameTypes.DeathCause] = []


func before_test() -> void:
	_deaths.clear()
	Events.player_died.connect(_on_player_died)


func after_test() -> void:
	Events.player_died.disconnect(_on_player_died)
	Events.debug_invincibility_changed.emit(false)


func test_spike_on_own_wall_kills_once() -> void:
	await _start_run()
	_add_spike(true, _player.position.y - 300.0)
	await _frames(60)
	assert_array(_deaths).is_equal([GameTypes.DeathCause.HAZARD])
	assert_bool(_player.is_alive()).is_false()


func test_spike_on_other_wall_does_not_kill() -> void:
	await _start_run()
	_add_spike(false, _player.position.y - 300.0)
	await _frames(60)
	assert_array(_deaths).is_empty()
	assert_bool(_player.is_alive()).is_true()


func test_dead_player_freezes() -> void:
	await _start_run()
	_add_spike(true, _player.position.y - 300.0)
	await _frames(60)
	var frozen_y: float = _player.position.y
	await _frames(20)
	assert_float(_player.position.y).is_equal(frozen_y)


func test_debug_invincibility_ignores_hits() -> void:
	await _start_run()
	Events.debug_invincibility_changed.emit(true)
	_add_spike(true, _player.position.y - 300.0)
	await _frames(60)
	assert_array(_deaths).is_empty()
	assert_bool(_player.is_alive()).is_true()
	assert_float(_player.modulate.a).is_less(1.0)


func _start_run() -> void:
	_run = auto_free(RUN_SCENE.instantiate()) as Run
	_run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	_run.run_seed = 12345
	add_child(_run)
	_player = _run.get_node("Player") as Player
	await _frames(SETTLE_FRAMES)


## Duvara yapışık bir diken ekler. Tur başındaki ilk geçici diken 25 m ileride olduğu için
## bu testlerdeki dikenler ondan önce gelir.
func _add_spike(on_left: bool, y: float) -> void:
	var spike: Node2D = SPIKE_SCENE.instantiate() as Node2D
	spike.position = Vector2(-WALL_EDGE_X if on_left else WALL_EDGE_X, y)
	spike.scale.x = 1.0 if on_left else -1.0
	_run.add_child(spike)


func _on_player_died(cause: GameTypes.DeathCause) -> void:
	_deaths.append(cause)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
