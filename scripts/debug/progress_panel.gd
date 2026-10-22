class_name ProgressPanel
extends PanelContainer
## Debug İlerleme sayfası (M4-03, architecture.md §13): cüzdan, rekor ve yükseltme seviyeleri;
## yükseltme satın alma, +1000 Glimmer ve kaydı sıfırlama. Mağaza (M5) gelene dek yükseltmeler
## buradan denenir. Progression'ı servis olarak çağırır, değişince Events'ten yenilenir.
## İzler (M4-08): ikinci sayfada satın alma ve kuşanma; başarım izi debug için bedelsiz açılır.
## Kontrol noktası (M4-09): iki sayfada da başlangıç sektörü açık sektörler arasında döndürülür;
## seçim sonraki turdan geçerli.
## Yalnızca geliştirici görür; metinler tr() ile değil doğrudan yazılır (yükseltme ve iz adları
## hariç).

const UPGRADES: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const TRAILS: TrailCatalog = preload("res://data/trails/trail_catalog.tres")
const GIFT_AMOUNT: int = 1000
const FONT_SIZE: int = 30
const TITLE_FONT_SIZE: int = 36
const BUTTON_FONT_SIZE: int = 28
const BUTTON_HEIGHT: float = 80.0
const BUY_WIDTH: float = 220.0
const MARGIN: int = 24
const SEPARATION: int = 12
const SUMMARY_COLOR: Color = Color(0.7, 0.9, 0.7)
const UPGRADES_PAGE_TEXT: String = "Yükseltmeler ›"
const TRAILS_PAGE_TEXT: String = "İzler ›"
const SECTOR_BUTTON_TEXT: String = "Sonraki ›"

var _summary: Label
var _levels: Dictionary[StringName, Label] = {}
var _buy_buttons: Dictionary[StringName, Button] = {}
var _trail_labels: Dictionary[StringName, Label] = {}
var _trail_buttons: Dictionary[StringName, Button] = {}
var _upgrade_page: VBoxContainer
var _trail_page: VBoxContainer
var _page_button: Button
var _sector_label: Label
var _sector_button: Button


func _ready() -> void:
	_build()
	Events.glimmers_changed.connect(_on_value_changed)
	Events.best_height_changed.connect(_on_value_changed)
	Events.upgrade_purchased.connect(_on_upgrade_purchased)
	Events.trail_unlocked.connect(_on_trail_changed)
	Events.trail_equipped.connect(_on_trail_changed)
	Events.sector_unlocked.connect(_on_sector_changed)
	Events.start_sector_selected.connect(_on_sector_changed)
	visibility_changed.connect(_refresh)
	_refresh()


## Satın alma düğmesi (testler de basar).
func buy_button(id: StringName) -> Button:
	return _buy_buttons[id]


func level_label(id: StringName) -> Label:
	return _levels[id]


func summary_label() -> Label:
	return _summary


## İzin düğmesi: Al / Kuşan / Aç (debug); kuşanılıysa kapalı.
func trail_button(id: StringName) -> Button:
	return _trail_buttons[id]


func trail_label(id: StringName) -> Label:
	return _trail_labels[id]


## Yükseltmeler ile izler arasında geçiş.
func page_button() -> Button:
	return _page_button


func showing_trails() -> bool:
	return _trail_page.visible


## Başlangıç sektörünü açık sektörler arasında sonrakine geçirir (sonuncudan S1'e).
func sector_button() -> Button:
	return _sector_button


func sector_label() -> Label:
	return _sector_label


func _on_value_changed(_value: int) -> void:
	_refresh()


func _on_upgrade_purchased(_id: StringName, _level: int) -> void:
	_refresh()


func _on_trail_changed(_id: StringName) -> void:
	_refresh()


func _on_sector_changed(_index: int) -> void:
	_refresh()


func _on_buy_pressed(id: StringName) -> void:
	Progression.buy_upgrade(id)


## Sahip olunmayan iz satın alınır (başarım izi bedelsiz açılır), sahip olunan kuşanılır.
func _on_trail_pressed(id: StringName) -> void:
	if Progression.owns_trail(id):
		Progression.equip_trail(id)
	elif TRAILS.get_def(id).unlock == GameTypes.TrailUnlock.PURCHASE:
		Progression.buy_trail(id)
	else:
		Progression.grant_trail(id)
		Progression.save()


func _on_sector_pressed() -> void:
	Progression.select_start_sector(Progression.start_sector % Progression.highest_sector + 1)


func _on_page_pressed() -> void:
	_trail_page.visible = not _trail_page.visible
	_upgrade_page.visible = not _trail_page.visible
	_page_button.text = UPGRADES_PAGE_TEXT if _trail_page.visible else TRAILS_PAGE_TEXT


