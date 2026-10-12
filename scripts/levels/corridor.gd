class_name Corridor
extends Node2D
## Koridorun iki duvarı (M1-03). Sabit sayıda duvar parçası tur başında oluşturulur; görünür
## alanın altında kalan parça en üste taşınır (tur sırasında düğüm oluşturulmaz, .clauderules §6).
## Parçalar StaticBody2D'dir; oyuncu duvara bunlarla tutunur (architecture.md §8.1).
## Görseller Polygon2D'dir: dünyada Control kullanılmaz, çünkü Control dokunuşları yutar.
##
## Duvar boşlukları (M2-11): Run etkin boşlukları set_gaps() ile bildirir. Her parça, boşlukların
## dışında kalan katı aralıklara bölünür (en fazla MAX_PIECES); çarpışma ve görüntü yalnızca bu
## aralıklarda vardır. Parçacıklar baştan oluşturulur, yalnızca boyları ve yerleri değişir.

const SEGMENT_HEIGHT: float = 400.0
const WALL_THICKNESS: float = 60.0
## Desteklenen en uzun görünür alan (21:9 ≈ 2520 px) ve pay; parça sayısı buna göre seçilir.
const MAX_VIEW_HEIGHT: float = 3200.0
## Bir parçanın en fazla kaç katı aralığa bölünebileceği (iki boşluk arası ve iki uç).
const MAX_PIECES: int = 3
## Bundan kısa katı aralık çizilmez ve çarpışmaz (px).
const MIN_PIECE: float = 1.0
## M1 gri kutuları: parçalar sırayla açık ve koyu boyanır, böylece kayma gözle görülür.
const COLOR_LIGHT: Color = Color(0.42, 0.45, 0.52)
const COLOR_DARK: Color = Color(0.3, 0.33, 0.4)
## Geçici palet tonu (M2-09): duvarlar sektörün rengine bu oranda çekilir. Kesin palet M3'te.
const TINT_WEIGHT: float = 0.35
## Ton geçişinin süresi (yalnızca görsel).
const TINT_TIME: float = 0.6

var _left: Array[StaticBody2D] = []
var _right: Array[StaticBody2D] = []
var _ring_height: float = 0.0
## Her parçanın katı parçacıkları (çarpışma ve görüntü), parçayla aynı sırada.
var _shapes: Dictionary[StaticBody2D, Array] = {}
var _pieces: Dictionary[StaticBody2D, Array] = {}
var _visuals: Array[Polygon2D] = []
var _base_colors: Array[Color] = []
var _tint: Color = Color.WHITE
var _tint_tween: Tween
## Etkin boşluklar: (duvar -1/+1, üst y, alt y).
var _gaps: Array[Vector3] = []
var _gaps_dirty: bool = true


## Duvar parçalarını oluşturur; en üstteki parçanın üst kenarı top_y olur.
func build(top_y: float) -> void:
	# Çift sayı: parça bir halka boyu yukarı taşınınca renk sırası bozulmaz.
	var count: int = ceili(MAX_VIEW_HEIGHT / SEGMENT_HEIGHT) + 2
	count += count % 2
	_ring_height = count * SEGMENT_HEIGHT
	for i: int in count:
		var color: Color = COLOR_LIGHT if i % 2 == 0 else COLOR_DARK
		var y: float = top_y + (i + 0.5) * SEGMENT_HEIGHT
		_left.append(_make_segment(color, y))
		_right.append(_make_segment(color, y))
	_gaps_dirty = true


## Etkin boşlukları bildirir; değiştiyse parçalar yeniden bölünür (update_view'da).
func set_gaps(gaps: Array[Vector3]) -> void:
	if gaps != _gaps:
		_gaps = gaps.duplicate()
		_gaps_dirty = true


## Duvarları sektörün geçici rengine doğru tonlar; instant değilse yumuşak geçişle.
func set_tint(color: Color, instant: bool = false) -> void:
	if _tint_tween != null:
		_tint_tween.kill()
	if instant:
		_apply_tint(color)
		return
	_tint_tween = create_tween()
	_tint_tween.tween_method(_apply_tint, _tint, color, TINT_TIME)


## Şu anki ton rengi (testler).
func tint() -> Color:
	return _tint


