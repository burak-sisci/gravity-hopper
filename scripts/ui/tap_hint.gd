class_name TapHint
extends Control
## İlk açılışın "dokun" ipucu (M5-07, GDD §18): metinsiz, nabız atan bir el ve parmak ucundan
## yayılan halka. Doku dosyası yok; şekiller kodla çizilir (açık dolgu, neon kenar). Dokunuşu
## yutmaz (MOUSE_FILTER_IGNORE): oyuncu elin üstüne de dokunsa çevirir. HUD açar; oyuncunun ilk
## çevirmesinde (Events.player_flipped) kaybolur. Animasyon yalnızca görseldir (_process).

## Nabız süresi (sn): el bu sürede bir kez basar, halka bir kez yayılır.
const PULSE_PERIOD: float = 1.0
## Elin basarken küçüldüğü oran.
const PRESS_SCALE: float = 0.88
## Kenar kalınlığı ve halkanın çizgisi (px).
const OUTLINE_PX: float = 8.0
const RING_WIDTH_PX: float = 8.0
## Halkanın başlangıç ve son yarıçapı (px).
const RING_FROM_PX: float = 30.0
const RING_TO_PX: float = 100.0
## Elin parçaları (yerel px; kutu 300 × 380, parmak ucu üstte ortada).
const FINGERTIP: Vector2 = Vector2(150.0, 110.0)
const FINGER: Rect2 = Rect2(124.0, 110.0, 52.0, 160.0)
const PALM: Rect2 = Rect2(92.0, 230.0, 150.0, 140.0)
const THUMB: Rect2 = Rect2(56.0, 250.0, 64.0, 80.0)
const KNUCKLES: Array[Rect2] = [
	Rect2(176.0, 200.0, 44.0, 70.0),
	Rect2(214.0, 214.0, 40.0, 64.0),
]
const FILL: Color = Color(0.92, 0.97, 1.0)
## Kenar ve halka rengi (HUD camgöbeği).
@export var accent: Color = Color(0.0, 0.85, 1.0)

var _time: float = 0.0
var _outline_box: StyleBoxFlat
var _fill_box: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	Events.player_flipped.connect(hide_hint)
	_outline_box = _box(accent)
	_fill_box = _box(FILL)


func _process(delta: float) -> void:
	if not visible:
		return
	_time = fposmod(_time + delta, PULSE_PERIOD)
	queue_redraw()


## İpucunu gösterir (nabız baştan başlar).
func show_hint() -> void:
	_time = 0.0
	visible = true
	queue_redraw()


func hide_hint() -> void:
	visible = false


## Nabzın evresi: 0 → 1 (her PULSE_PERIOD'da bir).
func phase() -> float:
	return _time / PULSE_PERIOD


## Halkanın en büyük hali ve elin kenarlı şekilleri dahil çizilen her şeyin sınırı (yerel px).
func drawn_bounds() -> Rect2:
	var reach: float = RING_TO_PX + RING_WIDTH_PX * 0.5
	var bounds: Rect2 = Rect2(FINGERTIP - Vector2.ONE * reach, Vector2.ONE * reach * 2.0)
	for rect: Rect2 in hand_rects():
		bounds = bounds.merge(rect.grow(OUTLINE_PX))
	return bounds


## Elin çizildiği şekiller (yerel px): parmak, eklemler, avuç, başparmak.
func hand_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = [FINGER, PALM, THUMB]
	rects.append_array(KNUCKLES)
	return rects


func _draw() -> void:
	var t: float = phase()
	# Halka parmak ucundan yayılır ve söner.
	var ring_color: Color = Color(accent, 1.0 - t)
	draw_arc(FINGERTIP, lerpf(RING_FROM_PX, RING_TO_PX, t), 0.0, TAU, 48, ring_color,
			RING_WIDTH_PX, true)
	# El evrenin ilk yarısında basar (küçülür), ikinci yarısında geri gelir.
	var press: float = lerpf(1.0, PRESS_SCALE, sin(t * PI))
	draw_set_transform(FINGERTIP * (1.0 - press), 0.0, Vector2.ONE * press)
	for rect: Rect2 in hand_rects():
		draw_style_box(_outline_box, rect.grow(OUTLINE_PX))
	for rect: Rect2 in hand_rects():
		draw_style_box(_fill_box, rect)
	draw_set_transform(Vector2.ZERO)


func _box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(roundi(FINGER.size.x * 0.5))
	box.anti_aliasing = true
	return box
