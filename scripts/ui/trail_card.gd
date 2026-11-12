class_name TrailCard
extends PanelContainer
## Mağazadaki iz kartı (M5-04, GDD §11, architecture.md §5.3): ad, canlı önizleme (oyundaki
## Trail'in kendisi, sabit yatay noktalarla), koşul ve tek düğme. Düğme izin durumuna göre:
## fiyat (Al; alınınca kuşanılır), KUŞAN, KUŞANILDI (kapalı) ya da KİLİTLİ (başarım izi; koşul
## metni görünür). İşlemler Progression servisinden (.clauderules §3).

## Önizleme çizgisinin nokta sayısı ve boyu (kart iç genişliğinin oranı).
const PREVIEW_POINTS: int = 16
const PREVIEW_LENGTH: float = 0.8

## Kartın izi (ShopScreen kurarken verir).
var def: TrailDef

var _box: StyleBoxFlat

@onready var _name: NeonLabel = %NameLabel
@onready var _preview: Control = %Preview
@onready var _trail: Trail = %PreviewTrail
@onready var _status: NeonLabel = %StatusLabel
@onready var _action: NeonButton = %ActionButton


func _ready() -> void:
	_box = StyleBoxFlat.new()
	_box.bg_color = UpgradeCard.FILL
	_box.set_border_width_all(UpgradeCard.BORDER_PX)
	_box.set_corner_radius_all(UpgradeCard.RADIUS_PX)
	_box.set_content_margin_all(UpgradeCard.MARGIN_PX)
	add_theme_stylebox_override(&"panel", _box)
	# Sürükleme listeye geçsin (UpgradeCard'daki gibi).
	_action.mouse_filter = Control.MOUSE_FILTER_PASS
	_action.pressed.connect(_on_action_pressed)
	_preview.resized.connect(_place_preview)
	_trail.apply_def(def)
	_place_preview()
	refresh()


## Önizlemenin çevre rengi (seçili kontrol noktasının sektörü): varsayılan iz ve saydam
## parlamalı izler bunu izler, oyundaki gibi.
func set_ambient(ambient: Color) -> void:
	_trail.set_ambient(ambient)


## Önizlemedeki iz (testler oyundaki izle karşılaştırır).
func preview_trail() -> Trail:
	return _trail


## Ad, koşul ve düğmeyi Progression'daki duruma göre yazar.
func refresh() -> void:
	if def == null or not is_node_ready():
		return
	var owned: bool = Progression.owns_trail(def.id)
	var equipped: bool = Progression.equipped_trail() == def.id
	_name.text = tr(def.name_key)
	_status.text = ""
	_action.disabled = false
	if equipped:
		_action.text = "SHOP_EQUIPPED"
		_action.disabled = true
	elif owned:
		_action.text = "SHOP_EQUIP"
	elif def.unlock == GameTypes.TrailUnlock.PURCHASE:
		_action.text = str(def.cost)
		_action.disabled = not Progression.can_buy_trail(def.id)
	else:
		_action.text = "SHOP_LOCKED"
		_action.disabled = true
		var condition: String = tr(def.desc_key)
		_status.text = condition % def.goal if condition.contains("%d") else condition
	_box.border_color = UpgradeCard.BORDER if equipped else UpgradeCard.BORDER_DIM


func _place_preview() -> void:
	var half: float = _preview.size.x * PREVIEW_LENGTH * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	# Baş sağda (ilk nokta), kuyruk solda söner.
	for i: int in PREVIEW_POINTS:
		points.append(Vector2(lerpf(half, -half, float(i) / (PREVIEW_POINTS - 1)), 0.0))
	_trail.position = _preview.size * 0.5
	_trail.points = points


func _on_action_pressed() -> void:
	if Progression.owns_trail(def.id):
		Progression.equip_trail(def.id)
	elif Progression.buy_trail(def.id):
		Progression.equip_trail(def.id)
