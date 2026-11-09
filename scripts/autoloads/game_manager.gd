extends Node
## Uygulama durum makinesi ve tur yaşam döngüsü (architecture.md §5.1, §7.3).
##
## Karar verir, sahneye dokunmaz: tohumu seçer, durumu tutar, turun başladığını ve bittiğini
## Events ile duyurur. Sahnedeki işi (eski turu kaldırıp yenisini kurmak) kök sahne Main yapar;
## autoload'lar sahne düğümlerine erişmez (.clauderules §3).
##
## İkinci Şans (M4-07, GDD §7): yükte diriliş hakkı varsa ölüm turu bitirmez; hak harcanır ve
## kısa bir süre sonra Events.player_revived duyurulur (Run oyuncuyu canlandırır). Hak yoksa ya
## da harcandıysa ölüm turu bitirir. Sonuç ekranı gelene kadar diriliş kendiliğinden olur;
## M5-03'te düğmeye (Events.revive_requested → revive()) bağlanır.

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

## M4-07 geçici akışı: ölümden bu kadar sonra, hak varsa, diriliş kendiliğinden olur (ölüm
## donması ve patlaması görünsün). M5-03'te sonuç ekranındaki düğme bunun yerini alır.
const AUTO_REVIVE_DELAY: float = 0.8

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
## Her turda artar: önceki turun bekleyen dirilişi yeni turda olmasın.
var _run_serial: int = 0


func _ready() -> void:
	Events.player_died.connect(_on_player_died)
	Events.height_changed.connect(_on_height_changed)
	Events.sector_entered.connect(_on_sector_entered)
	Events.glimmer_collected.connect(_on_glimmer_collected)
	Events.near_miss.connect(_on_near_miss)
	Events.menu_requested.connect(_on_menu_requested)


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
## Ana menü (M5-02) ve ilk açılış deneyimi (M5-07) gelene dek her açılış doğrudan tura girer.
func launch_state() -> GameTypes.AppState:
	return GameTypes.AppState.RUNNING


## Durumu duyurmadan açılışa döndürür. Yalnızca testler içindir (her test temiz başlasın).
func reset() -> void:
	state = GameTypes.AppState.BOOT
	_revive_pending = false
	_run_serial += 1


## Yeni turun tohumu. Günlük meydan okumada (M7-03) tohum tarihten gelir.
func new_run_seed() -> int:
	return RunRng.make_seed()


## Main, yeni turu dünyaya ekledikten sonra çağırır; tur başlamış sayılır ve duyurulur.
## Kalıcı değerler (cüzdan, rekor) de yeniden duyurulur: arayüz ilk değerlerini böyle alır.
## Yük (M4-04) turun yükseltmeleridir; Glimmer Çarpanı tur sonu kazancına uygulanır.
func begin_run(run_seed: int, start_sector: int, loadout: RunLoadout = null) -> void:
	_run_seed = run_seed
	_glimmer_boost = loadout.glimmer_boost if loadout != null else 0.0
	_revives_left = loadout.revives if loadout != null else 0
	_revive_pending = false
	_run_serial += 1
	_start_sector = start_sector
	_height_m = 0
	_sector_reached = start_sector
	_glimmers = 0
	_near_misses = 0
	change_state(GameTypes.AppState.RUNNING)
	Progression.announce()
	Events.run_started.emit(run_seed, start_sector)


## Bekleyen dirilişi yapar: Events.player_revived duyurulur, tur sürer. Bekleyen yoksa ya da
## tur sürmüyorsa bir şey olmaz.
func revive() -> void:
	if not _revive_pending or state != GameTypes.AppState.RUNNING:
		return
	_revive_pending = false
	Events.player_revived.emit()


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
	if _revives_left > 0:
		_revives_left -= 1
		_revive_pending = true
		_revive_later(_run_serial)
		return
	change_state(GameTypes.AppState.RESULTS)
	var result: RunResult = RunResult.new()
	result.height_m = _height_m
	result.cause = cause
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
## Bekleyen diriliş iptal olur.
func _on_menu_requested() -> void:
	if change_state(GameTypes.AppState.MENU):
		_revive_pending = false
		_run_serial += 1


## Geçici akış (M5-03'e dek): diriliş AUTO_REVIVE_DELAY sonra kendiliğinden. Arada yeni tur
## başladıysa (serial değişti) bir şey olmaz.
func _revive_later(serial: int) -> void:
	await get_tree().create_timer(AUTO_REVIVE_DELAY).timeout
	if serial == _run_serial:
		revive()
