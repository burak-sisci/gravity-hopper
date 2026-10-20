extends GdUnitTestSuite
## Neon bileşenleri (M3-01, architecture.md §9): parlama katman sayısı efekt kalitesine göre
## değişir (yüksek 2, orta 1, düşük 0), düğüm sayısı değişmez, doku ve malzeme paylaşılır.
## Vuruş nabzı (M3-03) vuruşta tepe yapar ve söner. Sabit renkli şekil rengini tone'dan alır,
## sharp köşeleri sivriltir (M3-05). Neon yazı (M3-18) katmanlarını kaliteden, kalınlıklarını
## yazı boyutundan alır.

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


func test_beat_pulse_peaks_on_beat_and_fades() -> void:
	var style: NeonStyle = Neon.STYLE
	assert_float(style.beat_pulse(0.0)).is_equal_approx(1.0, 0.0001)
	assert_float(style.beat_pulse(3.0)).is_equal_approx(1.0, 0.0001)
	var early: float = style.beat_pulse(style.beat_pulse_length * 0.25)
	var late: float = style.beat_pulse(style.beat_pulse_length * 0.75)
	assert_bool(early < 1.0 and late < early and late > 0.0).is_true()
	assert_float(style.beat_pulse(style.beat_pulse_length)).is_equal(0.0)
	assert_float(style.beat_pulse(0.99)).is_equal(0.0)


func test_tone_takes_fixed_color_and_sharp_sets_joints() -> void:
	var shape: NeonShape = _add_shape(SPIKE, NeonShape.Glow.LINE)
	shape.color = Color.BLUE
	assert_object(shape.shown_color()).is_equal(Color.BLUE)
	shape.tone = GameTypes.NeonTone.HAZARD
	var red: Color = Neon.STYLE.hazard_color
	assert_object(shape.shown_color()).is_equal(red)
	var outline: Line2D = _outline(shape)
	assert_object(outline.default_color).is_equal(red)
	assert_object(Color((_visible_glows(shape)[0] as Line2D).default_color, 1.0)).is_equal(red)
	shape.tone = GameTypes.NeonTone.GLIMMER
	assert_object(outline.default_color).is_equal(Neon.STYLE.glimmer_color)
	assert_int(outline.joint_mode).is_equal(Line2D.LINE_JOINT_ROUND)
	shape.sharp = true
	assert_int(outline.joint_mode).is_equal(Line2D.LINE_JOINT_SHARP)
	assert_float(outline.sharp_limit).is_equal(Neon.STYLE.sharp_limit)


func test_label_layers_follow_quality_and_size() -> void:
	var label: NeonLabel = auto_free(NeonLabel.new()) as NeonLabel
	label.font_size = 100
	label.tone = GameTypes.NeonTone.RECORD
	add_child(label)
	var settings: LabelSettings = label.label_settings
	var glow: Color = Neon.STYLE.record_color
	assert_int(label.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(settings.font_size).is_equal(100)
	assert_object(settings.outline_color).is_equal(glow)
	assert_object(settings.font_color).is_equal(Neon.STYLE.text_core(glow))
	assert_int(settings.outline_size).is_equal(roundi(100 * Neon.STYLE.text_edge))
	assert_int(settings.stacked_outline_count).is_equal(Neon.STYLE.text_high_layers.size())
	var inner: Vector2 = Neon.STYLE.text_high_layers[0]
	assert_int(settings.get_stacked_outline_size(0)).is_equal(roundi(100 * inner.x))
	assert_object(settings.get_stacked_outline_color(0)).is_equal(Color(glow, inner.y))
	Neon.set_quality(GameTypes.Quality.MEDIUM, get_tree())
	assert_int(settings.stacked_outline_count).is_equal(Neon.STYLE.text_medium_layers.size())
	Neon.set_quality(GameTypes.Quality.LOW, get_tree())
	assert_int(settings.stacked_outline_count).is_equal(0)
	assert_int(settings.outline_size).is_greater(0)
	label.font_size = 50
	assert_int(settings.outline_size).is_equal(roundi(50 * Neon.STYLE.text_edge))
	assert_int(label.get_child_count()).is_equal(0)


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


## Kenar çizgisi: parlama olmayan kapalı çizgi.
func _outline(shape: NeonShape) -> Line2D:
	for child: Node in shape.get_children():
		var line: Line2D = child as Line2D
		if line != null and line.closed and line.material == null:
			return line
	return null


func _glow_count(node: Node2D) -> int:
	return _visible_glows(node).size()
