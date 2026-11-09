class_name NeonButton
extends Button
## Neon düğme (M5-02, architecture.md §5.3): koyu dolgu, renkli neon kenar ve kenarın renginde
## yumuşak parlama (StyleBoxFlat gölgesi; doku, düğüm ya da shader yok). Yazı proje fontu
## (Exo 2 kalın); metin çeviri anahtarıdır, Button kendisi çevirir. Basılınca dolgu aydınlanır.
## Ölçüler (dokunma hedefi ≥ 48 dp, metin kontrastı) tests/ui/main_menu_test.gd'de.

## Dolgu: metin kontrastı bunun üstünde ölçülür.
const FILL: Color = Color(0.03, 0.05, 0.12, 0.94)
## Basılıyken dolgu.
const FILL_PRESSED: Color = Color(0.1, 0.18, 0.32, 0.96)
const TEXT: Color = Color(0.94, 0.98, 1.0)
const TEXT_DISABLED: Color = Color(0.55, 0.6, 0.68)
## Kapalı düğmenin kenarı vurgunun bu kadar saydamıdır.
const DISABLED_BORDER_ALPHA: float = 0.3
const BORDER_PX: int = 5
const RADIUS_PX: int = 28
const GLOW_PX: int = 14
const GLOW_ALPHA: float = 0.35

## Kenar ve parlamanın rengi.
@export var accent: Color = Color(0.0, 0.85, 1.0):
	set(value):
		accent = value
		apply_style()
## Yazı boyutu.
@export_range(16, 160, 1, "suffix:px") var font_size: int = 56:
	set(value):
		font_size = value
		apply_style()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	apply_style()


## Kutuları ve yazı renklerini vurgu rengiyle yeniden kurar.
func apply_style() -> void:
	add_theme_stylebox_override(&"normal", _box(FILL, accent))
	add_theme_stylebox_override(&"hover", _box(FILL, accent))
	add_theme_stylebox_override(&"pressed", _box(FILL_PRESSED, accent.lightened(0.3)))
	add_theme_stylebox_override(&"hover_pressed", _box(FILL_PRESSED, accent.lightened(0.3)))
	add_theme_stylebox_override(&"disabled",
			_box(FILL, Color(accent, DISABLED_BORDER_ALPHA), false))
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_hover_pressed_color", &"font_focus_color"]:
		add_theme_color_override(state, TEXT)
	add_theme_color_override(&"font_disabled_color", TEXT_DISABLED)
	add_theme_font_size_override(&"font_size", font_size)


func _box(fill: Color, border: Color, glow: bool = true) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(BORDER_PX)
	box.set_corner_radius_all(RADIUS_PX)
	box.set_content_margin_all(BORDER_PX * 4.0)
	if glow:
		box.shadow_color = Color(border, GLOW_ALPHA)
		box.shadow_size = GLOW_PX
	return box
