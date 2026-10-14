extends GdUnitTestSuite
## Çöküş duvarının görseli (M3-09, architecture.md §9): Control yok (dokunuş yutmaz); glitch
## bandı yalnızca kenarın çevresinde (tam ekran değil), dolgu opak; kaliteye göre bant, renk
## kayması ve düşük kalitede kırık kenar; kırık kenar öldürme çizgisinin altına inmez; desen
## vuruşla değişir, kenar vuruşta parlar.

const WALL_SCENE: PackedScene = preload("res://scenes/entities/collapse_wall.tscn")

var _stored_quality: GameTypes.Quality


func before_test() -> void:
	_stored_quality = Neon.quality


func after_test() -> void:
	Neon.set_quality(_stored_quality, get_tree())


func test_glitch_band_is_local_and_body_is_opaque() -> void:
	var wall: CollapseWall = _make()
	assert_array(wall.find_children("*", "Control", true, false)).is_empty()
	var style: NeonStyle = Neon.STYLE
	var view: Vector2 = wall.get_viewport_rect().size
	# Bant ekranın genişliğini kaplar ama yalnızca kenarın çevresinde: ekranın küçük bir kısmı.
	var band: Rect2 = _bounds(_polygon(wall, "%Glitch").polygon)
	assert_float(band.position.x).is_less_equal(-view.x * 0.5)
	assert_float(band.end.x).is_greater_equal(view.x * 0.5)
	assert_float(band.position.y).is_equal(-style.collapse_rise)
	assert_float(band.end.y).is_equal(style.collapse_depth)
	assert_float(band.size.y).is_less(view.y * 0.15)
	# Dolgu kenardan ekranın altına kadar ve opak: altında kalan her şey silinmiş görünür.
	var body: Polygon2D = _polygon(wall, "%Body")
	var body_rect: Rect2 = _bounds(body.polygon)
	assert_float(body_rect.position.y).is_equal(0.0)
	assert_float(body_rect.end.y).is_greater_equal(view.y)
	assert_float(body_rect.position.x).is_less_equal(-view.x * 0.5)
	assert_float(body.color.a).is_equal(1.0)


func test_quality_sets_glitch_split_and_low_edge() -> void:
	var wall: CollapseWall = _make()
	var material: ShaderMaterial = _polygon(wall, "%Glitch").material as ShaderMaterial
	Neon.set_quality(GameTypes.Quality.HIGH, get_tree())
	assert_bool(_visible(wall, "%Glitch")).is_true()
	assert_bool(_visible(wall, "%Edge")).is_false()
	assert_bool(_visible(wall, "%Top")).is_false()
	assert_float(material.get_shader_parameter(&"split_px") as float).is_greater(0.0)
	Neon.set_quality(GameTypes.Quality.MEDIUM, get_tree())
	assert_bool(_visible(wall, "%Glitch")).is_true()
	assert_float(material.get_shader_parameter(&"split_px") as float).is_equal(0.0)
	Neon.set_quality(GameTypes.Quality.LOW, get_tree())
	assert_bool(_visible(wall, "%Glitch")).is_false()
	assert_bool(_visible(wall, "%Edge")).is_true()
	assert_bool(_visible(wall, "%Top")).is_true()


func test_low_edge_never_drops_below_kill_line() -> void:
	Neon.set_quality(GameTypes.Quality.LOW, get_tree())
	var wall: CollapseWall = _make()
	var style: NeonStyle = Neon.STYLE
	var half: float = wall.get_viewport_rect().size.x * 0.5
	var edge: NeonLine = wall.get_node("%Edge") as NeonLine
	var heights: Dictionary[float, bool] = {}
	for beat: float in [0.0, 0.3, 1.7, 12.25, 333.5]:
		wall.set_beat(beat)
		var points: PackedVector2Array = wall.edge_points()
		assert_array(Array(edge.points)).is_equal(Array(points))
		assert_float(points[0].x).is_less_equal(-half)
		assert_float(points[points.size() - 1].x).is_greater_equal(half)
		for point: Vector2 in points:
			assert_float(point.y).is_between(-style.collapse_jag, 0.0)
			heights[snappedf(point.y, 1.0)] = true
	# Kenar gerçekten kırık (düz değil).
	assert_int(heights.size()).is_greater(5)


