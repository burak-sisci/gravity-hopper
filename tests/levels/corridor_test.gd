extends GdUnitTestSuite
## Koridor ve duvar boşlukları (M2-11, architecture.md §5.2): boşluk aralığında duvar yok, sınırlar
## tam boşluk kenarında, düğüm sayısı değişmez.

const HALF_WIDTH: float = 450.0

var _corridor: Corridor


func before_test() -> void:
	_corridor = auto_free(Corridor.new()) as Corridor
	add_child(_corridor)
	_corridor.build(-3000.0)
	_corridor.update_view(0.0, HALF_WIDTH)


func test_no_gap_means_full_walls() -> void:
	# Her duvar, parça sayısı × parça boyu kadar katıdır (iki duvarın parçaları koridorun çocukları).
	var per_side: float = _corridor.get_child_count() * 0.5 * Corridor.SEGMENT_HEIGHT
	for side: float in [-1.0, 1.0]:
		var total: float = 0.0
		for span: Vector2 in _corridor.solid_ranges(side):
			total += span.y - span.x
		assert_float(total).is_equal_approx(per_side, 0.01)


func test_gap_cuts_only_its_wall() -> void:
	var nodes: int = _count_nodes()
	var right_before: Array[Vector2] = _corridor.solid_ranges(1.0)
	var gaps: Array[Vector3] = [Vector3(-1.0, -900.0, -500.0)]
	_corridor.set_gaps(gaps)
	_corridor.update_view(0.0, HALF_WIDTH)
	var touches_top: bool = false
	var touches_bottom: bool = false
	for span: Vector2 in _corridor.solid_ranges(-1.0):
		# Hiçbir katı aralık boşluğun içine girmez.
		assert_bool(span.x < -500.0 - 0.01 and span.y > -900.0 + 0.01).is_false()
		touches_top = touches_top or is_equal_approx(span.y, -900.0)
		touches_bottom = touches_bottom or is_equal_approx(span.x, -500.0)
	assert_bool(touches_top and touches_bottom).is_true()
	assert_array(_corridor.solid_ranges(1.0)).is_equal(right_before)
	assert_int(_count_nodes()).is_equal(nodes)


func test_gap_removed_restores_wall() -> void:
	var full_left: Array[Vector2] = _corridor.solid_ranges(-1.0)
	var gaps: Array[Vector3] = [Vector3(-1.0, -1700.0, -1450.0), Vector3(-1.0, -1300.0, -1250.0)]
	_corridor.set_gaps(gaps)
	_corridor.update_view(0.0, HALF_WIDTH)
	assert_array(_corridor.solid_ranges(-1.0)).is_not_equal(full_left)
	var none: Array[Vector3] = []
	_corridor.set_gaps(none)
	_corridor.update_view(0.0, HALF_WIDTH)
	assert_array(_corridor.solid_ranges(-1.0)).is_equal(full_left)


func _count_nodes() -> int:
	return _corridor.find_children("*", "", true, false).size()
