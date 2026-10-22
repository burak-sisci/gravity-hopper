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
	assert_int(Earnings.sector_bonus(1, 1)).is_equal(0)
	assert_int(Earnings.sector_bonus(1, 2)).is_equal(25)
	assert_int(Earnings.sector_bonus(1, 3)).is_equal(25 + 50)
	assert_int(Earnings.sector_bonus(1, 5)).is_equal(25 + 50 + 75 + 100)
	# Kontrol noktasından başlayan tur yalnızca kendi geçtiği sektörleri alır.
	assert_int(Earnings.sector_bonus(3, 5)).is_equal(75 + 100)
	assert_int(Earnings.sector_bonus(3, 3)).is_equal(0)


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


## Satın alma (M4-03): cüzdan yetmezse ya da en üst seviyedeyse olmaz; alınan seviye hemen
## kaydedilir ve duyurulur.
func test_buying_an_upgrade_spends_and_saves() -> void:
	var purchases: Array[String] = []
	var on_purchase: Callable = func(id: StringName, level: int) -> void:
		purchases.append("%s:%d" % [id, level])
	Events.upgrade_purchased.connect(on_purchase)
	assert_bool(Progression.buy_upgrade(&"magnet")).is_false()
	Progression.add_glimmers(99)
	assert_bool(Progression.can_buy(&"magnet")).is_false()
	assert_bool(Progression.buy_upgrade(&"magnet")).is_false()
	Progression.add_glimmers(1)
	assert_bool(Progression.buy_upgrade(&"magnet")).is_true()
	assert_int(Progression.upgrade_level(&"magnet")).is_equal(1)
	assert_int(Progression.glimmers).is_equal(0)
	assert_int(Progression.upgrade_cost(&"magnet")).is_equal(200)
	assert_float(Progression.loadout().magnet_m).is_equal_approx(1.8, 0.0001)
	assert_array(purchases).is_equal(["magnet:1"])
	assert_int(_wallets.back()).is_equal(0)
	var saved: Dictionary[String, Variant] = SaveManager.load_game()
	assert_int((saved["upgrades"] as Dictionary)["magnet"]).is_equal(1)
	assert_int(saved["glimmers"]).is_equal(0)
	Events.upgrade_purchased.disconnect(on_purchase)


func test_top_level_cannot_be_bought_again() -> void:
	Progression.add_glimmers(20000)
	assert_bool(Progression.buy_upgrade(&"second_chance")).is_true()
	assert_int(Progression.upgrade_cost(&"second_chance")).is_equal(-1)
	assert_bool(Progression.buy_upgrade(&"second_chance")).is_false()
	assert_int(Progression.glimmers).is_equal(15000)
	for i: int in 5:
		assert_bool(Progression.buy_upgrade(&"shield")).is_true()
	assert_bool(Progression.buy_upgrade(&"shield")).is_false()
	assert_int(Progression.glimmers).is_equal(15000 - 4650)
	assert_float(Progression.loadout().shield_regen_m).is_equal(600.0)
	# Bilinmeyen yükseltme alınamaz.
	assert_bool(Progression.buy_upgrade(&"laser_eyes")).is_false()
	assert_int(Progression.upgrade_cost(&"laser_eyes")).is_equal(-1)
	assert_int(Progression.upgrade_level(&"laser_eyes")).is_equal(0)


func test_bought_levels_survive_a_restart() -> void:
	Progression.add_glimmers(300)
	Progression.buy_upgrade(&"head_start")
	Progression.reload()
	assert_int(Progression.upgrade_level(&"head_start")).is_equal(1)
	assert_int(Progression.glimmers).is_equal(180)
	assert_int(Progression.upgrade_level(&"magnet")).is_equal(0)


## Glimmer Çarpanı (M4-04, GDD §9.1): tur sonu kazancına (Glimmer + sektör bonusu) +%10 / seviye,
## en yakın tam sayıya yuvarlanır.
func test_glimmer_boost_raises_the_run_earnings() -> void:
	var result: RunResult = _result(120, 30, 1, 3)
	result.glimmer_boost = 0.3
	Progression.finish_run(result)
	# 30 + 75 bonus = 105; %30'u 31,5 → 32.
	assert_int(result.boost_bonus).is_equal(32)
	assert_int(result.earned).is_equal(137)
	assert_int(Progression.glimmers).is_equal(137)
	assert_int((SaveManager.load_game()["stats"] as Dictionary)["glimmers_earned"]).is_equal(137)
	var plain: RunResult = _result(10, 7, 1, 1)
	Progression.finish_run(plain)
	assert_int(plain.boost_bonus).is_equal(0)
	assert_int(plain.earned).is_equal(7)
	assert_int(Earnings.boost_bonus(7, 0.1)).is_equal(1)
	assert_int(Earnings.boost_bonus(4, 0.1)).is_equal(0)


## Tur başındaki yük satın alınan seviyelerin etkisidir; tur sırasında alınan seviye o turun
## kazancını değiştirmez (GameManager yükü tur başında alır).
func test_loadout_follows_levels_and_is_fixed_for_the_run() -> void:
	var empty: RunLoadout = Progression.loadout()
	assert_float(empty.magnet_m).is_equal(0.0)
	assert_float(empty.glimmer_boost).is_equal(0.0)
	Progression.set_upgrade_level(&"magnet", 3)
	Progression.set_upgrade_level(&"glimmer_boost", 2)
	var loadout: RunLoadout = Progression.loadout()
	assert_float(loadout.magnet_m).is_equal_approx(3.4, 0.0001)
	assert_float(loadout.glimmer_boost).is_equal_approx(0.2, 0.0001)
	var results: Array[RunResult] = []
	var on_end: Callable = func(result: RunResult) -> void: results.append(result)
	Events.run_ended.connect(on_end)
	GameManager.begin_run(7, 1, loadout)
	Events.glimmer_collected.emit(10)
	Progression.set_upgrade_level(&"glimmer_boost", 5)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	Events.run_ended.disconnect(on_end)
	assert_int(results.size()).is_equal(1)
	assert_float(results[0].glimmer_boost).is_equal_approx(0.2, 0.0001)
	assert_int(results[0].boost_bonus).is_equal(2)
	assert_int(results[0].earned).is_equal(12)
	# Debug seviye koyma sınırlanır; bilinmeyen yükseltme yok sayılır.
	Progression.set_upgrade_level(&"magnet", 9)
	assert_int(Progression.upgrade_level(&"magnet")).is_equal(5)
	Progression.set_upgrade_level(&"laser_eyes", 2)
	assert_int(Progression.upgrade_level(&"laser_eyes")).is_equal(0)


## Kalkan yükseltmesi (M4-05, GDD §10): her seviye turu kalkanla başlatır; Sv1 yenilenmez,
## Sv2–5 kırılan kalkan 1500 / 1200 / 900 / 600 m sonra gelir.
func test_shield_loadout_follows_the_level() -> void:
	var none: RunLoadout = Progression.loadout()
	assert_bool(none.start_shield).is_false()
	assert_float(none.shield_regen_m).is_equal(0.0)
	var regen: Array[float] = [0.0, 1500.0, 1200.0, 900.0, 600.0]
	for level: int in range(1, 6):
		Progression.set_upgrade_level(&"shield", level)
		var loadout: RunLoadout = Progression.loadout()
		assert_bool(loadout.start_shield).is_true()
		assert_float(loadout.shield_regen_m).is_equal(regen[level - 1])


## Başlangıç Sıçraması (M4-06, GDD §10): ek yol 100 / 200 / 300 / 400 / 500 m.
func test_head_start_loadout_follows_the_level() -> void:
	assert_float(Progression.loadout().head_start_m).is_equal(0.0)
	for level: int in range(1, 6):
		Progression.set_upgrade_level(&"head_start", level)
		assert_float(Progression.loadout().head_start_m).is_equal(100.0 * level)


func test_second_chance_loadout_follows_the_level() -> void:
	assert_int(Progression.loadout().revives).is_equal(0)
	Progression.set_upgrade_level(&"second_chance", 1)
	assert_int(Progression.loadout().revives).is_equal(1)


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
