class_name ShopScreen
extends Control
## Mağaza (M5-04, GDD §10–11 ve §20, architecture.md §5.3): Yükseltmeler ve İzler sekmeleri,
## cüzdan ve geri düğmesi. Kartlar açılışta kataloglardan kurulur (Progression.UPGRADES /
## TRAILS; yeni yükseltme ya da iz kendiliğinden gelir), listeler dikey kaydırılır.
## Dünyaya erişmez: Events.shop_requested sekmeyi seçer, geri düğmesi Events.menu_requested
## yayar. Main, durum SHOP olunca open() çağırır. Progression'ın duyurularında kartlar yenilenir.

const UPGRADE_CARD: PackedScene = preload("res://scenes/ui/upgrade_card.tscn")
const TRAIL_CARD: PackedScene = preload("res://scenes/ui/trail_card.tscn")
## Seçili ve seçili olmayan sekmenin vurgusu.
const TAB_ACTIVE: Color = Color(0.0, 0.85, 1.0)
const TAB_IDLE: Color = Color(0.3, 0.38, 0.5)

## Sektör renkleri (iz önizlemesinin çevre rengi).
@export var sectors: SectorCatalog

## Seçili sekme.
var tab: GameTypes.ShopTab = GameTypes.ShopTab.UPGRADES

var _upgrade_cards: Array[UpgradeCard] = []
var _trail_cards: Array[TrailCard] = []

@onready var _back: NeonButton = %BackButton
@onready var _wallet: NeonLabel = %Wallet
@onready var _upgrades_tab: NeonButton = %UpgradesTab
@onready var _trails_tab: NeonButton = %TrailsTab
@onready var _upgrades_list: ScrollContainer = %UpgradesList
@onready var _trails_list: ScrollContainer = %TrailsList


func _ready() -> void:
	for upgrade: UpgradeDef in Progression.UPGRADES.upgrades:
		var card: UpgradeCard = UPGRADE_CARD.instantiate() as UpgradeCard
		card.def = upgrade
		%UpgradesBox.add_child(card)
		_upgrade_cards.append(card)
	for trail: TrailDef in Progression.TRAILS.trails:
		var card: TrailCard = TRAIL_CARD.instantiate() as TrailCard
		card.def = trail
		%TrailsGrid.add_child(card)
		_trail_cards.append(card)
	_back.pressed.connect(Events.menu_requested.emit)
	_upgrades_tab.pressed.connect(select_tab.bind(GameTypes.ShopTab.UPGRADES))
	_trails_tab.pressed.connect(select_tab.bind(GameTypes.ShopTab.TRAILS))
	Events.shop_requested.connect(select_tab)
	Events.glimmers_changed.connect(func(_total: int) -> void: refresh())
	Events.upgrade_purchased.connect(func(_id: StringName, _level: int) -> void: refresh())
	Events.trail_unlocked.connect(func(_id: StringName) -> void: refresh())
	Events.trail_equipped.connect(func(_id: StringName) -> void: refresh())
	select_tab(tab)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Ekranı gösterir; listeler başa döner, değerler yeniden okunur.
func open() -> void:
	visible = true
	_upgrades_list.scroll_vertical = 0
	_trails_list.scroll_vertical = 0
	refresh()


## Sekmeyi seçer: listesi görünür, sekme düğmesi vurgulanır.
func select_tab(new_tab: GameTypes.ShopTab) -> void:
	tab = new_tab
	var upgrades: bool = new_tab == GameTypes.ShopTab.UPGRADES
	_upgrades_list.visible = upgrades
	_trails_list.visible = not upgrades
	_upgrades_tab.accent = TAB_ACTIVE if upgrades else TAB_IDLE
	_trails_tab.accent = TAB_IDLE if upgrades else TAB_ACTIVE
	refresh()


## Cüzdanı ve bütün kartları yeniden yazar.
func refresh() -> void:
	_wallet.text = tr("HUD_GLIMMERS") % Progression.glimmers
	var ambient: Color = sectors.def_at(Progression.start_sector).palette.ambient
	for card: UpgradeCard in _upgrade_cards:
		card.refresh()
	for card: TrailCard in _trail_cards:
		card.set_ambient(ambient)
		card.refresh()


func upgrade_cards() -> Array[UpgradeCard]:
	return _upgrade_cards


func trail_cards() -> Array[TrailCard]:
	return _trail_cards
