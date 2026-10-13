class_name Corridor
extends Node2D
## Koridorun iki duvarı (M1-03). Sabit sayıda duvar parçası tur başında oluşturulur; görünür
## alanın altında kalan parça en üste taşınır (tur sırasında düğüm oluşturulmaz, .clauderules §6).
## Parçalar StaticBody2D'dir; oyuncu duvara bunlarla tutunur (architecture.md §8.1).
## Görseller dünyada Control kullanmaz, çünkü Control dokunuşları yutar.
##
## Duvar boşlukları (M2-11): Run etkin boşlukları set_gaps() ile bildirir. Her parça, boşlukların
## dışında kalan katı aralıklara bölünür (en fazla MAX_PIECES); çarpışma ve görüntü yalnızca bu
## aralıklarda vardır. Parçacıklar baştan oluşturulur, yalnızca boyları ve yerleri değişir.
##
## Neon görünüş (M3-03, architecture.md §9): her parçacık saydam bir dolgu (Polygon2D) ve iç
## kenarında bir NeonLine'dır. Boşluğa bakan uçta çizgi duvar kalınlığı boyunca döner (temiz
## kesik). Renk paletten (set_colors); vuruşta bütün koridor vurgu rengine doğru nabız atar.

const SEGMENT_HEIGHT: float = 400.0
const WALL_THICKNESS: float = 60.0
## Desteklenen en uzun görünür alan (21:9 ≈ 2520 px) ve pay; parça sayısı buna göre seçilir.
const MAX_VIEW_HEIGHT: float = 3200.0
## Bir parçanın en fazla kaç katı aralığa bölünebileceği (iki boşluk arası ve iki uç).
const MAX_PIECES: int = 3
## Bundan kısa katı aralık çizilmez ve çarpışmaz (px).
const MIN_PIECE: float = 1.0
## Boşluk kenarı eşleşmesinde kabul edilen fark (px).
const GAP_EDGE_EPSILON: float = 0.01
## Nabız renk oranı hesabında çevre renginin kanal tabanı (sıfıra bölmeyi önler).
const MIN_CHANNEL: float = 0.05

var _left: Array[StaticBody2D] = []
var _right: Array[StaticBody2D] = []
var _ring_height: float = 0.0
## Her parçanın katı parçacıkları (çarpışma ve görüntü), parçayla aynı sırada.
var _shapes: Dictionary[StaticBody2D, Array] = {}
var _pieces: Dictionary[StaticBody2D, Array] = {}
var _edges: Dictionary[StaticBody2D, Array] = {}
var _fills: Array[Polygon2D] = []
var _fill_alphas: Array[float] = []
var _lines: Array[NeonLine] = []
var _ambient: Color = Color.WHITE
## Nabız tepesindeki modulate: kanal kanal vurgu / çevre oranı.
var _pulse_tint: Color = Color.WHITE
## Etkin boşluklar: (duvar -1/+1, üst y, alt y).
var _gaps: Array[Vector3] = []
var _gaps_dirty: bool = true


## Duvar parçalarını oluşturur; en üstteki parçanın üst kenarı top_y olur.
func build(top_y: float) -> void:
	# Çift sayı: parça bir halka boyu yukarı taşınınca renk sırası bozulmaz.
	var count: int = ceili(MAX_VIEW_HEIGHT / SEGMENT_HEIGHT) + 2
	count += count % 2
	_ring_height = count * SEGMENT_HEIGHT
	var style: NeonStyle = Neon.STYLE
	for i: int in count:
		var alpha: float = style.wall_fill_light if i % 2 == 0 else style.wall_fill_dark
		var y: float = top_y + (i + 0.5) * SEGMENT_HEIGHT
		_left.append(_make_segment(alpha, y))
		_right.append(_make_segment(alpha, y))
	set_colors(_ambient, Color.WHITE)
	_gaps_dirty = true


## Etkin boşlukları bildirir; değiştiyse parçalar yeniden bölünür (update_view'da).
func set_gaps(gaps: Array[Vector3]) -> void:
	if gaps != _gaps:
		_gaps = gaps.duplicate()
		_gaps_dirty = true


