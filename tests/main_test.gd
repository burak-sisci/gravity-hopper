extends GdUnitTestSuite
## Tur döngüsü (M1-09, M5-03, architecture.md §5.1): ölüm → GameManager sonucu duyurur → sonuç
## ekranı açılır, tur kendiliğinden yeniden başlamaz → Tekrar yeni turu hemen kurar.
## Rekor (M3-14, M4-02): Progression kalıcı rekoru tutar ve kaydeder, Main yeni tura verir;
## tur sonu kazancı cüzdana girer. Kontrol noktası (M4-09): tur seçili sektörden başlar.
## Testler geçici kayıtla çalışır (SaveManager.TEST_SAVE_DIR).
## Otomatik kalite (M6-11): turda yavaş kareler sayılır, duraklatmada ve menüde sayılmaz; oyuncunun
## seçimi ezilmez.
## İlk açılış (M5-07): boş kayıtta menü yerine tanıtım parçasıyla başlayan tur ve "dokun" eli.
## Öteki testler deneyimli oyuncu gibi açar (ftue_done = true).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
## Ölümden sonra kendiliğinden yeni tur gelmediği gözlenen süre (eski akış 0,35 sn = 21 kare).
const NO_RESTART_FRAMES: int = 40
## Sahne silinmeden önce beklenen kare (sonuç ekranının tween'i, ertelenmiş çağrılar).
const TEARDOWN_FRAMES: int = 30
## Tanıtım parçasının kimliği (ChunkLibrary.intro'nun dosya adı).
const INTRO_ID: String = "ftue_intro_01"
const SettingsTest: GDScript = preload("res://tests/autoloads/settings_test.gd")
const SETTINGS_TEST_PATH: String = "user://settings_main_test.cfg"
## 40 FPS'lik (25 ms) kare sayısı: kuralın 30 sn'si ve biraz fazlası (AutoQuality).
const SLOW_FRAMES: int = 1210

var _main: Node
var _started_seeds: Array[int] = []
var _started_sectors: Array[int] = []
var _results: Array[RunResult] = []
var _placed: Array[StringName] = []


func before_test() -> void:
	_started_seeds.clear()
	_started_sectors.clear()
	_results.clear()
	_placed.clear()
	Progression.reset()
	Events.run_started.connect(_on_run_started)
	Events.run_ended.connect(_on_run_ended)
	Events.chunk_placed.connect(_on_chunk_placed)


func after_test() -> void:
	Events.run_started.disconnect(_on_run_started)
	Events.run_ended.disconnect(_on_run_ended)
	Events.chunk_placed.disconnect(_on_chunk_placed)
	Progression.reset()


## Açılış ana menüden (M5-02): tur yok, menü açık, HUD gizli; Başla turu kurar.
func test_main_opens_the_menu_first() -> void:
	_open_main()
	await _frames(2)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.MENU)
	assert_int(_world().get_child_count()).is_equal(0)
	assert_bool((_main.get_node("%MainMenu") as Control).visible).is_true()
	assert_bool((_main.get_node("%Hud") as Control).visible).is_false()
	Events.play_requested.emit()
	assert_bool((_main.get_node("%MainMenu") as Control).visible).is_false()
	assert_bool((_main.get_node("%Hud") as Control).visible).is_true()
	await _frames(TEARDOWN_FRAMES)


## İlk açılış (M5-07, GDD §18): boş kayıt menüyü atlar, tur tanıtım parçasıyla başlar, el görünür;
## ilk çevirmede el söner. İlk ölümde Yükseltmeler parlar; Tekrar'da tanıtım ve el yok.
func test_first_launch_starts_the_intro_run_with_the_tap_hint() -> void:
	_open_main(true)
	await _frames(5)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.RUNNING)
	assert_int(_started_seeds.size()).is_equal(1)
	assert_array(_placed).is_not_empty()
	assert_str(String(_placed[0])).is_equal(INTRO_ID)
	var hud: Hud = _main.get_node("%Hud") as Hud
	assert_bool(hud.tap_hint_visible()).is_true()
	Events.player_flipped.emit()
	assert_bool(hud.tap_hint_visible()).is_false()
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_bool(_results[0].first_run).is_true()
	var results: ResultsScreen = _main.get_node("%ResultsScreen") as ResultsScreen
	assert_bool(results.is_upgrades_highlighted()).is_true()
	assert_bool(Progression.ftue_done).is_true()
	_placed.clear()
	_retry(2)
	await _frames(5)
	assert_bool(hud.tap_hint_visible()).is_false()
	assert_array(_placed).not_contains([StringName(INTRO_ID)])
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_bool(_results[1].first_run).is_false()
	assert_bool(results.is_upgrades_highlighted()).is_false()
	await _frames(TEARDOWN_FRAMES)


