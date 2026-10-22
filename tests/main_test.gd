extends GdUnitTestSuite
## Tur döngüsü (M1-09, architecture.md §5.1): ölüm → GameManager sonucu duyurur → Main turu
## kısa bir beklemeden sonra yeniden kurar. Telefonda 348–360 ms ölçüldü (M1-12).
## Rekor (M3-14, M4-02): Progression kalıcı rekoru tutar ve kaydeder, Main yeni tura verir;
## tur sonu kazancı cüzdana girer. Kontrol noktası (M4-09): tur seçili sektörden başlar.
## Testler geçici kayıtla çalışır (SaveManager.TEST_SAVE_DIR).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
## Yeniden başlama sınırı: 0,35 sn bekleme (21 kare) + pay. Telefonda ölçülen 360 ms'e karşılık.
const MAX_RESTART_FRAMES: int = 30
## Main'in yeniden başlama zamanlayıcısı askıdayken sahne silinmesin diye beklenen süre.
const TEARDOWN_FRAMES: int = 30

var _main: Node
var _started_seeds: Array[int] = []
var _started_sectors: Array[int] = []
var _results: Array[RunResult] = []


func before_test() -> void:
	_started_seeds.clear()
	_started_sectors.clear()
	_results.clear()
	Progression.reset()
	Events.run_started.connect(_on_run_started)
	Events.run_ended.connect(_on_run_ended)


func after_test() -> void:
	Events.run_started.disconnect(_on_run_started)
	Events.run_ended.disconnect(_on_run_ended)
	Progression.reset()


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


func test_result_carries_earnings_into_the_wallet() -> void:
	await _start_main()
	Events.glimmer_collected.emit(4)
	Events.sector_entered.emit(3)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	var result: RunResult = _results[0]
	assert_int(result.start_sector).is_equal(1)
	assert_int(result.sector_reached).is_equal(3)
	# S1 ve S2 geçildi: 25 × 1 + 25 × 2.
	assert_int(result.sector_bonus).is_equal(75)
	assert_int(result.earned).is_equal(result.glimmers + 75)
	assert_int(Progression.glimmers).is_equal(result.earned)
	assert_int(SaveManager.load_game()["glimmers"]).is_equal(result.earned)
	await _frames(TEARDOWN_FRAMES)


func test_record_is_saved_and_reaches_the_next_run() -> void:
	await _start_main()
	assert_int(_current_run().record_height).is_equal(0)
	Events.height_changed.emit(37)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_int(Progression.best_height_m).is_equal(37)
	assert_bool(_results[0].new_record).is_true()
	assert_int(SaveManager.load_game()["best_height_m"]).is_equal(37)
	await _wait_for_runs(2)
	assert_int(_current_run().record_height).is_equal(37)
	# Daha alçak bir tur rekoru düşürmez.
	Events.height_changed.emit(12)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_int(Progression.best_height_m).is_equal(37)
	assert_bool(_results[1].new_record).is_false()
	assert_int(_results[1].best_height_m).is_equal(37)
	await _wait_for_runs(3)
	assert_int(_current_run().record_height).is_equal(37)


func test_retry_request_starts_new_run_at_once() -> void:
	await _start_main()
	Events.retry_requested.emit()
	assert_int(_started_seeds.size()).is_equal(2)
	await get_tree().process_frame
	assert_int(_world().get_child_count()).is_equal(1)


## İlk tur seçili kontrol noktasından başlar; seçim değişince süren tur bozulmaz, sonraki tur
## yeni seçimden başlar.
func test_runs_start_from_the_selected_checkpoint() -> void:
	Events.sector_entered.emit(3)
	Progression.select_start_sector(2)
	await _start_main()
	assert_array(_started_sectors).is_equal([2])
	assert_int(_current_run().start_sector).is_equal(2)
	Progression.select_start_sector(3)
	assert_array(_started_sectors).is_equal([2])
	Events.retry_requested.emit()
	assert_array(_started_sectors).is_equal([2, 3])
	await get_tree().process_frame
	assert_int(_current_run().start_sector).is_equal(3)


func test_settings_change_sets_neon_quality() -> void:
	var stored: GameTypes.Quality = Settings.effect_quality
	await _start_main()
	assert_int(Neon.quality).is_equal(stored)
	Settings.effect_quality = GameTypes.Quality.LOW
	Events.settings_changed.emit()
	assert_int(Neon.quality).is_equal(GameTypes.Quality.LOW)
	Settings.effect_quality = stored
	Neon.quality = GameTypes.Quality.HIGH


func _start_main() -> void:
	_main = auto_free(MAIN_SCENE.instantiate()) as Node
	add_child(_main)
	await _frames(5)


func _world() -> Node2D:
	return _main.get_node("%World") as Node2D


func _current_run() -> Run:
	return _world().get_child(_world().get_child_count() - 1) as Run


## Ölümden sonraki yeniden başlamayı bekler (en çok MAX_RESTART_FRAMES + pay).
func _wait_for_runs(count: int) -> void:
	var frames: int = 0
	while _started_seeds.size() < count and frames < MAX_RESTART_FRAMES + 10:
		await get_tree().process_frame
		frames += 1
	assert_int(_started_seeds.size()).is_equal(count)


func _on_run_started(run_seed: int, start_sector: int) -> void:
	_started_seeds.append(run_seed)
	_started_sectors.append(start_sector)


func _on_run_ended(result: RunResult) -> void:
	_results.append(result)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
