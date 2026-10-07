class_name Corridor
extends Node2D
## Koridorun iki duvarı (M1-03). Sabit sayıda duvar parçası tur başında oluşturulur; görünür
## alanın altında kalan parça en üste taşınır (tur sırasında düğüm oluşturulmaz, .clauderules §6).
## Parçalar StaticBody2D'dir; oyuncu duvara bunlarla tutunur (architecture.md §8.1).
## Görseller Polygon2D'dir: dünyada Control kullanılmaz, çünkü Control dokunuşları yutar.

const SEGMENT_HEIGHT: float = 400.0
const WALL_THICKNESS: float = 60.0
## Desteklenen en uzun görünür alan (21:9 ≈ 2520 px) ve pay; parça sayısı buna göre seçilir.
const MAX_VIEW_HEIGHT: float = 3200.0
## M1 gri kutuları: parçalar sırayla açık ve koyu boyanır, böylece kayma gözle görülür.
const COLOR_LIGHT: Color = Color(0.42, 0.45, 0.52)
const COLOR_DARK: Color = Color(0.3, 0.33, 0.4)

var _left: Array[StaticBody2D] = []
var _right: Array[StaticBody2D] = []
var _ring_height: float = 0.0


## Duvar parçalarını oluşturur; en üstteki parçanın üst kenarı top_y olur.
func build(top_y: float) -> void:
	# Çift sayı: parça bir halka boyu yukarı taşınınca renk sırası bozulmaz.
	var count: int = ceili(MAX_VIEW_HEIGHT / SEGMENT_HEIGHT) + 2
	count += count % 2
	_ring_height = count * SEGMENT_HEIGHT
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(WALL_THICKNESS, SEGMENT_HEIGHT)
	for i: int in count:
		var color: Color = COLOR_LIGHT if i % 2 == 0 else COLOR_DARK
		var y: float = top_y + (i + 0.5) * SEGMENT_HEIGHT
		_left.append(_make_segment(shape, color, y))
		_right.append(_make_segment(shape, color, y))


## Duvarları koridor genişliğine yerleştirir ve görünür alanın altında kalan parçaları yukarı
## taşır. Genişlik her adımda okunur; canlı ayar paneliyle değişince duvarlar hemen kayar.
func update_view(view_bottom: float, half_width: float) -> void:
	var offset: float = half_width + WALL_THICKNESS * 0.5
	for i: int in _left.size():
		_place(_left[i], -offset, view_bottom)
		_place(_right[i], offset, view_bottom)


func _place(segment: StaticBody2D, x: float, view_bottom: float) -> void:
	segment.position.x = x
	if segment.position.y - SEGMENT_HEIGHT * 0.5 <= view_bottom:
		return
	while segment.position.y - SEGMENT_HEIGHT * 0.5 > view_bottom:
		segment.position.y -= _ring_height
	segment.reset_physics_interpolation()


func _make_segment(shape: RectangleShape2D, color: Color, y: float) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(0.0, y)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	var visual: Polygon2D = Polygon2D.new()
	var half: Vector2 = shape.size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	visual.color = color
	body.add_child(visual)
	add_child(body)
	return body
