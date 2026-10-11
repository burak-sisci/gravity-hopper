extends GdUnitTestSuite
## Tur döngüsü (M1-09, architecture.md §5.1): ölüm → GameManager sonucu duyurur → Main turu
## kısa bir beklemeden sonra yeniden kurar. Telefonda 348–360 ms ölçüldü (M1-12).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
## Yeniden başlama sınırı: 0,35 sn bekleme (21 kare) + pay. Telefonda ölçülen 360 ms'e karşılık.
const MAX_RESTART_FRAMES: int = 30
## Main'in yeniden başlama zamanlayıcısı askıdayken sahne silinmesin diye beklenen süre.
const TEARDOWN_FRAMES: int = 30

var _main: Node
var _started_seeds: Array[int] = []
var _results: Array[RunResult] = []


func before_test() -> void:
	_started_seeds.clear()
	_results.clear()
	Events.run_started.connect(_on_run_started)
	Events.run_ended.connect(_on_run_ended)


func after_test() -> void:
	Events.run_started.disconnect(_on_run_started)
	Events.run_ended.disconnect(_on_run_ended)


func test_main_starts_a_run() -> void:
	await _start_main()
	assert_int(_started_seeds.size()).is_equal(1)
	assert_int(_started_seeds[0]).is_not_equal(0)
	assert_int(_world().get_child_count()).is_equal(1)
	assert_int(GameManager.state).is_equal(GameManager.AppState.RUNNING)


func test_death_restarts_run_quickly() -> void:
	await _start_main()
	var first_run: Node = _world().get_child(0)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_int(GameManager.state).is_equal(GameManager.AppState.RESULTS)
	var frames: int = 0
	while _started_seeds.size() < 2 and frames < MAX_RESTART_FRAMES + 10:
		await get_tree().process_frame
		frames += 1
	assert_int(_started_seeds.size()).is_equal(2)
	if _started_seeds.size() < 2:
		return
	assert_int(frames).is_less_equal(MAX_RESTART_FRAMES)
	assert_int(_started_seeds[1]).is_not_equal(_started_seeds[0])
	assert_int(_world().get_child_count()).is_equal(1)
	assert_object(_world().get_child(0)).is_not_same(first_run)
	assert_int(GameManager.state).is_equal(GameManager.AppState.RUNNING)


func test_result_carries_height_cause_and_seed() -> void:
	await _start_main()
	Events.height_changed.emit(37)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	# Sonuç ekranındayken gelen ikinci ölüm yok sayılır.
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_int(_results.size()).is_equal(1)
	assert_int(_results[0].height_m).is_equal(37)
	assert_int(_results[0].cause).is_equal(GameTypes.DeathCause.HAZARD)
	assert_int(_results[0].run_seed).is_equal(_started_seeds[0])
	await _frames(TEARDOWN_FRAMES)


func test_retry_request_starts_new_run_at_once() -> void:
	await _start_main()
	Events.retry_requested.emit()
	assert_int(_started_seeds.size()).is_equal(2)
	await get_tree().process_frame
	assert_int(_world().get_child_count()).is_equal(1)


func _start_main() -> void:
	_main = auto_free(MAIN_SCENE.instantiate()) as Node
	add_child(_main)
	await _frames(5)


func _world() -> Node2D:
	return _main.get_node("%World") as Node2D


func _on_run_started(run_seed: int, _start_sector: int) -> void:
	_started_seeds.append(run_seed)


func _on_run_ended(result: RunResult) -> void:
	_results.append(result)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
