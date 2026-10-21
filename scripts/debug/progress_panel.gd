class_name ProgressPanel
extends PanelContainer
## Debug İlerleme sayfası (M4-03, architecture.md §13): cüzdan, rekor ve yükseltme seviyeleri;
## yükseltme satın alma, +1000 Glimmer ve kaydı sıfırlama. Mağaza (M5) gelene dek yükseltmeler
## buradan denenir. Progression'ı servis olarak çağırır, değişince Events'ten yenilenir.
## Yalnızca geliştirici görür; metinler tr() ile değil doğrudan yazılır (yükseltme adları hariç).

const UPGRADES: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const GIFT_AMOUNT: int = 1000
const FONT_SIZE: int = 30
const TITLE_FONT_SIZE: int = 36
const BUTTON_FONT_SIZE: int = 28
const BUTTON_HEIGHT: float = 80.0
const BUY_WIDTH: float = 220.0
const MARGIN: int = 24
const SEPARATION: int = 12
const SUMMARY_COLOR: Color = Color(0.7, 0.9, 0.7)

var _summary: Label
var _levels: Dictionary[StringName, Label] = {}
var _buy_buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	_build()
	Events.glimmers_changed.connect(_on_value_changed)
	Events.best_height_changed.connect(_on_value_changed)
	Events.upgrade_purchased.connect(_on_upgrade_purchased)
	visibility_changed.connect(_refresh)
	_refresh()


## Satın alma düğmesi (testler de basar).
func buy_button(id: StringName) -> Button:
	return _buy_buttons[id]


func level_label(id: StringName) -> Label:
	return _levels[id]


func summary_label() -> Label:
	return _summary


func _on_value_changed(_value: int) -> void:
	_refresh()


func _on_upgrade_purchased(_id: StringName, _level: int) -> void:
	_refresh()


func _on_buy_pressed(id: StringName) -> void:
	Progression.buy_upgrade(id)


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
	for def: UpgradeDef in UPGRADES.upgrades:
		var level: int = Progression.upgrade_level(def.id)
		var cost: int = Progression.upgrade_cost(def.id)
		_levels[def.id].text = "%s  %d/%d" % [tr(def.name_key), level, def.max_level()]
		var button: Button = _buy_buttons[def.id]
		button.text = "En üst" if cost < 0 else "Al %d" % cost
		button.disabled = not Progression.can_buy(def.id)


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
	for def: UpgradeDef in UPGRADES.upgrades:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", SEPARATION)
		box.add_child(row)
		var label: Label = _make_label("", FONT_SIZE, Color.WHITE)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_levels[def.id] = label
		var button: Button = _make_button("", _on_buy_pressed.bind(def.id))
		button.custom_minimum_size.x = BUY_WIDTH
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(button)
		_buy_buttons[def.id] = button
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", SEPARATION)
	box.add_child(buttons)
	buttons.add_child(_make_button("+%d Glimmer" % GIFT_AMOUNT, _on_gift_pressed))
	buttons.add_child(_make_button("Kaydı sıfırla", _on_reset_pressed))
	buttons.add_child(_make_button("Kapat", _on_close_pressed))


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