## Sütun ve dilim değerleri adım başına burada hesaplanıp shader'a dizi olarak yazılır.
func test_shader_arrays_match_and_stay_in_range() -> void:
	var wall: CollapseWall = _make()
	var style: NeonStyle = Neon.STYLE
	var material: ShaderMaterial = _polygon(wall, "%Glitch").material as ShaderMaterial
	var code: String = material.shader.code
	assert_str(code).contains("const int MAX_COLUMNS = %d;" % CollapseWall.MAX_COLUMNS)
	assert_str(code).contains("const int MAX_ROWS = %d;" % CollapseWall.MAX_ROWS)
	var shifted: int = 0
	for beat: float in [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75]:
		wall.set_beat(beat)
		var tops: PackedFloat32Array = wall.column_tops()
		var shifts: PackedFloat32Array = wall.slice_shifts()
		assert_int(tops.size()).is_equal(CollapseWall.MAX_COLUMNS)
		assert_int(shifts.size()).is_equal(CollapseWall.MAX_ROWS)
		assert_array(Array(material.get_shader_parameter(&"tops") as PackedFloat32Array)) \
				.is_equal(Array(tops))
		for top: float in tops:
			assert_float(top).is_between(-style.collapse_jag, 0.0)
		for shift: float in shifts:
			assert_float(absf(shift)).is_less_equal(style.collapse_slice_shift)
			if shift != 0.0:
				shifted += 1
	# Dilimlerin bir kısmı kayıyor, hepsi değil.
	assert_int(shifted).is_greater(0)
	assert_int(shifted).is_less(8 * CollapseWall.MAX_ROWS)


func test_glitch_changes_with_beat_and_pulses() -> void:
	var wall: CollapseWall = _make()
	var style: NeonStyle = Neon.STYLE
	var material: ShaderMaterial = _polygon(wall, "%Glitch").material as ShaderMaterial
	var step_beats: float = 1.0 / style.collapse_steps_per_beat
	wall.set_beat(0.0)
	var first: int = wall.glitch_step()
	assert_float(material.get_shader_parameter(&"pulse") as float).is_equal(1.0)
	# Adımın ortasında desen aynı, sonraki adımda değişir.
	wall.set_beat(step_beats * 0.5)
	assert_int(wall.glitch_step()).is_equal(first)
	wall.set_beat(step_beats)
	assert_int(wall.glitch_step()).is_equal(first + 1)
	assert_float(material.get_shader_parameter(&"glitch_step") as float).is_equal(first + 1.0)
	# Vuruşun ortasında nabız sönmüş.
	wall.set_beat(0.5)
	assert_float(material.get_shader_parameter(&"pulse") as float).is_equal(0.0)
	# Uzun turda ve tur başındaki eksi vuruşta adım sarılır, hep küçük bir sayı.
	for beat: float in [100000.0, -0.3]:
		wall.set_beat(beat)
		assert_int(wall.glitch_step()).is_between(0, CollapseWall.STEP_WRAP - 1)


func _make() -> CollapseWall:
	var wall: CollapseWall = auto_free(WALL_SCENE.instantiate()) as CollapseWall
	add_child(wall)
	return wall


func _polygon(wall: CollapseWall, path: String) -> Polygon2D:
	return wall.get_node(path) as Polygon2D


func _visible(wall: CollapseWall, path: String) -> bool:
	return (wall.get_node(path) as CanvasItem).visible


func _bounds(points: PackedVector2Array) -> Rect2:
	var rect: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect
