extends Node
## Uygulama durum makinesi ve tur yaşam döngüsü (architecture.md §5.1, §7.3).
##
## Karar verir, sahneye dokunmaz: tohumu seçer, durumu tutar, turun başladığını ve bittiğini
## Events ile duyurur. Sahnedeki işi (eski turu kaldırıp yenisini kurmak) kök sahne Main yapar;
## autoload'lar sahne düğümlerine erişmez (.clauderules §3).
##
## İkinci Şans (M4-07, M5-03, GDD §7): yükte diriliş hakkı varsa ölüm turu bitirmez; hak harcanır,
## durum RESULTS olur ve Events.revive_offered duyurulur (sonuç ekranı teklifi gösterir).
## revive_requested → oyuncu kaldığı yerde canlanır (Events.player_revived, durum RUNNING);
## revive_declined → tur biter. Teklif açıkken yeni tur ya da menü istenirse tur önce biter
## (kazanç kaybolmaz). Hak yoksa ölüm turu hemen bitirir.

## Durum makinesi (M5-01, architecture.md §5.1): her durumdan gidilebilecek durumlar. Burada
## olmayan geçiş reddedilir (debug günlüğüne "STATE rejected" yazılır). Yeni tur her durumdan
## başlayabilir (debug 5 tuşu ve --start= süren turu da yeniler).
const TRANSITIONS: Dictionary[GameTypes.AppState, Array] = {
	GameTypes.AppState.BOOT: [GameTypes.AppState.MENU, GameTypes.AppState.RUNNING],
	GameTypes.AppState.MENU: [GameTypes.AppState.RUNNING, GameTypes.AppState.SHOP],
	GameTypes.AppState.RUNNING: [
		GameTypes.AppState.RUNNING, GameTypes.AppState.PAUSED, GameTypes.AppState.RESULTS,
	],
	GameTypes.AppState.PAUSED: [GameTypes.AppState.RUNNING, GameTypes.AppState.MENU],
	GameTypes.AppState.RESULTS: [
		GameTypes.AppState.RUNNING, GameTypes.AppState.MENU, GameTypes.AppState.SHOP,
	],
	GameTypes.AppState.SHOP: [GameTypes.AppState.MENU, GameTypes.AppState.RUNNING],
}

## Uygulamanın şu anki durumu.
var state: GameTypes.AppState = GameTypes.AppState.BOOT

var _run_seed: int = 0
var _start_sector: int = 1
var _height_m: int = 0
var _sector_reached: int = 1
var _glimmers: int = 0
var _near_misses: int = 0
## Turun Glimmer Çarpanı (yükten, M4-04).
var _glimmer_boost: float = 0.0
## Turda kalan diriliş hakkı ve bekleyen diriliş (M4-07).
var _revives_left: int = 0
var _revive_pending: bool = false
## Teklif açıkken turu bitirecek ölüm nedeni.
var _death_cause: GameTypes.DeathCause = GameTypes.DeathCause.HAZARD


func _ready() -> void:
	Events.player_died.connect(_on_player_died)
	Events.height_changed.connect(_on_height_changed)
	Events.sector_entered.connect(_on_sector_entered)
	Events.glimmer_collected.connect(_on_glimmer_collected)
	Events.near_miss.connect(_on_near_miss)
	Events.menu_requested.connect(_on_menu_requested)
	Events.shop_requested.connect(_on_shop_requested)
	Events.revive_requested.connect(revive)
	Events.revive_declined.connect(_on_revive_declined)


## İzinliyse durumu değiştirir ve Events.app_state_changed duyurur; değilse durum aynı kalır.
func change_state(new_state: GameTypes.AppState) -> bool:
	if not can_change_to(new_state):
		if OS.is_debug_build():
			print("STATE rejected %s -> %s" % [
				GameTypes.AppState.keys()[state], GameTypes.AppState.keys()[new_state],
			])
		return false
	state = new_state
	Events.app_state_changed.emit(new_state)
	return true


## Şu anki durumdan new_state'e geçmek izinli mi.
func can_change_to(new_state: GameTypes.AppState) -> bool:
	return TRANSITIONS[state].has(new_state)


## Açılışta gidilecek durum. Main açılışta buna göre menüyü açar ya da turu başlatır.
## Açılış ana menüden (M5-02); ilk açılış deneyimi (M5-07) ilk açılışta doğrudan tura girer.
func launch_state() -> GameTypes.AppState:
	return GameTypes.AppState.MENU