func test_main_starts_a_run() -> void:
	await _start_main()
	assert_int(_started_seeds.size()).is_equal(1)
	assert_int(_started_seeds[0]).is_not_equal(0)
	assert_int(_world().get_child_count()).is_equal(1)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.RUNNING)


## Ölüm sonuç ekranını açar (HUD açık kalır, menü kapalı), ölü tur arkada kalır, yeni tur gelmez;
## Tekrar aynı karede yeni turu kurar ve sonuç ekranını kapatır.
func test_death_shows_results_and_retry_starts_a_new_run() -> void:
	await _start_main()
	var results: Control = _main.get_node("%ResultsScreen") as Control
	assert_bool(results.visible).is_false()
	var first_run: Node = _world().get_child(0)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.RESULTS)
	assert_bool(results.visible).is_true()
	assert_bool((_main.get_node("%MainMenu") as Control).visible).is_false()
	await _frames(NO_RESTART_FRAMES)
	assert_int(_started_seeds.size()).is_equal(1)
	assert_object(_world().get_child(0)).is_same(first_run)
	Events.retry_requested.emit()
	assert_int(_started_seeds.size()).is_equal(2)
	assert_bool(results.visible).is_false()
	await get_tree().process_frame
	assert_int(_started_seeds[1]).is_not_equal(_started_seeds[0])
	assert_int(_world().get_child_count()).is_equal(1)
	assert_object(_world().get_child(0)).is_not_same(first_run)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.RUNNING)


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
	# S1 ve S2 geçildi: sector_bonus × (1 + 2).
	var bonus: int = Earnings.tuning.sector_bonus * (1 + 2)
	assert_int(result.sector_bonus).is_equal(bonus)
	assert_int(result.earned).is_equal(result.glimmers + bonus)
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
	await _retry(2)
	assert_int(_current_run().record_height).is_equal(37)
	# Daha alçak bir tur rekoru düşürmez.
	Events.height_changed.emit(12)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_int(Progression.best_height_m).is_equal(37)
	assert_bool(_results[1].new_record).is_false()
	assert_int(_results[1].best_height_m).is_equal(37)
	await _retry(3)
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


## Menü (M5-01): sonuçtan menüye geçince tur kalkar ve kendiliğinden yeni tur gelmez; Başla
## niyeti seçili kontrol noktasından tur kurar.
func test_menu_removes_the_run_and_play_starts_one() -> void:
	Events.sector_entered.emit(2)
	Progression.select_start_sector(2)
	await _start_main()
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	Events.menu_requested.emit()
	assert_int(GameManager.state).is_equal(GameTypes.AppState.MENU)
	await _frames(NO_RESTART_FRAMES)
	assert_int(_world().get_child_count()).is_equal(0)
	assert_int(_started_seeds.size()).is_equal(1)
	Events.play_requested.emit()
	assert_array(_started_sectors).is_equal([2, 2])
	assert_int(GameManager.state).is_equal(GameTypes.AppState.RUNNING)
	await get_tree().process_frame
	assert_int(_world().get_child_count()).is_equal(1)


## Mağaza (M5-04): menüden açılınca menü ve HUD gizli, tur yok; sonuç ekranından açılınca tur
## kalkar; geri menüye döner.
func test_shop_opens_from_menu_and_results_without_a_run() -> void:
	_open_main()
	await _frames(2)
	var shop: Control = _main.get_node("%ShopScreen") as Control
	Events.shop_requested.emit(GameTypes.ShopTab.TRAILS)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.SHOP)
	assert_bool(shop.visible).is_true()
	assert_bool((_main.get_node("%MainMenu") as Control).visible).is_false()
	assert_bool((_main.get_node("%Hud") as Control).visible).is_false()
	Events.menu_requested.emit()
	assert_bool(shop.visible).is_false()
	assert_bool((_main.get_node("%MainMenu") as Control).visible).is_true()
	Events.play_requested.emit()
	await _frames(5)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	Events.shop_requested.emit(GameTypes.ShopTab.UPGRADES)
	assert_bool(shop.visible).is_true()
	assert_bool((_main.get_node("%ResultsScreen") as Control).visible).is_false()
	await get_tree().process_frame
	assert_int(_world().get_child_count()).is_equal(0)
	await _frames(TEARDOWN_FRAMES)


func test_settings_change_sets_neon_quality() -> void:
	var stored: GameTypes.Quality = Settings.effect_quality
	await _start_main()
	assert_int(Neon.quality).is_equal(stored)
	Settings.effect_quality = GameTypes.Quality.LOW
	Events.settings_changed.emit()
	assert_int(Neon.quality).is_equal(GameTypes.Quality.LOW)
	Settings.effect_quality = stored
	Neon.quality = GameTypes.Quality.HIGH


