extends Control
## Minimal HUD (M1-10, GDD §20): sol üstte anlık yükseklik, altında oturum rekoru.
## Yalnızca Events sinyallerini dinler; oyun dünyasındaki hiçbir düğüme erişmez (.clauderules §3).
## Metinler çeviri anahtarlarıyla kodda kurulur; dil değişince yeniden yazılır.
## Kök düğüm dokunuşları yutmaz (mouse_filter = IGNORE); yoksa dokunuş çevirme olmazdı.

var _height_m: int = 0
## Bu uygulama oturumundaki en iyi yükseklik; kalıcı rekor M4'te Progression'a taşınır.
var _best_m: int = 0

@onready var _height_label: Label = %HeightLabel
@onready var _best_label: Label = %BestLabel


func _ready() -> void:
	Events.run_started.connect(_on_run_started)
	Events.height_changed.connect(_on_height_changed)
	Events.run_ended.connect(_on_run_ended)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _on_run_started(_run_seed: int, _start_sector: int) -> void:
	_height_m = 0
	_refresh()


func _on_height_changed(meters: int) -> void:
	_height_m = meters
	_refresh()


func _on_run_ended(result: RunResult) -> void:
	_best_m = maxi(_best_m, result.height_m)
	_refresh()


func _refresh() -> void:
	_height_label.text = tr("HUD_HEIGHT") % _height_m
	_best_label.text = tr("HUD_BEST") % _best_m
	_best_label.visible = _best_m > 0