func _on_gift_pressed() -> void:
	Progression.add_glimmers(GIFT_AMOUNT)
	Progression.save()


func _on_reset_pressed() -> void:
	Progression.reset()
	print("DEBUG kayıt sıfırlandı")


func _on_close_pressed() -> void:
	visible = false


func _refresh() -> void:
	if _summary == null:
		return
	_summary.text = "Cüzdan %d Glimmer · rekor %d m · en yüksek sektör %d" % [
		Progression.glimmers, Progression.best_height_m, Progression.highest_sector,
	]
	_sector_label.text = "Başlangıç: S%d  · açık %d sektör" % [
		Progression.start_sector, Progression.highest_sector,
	]
	_sector_button.disabled = Progression.highest_sector <= 1
	for def: UpgradeDef in UPGRADES.upgrades:
		var level: int = Progression.upgrade_level(def.id)
		var cost: int = Progression.upgrade_cost(def.id)
		_levels[def.id].text = "%s  %d/%d" % [tr(def.name_key), level, def.max_level()]
		var button: Button = _buy_buttons[def.id]
		button.text = "En üst" if cost < 0 else "Al %d" % cost
		button.disabled = not Progression.can_buy(def.id)
	for def: TrailDef in TRAILS.trails:
		_refresh_trail(def)


func _refresh_trail(def: TrailDef) -> void:
	var owned: bool = Progression.owns_trail(def.id)
	var equipped: bool = Progression.equipped_trail() == def.id
	var state: String = "kuşanılı" if equipped else "sahip" if owned else _locked_text(def)
	_trail_labels[def.id].text = "%s  · %s" % [tr(def.name_key), state]
	var button: Button = _trail_buttons[def.id]
	if equipped:
		button.text = "Kuşanılı"
	elif owned:
		button.text = "Kuşan"
	elif def.unlock == GameTypes.TrailUnlock.PURCHASE:
		button.text = "Al %d" % def.cost
	else:
		button.text = "Aç (debug)"
	button.disabled = equipped or (not owned and def.unlock == GameTypes.TrailUnlock.PURCHASE
			and not Progression.can_buy_trail(def.id))


func _locked_text(def: TrailDef) -> String:
	match def.unlock:
		GameTypes.TrailUnlock.NEAR_MISSES:
			return "başarım: %d kıl payı" % def.goal
		GameTypes.TrailUnlock.GREAT_STORAGE:
			return "başarım: Büyük Depo"
	return "%d Glimmer" % def.cost


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(box)
	box.add_child(_make_label("İlerleme", TITLE_FONT_SIZE, Color.WHITE))
	_summary = _make_label("", FONT_SIZE, SUMMARY_COLOR)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)
	var sector_row: HBoxContainer = _make_row(box, _on_sector_pressed)
	_sector_label = sector_row.get_child(0) as Label
	_sector_button = sector_row.get_child(1) as Button
	_sector_button.text = SECTOR_BUTTON_TEXT
	_upgrade_page = _make_page(box)
	for def: UpgradeDef in UPGRADES.upgrades:
		var row: HBoxContainer = _make_row(_upgrade_page, _on_buy_pressed.bind(def.id))
		_levels[def.id] = row.get_child(0) as Label
		_buy_buttons[def.id] = row.get_child(1) as Button
	_trail_page = _make_page(box)
	_trail_page.visible = false
	for def: TrailDef in TRAILS.trails:
		var row: HBoxContainer = _make_row(_trail_page, _on_trail_pressed.bind(def.id))
		_trail_labels[def.id] = row.get_child(0) as Label
		_trail_buttons[def.id] = row.get_child(1) as Button
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", SEPARATION)
	box.add_child(buttons)
	buttons.add_child(_make_button("+%d Glimmer" % GIFT_AMOUNT, _on_gift_pressed))
	buttons.add_child(_make_button("Kaydı sıfırla", _on_reset_pressed))
	_page_button = _make_button(TRAILS_PAGE_TEXT, _on_page_pressed)
	buttons.add_child(_page_button)
	buttons.add_child(_make_button("Kapat", _on_close_pressed))


func _make_page(parent: Container) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", SEPARATION)
	parent.add_child(page)
	return page


## Satır: ad etiketi (0. çocuk) + sağda düğme (1. çocuk).
func _make_row(page: VBoxContainer, action: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", SEPARATION)
	page.add_child(row)
	var label: Label = _make_label("", FONT_SIZE, Color.WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button: Button = _make_button("", action)
	button.custom_minimum_size.x = BUY_WIDTH
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(button)
	return row


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.pressed.connect(action)
	return button
