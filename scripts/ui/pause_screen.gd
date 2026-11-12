class_name PauseScreen
extends Control
## Duraklatma (M5-06, GDD §20, architecture.md §5.3): tur durum PAUSED iken açıktır (Main açar).
## Oyun ağacı duraklıyken çalışır (process_mode ALWAYS). DEVAM 3-2-1 sayar, sonra
## Events.resume_requested yayar; sayım sürerken perde açılır (oyuncu yerini görsün) ve düğmeler
## gizlenir. AYARLAR ayarlar ekranını üstte açar (Events.settings_requested), MENÜ turu bitirip
## menüye döner (Events.menu_requested; kazanç korunur). Uygulama sayım sırasında arka plana
## geçerse sayım iptal olur, düğmeler geri gelir. Dünyaya erişmez.

## Sayımın başladığı sayı ve her adımın süresi (gerçek zaman, sn).
const COUNTDOWN_FROM: int = 3
const COUNT_STEP: float = 1.0
## Sayı belirirken başladığı büyüklük ve yerine oturma süresi.
const COUNT_POP_SCALE: float = 1.5
const COUNT_POP_TIME: float = 0.2
## Perdenin saydamlığı: menüdeyken koyu, sayımda oyun görünsün diye açık.
const OVERLAY_ALPHA: float = 0.88
const COUNTDOWN_OVERLAY_ALPHA: float = 0.35

var _tween: Tween

@onready var _overlay: ColorRect = %Overlay
@onready var _column: Control = %Column
@onready var _countdown: NeonLabel = %CountdownLabel
@onready var _resume: NeonButton = %ResumeButton
@onready var _settings: NeonButton = %SettingsButton
@onready var _menu: NeonButton = %MenuButton


func _ready() -> void:
	_resume.pressed.connect(start_countdown)
	_settings.pressed.connect(Events.settings_requested.emit)
	_menu.pressed.connect(Events.menu_requested.emit)
	_show_buttons()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if counting():
				_show_buttons()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not visible:
				_stop_tween()


## Ekranı düğmeleriyle açar (sayım varsa iptal).
func open() -> void:
	visible = true
	_show_buttons()


## Sayım sürüyor mu.
func counting() -> bool:
	return _countdown.visible


## DEVAM: 3-2-1 sayar, sonra devam ister.
func start_countdown() -> void:
	_stop_tween()
	_column.visible = false
	_countdown.visible = true
	_overlay.color.a = COUNTDOWN_OVERLAY_ALPHA
	_tween = create_tween().set_ignore_time_scale()
	for count: int in range(COUNTDOWN_FROM, 0, -1):
		_tween.tween_callback(_show_count.bind(count))
		_tween.tween_interval(COUNT_STEP)
	_tween.tween_callback(_finish_countdown)


func _show_count(count: int) -> void:
	_countdown.text = str(count)
	_countdown.pivot_offset = _countdown.size * 0.5
	_countdown.scale = Vector2.ONE * COUNT_POP_SCALE
	var pop: Tween = create_tween().set_ignore_time_scale()
	pop.tween_property(_countdown, ^"scale", Vector2.ONE, COUNT_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _finish_countdown() -> void:
	_countdown.visible = false
	Events.resume_requested.emit()


func _show_buttons() -> void:
	_stop_tween()
	_column.visible = true
	_countdown.visible = false
	_overlay.color.a = OVERLAY_ALPHA


func _stop_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
