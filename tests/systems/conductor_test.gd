extends GdUnitTestSuite
## Conductor (M2-07, architecture.md §8.3): vuruşlar oyun zamanından yayılır; gerçek turda
## dikenler yarım vuruş anlarında geçer (vuruş ızgarası ile ritim aynı).

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const DT: float = 1.0 / 60.0

var _beats: Array[int] = []
var _beat_frames: Array[int] = []
var _frame: int = 0


func before_test() -> void:
	_beats.clear()
	_beat_frames.clear()
	Events.beat.connect(_on_beat)


func after_test() -> void:
	Events.beat.disconnect(_on_beat)
	Events.debug_invincibility_changed.emit(false)


func test_beats_follow_bpm() -> void:
	var conductor: Conductor = auto_free(Conductor.new()) as Conductor
	add_child(conductor)
	# 100 BPM: vuruş 0,6 sn = 36 kare.
	for frame: int in 120:
		_frame = frame + 1
		conductor.advance(DT)
	assert_array(_beats).is_equal([1, 2, 3])
	assert_array(_beat_frames).is_equal([36, 72, 108])
	conductor.bpm = 120.0
	assert_float(conductor.beat_length()).is_equal_approx(0.5, 0.000001)


func test_time_scale_slows_beats() -> void:
	var conductor: Conductor = auto_free(Conductor.new()) as Conductor
	add_child(conductor)
	# Yavaş çekimde (0,3) delta küçülür: 0,6 sn'lik vuruş için 120 kare gerekir.
	for frame: int in 119:
		conductor.advance(DT * 0.3)
	assert_array(_beats).is_empty()
	conductor.advance(DT * 0.3)
	assert_array(_beats).is_equal([1])
	assert_float(conductor.run_time).is_equal_approx(0.6, 0.0001)


func test_spikes_pass_on_half_beats() -> void:
	var run: Run = auto_free(RUN_SCENE.instantiate()) as Run
	run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	run.run_seed = 77
	add_child(run)
	Events.debug_invincibility_changed.emit(true)
	var conductor: Conductor = run.get_node("%Conductor") as Conductor
	var spawner: ChunkSpawner = run.get_node("%ChunkSpawner") as ChunkSpawner
	var player: Node2D = run.get_node("%Player") as Node2D
	var half_beat: float = conductor.beat_length() * 0.5
	var passes: int = 0
	var previous_y: float = player.position.y
	for frame: int in 1500:
		await get_tree().physics_frame
		for chunk: ChunkInfo in spawner.active_chunks():
			for item: Node2D in chunk.items():
				var y: float = chunk.position.y + item.position.y
				if previous_y > y and player.position.y <= y:
					passes += 1
					# Geçiş anı yarım vuruşun tam katından en fazla bir kare sapar.
					var off: float = absf(conductor.run_time
							- roundf(conductor.run_time / half_beat) * half_beat)
					assert_float(off).override_failure_message(
							"%s %.3f sn'de geçti, yarım vuruştan %.3f sn uzak" % [
								item.name, conductor.run_time, off,
							]).is_less_equal(DT + 0.0001)
		previous_y = player.position.y
	assert_int(passes).is_greater(10)


func _on_beat(index: int) -> void:
	_beats.append(index)
	_beat_frames.append(_frame)
