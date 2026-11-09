class_name ResultsScreen
extends Control
## Sonuç ekranı (M5-03, GDD §20, architecture.md §5.3). İki kip:
## - Sonuç (Events.run_ended): yükseklik, rekor durumu ("YENİ REKOR!" ya da "REKORA X m"),
##   kazanç (cüzdana girenle aynı: RunResult.earned) ve dökümü; Tekrar, Yükseltmeler, Menü.
## - Diriliş teklifi (Events.revive_offered, İkinci Şans hakkı varken): yükseklik, "İKİNCİ ŞANS";
##   Dirilt ve Vazgeç. Reklamlı diriliş M7-05'te eklenir.
## Dünyaya erişmez; düğmeler niyet yayar. Main, durum RESULTS olunca open() çağırır. İçerik ölüm
## donması ve patlaması görünsün diye SHOW_DELAY sonra belirir; o ana dek dokunuş almaz.
## Yükseltmeler düğmesi ekranı gelene dek (M5-04) kapalı.

## Ölümden içeriğin belirmesine kadar (ölüm donması 0,1 sn + patlama).
const SHOW_DELAY: float = 0.5
const FADE_TIME: float = 0.2

var _result: RunResult
var _offering: bool = false
var _offer_height: int = 0
var _tween: Tween

@onready var _content: Control = %Content
@onready var _height: NeonLabel = %HeightLabel
@onready var _record: NeonLabel = %RecordLabel
@onready var _earned: NeonLabel = %EarnedLabel
@onready var _breakdown: NeonLabel = %BreakdownLabel
@onready var _retry: NeonButton = %RetryButton
@onready var _revive: NeonButton = %ReviveButton
@onready var _upgrades: NeonButton = %UpgradesButton
@onready var _give_up: NeonButton = %GiveUpButton
@onready var _menu: NeonButton = %MenuButton


func _ready() -> void:
	_retry.pressed.connect(Events.retry_requested.emit)
	_revive.pressed.connect(Events.revive_requested.emit)
	_give_up.pressed.connect(Events.revive_declined.emit)
	_menu.pressed.connect(Events.menu_requested.emit)
	Events.run_ended.connect(_on_run_ended)
	Events.revive_offered.connect(_on_revive_offered)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Ekranı açar; içerik SHOW_DELAY sonra belirir.
func open() -> void:
	visible = true
	_content.visible = false
	_content.modulate.a = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale()
	_tween.tween_interval(SHOW_DELAY)
	_tween.tween_callback(func() -> void: _content.visible = true)
	_tween.tween_property(_content, ^"modulate:a", 1.0, FADE_TIME)


## İçeriği beklemeden gösterir (testler).
func show_now() -> void:
	if _tween != null:
		_tween.kill()
	_content.visible = true
	_content.modulate.a = 1.0


## Diriliş teklifi kipinde mi.
func is_offering() -> bool:
	return _offering


func _on_run_ended(result: RunResult) -> void:
	_result = result
	_offering = false
	_refresh()


func _on_revive_offered(height_m: int) -> void:
	_offering = true
	_offer_height = height_m
	_refresh()


func _refresh() -> void:
	if not _offering and _result == null:
		return
	var offering: bool = _offering
	_revive.visible = offering
	_give_up.visible = offering
	_retry.visible = not offering
	_upgrades.visible = not offering
	_menu.visible = not offering
	_earned.visible = not offering
	_breakdown.visible = not offering
	if offering:
		_height.text = tr("HUD_HEIGHT") % _offer_height
		_record.text = tr("RESULTS_SECOND_CHANCE")
		_record.tone = GameTypes.NeonTone.PLAYER
		return
	_height.text = tr("HUD_HEIGHT") % _result.height_m
	if _result.new_record:
		_record.text = tr("RESULTS_NEW_RECORD")
		_record.tone = GameTypes.NeonTone.RECORD
	else:
		_record.text = tr("RESULTS_TO_RECORD") % (_result.best_height_m - _result.height_m)
		_record.tone = GameTypes.NeonTone.PLAYER
	_earned.text = tr("RESULTS_EARNED") % _result.earned
	_breakdown.text = tr("RESULTS_BREAKDOWN") % [
		_result.glimmers, _result.sector_bonus + _result.boost_bonus,
	]
