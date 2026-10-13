class_name Shield
extends Node2D
## Kalkan (M2-16, GDD §7): tek bir tehlike darbesini emer, ardından kısa bir dokunulmazlık gelir.
## Düşmeye ve çöküş duvarına karşı korumaz. Sahibi (Player) give() ve consume() çağırır; durum
## değişince yukarı changed yayar. Görseli oyuncunun çevresinde neon bir halkadır (M3-04);
## dokunulmazlıkta yanıp söner (yalnızca görsel, _process).

signal changed(active: bool)

const RING_RADIUS: float = 56.0
const RING_POINTS: int = 24
## Dokunulmazlıktaki yanıp sönmenin hızı (sn'de kaç kez).
const BLINK_RATE: float = 8.0

## Kalkan şu an takılı mı.
var active: bool = false

var _grace_left: float = 0.0
var _ring: NeonLine


func _ready() -> void:
	_ring = NeonLine.new()
	_ring.color = Neon.STYLE.shield_color
	_ring.closed = true
	var circle: PackedVector2Array = PackedVector2Array()
	for i: int in RING_POINTS:
		circle.append(Vector2.from_angle(TAU * i / RING_POINTS) * RING_RADIUS)
	_ring.points = circle
	add_child(_ring)
	_ring.visible = false


func _process(_delta: float) -> void:
	if _grace_left > 0.0:
		_ring.visible = fmod(_grace_left * BLINK_RATE, 1.0) < 0.5


## Kalkan takar (yükseltme M4'te; şimdilik debug).
func give() -> void:
	if active:
		return
	active = true
	_ring.visible = true
	changed.emit(true)


## Kalkanı tüketir ve grace saniyelik dokunulmazlık başlatır.
func consume(grace: float) -> void:
	active = false
	_grace_left = grace
	changed.emit(false)


## Sahibi her fizik adımında çağırır: dokunulmazlık süresi azalır.
func tick(delta: float) -> void:
	if _grace_left <= 0.0:
		return
	_grace_left = maxf(_grace_left - delta, 0.0)
	if _grace_left == 0.0:
		_ring.visible = active


func is_in_grace() -> bool:
	return _grace_left > 0.0