## Bir duvarın katı aralıkları (üst y, alt y), dünyada; testler için.
func solid_ranges(side: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for segment: StaticBody2D in (_left if side < 0.0 else _right):
		for shape: CollisionShape2D in _shapes[segment]:
			if not shape.disabled:
				var half: float = (shape.shape as RectangleShape2D).size.y * 0.5
				var center: float = segment.position.y + shape.position.y
				result.append(Vector2(center - half, center + half))
	return result


## Duvarları koridor genişliğine yerleştirir ve görünür alanın altında kalan parçaları yukarı
## taşır. Genişlik her adımda okunur; canlı ayar paneliyle değişince duvarlar hemen kayar.
func update_view(view_bottom: float, half_width: float) -> void:
	var offset: float = half_width + WALL_THICKNESS * 0.5
	for i: int in _left.size():
		_place(_left[i], -offset, view_bottom)
		_place(_right[i], offset, view_bottom)
	if _gaps_dirty:
		_gaps_dirty = false
		for segment: StaticBody2D in _left:
			_cut(segment, -1.0)
		for segment: StaticBody2D in _right:
			_cut(segment, 1.0)


func _place(segment: StaticBody2D, x: float, view_bottom: float) -> void:
	segment.position.x = x
	if segment.position.y - SEGMENT_HEIGHT * 0.5 <= view_bottom:
		return
	while segment.position.y - SEGMENT_HEIGHT * 0.5 > view_bottom:
		segment.position.y -= _ring_height
	segment.reset_physics_interpolation()
	# Yeni yerinde başka boşluklar olabilir.
	_gaps_dirty = true


## Parçayı, o duvarın boşlukları dışında kalan katı aralıklara böler.
func _cut(segment: StaticBody2D, side: float) -> void:
	var top: float = segment.position.y - SEGMENT_HEIGHT * 0.5
	var bottom: float = segment.position.y + SEGMENT_HEIGHT * 0.5
	var solids: Array[Vector2] = [Vector2(top, bottom)]
	for gap: Vector3 in _gaps:
		if gap.x != side or gap.z <= top or gap.y >= bottom:
			continue
		var next: Array[Vector2] = []
		for solid: Vector2 in solids:
			if gap.y > solid.x:
				next.append(Vector2(solid.x, minf(gap.y, solid.y)))
			if gap.z < solid.y:
				next.append(Vector2(maxf(gap.z, solid.x), solid.y))
		solids = next
	var shapes: Array = _shapes[segment]
	var pieces: Array = _pieces[segment]
	var used: int = 0
	for solid: Vector2 in solids:
		if solid.y - solid.x < MIN_PIECE or used >= MAX_PIECES:
			continue
		var shape: CollisionShape2D = shapes[used]
		var piece: Polygon2D = pieces[used]
		var length: float = solid.y - solid.x
		var center: float = (solid.x + solid.y) * 0.5 - segment.position.y
		(shape.shape as RectangleShape2D).size = Vector2(WALL_THICKNESS, length)
		shape.position = Vector2(0.0, center)
		shape.disabled = false
		piece.polygon = _rect(Vector2(WALL_THICKNESS, length), center)
		piece.visible = true
		used += 1
	for i: int in range(used, MAX_PIECES):
		(shapes[i] as CollisionShape2D).disabled = true
		(pieces[i] as Polygon2D).visible = false


func _apply_tint(color: Color) -> void:
	_tint = color
	for i: int in _visuals.size():
		_visuals[i].color = _base_colors[i].lerp(color, TINT_WEIGHT)


func _make_segment(color: Color, y: float) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(0.0, y)
	var shapes: Array[CollisionShape2D] = []
	var pieces: Array[Polygon2D] = []
	for i: int in MAX_PIECES:
		var collision: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(WALL_THICKNESS, SEGMENT_HEIGHT)
		collision.shape = shape
		collision.disabled = i > 0
		body.add_child(collision)
		shapes.append(collision)
		var visual: Polygon2D = Polygon2D.new()
		visual.polygon = _rect(shape.size, 0.0)
		visual.color = color
		visual.visible = i == 0
		body.add_child(visual)
		pieces.append(visual)
		_visuals.append(visual)
		_base_colors.append(color)
	_shapes[body] = shapes
	_pieces[body] = pieces
	add_child(body)
	return body


static func _rect(size: Vector2, center_y: float) -> PackedVector2Array:
	var half: Vector2 = size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, center_y - half.y), Vector2(half.x, center_y - half.y),
		Vector2(half.x, center_y + half.y), Vector2(-half.x, center_y + half.y),
	])
