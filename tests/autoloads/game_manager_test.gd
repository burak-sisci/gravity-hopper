extends GdUnitTestSuite
## İkinci Şans kararı (M4-07, M5-03, architecture.md §7.3): yükte hak varsa ölüm turu bitirmez;
## hak harcanır, durum RESULTS olur ve revive_offered duyurulur. revive_requested turu sürdürür,
## revive_declined bitirir; teklif açıkken yeni tur ya da menü turu önce bitirir (kazanç kaybolmaz).
## Kendiliğinden diriliş yoktur. Tur sahnesi yok, yalnızca Events.
## Durum makinesi (M5-01, architecture.md §5.1): 36 geçişin hepsi, yazılı akışa karşı.

## İzinli geçişler, architecture.md §5.1'deki akıştan elle yazıldı (koddaki tablodan kopya değil):
## BOOT → MENU | RUNNING (ilk açılış, M5-07); MENU → RUNNING | SHOP;
## RUNNING → RUNNING (yeni tur) | PAUSED | RESULTS; PAUSED → RUNNING | MENU;
## RESULTS → RUNNING | MENU | SHOP; SHOP → MENU | RUNNING.
const ALLOWED: Array[String] = [
	"BOOT>MENU", "BOOT>RUNNING", "MENU>RUNNING", "MENU>SHOP", "RUNNING>RUNNING", "RUNNING>PAUSED",
	"RUNNING>RESULTS", "PAUSED>RUNNING", "PAUSED>MENU", "RESULTS>RUNNING", "RESULTS>MENU",
	"RESULTS>SHOP", "SHOP>MENU", "SHOP>RUNNING",
]

var _revived: int = 0
var _offers: Array[int] = []
var _results: Array[RunResult] = []
var _states: Array[GameTypes.AppState] = []


func before_test() -> void:
	_revived = 0
	_offers.clear()
	_results.clear()
	_states.clear()
	Progression.reset()
	Events.player_revived.connect(_on_player_revived)
	Events.revive_offered.connect(_on_revive_offered)
	Events.app_state_changed.connect(_on_app_state_changed)
	Events.run_ended.connect(_on_run_ended)


func after_test() -> void:
	Events.player_revived.disconnect(_on_player_revived)
	Events.revive_offered.disconnect(_on_revive_offered)
	Events.run_ended.disconnect(_on_run_ended)
	Events.app_state_changed.disconnect(_on_app_state_changed)
	GameManager.reset()
	Progression.reset()


func test_offered_revive_continues_then_the_second_death_ends_the_run() -> void:
	GameManager.begin_run(11, 1, _loadout(1))
	assert_int(GameManager.revives_left()).is_equal(1)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_array(_results).is_empty()
	assert_array(_offers).contains_exactly([0])
	assert_int(GameManager.revives_left()).is_equal(0)
	assert_bool(GameManager.is_revive_offered()).is_true()
	assert_int(GameManager.state).is_equal(GameTypes.AppState.RESULTS)
	# Teklif açıkken gelen ölüm bildirimi hakkı, teklifi ya da turu etkilemez.
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_array(_results).is_empty()
	assert_int(_offers.size()).is_equal(1)
	# Kendiliğinden diriliş yok: yalnızca istekle.
	await _seconds(0.6)
	assert_int(_revived).is_equal(0)
	Events.revive_requested.emit()
	assert_int(_revived).is_equal(1)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.RUNNING)
	assert_bool(GameManager.is_revive_offered()).is_false()
	# İkinci istek bir şey yapmaz.
	Events.revive_requested.emit()
	assert_int(_revived).is_equal(1)
	Events.player_died.emit(GameTypes.DeathCause.FELL)
	assert_int(_results.size()).is_equal(1)
	assert_int(_results[0].cause).is_equal(GameTypes.DeathCause.FELL)
	assert_int(_offers.size()).is_equal(1)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.RESULTS)
	Events.revive_requested.emit()
	assert_int(_revived).is_equal(1)


## Vazgeç turu ilk ölümün nedeniyle bitirir; Glimmer cüzdana girer, sonra diriliş olmaz.
func test_declined_revive_ends_the_run_and_keeps_the_earnings() -> void:
	GameManager.begin_run(12, 1, _loadout(1))
	Events.height_changed.emit(40)
	Events.glimmer_collected.emit(7)
	Events.player_died.emit(GameTypes.DeathCause.WALL)
	assert_array(_offers).contains_exactly([40])
	Events.revive_declined.emit()
	assert_int(_results.size()).is_equal(1)
	assert_int(_results[0].cause).is_equal(GameTypes.DeathCause.WALL)
	assert_int(_results[0].height_m).is_equal(40)
	assert_int(Progression.glimmers).is_equal(_results[0].earned)
	assert_int(_results[0].earned).is_greater_equal(7)
	Events.revive_declined.emit()
	Events.revive_requested.emit()
	assert_int(_results.size()).is_equal(1)
	assert_int(_revived).is_equal(0)


