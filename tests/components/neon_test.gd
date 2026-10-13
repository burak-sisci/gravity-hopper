extends GdUnitTestSuite
## Neon bileşenleri (M3-01, architecture.md §9): parlama katman sayısı efekt kalitesine göre
## değişir (yüksek 2, orta 1, düşük 0), düğüm sayısı değişmez, doku ve malzeme paylaşılır.

const SPIKE: PackedVector2Array = [Vector2(0, -35), Vector2(60, 0), Vector2(0, 35)]
const BLOCK: PackedVector2Array = [
	Vector2(0, -30), Vector2(150, -30), Vector2(150, 30), Vector2(0, 30),
]


func after_test() -> void:
	Neon.quality = GameTypes.Quality.HIGH


func test_line_glow_layers_follow_quality() -> void:
	var line: NeonLine = _add_line()
	var node_count: int = line.get_child_count()
	assert_int(_glow_count(line)).is_equal(2)
	Neon.set_quality(GameTypes.Quality.MEDIUM, get_tree())
	assert_int(_glow_count(line)).is_equal(1)
	var layer: Vector2 = Neon.STYLE.medium_layers[0]
	assert_float(_visible_glows(line)[0].width).is_equal(layer.x)
	Neon.set_quality(GameTypes.Quality.LOW, get_tree())
	assert_int(_glow_count(line)).is_equal(0)
	Neon.set_quality(GameTypes.Quality.HIGH, get_tree())
	assert_int(_glow_count(line)).is_equal(2)
	assert_int(line.get_child_count()).is_equal(node_count)


func test_spike_shape_blob_follows_quality() -> void:
	var spike: NeonShape = _add_shape(SPIKE, NeonShape.Glow.BLOB)
	assert_int(_glow_count(spike)).is_equal(1)
	assert_bool(_visible_glows(spike)[0] is Sprite2D).is_true()
	Neon.set_quality(GameTypes.Quality.MEDIUM, get_tree())
	assert_int(_glow_count(spike)).is_equal(1)
	Neon.set_quality(GameTypes.Quality.LOW, get_tree())
	assert_int(_glow_count(spike)).is_equal(0)


func test_block_shape_uses_line_glow() -> void:
	var block: NeonShape = _add_shape(BLOCK, NeonShape.Glow.LINE)
	assert_int(_glow_count(block)).is_equal(2)
	for glow: CanvasItem in _visible_glows(block):
		assert_bool(glow is Line2D).is_true()
	Neon.set_quality(GameTypes.Quality.MEDIUM, get_tree())
	assert_int(_glow_count(block)).is_equal(1)
	Neon.set_quality(GameTypes.Quality.LOW, get_tree())
	assert_int(_glow_count(block)).is_equal(0)


func test_new_component_takes_current_quality() -> void:
	Neon.quality = GameTypes.Quality.LOW
	assert_int(_glow_count(_add_line())).is_equal(0)
	Neon.quality = GameTypes.Quality.MEDIUM
	assert_int(_glow_count(_add_shape(BLOCK, NeonShape.Glow.LINE))).is_equal(1)


func test_disabled_glow_stays_hidden() -> void:
	var line: NeonLine = _add_line()
	line.glow_enabled = false
	assert_int(_glow_count(line)).is_equal(0)
	Neon.set_quality(GameTypes.Quality.MEDIUM, get_tree())
	assert_int(_glow_count(line)).is_equal(0)


func test_color_reaches_line_and_glow() -> void:
	var line: NeonLine = _add_line()
	line.color = Color.RED
	for glow: CanvasItem in _visible_glows(line):
		var halo: Line2D = glow as Line2D
		assert_object(Color(halo.default_color, 1.0)).is_equal(Color.RED)
		assert_float(halo.default_color.a).is_less(1.0)
	line.glow_color = Color.CYAN
	assert_object(Color((_visible_glows(line)[0] as Line2D).default_color, 1.0)).is_equal(Color.CYAN)


func test_glow_resources_are_shared() -> void:
	var first: NeonLine = _add_line()
	var second: NeonShape = _add_shape(BLOCK, NeonShape.Glow.LINE)
	var first_halo: Line2D = _visible_glows(first)[0] as Line2D
	var second_halo: Line2D = _visible_glows(second)[0] as Line2D
	assert_object(first_halo.texture).is_same(second_halo.texture)
	assert_object(first_halo.material).is_same(second_halo.material)


func _add_line() -> NeonLine:
	var line: NeonLine = auto_free(NeonLine.new()) as NeonLine
	line.points = PackedVector2Array([Vector2(0, 0), Vector2(0, 400)])
	add_child(line)
	return line


func _add_shape(polygon: PackedVector2Array, glow: NeonShape.Glow) -> NeonShape:
	var shape: NeonShape = auto_free(NeonShape.new()) as NeonShape
	shape.polygon = polygon
	shape.glow = glow
	add_child(shape)
	return shape


## Görünen parlama düğümleri: toplamsal karışımla çizilen çocuklar.
func _visible_glows(node: Node2D) -> Array[CanvasItem]:
	var glows: Array[CanvasItem] = []
	for child: Node in node.get_children():
		var item: CanvasItem = child as CanvasItem
		if item != null and item.visible and item.material == Neon.additive_material():
			glows.append(item)
	return glows


func _glow_count(node: Node2D) -> int:
	return _visible_glows(node).size()
