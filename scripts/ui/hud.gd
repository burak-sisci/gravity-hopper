extends Control
## Minimal HUD (M1-10, GDD §20): sol üstte anlık yükseklik, altında oturum rekoru.
## Sektör afişi (M2-09): sektöre girince ya da tur bir sonraki sektörden başlayınca "SEKTÖR 2 ·
## VERİ AKIŞI" kısa süre görünüp söner. Adlar sektör kataloğundan (veri kaynağı) okunur.
## Yalnızca Events sinyallerini dinler; oyun dünyasındaki hiçbir düğüme erişmez (.clauderules §3).
## Metinler çeviri anahtarlarıyla kodda kurulur; dil değişince yeniden yazılır.
## Kök düğüm dokunuşları yutmaz (mouse_filter = IGNORE); yoksa dokunuş çevirme olmazdı.

## Afişin ekranda kaldığı süre ve sönme süresi (sn).
const BANNER_TIME: float = 2.0
const BANNER_FADE: float = 0.4

## Sektör adları ve renkleri için (veri; dünyaya erişim değil).
@export var sectors: SectorCatalog

var _height_m: int = 0
## Bu uygulama oturumundaki en iyi yükseklik; kalıcı rekor M4'te Progression'a taşınır.
var _best_m: int = 0
## Afişte gösterilen sektör (0 = afiş yok).
var _banner_sector: int = 0
var _banner_tween: Tween

@onready var _height_label: Label = %HeightLabel
@onready var _best_label: Label = %BestLabel
@onready var _sector_banner: Label = %SectorBanner


func _ready() -> void:
	Events.run_started.connect(_on_run_started)
	Events.height_changed.connect(_on_height_changed)
	Events.run_ended.connect(_on_run_ended)
	Events.sector_entered.connect(_show_banner)
	_sector_banner.visible = false
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _on_run_started(_run_seed: int, start_sector: int) -> void:
	_height_m = 0
	if start_sector > 1:
		_show_banner(start_sector)
	else:
		_hide_banner()
	_refresh()


func _on_height_changed(meters: int) -> void:
	_height_m = meters
	_refresh()


func _on_run_ended(result: RunResult) -> void:
	_best_m = maxi(_best_m, result.height_m)
	_refresh()


func _show_banner(index: int) -> void:
	_banner_sector = index
	_refresh()
	if _banner_tween != null:
		_banner_tween.kill()
	_sector_banner.visible = true
	_sector_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(BANNER_TIME)
	_banner_tween.tween_property(_sector_banner, "modulate:a", 0.0, BANNER_FADE)
	_banner_tween.tween_callback(_hide_banner)


func _hide_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_sector = 0
	_sector_banner.visible = false


func _refresh() -> void:
	_height_label.text = tr("HUD_HEIGHT") % _height_m
	_best_label.text = tr("HUD_BEST") % _best_m
	_best_label.visible = _best_m > 0
	if _banner_sector > 0 and sectors != null:
		var def: SectorDef = sectors.def_at(_banner_sector)
		_sector_banner.text = tr("HUD_SECTOR") % [_banner_sector, tr(def.name_key)]
		_sector_banner.add_theme_color_override("font_color", def.ambient_color)