## Otomatik kalite (M6-11): oyuncu seçmediyse tur sürerken 30 sn boyunca 40 FPS'lik kareler
## kaliteyi bir kademe düşürür ve neon bileşenlerine uygular; duraklatmada ve menüde sayılmaz;
## oyuncunun seçimi ezilmez. Ayarlar geçici dosyaya yazılır.
func test_slow_frames_lower_quality_only_in_a_run_and_never_a_choice() -> void:
	var saved: Dictionary[String, Variant] = SettingsTest.snapshot()
	Settings.path = SETTINGS_TEST_PATH
	Settings.auto_quality = true
	Settings.quality_chosen = false
	Settings.effect_quality = GameTypes.Quality.HIGH
	await _start_main()
	_slow_frames(SLOW_FRAMES)
	assert_int(Settings.effect_quality).is_equal(GameTypes.Quality.MEDIUM)
	assert_int(Neon.quality).is_equal(GameTypes.Quality.MEDIUM)
	Settings.set_effect_quality(GameTypes.Quality.HIGH)
	_slow_frames(SLOW_FRAMES)
	assert_int(Settings.effect_quality).is_equal(GameTypes.Quality.HIGH)
	Settings.quality_chosen = false
	for state: GameTypes.AppState in [GameTypes.AppState.PAUSED, GameTypes.AppState.MENU]:
		assert_bool(GameManager.change_state(state)).is_true()
		_slow_frames(SLOW_FRAMES)
		assert_int(Settings.effect_quality).is_equal(GameTypes.Quality.HIGH)
	SettingsTest.restore(saved)
	Neon.quality = GameTypes.Quality.HIGH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TEST_PATH))
	await _frames(TEARDOWN_FRAMES)


## Duraklatma (M5-06): HUD düğmesi oyunu dondurur (oyuncu yerinde kalır), duraklatma ekranı açılır;
## devam isteği turu sürdürür (oyuncu yeniden ilerler); duraklatmadan Menü turu kaldırır ve
## sonucu QUIT nedeniyle duyurur.
func test_pause_freezes_the_run_and_menu_ends_it() -> void:
	await _start_main()
	await _frames(20)
	var player: Node2D = _current_run().get_node("%Player") as Node2D
	var pause: Control = _main.get_node("%PauseScreen") as Control
	Events.pause_requested.emit()
	assert_int(GameManager.state).is_equal(GameTypes.AppState.PAUSED)
	assert_bool(get_tree().paused).is_true()
	assert_bool(pause.visible).is_true()
	var frozen: Vector2 = player.global_position
	await _frames(30)
	assert_that(player.global_position).is_equal(frozen)
	Events.resume_requested.emit()
	assert_bool(get_tree().paused).is_false()
	assert_bool(pause.visible).is_false()
	await _frames(10)
	assert_that(player.global_position).is_not_equal(frozen)
	Events.pause_requested.emit()
	Events.menu_requested.emit()
	assert_bool(get_tree().paused).is_false()
	assert_int(GameManager.state).is_equal(GameTypes.AppState.MENU)
	assert_int(_results.size()).is_equal(1)
	assert_int(_results[0].cause).is_equal(GameTypes.DeathCause.QUIT)
	await _frames(NO_RESTART_FRAMES)
	assert_int(_world().get_child_count()).is_equal(0)


## Açılış menüden (M5-02); testler Başla ile tura girer.
func _start_main() -> void:
	_open_main()
	Events.play_requested.emit()
	await _frames(5)


func _open_main(first_launch: bool = false) -> void:
	GameManager.reset()
	Progression.ftue_done = not first_launch
	_main = auto_free(MAIN_SCENE.instantiate()) as Node
	add_child(_main)


func _world() -> Node2D:
	return _main.get_node("%World") as Node2D


func _current_run() -> Run:
	return _world().get_child(_world().get_child_count() - 1) as Run


## Sonuç ekranından Tekrar: yeni tur hemen kurulur (count. tur).
func _retry(count: int) -> void:
	Events.retry_requested.emit()
	assert_int(_started_seeds.size()).is_equal(count)
	await get_tree().process_frame


func _on_chunk_placed(chunk_id: StringName, _difficulty: int, _sector: int) -> void:
	_placed.append(chunk_id)


func _on_run_started(run_seed: int, start_sector: int) -> void:
	_started_seeds.append(run_seed)
	_started_sectors.append(start_sector)


func _on_run_ended(result: RunResult) -> void:
	_results.append(result)


## Ana sahneye count kadar 25 ms'lik kare verir; sayaç baştan (önceki gerçek kareler sayılmaz).
## Main'in gerçek kare yoluna (_process: mikrosaniye farkı) count tane 25 ms'lik kare verir.
func _slow_frames(count: int) -> void:
	_main.set(&"_auto_quality", AutoQuality.new())
	for i: int in count:
		_main.set(&"_last_frame_usec", Time.get_ticks_usec() - 25_000)
		_main.call(&"_process", 0.0)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