## Duvarları paletin çevre ve vurgu rengine göre boyar: dolgu ve parlama çevre renginde, kenarın
## çekirdeği beyaza yakın; nabız vurgu rengine çeker. Sektör geçişindeki yumuşak geçişi Run yapar.
func set_colors(ambient_color: Color, accent: Color) -> void:
	_ambient = ambient_color
	var core: Color = ambient_color.lerp(Color.WHITE, Neon.STYLE.wall_core_whiten)
	for line: NeonLine in _lines:
		line.color = core
		line.glow_color = ambient_color
	for i: int in _fills.size():
		_fills[i].color = Color(ambient_color, _fill_alphas[i])
	var boost: float = Neon.STYLE.beat_pulse_boost
	_pulse_tint = Color(accent.r / maxf(ambient_color.r, MIN_CHANNEL) * boost,
			accent.g / maxf(ambient_color.g, MIN_CHANNEL) * boost,
			accent.b / maxf(ambient_color.b, MIN_CHANNEL) * boost)


## Vuruş nabzı (yalnızca görsel): beat, tempo ızgarasının başından beri geçen vuruş sayısı.
func set_beat(beat: float) -> void:
	var strength: float = Neon.STYLE.beat_pulse_gain * Neon.STYLE.beat_pulse(beat)
	modulate = Color.WHITE.lerp(_pulse_tint, strength)


## Duvarların şu anki çevre rengi.
func ambient() -> Color:
	return _ambient


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


## Bir duvarın görünen kenar çizgileri, dünyada; testler için.
func edge_lines(side: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for segment: StaticBody2D in (_left if side < 0.0 else _right):
		for line: NeonLine in _edges[segment]:
			if line.visible:
				result.append(segment.transform * line.points)
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
	var edges: Array = _edges[segment]
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
		var edge: NeonLine = edges[used]
		edge.points = _edge_points(side, solid - Vector2.ONE * segment.position.y,
				_is_gap_edge(side, solid.x, true), _is_gap_edge(side, solid.y, false))
		edge.visible = true
		used += 1
	for i: int in range(used, MAX_PIECES):
		(shapes[i] as CollisionShape2D).disabled = true
		(pieces[i] as Polygon2D).visible = false
		(edges[i] as NeonLine).visible = false


## y, o duvardaki bir boşluğun kenarı mı: katı aralığın üstü boşluğun altına, altı boşluğun
## üstüne denk gelir.
func _is_gap_edge(side: float, y: float, solid_top: bool) -> bool:
	for gap: Vector3 in _gaps:
		if gap.x == side and absf((gap.z if solid_top else gap.y) - y) < GAP_EDGE_EPSILON:
			return true
	return false


func _make_segment(fill_alpha: float, y: float) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(0.0, y)
	var shapes: Array[CollisionShape2D] = []
	var pieces: Array[Polygon2D] = []
	var edges: Array[NeonLine] = []
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
		visual.visible = i == 0
		body.add_child(visual)
		pieces.append(visual)
		_fills.append(visual)
		_fill_alphas.append(fill_alpha)
		var edge: NeonLine = NeonLine.new()
		edge.visible = i == 0
		body.add_child(edge)
		edges.append(edge)
		_lines.append(edge)
	_shapes[body] = shapes
	_pieces[body] = pieces
	_edges[body] = edges
	add_child(body)
	return body


## Kenar çizgisi (parçanın yerel koordinatında): iç kenar boyunca; boşluğa bakan uçta duvar
## kalınlığı boyunca dış kenara döner. side -1 sol, +1 sağ duvar; span (üst y, alt y).
static func _edge_points(side: float, span: Vector2, cap_top: bool,
		cap_bottom: bool) -> PackedVector2Array:
	var inner: float = -side * WALL_THICKNESS * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	if cap_top:
		points.append(Vector2(-inner, span.x))
	points.append(Vector2(inner, span.x))
	points.append(Vector2(inner, span.y))
	if cap_bottom:
		points.append(Vector2(-inner, span.y))
	return points


static func _rect(size: Vector2, center_y: float) -> PackedVector2Array:
	var half: Vector2 = size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, center_y - half.y), Vector2(half.x, center_y - half.y),
		Vector2(half.x, center_y + half.y), Vector2(-half.x, center_y + half.y),
	])
