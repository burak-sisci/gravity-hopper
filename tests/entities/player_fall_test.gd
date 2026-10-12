extends GdUnitTestSuite
## Duvar boşluğundan düşme ve coyote süresi (M2-11, architecture.md §8.1). Tur, tek bir boşluklu
## parçadan oluşan bir kütüphaneyle kurulur: sol duvarda 1. vuruştan başlayan 4 vuruşluk boşluk.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SETTLE_FRAMES: int = 40
const MAX_FRAMES: int = 600

var _run: Run
var _player: Player
var _deaths: Array[GameTypes.DeathCause] = []


func before_test() -> void:
	_deaths.clear()
	Events.player_died.connect(_on_player_died)


func after_test() -> void:
	Events.player_died.disconnect(_on_player_died)


func test_player_falls_through_gap() -> void:
	await _start_run()
	await _frames_until(func() -> bool: return not _deaths.is_empty())
	assert_array(_deaths).is_equal([GameTypes.DeathCause.FELL])
	assert_bool(_player.is_gravity_right()).is_false()


func test_tap_right_after_wall_ends_still_flips() -> void:
	await _start_run()
	await _frames_until(func() -> bool: return not _player.is_on_wall())
	# Duvar bitti; coyote süresi (0,1 sn = 6 kare) içinde dokunuş.
	await _frames(2)
	_tap()
	await _frames(90)
	assert_array(_deaths).is_empty()
	assert_bool(_player.is_gravity_right()).is_true()
	assert_bool(_player.is_on_wall()).is_true()


func test_tap_after_coyote_is_too_late() -> void:
	await _start_run()
	await _frames_until(func() -> bool: return not _player.is_on_wall())
	await _frames(10)
	_tap()
	await _frames(30)
	assert_array(_deaths).is_equal([GameTypes.DeathCause.FELL])


func _start_run() -> void:
	_run = auto_free(RUN_SCENE.instantiate()) as Run
	_run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	_run.run_seed = 4
	var library: ChunkLibrary = ChunkLibrary.new()
	library.chunks = [_gap_chunk()]
	(_run.get_node("%ChunkSpawner") as ChunkSpawner).library = library
	add_child(_run)
	_player = _run.get_node("%Player") as Player
	await _frames(SETTLE_FRAMES)


## 8 vuruşluk parça; sol duvarda 1. vuruştan 5. vuruşa boşluk. Yalnızca test için S1'de izinli.
func _gap_chunk() -> PackedScene:
	var root: ChunkInfo = ChunkInfo.new()
	root.length_beats = 8
	var gap: WallGap = WallGap.new()
	gap.position = Vector2(-450, -100)
	gap.length = 400.0
	root.add_child(gap)
	gap.owner = root
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _frames_until(condition: Callable) -> void:
	for i: int in MAX_FRAMES:
		if condition.call():
			return
		await get_tree().physics_frame


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _tap() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(540, 1200)
	get_tree().root.push_input(touch, true)


func _on_player_died(cause: GameTypes.DeathCause) -> void:
	_deaths.append(cause)
