extends Node
## Uygulama durum makinesi ve tur yaşam döngüsü (architecture.md §5.1, §7.3).
##
## Karar verir, sahneye dokunmaz: tohumu seçer, durumu tutar, turun başladığını ve bittiğini
## Events ile duyurur. Sahnedeki işi (eski turu kaldırıp yenisini kurmak) kök sahne Main yapar;
## autoload'lar sahne düğümlerine erişmez (.clauderules §3).

enum AppState { BOOT, MENU, RUNNING, PAUSED, RESULTS, SHOP }

## Uygulamanın şu anki durumu.
var state: AppState = AppState.BOOT

var _run_seed: int = 0
var _height_m: int = 0


func _ready() -> void:
	Events.player_died.connect(_on_player_died)
	Events.height_changed.connect(_on_height_changed)


## Durumu değiştirir. Geçersiz geçişlerin engellenmesi M5-01'de eklenecek.
func change_state(new_state: AppState) -> void:
	state = new_state


## Yeni turun tohumu. Günlük meydan okumada (M7-03) tohum tarihten gelir.
func new_run_seed() -> int:
	return RunRng.make_seed()


## Main, yeni turu dünyaya ekledikten sonra çağırır; tur başlamış sayılır ve duyurulur.
func begin_run(run_seed: int, start_sector: int) -> void:
	_run_seed = run_seed
	_height_m = 0
	change_state(AppState.RUNNING)
	Events.run_started.emit(run_seed, start_sector)


func _on_height_changed(meters: int) -> void:
	_height_m = meters


func _on_player_died(cause: GameTypes.DeathCause) -> void:
	if state != AppState.RUNNING:
		return
	change_state(AppState.RESULTS)
	var result: RunResult = RunResult.new()
	result.height_m = _height_m
	result.cause = cause
	result.run_seed = _run_seed
	Events.run_ended.emit(result)
