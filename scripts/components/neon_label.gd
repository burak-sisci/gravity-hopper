class_name NeonLabel
extends Label
## Neon yazı (M3-18, architecture.md §9): açık renkli çekirdek, renkli kenar ve kaliteye göre üst
## üste, dışa doğru sönen parlama katmanları. Hepsi tek bir LabelSettings'in dış çizgileri:
## düğüm, doku ya da shader yok. Kalınlıklar yazı boyutunun oranıdır (NeonStyle →
## HUD yazıları); kalite değişince yalnızca katmanlar yeniden yazılır.
## Dokunuş yutmaz (mouse_filter = IGNORE): HUD'un üstüne dokunuş çevirme yapar.

## Parlamanın rengi (tone CUSTOM iken); çekirdek bunun beyaza çekilmişidir.
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		apply_quality()
## Renk kaynağı: CUSTOM değilse renk NeonStyle'daki sabit renktir (ör. Glimmer yeşili).
@export var tone: GameTypes.NeonTone = GameTypes.NeonTone.CUSTOM:
	set(value):
		tone = value
		apply_quality()
## Yazı boyutu; kenar ve parlama kalınlıkları bununla ölçeklenir.
@export_range(8, 200, 1, "suffix:px") var font_size: int = 64:
	set(value):
		font_size = value
		apply_quality()


func _init() -> void:
	add_to_group(Neon.GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_settings = LabelSettings.new()
	apply_quality()


func _enter_tree() -> void:
	apply_quality()


## Görünüşü geçerli kaliteye göre kurar (Neon.set_quality çağırır).
func apply_quality() -> void:
	var settings: LabelSettings = label_settings
	if settings == null:
		return
	var style: NeonStyle = Neon.STYLE
	var glow: Color = shown_color()
	settings.font_size = font_size
	settings.font_color = style.text_core(glow)
	settings.outline_size = _px(style.text_edge)
	settings.outline_color = glow
	# Üst üste dış çizgilerin kalınlıkları birikir: her katman bir öncekinin dışına taşar.
	var layers: Array[Vector2] = style.text_layers_for(Neon.quality)
	settings.stacked_outline_count = layers.size()
	for i: int in layers.size():
		settings.set_stacked_outline_size(i, _px(layers[i].x))
		settings.set_stacked_outline_color(i, Color(glow, layers[i].y))


## Yazının görünen parlama rengi: tone'a göre sabit renk ya da color.
func shown_color() -> Color:
	return Neon.STYLE.tone_color(tone, color)


## Yazı boyutunun oranını piksele çevirir (oran 0 değilse en az 1 px).
func _px(ratio: float) -> int:
	if ratio <= 0.0:
		return 0
	return maxi(roundi(font_size * ratio), 1)
