extends GdUnitTestSuite
## Kontrol noktaları (M4-09, GDD §12, architecture.md §11): varılan her sektörün başı tur
## sırasında açılır; yalnızca açık sektör başlangıç olarak seçilebilir; açılan sektörler ve seçim
## uygulama yeniden açılınca durur. Testler geçici kayıtla çalışır (SaveManager.TEST_SAVE_DIR).

var _unlocked: Array[int] = []
var _selected: Array[int] = []


func before_test() -> void:
	Progression.reset()
	_unlocked.clear()
	_selected.clear()
	Events.sector_unlocked.connect(_on_sector_unlocked)
	Events.start_sector_selected.connect(_on_start_sector_selected)


func after_test() -> void:
	Events.sector_unlocked.disconnect(_on_sector_unlocked)
	Events.start_sector_selected.disconnect(_on_start_sector_selected)
	Progression.reset()


func test_reaching_a_sector_unlocks_it() -> void:
	assert_int(Progression.highest_sector).is_equal(1)
	assert_int(Progression.start_sector).is_equal(1)
	assert_bool(Progression.select_start_sector(2)).is_false()
	Events.sector_entered.emit(2)
	assert_int(Progression.highest_sector).is_equal(2)
	# Aynı ya da daha alçak sektöre yeniden varmak bir şey açmaz.
	Events.sector_entered.emit(2)
	Events.sector_entered.emit(1)
	assert_array(_unlocked).is_equal([2])
	# Açılmak seçmek değildir: tur yine seçili sektörden başlar.
	assert_int(Progression.start_sector).is_equal(1)
	assert_bool(Progression.select_start_sector(2)).is_true()
	assert_int(Progression.start_sector).is_equal(2)
	assert_array(_selected).is_equal([2])
	assert_int(SaveManager.load_game()["start_sector"]).is_equal(2)


func test_locked_sector_cannot_be_selected() -> void:
	Events.sector_entered.emit(2)
	for index: int in [0, -1, 3, 5]:
		assert_bool(Progression.select_start_sector(index)).is_false()
	assert_int(Progression.start_sector).is_equal(1)
	assert_array(_selected).is_empty()
	assert_int(SaveManager.load_game()["start_sector"]).is_equal(1)


func test_unlock_is_written_when_the_app_pauses() -> void:
	Events.sector_entered.emit(3)
	assert_int(SaveManager.load_game()["highest_sector"]).is_equal(1)
	Progression.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(SaveManager.load_game()["highest_sector"]).is_equal(3)


func test_finished_run_unlocks_the_reached_sector() -> void:
	var result: RunResult = RunResult.new()
	result.height_m = 800
	result.sector_reached = 2
	Progression.finish_run(result)
	assert_array(_unlocked).is_equal([2])
	assert_int(SaveManager.load_game()["highest_sector"]).is_equal(2)


func test_selection_survives_a_restart() -> void:
	Events.sector_entered.emit(2)
	Events.sector_entered.emit(3)
	Progression.select_start_sector(3)
	# Uygulama kapanıp açılmış gibi: bellek kayıttan yeniden kurulur.
	Progression.start_sector = 1
	Progression.highest_sector = 1
	Progression.reload()
	assert_int(Progression.highest_sector).is_equal(3)
	assert_int(Progression.start_sector).is_equal(3)
	assert_bool(Progression.select_start_sector(2)).is_true()
	Progression.reload()
	assert_int(Progression.start_sector).is_equal(2)
	Progression.reset()
	assert_int(Progression.start_sector).is_equal(1)


func test_saved_selection_never_points_at_a_locked_sector() -> void:
	var data: Dictionary[String, Variant] = SaveManager.default_data()
	data["highest_sector"] = 2
	data["start_sector"] = 4
	SaveManager.save_game(data)
	Progression.reload()
	assert_int(Progression.start_sector).is_equal(2)
	data["highest_sector"] = 0
	data["start_sector"] = 0
	SaveManager.save_game(data)
	Progression.reload()
	assert_int(Progression.highest_sector).is_equal(1)
	assert_int(Progression.start_sector).is_equal(1)


func _on_sector_unlocked(index: int) -> void:
	_unlocked.append(index)


func _on_start_sector_selected(index: int) -> void:
	_selected.append(index)
