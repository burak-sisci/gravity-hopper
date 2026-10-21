extends GdUnitTestSuite
## İkinci Şans kararı (M4-07, architecture.md §7.3): yükte hak varsa GameManager ölümde turu
## bitirmez, AUTO_REVIVE_DELAY sonra player_revived duyurur; hak bitince ölüm turu bitirir.
## Bekleyen diriliş yeni tura taşmaz. Tur sahnesi yok, yalnızca Events.

var _revived: int = 0
var _results: Array[RunResult] = []


func before_test() -> void:
	_revived = 0
	_results.clear()
	Progression.reset()
	Events.player_revived.connect(_on_player_revived)
	Events.run_ended.connect(_on_run_ended)


func after_test() -> void:
	Events.player_revived.disconnect(_on_player_revived)
	Events.run_ended.disconnect(_on_run_ended)
	GameManager.change_state(GameManager.AppState.BOOT)
	Progression.reset()


func test_free_revive_then_the_second_death_ends_the_run() -> void:
	GameManager.begin_run(11, 1, _loadout(1))
	assert_int(GameManager.revives_left()).is_equal(1)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_array(_results).is_empty()
	assert_int(GameManager.revives_left()).is_equal(0)
	assert_int(GameManager.state).is_equal(GameManager.AppState.RUNNING)
	# Diriliş beklenirken gelen ölüm bildirimi hakkı ya da turu etkilemez.
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_array(_results).is_empty()
	assert_int(_revived).is_equal(0)
	await _wait_delay()
	assert_int(_revived).is_equal(1)
	Events.player_died.emit(GameTypes.DeathCause.FELL)
	assert_int(_results.size()).is_equal(1)
	assert_int(_results[0].cause).is_equal(GameTypes.DeathCause.FELL)
	assert_int(GameManager.state).is_equal(GameManager.AppState.RESULTS)
	await _wait_delay()
	assert_int(_revived).is_equal(1)


## Önceki turun zamanlayıcısı, yeni turdaki dirilişi erken getirmez; hakkı olmayan yeni turda
## da diriliş olmaz.
func test_pending_revive_does_not_carry_into_a_new_run() -> void:
	GameManager.begin_run(12, 1, _loadout(1))
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	await _seconds(GameManager.AUTO_REVIVE_DELAY * 0.5)
	GameManager.begin_run(13, 1, _loadout(1))
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	# Önceki turun zamanlayıcısı bu arada doldu; yeni turunki henüz dolmadı.
	await _seconds(GameManager.AUTO_REVIVE_DELAY * 0.75)
	assert_int(_revived).is_equal(0)
	await _seconds(GameManager.AUTO_REVIVE_DELAY * 0.5)
	assert_int(_revived).is_equal(1)
	GameManager.begin_run(14, 1, RunLoadout.new())
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_int(_results.size()).is_equal(1)
	await _wait_delay()
	assert_int(_revived).is_equal(1)


func test_without_the_upgrade_death_ends_the_run() -> void:
	GameManager.begin_run(14, 1, RunLoadout.new())
	assert_int(GameManager.revives_left()).is_equal(0)
	Events.player_died.emit(GameTypes.DeathCause.WALL)
	assert_int(_results.size()).is_equal(1)
	await _wait_delay()
	assert_int(_revived).is_equal(0)


func _loadout(revives: int) -> RunLoadout:
	var loadout: RunLoadout = RunLoadout.new()
	loadout.revives = revives
	return loadout


func _wait_delay() -> void:
	await _seconds(GameManager.AUTO_REVIVE_DELAY + 0.1)


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func _on_player_revived() -> void:
	_revived += 1


func _on_run_ended(result: RunResult) -> void:
	_results.append(result)
