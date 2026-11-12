class_name MainMenu
extends Control
## Ana menü (M5-02, GDD §20, architecture.md §5.3): başlık, cüzdan, kontrol noktası seçimi
## (yalnızca açık sektörler, M4-09), Başla, Yükseltmeler, İzler, Ayarlar.
## Dünyaya erişmez: Başla Events.play_requested yayar; seçim ve cüzdan Progression servisinden
## (.clauderules §3: autoload servis gibi çağrılabilir). Main, durum MENU olunca open() çağırır.
## Yükseltmeler / İzler mağazayı ilgili sekmesiyle açar (Events.shop_requested, M5-04).
## Ayarlar (M5-05) ekranı gelene dek kapalıdır.

## Sektör adları ve renkleri.
@export var sectors: SectorCatalog

@onready var _title: NeonLabel = %Title
@onready var _wallet: NeonLabel = %Wallet
@onready var _sector_label: NeonLabel = %SectorLabel
@onready var _prev: NeonButton = %PrevButton
@onready var _next: NeonButton = %NextButton
@onready var _play: NeonButton = %PlayButton
@onready var _upgrades: NeonButton = %UpgradesButton
@onready var _trails: NeonButton = %TrailsButton


func _ready() -> void:
	_prev.pressed.connect(_step.bind(-1))
	_next.pressed.connect(_step.bind(1))
	_play.pressed.connect(Events.play_requested.emit)
	_upgrades.pressed.connect(Events.shop_requested.emit.bind(GameTypes.ShopTab.UPGRADES))
	_trails.pressed.connect(Events.shop_requested.emit.bind(GameTypes.ShopTab.TRAILS))
	Events.glimmers_changed.connect(func(_total: int) -> void: refresh())
	Events.sector_unlocked.connect(func(_index: int) -> void: refresh())
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Menüyü gösterir ve değerleri yeniden okur.
func open() -> void:
	visible = true
	refresh()


## Başlık, cüzdan ve seçili kontrol noktası yazılarını yazar.
func refresh() -> void:
	_title.text = tr("APP_TITLE")
	_wallet.text = tr("HUD_GLIMMERS") % Progression.glimmers
	var index: int = Progression.start_sector
	_sector_label.text = sector_text(index)
	_sector_label.color = sectors.def_at(index).palette.ambient
	_prev.disabled = index <= 1
	_next.disabled = index >= Progression.highest_sector


## Kontrol noktası yazısı (ör. "SEKTÖR 2 · VERİ AKIŞI").
func sector_text(index: int) -> String:
	return tr("HUD_SECTOR") % [index, tr(sectors.def_at(index).name_key)]


func _step(direction: int) -> void:
	var index: int = clampi(Progression.start_sector + direction, 1, Progression.highest_sector)
	Progression.select_start_sector(index)
	refresh()
