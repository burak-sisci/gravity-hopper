class_name AboutScreen
extends Control
## Hakkında / lisanslar (M5-09, GDD §20, architecture.md §5.3): sürüm, emeği geçenler
## (CreditsCatalog; CREDITS.md'nin oyuna giren her satırı), Godot'nun MIT lisans metni
## (Engine.get_license_text), motorun üçüncü taraf bileşenleri (Engine.get_copyright_info) ve
## onların lisans metinleri (Engine.get_license_info). Ayarların üstünde açılır
## (Events.about_requested); geri düğmesi ve durum değişimi kapatır. Dünyaya erişmez.
## Liste ilk açılışta kurulur ve dil değişince yeniden yazılır. ≈ 80 bin karakter tek karede
## kurulunca Redmi'de ekran 1051 ms donuyordu: yazılar sıraya alınır, her karede en çok
## BUILD_BUDGET_MS kadarı eklenir (uzun lisans metinleri paragraflara bölünür); üst kısım ilk
## karede görünür. Duraklatmadan da açılır (process_mode ALWAYS).

## Yazı boyutları (px; UI kabulü ≥ 36) ve renkleri. Zemin ayarlar ekranıyla aynı koyu lacivert.
const HEADING_PX: int = 52
const TITLE_PX: int = 40
const BODY_PX: int = 36
const HEADING_COLOR: Color = Color(0.0, 0.85, 1.0)
const TITLE_COLOR: Color = Color(0.94, 0.98, 1.0)
const BODY_COLOR: Color = Color(0.78, 0.84, 0.92)
## Bölümler arası ek boşluk (px).
const SECTION_GAP_PX: float = 40.0
## Bir karede yazı eklemeye ayrılan en uzun süre (ms; 60 FPS'te kare 16,7 ms).
const BUILD_BUDGET_MS: float = 4.0

@export var catalog: CreditsCatalog

var _built_locale: String = ""
## Eklenmeyi bekleyen yazılar: [metin, boyut, renk, başlık mı].
var _pending: Array[Array] = []
var _build_started_usec: int = 0
var _slowest_frame_ms: float = 0.0
## Kurulum sürerken ölçülen en uzun gerçek kare süresi (ms; yerleşim ve çizim dahil, günlük).
var _longest_delta_ms: float = 0.0

@onready var _back: NeonButton = %BackButton
@onready var _list: ScrollContainer = %List
@onready var _box: VBoxContainer = %Box


func _ready() -> void:
	_back.pressed.connect(close)
	Events.about_requested.connect(open)
	Events.app_state_changed.connect(func(_state: GameTypes.AppState) -> void: close())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		build()


## Ekranı açar; liste kurulmamışsa ya da dil değiştiyse kurar, başa sarar.
func open() -> void:
	visible = true
	if _built_locale != TranslationServer.get_locale():
		build()
	_list.scroll_vertical = 0


func close() -> void:
	visible = false


## Listeyi baştan kurar: yazıları sıraya alır, ilk bütçe kadarını hemen ekler.
func build() -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.free()
	_pending.clear()
	_built_locale = TranslationServer.get_locale()
	_build_started_usec = Time.get_ticks_usec()
	_slowest_frame_ms = 0.0
	_longest_delta_ms = 0.0
	_queue(tr("ABOUT_VERSION") % ProjectSettings.get_setting("application/config/version"),
			BODY_PX, BODY_COLOR)
	_queue_heading("ABOUT_CREDITS")
	for entry: CreditEntry in catalog.entries:
		_queue(tr(entry.title), TITLE_PX, TITLE_COLOR)
		_queue("%s · %s" % [entry.author, tr(entry.license)], BODY_PX, BODY_COLOR)
	_queue_heading("ABOUT_GODOT")
	_queue_paragraphs(Engine.get_license_text())
	_queue_heading("ABOUT_THIRD_PARTY")
	for component: Dictionary in Engine.get_copyright_info():
		_queue(String(component["name"]), TITLE_PX, TITLE_COLOR)
		_queue(_component_text(component), BODY_PX, BODY_COLOR)
	_queue_heading("ABOUT_LICENSE_TEXTS")
	var licenses: Dictionary = Engine.get_license_info()
	for license_name: String in licenses:
		_queue(license_name, TITLE_PX, TITLE_COLOR)
		_queue_paragraphs(String(licenses[license_name]))
	_drain(BUILD_BUDGET_MS)


## Sıradaki bütün yazıları hemen ekler (testler).
func finish_build() -> void:
	_drain(INF)


## Bu kurulumda bir karede yazı eklemeye harcanan en uzun süre (ms; testler ve günlük).
func slowest_frame_ms() -> float:
	return _slowest_frame_ms


## Eklenmeyi bekleyen yazı kalmadı mı.
func is_built() -> bool:
	return _pending.is_empty()


## Listedeki bütün yazılar alt alta (testler).
func shown_text() -> String:
	var lines: PackedStringArray = []
	for child: Node in _box.get_children():
		var label: Label = child as Label
		if label != null:
			lines.append(label.text)
	return "\n".join(lines)


func _process(delta: float) -> void:
	if visible and not _pending.is_empty():
		_longest_delta_ms = maxf(_longest_delta_ms, delta * 1000.0)
		_drain(BUILD_BUDGET_MS)


func _component_text(component: Dictionary) -> String:
	var lines: PackedStringArray = []
	for part: Dictionary in component["parts"]:
		for holder: String in part["copyright"]:
			lines.append("© " + holder)
		lines.append(String(part["license"]))
	return "\n".join(lines)


func _queue(text: String, size_px: int, color: Color, heading: bool = false) -> void:
	_pending.append([text, size_px, color, heading])


func _queue_heading(key: String) -> void:
	_queue(tr(key), HEADING_PX, HEADING_COLOR, true)


## Uzun metin boş satırlardan paragraflara bölünür (tek yazı kare bütçesini aşmasın).
func _queue_paragraphs(text: String) -> void:
	for paragraph: String in text.strip_edges().split("\n\n", false):
		_queue(paragraph, BODY_PX, BODY_COLOR)


## Bütçe dolana dek sıradaki yazıları ekler (en az bir yazı).
func _drain(budget_ms: float) -> void:
	var started: int = Time.get_ticks_usec()
	while not _pending.is_empty():
		var item: Array = _pending.pop_front()
		var label: Label = _add(item[0], item[1], item[2])
		if item[3]:
			label.custom_minimum_size.y = HEADING_PX + SECTION_GAP_PX
			label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		if (Time.get_ticks_usec() - started) / 1000.0 >= budget_ms:
			break
	_slowest_frame_ms = maxf(_slowest_frame_ms, (Time.get_ticks_usec() - started) / 1000.0)
	if _pending.is_empty() and OS.is_debug_build():
		print("ABOUT built labels=%d total_ms=%.1f slowest_frame_ms=%.1f longest_delta_ms=%.1f" % [
			_box.get_child_count(), (Time.get_ticks_usec() - _build_started_usec) / 1000.0,
			_slowest_frame_ms, _longest_delta_ms])


func _add(text: String, size_px: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = size_px
	settings.font_color = color
	label.label_settings = settings
	label.text = text
	_box.add_child(label)
	return label
