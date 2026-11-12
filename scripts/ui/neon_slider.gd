class_name NeonSlider
extends HSlider
## Neon kaydırıcı (M5-05, architecture.md §5.3): NeonButton görünümünde koyu iz, dolu kısım vurgu
## renginde, yuvarlak tutamaç. Doku dosyası yok: tutamaç kodla çizilen küçük bir görüntü.
## Dokunma hedefi kaydırıcının bütün kutusudur (yükseklik ≥ 48 dp); izin herhangi bir yerine
## dokunmak değeri oraya taşır.

const TRACK_PX: int = 24
const GRABBER_PX: int = 72
const TRACK_FILL: Color = Color(0.1, 0.14, 0.24)

## Dolu kısmın ve tutamacın rengi.
@export var accent: Color = Color(0.0, 0.85, 1.0):
	set(value):
		accent = value
		apply_style()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	apply_style()


## İzi, dolu kısmı ve tutamacı vurgu rengiyle kurar.
func apply_style() -> void:
	add_theme_stylebox_override(&"slider", _track(TRACK_FILL))
	add_theme_stylebox_override(&"grabber_area", _track(accent))
	add_theme_stylebox_override(&"grabber_area_highlight", _track(accent.lightened(0.2)))
	var grabber: ImageTexture = _grabber(Color.WHITE.lerp(accent, 0.15))
	add_theme_icon_override(&"grabber", grabber)
	add_theme_icon_override(&"grabber_highlight", grabber)
	add_theme_icon_override(&"grabber_disabled", grabber)


func _track(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(roundi(TRACK_PX * 0.5))
	box.content_margin_top = TRACK_PX / 2.0
	box.content_margin_bottom = TRACK_PX / 2.0
	return box


## Kenarı yumuşatılmış dolu daire.
static func _grabber(color: Color) -> ImageTexture:
	var image: Image = Image.create_empty(GRABBER_PX, GRABBER_PX, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2.ONE * (GRABBER_PX - 1) * 0.5
	var radius: float = GRABBER_PX * 0.5 - 1.0
	for y: int in GRABBER_PX:
		for x: int in GRABBER_PX:
			var alpha: float = clampf(radius - Vector2(x, y).distance_to(center) + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(color, alpha))
	return ImageTexture.create_from_image(image)
