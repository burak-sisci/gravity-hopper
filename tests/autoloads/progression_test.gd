extends GdUnitTestSuite
## Kalıcı ilerleme (M4-02, architecture.md §11): tur sonu kazancı (toplanan Glimmer + sektör
## bonusu), rekor, en yüksek sektör ve istatistikler kayda iner; uygulama yeniden açılınca geri
## gelir; arka plana geçişte kaydedilmemiş değişiklik yazılır. Testler geçici kayıtla çalışır
## (SaveManager.TEST_SAVE_DIR) ve her test boş kayıtla başlar.

var _wallets: Array[int] = []
var _records: Array[int] = []


func before_test() -> void:
	Progression.reset()
	_wallets.clear()
	_records.clear()
	Events.glimmers_changed.connect(_on_glimmers_changed)
	Events.best_height_changed.connect(_on_best_height_changed)


func after_test() -> void:
	Events.glimmers_changed.disconnect(_on_glimmers_changed)
	Events.best_height_changed.disconnect(_on_best_height_changed)
	Progression.reset()


func test_sector_bonus_counts_completed_sectors() -> void:
	# Her geçilen sektör için 25 × sektör numarası (GDD §9.1).
	assert_int(Progression.sector_bonus(1, 1)).is_equal(0)
	assert_int(Progression.sector_bonus(1, 2)).is_equal(25)
	assert_int(Progression.sector_bonus(1, 3)).is_equal(25 + 50)
	assert_int(Progression.sector_bonus(1, 5)).is_equal(25 + 50 + 75 + 100)
	# Kontrol noktasından başlayan tur yalnızca kendi geçtiği sektörleri alır.
	assert_int(Progression.sector_bonus(3, 5)).is_equal(75 + 100)
	assert_int(Progression.sector_bonus(3, 3)).is_equal(0)


func test_finished_run_fills_the_wallet_and_is_saved() -> void:
	var result: RunResult = _result(120, 30, 1, 3)
	result.near_misses = 4
	Progression.finish_run(result)
	assert_int(result.sector_bonus).is_equal(75)
	assert_int(result.earned).is_equal(105)
	assert_bool(result.new_record).is_true()
	assert_int(result.best_height_m).is_equal(120)
	assert_int(Progression.glimmers).is_equal(105)
	assert_int(Progression.best_height_m).is_equal(120)
	assert_int(Progression.highest_sector).is_equal(3)
	assert_array(_wallets).is_equal([105])
	assert_array(_records).is_equal([120])
	var saved: Dictionary[String, Variant] = SaveManager.load_game()
	assert_int(saved["glimmers"]).is_equal(105)
	assert_int(saved["best_height_m"]).is_equal(120)
	assert_int(saved["highest_sector"]).is_equal(3)
	var stats: Dictionary = saved["stats"]
	assert_int(stats["runs"]).is_equal(1)
	assert_int(stats["total_height_m"]).is_equal(120)
	assert_int(stats["near_misses"]).is_equal(4)
	assert_int(stats["glimmers_earned"]).is_equal(105)


func test_shorter_run_keeps_the_record() -> void:
	Progression.finish_run(_result(120, 10, 1, 2))
	var result: RunResult = _result(50, 7, 1, 1)
	Progression.finish_run(result)
	assert_bool(result.new_record).is_false()
	assert_int(result.best_height_m).is_equal(120)
	assert_int(Progression.best_height_m).is_equal(120)
	assert_int(Progression.highest_sector).is_equal(2)
	# Cüzdan birikir: 10 + 25 bonus, sonra 7.
	assert_int(Progression.glimmers).is_equal(42)
	assert_array(_records).is_equal([120])
	assert_int((SaveManager.load_game()["stats"] as Dictionary)["runs"]).is_equal(2)


func test_progress_survives_a_restart() -> void:
	Progression.finish_run(_result(240, 18, 2, 4))
	# Uygulama kapanıp açılmış gibi: bellek kayıttan yeniden kurulur.
	Progression.glimmers = 0
	Progression.best_height_m = 0
	Progression.highest_sector = 1
	_wallets.clear()
	_records.clear()
	Progression.reload()
	assert_int(Progression.glimmers).is_equal(18 + 50 + 75)
	assert_int(Progression.best_height_m).is_equal(240)
	assert_int(Progression.highest_sector).is_equal(4)
	# Yeniden açılınca arayüze ilk değerler duyurulur.
	assert_array(_wallets).is_equal([143])
	assert_array(_records).is_equal([240])


func test_unsaved_change_is_written_when_the_app_pauses_or_closes() -> void:
	Progression.add_glimmers(7)
	assert_int(SaveManager.load_game()["glimmers"]).is_equal(0)
	Progression.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(SaveManager.load_game()["glimmers"]).is_equal(7)
	Progression.add_glimmers(5)
	Progression.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_int(SaveManager.load_game()["glimmers"]).is_equal(12)


func test_reset_starts_from_an_empty_save() -> void:
	Progression.finish_run(_result(99, 5, 1, 2))
	Progression.reset()
	assert_int(Progression.glimmers).is_equal(0)
	assert_int(Progression.best_height_m).is_equal(0)
	assert_int(Progression.highest_sector).is_equal(1)
	assert_int(SaveManager.load_game()["glimmers"]).is_equal(0)


func _result(height_m: int, glimmers: int, start_sector: int, reached: int) -> RunResult:
	var result: RunResult = RunResult.new()
	result.height_m = height_m
	result.glimmers = glimmers
	result.start_sector = start_sector
	result.sector_reached = reached
	return result


func _on_glimmers_changed(total: int) -> void:
	_wallets.append(total)


func _on_best_height_changed(meters: int) -> void:
	_records.append(meters)