## Teklif açıkken yeni tur, menü ya da mağaza: tur önce biter (sonuç ve kazanç bir kez), teklif
## yeni tura taşmaz; hakkı olmayan yeni turda teklif olmaz.
func test_open_offer_closes_on_a_new_run_or_menu() -> void:
	GameManager.begin_run(13, 1, _loadout(1))
	Events.glimmer_collected.emit(5)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	GameManager.begin_run(14, 1, RunLoadout.new())
	assert_int(_results.size()).is_equal(1)
	assert_int(Progression.glimmers).is_equal(_results[0].earned)
	assert_bool(GameManager.is_revive_offered()).is_false()
	Events.revive_requested.emit()
	assert_int(_revived).is_equal(0)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_int(_results.size()).is_equal(2)
	assert_int(_offers.size()).is_equal(1)
	GameManager.begin_run(15, 1, _loadout(1))
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	Events.menu_requested.emit()
	assert_int(GameManager.state).is_equal(GameTypes.AppState.MENU)
	assert_int(_results.size()).is_equal(3)
	Events.revive_requested.emit()
	assert_int(_revived).is_equal(0)
	GameManager.begin_run(16, 1, _loadout(1))
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	Events.shop_requested.emit(GameTypes.ShopTab.UPGRADES)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.SHOP)
	assert_int(_results.size()).is_equal(4)


func test_without_the_upgrade_death_ends_the_run() -> void:
	GameManager.begin_run(14, 1, RunLoadout.new())
	assert_int(GameManager.revives_left()).is_equal(0)
	Events.player_died.emit(GameTypes.DeathCause.WALL)
	assert_int(_results.size()).is_equal(1)
	assert_array(_offers).is_empty()
	Events.revive_requested.emit()
	assert_int(_revived).is_equal(0)


## Her durumdan her duruma: izinliyse geçilir ve duyurulur, değilse durum aynı kalır, duyuru yok.
func test_every_transition_follows_the_flow() -> void:
	var names: PackedStringArray = PackedStringArray(GameTypes.AppState.keys())
	var allowed: int = 0
	for from: int in names.size():
		for to: int in names.size():
			GameManager.reset()
			GameManager.state = from as GameTypes.AppState
			_states.clear()
			var pair: String = "%s>%s" % [names[from], names[to]]
			var expected: bool = ALLOWED.has(pair)
			var changed: bool = GameManager.change_state(to as GameTypes.AppState)
			assert_bool(changed).override_failure_message(pair).is_equal(expected)
			var now: int = to if expected else from
			assert_int(GameManager.state).override_failure_message(pair).is_equal(now)
			assert_int(_states.size()).override_failure_message(pair).is_equal(1 if expected else 0)
			allowed += 1 if changed else 0
	assert_int(allowed).is_equal(ALLOWED.size())


## Menü isteği sonuçtan ve duraklatmadan menüye götürür, süren turda reddedilir.
func test_menu_request_leaves_results_but_not_a_running_run() -> void:
	GameManager.begin_run(15, 1, _loadout(1))
	Events.menu_requested.emit()
	assert_int(GameManager.state).is_equal(GameTypes.AppState.RUNNING)
	GameManager.change_state(GameTypes.AppState.PAUSED)
	Events.menu_requested.emit()
	assert_int(GameManager.state).is_equal(GameTypes.AppState.MENU)
	GameManager.begin_run(16, 1, RunLoadout.new())
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	Events.menu_requested.emit()
	assert_int(GameManager.state).is_equal(GameTypes.AppState.MENU)
	assert_array(_states).contains_exactly([
		GameTypes.AppState.RUNNING, GameTypes.AppState.PAUSED, GameTypes.AppState.MENU,
		GameTypes.AppState.RUNNING, GameTypes.AppState.RESULTS, GameTypes.AppState.MENU,
	])


func _loadout(revives: int) -> RunLoadout:
	var loadout: RunLoadout = RunLoadout.new()
	loadout.revives = revives
	return loadout


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func _on_player_revived() -> void:
	_revived += 1


func _on_revive_offered(height_m: int) -> void:
	_offers.append(height_m)


func _on_run_ended(result: RunResult) -> void:
	_results.append(result)


func _on_app_state_changed(state: GameTypes.AppState) -> void:
	_states.append(state)
