extends GdUnitTestSuite
## Kalkan (M2-16, GDD §7): tek darbeyi emer, 1 sn dokunulmazlık, çöküş duvarını 8 m çeker,
## Events.shield_changed. Oyuncu sol duvarda tırmanırken kendi duvarına dikenler konur; tur boş
## bir parça kütüphanesiyle kurulur (oyuncu 10 px/kare tırmanır).

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/entities/spike.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SETTLE_FRAMES: int = 40

var _run: Run
var _player: Player
var _deaths: Array[GameTypes.DeathCause] = []
var _shield_events: Array[bool] = []


func before_test() -> void:
	_deaths.clear()
	_shield_events.clear()
	Events.player_died.connect(_on_player_died)
	Events.shield_changed.connect(_on_shield_changed)


func after_test() -> void:
	Events.player_died.disconnect(_on_player_died)
	Events.shield_changed.disconnect(_on_shield_changed)


func test_shield_absorbs_one_hit_then_grace_then_death() -> void:
	await _start_run()
	Events.debug_shield_requested.emit()
	assert_bool(_player.has_shield()).is_true()
	var pressure: PressureSystem = _run.get_node("%PressureSystem") as PressureSystem
	# 1. diken ~24. karede değer (kalkan tükenir), 2.'si ~64. karede (dokunulmazlık, 60 kare),
	# 3.'sü ~134. karede (dokunulmazlık bitti: ölüm).
	_add_spike(300.0)
	_add_spike(700.0)
	_add_spike(1400.0)
	await _frames(40)
	assert_array(_deaths).is_empty()
	assert_bool(_player.has_shield()).is_false()
	assert_array(_shield_events).is_equal([true, false])
	# 20 m − 8 m kalkan çekmesi − sürünme (S1 0,3 m/sn).
	assert_float(pressure.distance_m).is_less(12.5)
	await _frames(50)
	assert_array(_deaths).is_empty()
	await _frames(70)
	assert_array(_deaths).is_equal([GameTypes.DeathCause.HAZARD])


func test_without_shield_first_hit_kills() -> void:
	await _start_run()
	_add_spike(300.0)
	await _frames(40)
	assert_array(_deaths).is_equal([GameTypes.DeathCause.HAZARD])
	assert_array(_shield_events).is_empty()


func _start_run() -> void:
	_run = auto_free(RUN_SCENE.instantiate()) as Run
	_run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	_run.run_seed = 2
	var library: ChunkLibrary = ChunkLibrary.new()
	var root: ChunkInfo = ChunkInfo.new()
	root.length_beats = 6
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	library.chunks = [scene]
	(_run.get_node("%ChunkSpawner") as ChunkSpawner).library = library
	add_child(_run)
	_player = _run.get_node("%Player") as Player
	await _frames(SETTLE_FRAMES)


## Oyuncunun duvarına (sol), ahead px yukarıya diken koyar.
func _add_spike(ahead: float) -> void:
	var spike: Node2D = SPIKE_SCENE.instantiate() as Node2D
	spike.position = Vector2(-450, _player.position.y - ahead)
	_run.add_child(spike)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _on_player_died(cause: GameTypes.DeathCause) -> void:
	_deaths.append(cause)


func _on_shield_changed(active: bool) -> void:
	_shield_events.append(active)
