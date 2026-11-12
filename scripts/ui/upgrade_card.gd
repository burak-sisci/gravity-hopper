class_name UpgradeCard
extends PanelContainer
## Mağazadaki yükseltme kartı (M5-04, GDD §10, architecture.md §5.3): ad, seviye, açıklama,
## sonraki seviyenin etkisi ve fiyatlı Al düğmesi. Satın alma Progression servisinden
## (.clauderules §3); cüzdan yetmezse ya da en üst seviyedeyse düğme kapalıdır.
## Kart kendini yenilemez: ShopScreen, Progression'ın duyurularında refresh() çağırır.

## Kartın zemini: yazı kontrastı bunun üstünde ölçülür.
const FILL: Color = Color(0.03, 0.05, 0.12, 1.0)
const BORDER: Color = Color(0.0, 0.85, 1.0, 0.55)
## Alınamayan (cüzdan yetmez ya da en üst seviye) kartın kenarı.
const BORDER_DIM: Color = Color(0.0, 0.85, 1.0, 0.2)
const BORDER_PX: int = 3
const RADIUS_PX: int = 24
const MARGIN_PX: int = 24

## Kartın yükseltmesi (ShopScreen kurarken verir).
var def: UpgradeDef

var _box: StyleBoxFlat

@onready var _name: NeonLabel = %NameLabel
@onready var _level: NeonLabel = %LevelLabel
@onready var _desc: NeonLabel = %DescLabel
@onready var _effect: NeonLabel = %EffectLabel
@onready var _buy: NeonButton = %BuyButton


func _ready() -> void:
	_box = StyleBoxFlat.new()
	_box.bg_color = FILL
	_box.set_border_width_all(BORDER_PX)
	_box.set_corner_radius_all(RADIUS_PX)
	_box.set_content_margin_all(MARGIN_PX)
	add_theme_stylebox_override(&"panel", _box)
	# Sürükleme listeye geçsin: parmak düğmede başlasa da liste kayar (Redmi'de ölçüldü).
	_buy.mouse_filter = Control.MOUSE_FILTER_PASS
	_buy.pressed.connect(_on_buy_pressed)
	refresh()


## Yazıları ve düğmeyi Progression'daki seviyeye ve cüzdana göre yazar.
func refresh() -> void:
	if def == null or not is_node_ready():
		return
	var level: int = Progression.upgrade_level(def.id)
	var maxed: bool = level >= def.max_level()
	_name.text = tr(def.name_key)
	_level.text = tr("SHOP_LEVEL") % [level, def.max_level()]
	_desc.text = tr(def.desc_key)
	if maxed:
		_effect.text = tr("SHOP_NOW") % effect_text(def, level)
		_buy.text = "SHOP_MAXED"
	else:
		_effect.text = tr("SHOP_NEXT") % effect_text(def, level + 1)
		_buy.text = str(Progression.upgrade_cost(def.id))
	_buy.disabled = not Progression.can_buy(def.id)
	_box.border_color = BORDER if not _buy.disabled else BORDER_DIM


## Seviyenin etkisi okunur metin olarak (ör. "2,4 m çekim", "+%20 Glimmer").
static func effect_text(upgrade: UpgradeDef, level: int) -> String:
	var value: float = upgrade.value_at(level)
	if is_zero_approx(value) and not upgrade.effect_zero_key.is_empty():
		return TranslationServer.translate(upgrade.effect_zero_key)
	if upgrade.unit == "ratio":
		value *= 100.0
	return TranslationServer.translate(upgrade.effect_key) % number_text(value)


## Sayı; tam değilse bir ondalıkla, dilin ondalık ayırıcısıyla (TR "2,4").
static func number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return ("%.1f" % value).replace(".", TranslationServer.translate("NUMBER_DECIMAL"))


func _on_buy_pressed() -> void:
	Progression.buy_upgrade(def.id)
