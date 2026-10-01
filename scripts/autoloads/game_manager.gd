extends Node
## Uygulama durum makinesi.
##
## Menü, tur, duraklatma ve sonuç ekranları arasındaki geçişleri yönetir.
## Turu Run sahnesine aşağı çağrıyla başlatır, sonuçları Events üzerinden duyurur.
## M0-06 iskeleti: yalnızca durum takibi. Tur döngüsü M1-07'de, sahne geçişleri M5-01'de eklenecek.

enum AppState { BOOT, MENU, RUNNING, PAUSED, RESULTS, SHOP }

## Uygulamanın şu anki durumu.
var state: AppState = AppState.BOOT


func _ready() -> void:
	Events.player_died.connect(_on_player_died)


## Durumu değiştirir. Geçersiz geçişlerin engellenmesi M5-01'de eklenecek.
func change_state(new_state: AppState) -> void:
	state = new_state


func _on_player_died(_cause: GameTypes.DeathCause) -> void:
	change_state(AppState.RESULTS)
