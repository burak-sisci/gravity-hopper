extends PanelContainer
## Canlı ayar paneli (M1-11, architecture.md §13). TuningConfig'in @export alanlarından
## kaydırıcıları kendiliğinden kurar; aralık, adım ve birim @export_range'den gelir.
## Run ile aynı kaynak örneğini düzenler: res:// yolundan yüklenen kaynak bellekte tek örnektir,
## bu yüzden değişiklik oynarken hemen etki eder ve panelin dünyaya erişmesi gerekmez.
## Kaydet → user://tuning_override.tres; debug build açılışta bu dosya varsa onu uygular.
## Yalnızca geliştirici görür; metinler tr() ile değil doğrudan yazılır.

signal fps_requested

const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const OVERRIDE_PATH: String = "user://tuning_override.tres"
const FONT_SIZE: int = 30
const HEADER_FONT_SIZE: int = 32
const SLIDER_HEIGHT: float = 56.0
const HEADER_COLOR: Color = Color(0.55, 0.85, 1.0)

var _tuning: TuningConfig
var _sliders: Dictionary[StringName, HSlider] = {}
var _labels: Dictionary[StringName, Label] = {}
var _suffixes: Dictionary[StringName, String] = {}
var _decimals: Dictionary[StringName, int] = {}

@onready var _rows: VBoxContainer = %Rows
@onready var _status: Label = %Status
@onready var _pause_button: Button = %PauseButton


func _ready() -> void:
	_tuning = load(TUNING_PATH) as TuningConfig
	_apply_override()
	_build_rows()


func _on_save_pressed() -> void:
	var error: Error = ResourceSaver.save(_tuning.duplicate(), OVERRIDE_PATH)
	if error != OK:
		_status.text = "Kaydedilemedi (hata %d)" % error
		return
	_status.text = "Kaydedildi: %s" % Time.get_time_string_from_system()
	print("TUNING kaydedildi %s" % ProjectSettings.globalize_path(OVERRIDE_PATH))


func _on_reset_pressed() -> void:
	var defaults: TuningConfig = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	_copy(defaults, _tuning)
	if FileAccess.file_exists(OVERRIDE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OVERRIDE_PATH))
	_refresh_rows()
	_status.text = "Varsayılan değerlere dönüldü"
	print("TUNING varsayılana dönüldü")


func _on_pause_pressed() -> void:
	get_tree().paused = not get_tree().paused
	_pause_button.text = "Devam" if get_tree().paused else "Duraklat"


func _on_fps_pressed() -> void:
	fps_requested.emit()


func _on_close_pressed() -> void:
	visible = false


func _on_slider_changed(value: float, property: StringName) -> void:
	_tuning.set(property, value)
	_update_label(property)


## Kayıtlı ayar dosyası varsa değerlerini paylaşılan örneğe kopyalar.
func _apply_override() -> void:
	if not FileAccess.file_exists(OVERRIDE_PATH):
		return
	var saved: TuningConfig = ResourceLoader.load(
			OVERRIDE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	if saved == null:
		push_warning("Ayar paneli: %s okunamadı" % OVERRIDE_PATH)
		return
	_copy(saved, _tuning)
	print("TUNING kayıtlı ayarlar uygulandı")


## @export alanlarını sırayla dolaşır: grup başlığı ve her aralıklı alan için bir satır.
## Başlık, altında en az bir kaydırıcı varsa eklenir (taban Resource sınıfının grupları atlanır).
func _build_rows() -> void:
	var pending_header: String = ""
	for info: Dictionary in _tuning.get_property_list():
		var usage: int = info["usage"]
		var property: StringName = info["name"]
		if usage & PROPERTY_USAGE_GROUP:
			pending_header = String(property)
		elif usage & PROPERTY_USAGE_SCRIPT_VARIABLE and int(info["hint"]) == PROPERTY_HINT_RANGE:
			if not pending_header.is_empty():
				_rows.add_child(_make_label(pending_header, HEADER_FONT_SIZE, HEADER_COLOR))
				pending_header = ""
			_add_slider_row(property, String(info["hint_string"]))


func _add_slider_row(property: StringName, hint: String) -> void:
	var parts: PackedStringArray = hint.split(",")
	var step: float = float(parts[2])
	_suffixes[property] = ""
	for part: String in parts:
		if part.begins_with("suffix:"):
			_suffixes[property] = part.trim_prefix("suffix:")
	_decimals[property] = maxi(0, ceili(-log(step) / log(10.0) - 0.0001))
	var label: Label = _make_label("", FONT_SIZE, Color.WHITE)
	_rows.add_child(label)
	_labels[property] = label
	var slider: HSlider = HSlider.new()
	slider.min_value = float(parts[0])
	slider.max_value = float(parts[1])
	slider.step = step
	slider.custom_minimum_size.y = SLIDER_HEIGHT
	slider.focus_mode = Control.FOCUS_NONE
	slider.value = float(_tuning.get(property))
	slider.value_changed.connect(_on_slider_changed.bind(property))
	_rows.add_child(slider)
	_sliders[property] = slider
	_update_label(property)


func _refresh_rows() -> void:
	for property: StringName in _sliders:
		_sliders[property].set_value_no_signal(float(_tuning.get(property)))
		_update_label(property)


func _update_label(property: StringName) -> void:
	var value: float = float(_tuning.get(property))
	_labels[property].text = "%s: %s %s" % [
		String(property).capitalize(), String.num(value, _decimals[property]), _suffixes[property],
	]


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func _copy(from: TuningConfig, to: TuningConfig) -> void:
	for info: Dictionary in from.get_property_list():
		var usage: int = info["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			to.set(info["name"], from.get(info["name"]))