## Durumu duyurmadan açılışa döndürür. Yalnızca testler içindir (her test temiz başlasın).
func reset() -> void:
	state = GameTypes.AppState.BOOT
	_revive_pending = false


## Yeni turun tohumu. Günlük meydan okumada (M7-03) tohum tarihten gelir.
func new_run_seed() -> int:
	return RunRng.make_seed()


## Main, yeni turu dünyaya ekledikten sonra çağırır; tur başlamış sayılır ve duyurulur.
## Kalıcı değerler (cüzdan, rekor) de yeniden duyurulur: arayüz ilk değerlerini böyle alır.
## Yük (M4-04) turun yükseltmeleridir; Glimmer Çarpanı tur sonu kazancına uygulanır.
func begin_run(run_seed: int, start_sector: int, loadout: RunLoadout = null) -> void:
	_close_offer()
	_run_seed = run_seed
	_glimmer_boost = loadout.glimmer_boost if loadout != null else 0.0
	_revives_left = loadout.revives if loadout != null else 0
	_start_sector = start_sector
	_height_m = 0
	_sector_reached = start_sector
	_glimmers = 0
	_near_misses = 0
	change_state(GameTypes.AppState.RUNNING)
	Progression.announce()
	Events.run_started.emit(run_seed, start_sector)


## Teklif edilen dirilişi yapar (sonuç ekranındaki Dirilt): durum RUNNING olur,
## Events.player_revived duyurulur, tur sürer. Teklif yoksa bir şey olmaz.
func revive() -> void:
	if not _revive_pending or state != GameTypes.AppState.RESULTS:
		return
	_revive_pending = false
	change_state(GameTypes.AppState.RUNNING)
	Events.player_revived.emit()


## Diriliş teklifi açık mı (testler ve sonuç ekranı).
func is_revive_offered() -> bool:
	return _revive_pending


## Turda kalan diriliş hakkı (testler).
func revives_left() -> int:
	return _revives_left


func _on_height_changed(meters: int) -> void:
	_height_m = meters


func _on_glimmer_collected(value: int) -> void:
	if state == GameTypes.AppState.RUNNING:
		_glimmers += value


func _on_near_miss(_combo: int, _multiplier: int) -> void:
	if state == GameTypes.AppState.RUNNING:
		_near_misses += 1


func _on_sector_entered(index: int) -> void:
	_sector_reached = maxi(_sector_reached, index)


func _on_player_died(cause: GameTypes.DeathCause) -> void:
	if state != GameTypes.AppState.RUNNING or _revive_pending:
		return
	_death_cause = cause
	change_state(GameTypes.AppState.RESULTS)
	if _revives_left > 0:
		_revives_left -= 1
		_revive_pending = true
		Events.revive_offered.emit(_height_m)
		return
	_end_run()


## Turu bitirir: sonuç kurulur, kazanç ve rekor kaydedilir, Events.run_ended duyurulur.
func _end_run() -> void:
	var result: RunResult = RunResult.new()
	result.height_m = _height_m
	result.cause = _death_cause
	result.run_seed = _run_seed
	result.start_sector = _start_sector
	result.sector_reached = _sector_reached
	result.glimmers = _glimmers
	result.near_misses = _near_misses
	result.glimmer_boost = _glimmer_boost
	# Kazanç ve rekor sonuca yazılır, kayıt run_ended'den önce diske iner (§7.3).
	Progression.finish_run(result)
	Events.run_ended.emit(result)


## Menü isteği: turdan çıkılır (sonuç ekranından ya da duraklatmadan). İzinsizse bir şey olmaz.
## Diriliş teklifi açıksa tur önce biter.
func _on_menu_requested() -> void:
	if can_change_to(GameTypes.AppState.MENU):
		_close_offer()
		change_state(GameTypes.AppState.MENU)


## Mağaza isteği (ana menü ve sonuç ekranı, M5-04); sekmeyi ekran kendisi seçer.
func _on_shop_requested(_tab: GameTypes.ShopTab) -> void:
	if can_change_to(GameTypes.AppState.SHOP):
		_close_offer()
		change_state(GameTypes.AppState.SHOP)


func _on_revive_declined() -> void:
	if state == GameTypes.AppState.RESULTS:
		_close_offer()


## Açık diriliş teklifi varsa turu bitirir (Vazgeç, yeni tur ya da menü).
func _close_offer() -> void:
	if not _revive_pending:
		return
	_revive_pending = false
	_end_run()
