extends GdUnitTestSuite
## Koridor ve duvar boşlukları (M2-11, architecture.md §5.2): boşluk aralığında duvar yok, sınırlar
## tam boşluk kenarında, düğüm sayısı değişmez. Neon kenarlar (M3-03) çarpışmayla aynı yerde,
## kesik yalnızca boşluk kenarında; vuruşta nabız. Renk dalgası (M3-08) parçaları önün altında
## yeni, üstünde eski renge boyar.

const HALF_WIDTH: float = 450.0
## İki duvarda boşluklar; ikisi parça sınırına (-1000, -1400) tam denk gelir.
const GAPS: Array[Vector3] = [
	Vector3(-1.0, -900.0, -500.0), Vector3(1.0, -1400.0, -1000.0), Vector3(1.0, -2350.0, -2150.0),
]

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


func test_edges_match_collision() -> void:
	_corridor.set_gaps(GAPS)
	_corridor.update_view(0.0, HALF_WIDTH)
	for side: float in [-1.0, 1.0]:
		var visual: Array[Vector3] = []
		for line: PackedVector2Array in _corridor.edge_lines(side):
			visual.append(_inner_run(line))
		visual.sort()
		var physical: Array[Vector3] = _collision_edges(side)
		assert_int(visual.size()).is_equal(physical.size())
		for i: int in physical.size():
			# Kenar çizgisi, oyuncunun dokunduğu iç kenarın tam üstünde ve aynı boyda.
			assert_bool(visual[i].is_equal_approx(physical[i])).is_true()
			assert_float(visual[i].x).is_equal_approx(side * HALF_WIDTH, 0.01)


func test_cut_only_at_gap_edges() -> void:
	_corridor.set_gaps(GAPS)
	_corridor.update_view(0.0, HALF_WIDTH)
	for side: float in [-1.0, 1.0]:
		var caps: Array[float] = []
		for line: PackedVector2Array in _corridor.edge_lines(side):
			for end: int in [0, line.size() - 1]:
				var next: Vector2 = line[1 if end == 0 else end - 1]
				if not is_equal_approx(line[end].x, next.x):
					# Kesik duvar kalınlığı boyunca, boşluk kenarında yatay.
					assert_float(absf(line[end].x - next.x)).is_equal_approx(
							Corridor.WALL_THICKNESS, 0.01)
					assert_float(line[end].y).is_equal_approx(next.y, 0.01)
					caps.append(line[end].y)
		var expected: Array[float] = []
		for gap: Vector3 in GAPS:
			if gap.x == side:
				expected.append_array([gap.y, gap.z])
		caps.sort()
		expected.sort()
		assert_array(caps).is_equal(expected)


func test_beat_pulse_brightens_walls_toward_accent() -> void:
	_corridor.set_colors(Color(0.3, 0.85, 0.95), Color(0.8, 0.97, 1.0))
	_corridor.set_beat(0.5)
	assert_bool(_corridor.modulate.is_equal_approx(Color.WHITE)).is_true()
	_corridor.set_beat(4.0)
	var peak: Color = _corridor.modulate
	# Çevre renginin en zayıf kanalı (kırmızı) vurguya doğru en çok artar.
	assert_bool(peak.r > peak.g and peak.g > 1.0 and peak.b > 1.0).is_true()
	_corridor.set_beat(4.1)
	assert_bool(_corridor.modulate.r < peak.r and _corridor.modulate.r > 1.0).is_true()


func test_wave_paints_below_front_new_and_above_old() -> void:
	var old_color: Color = Color(0.3, 0.85, 0.95)
	var new_color: Color = Color(0.65, 0.45, 1.0)
	_corridor.set_colors(old_color, Color(0.8, 0.97, 1.0))
	var front: float = -2000.0
	var half_band: float = Neon.STYLE.wave_blend * 0.5
	_corridor.set_wave(front, new_color, Color(0.88, 0.8, 1.0))
	var counts: Vector3i = Vector3i.ZERO
	for side: float in [-1.0, 1.0]:
		for entry: Vector4 in _corridor.segment_colors(side):
			var color: Color = Color(entry.y, entry.z, entry.w)
			if entry.x >= front + half_band:
				assert_bool(color.is_equal_approx(new_color)).is_true()
				counts.x += 1
			elif entry.x <= front - half_band:
				assert_bool(color.is_equal_approx(old_color)).is_true()
				counts.y += 1
			else:
				# Bantta karışık: kırmızı kanal iki rengin arasında.
				assert_float(color.r).is_between(old_color.r, new_color.r)
				counts.z += 1
	assert_bool(counts.x > 0 and counts.y > 0).is_true()
	# Görünüş de boyanıyor: kenar parlamaları iki renkte.
	var glows: Array[Color] = []
	for line: Node in _corridor.find_children("*", "NeonLine", true, false):
		glows.append((line as NeonLine).glow_color)
	assert_array(glows).contains([old_color, new_color])
	# Dalganın üstündeki renk set_colors'unki; dalga bitince set_colors hepsini yeniler.
	assert_bool(_corridor.ambient().is_equal_approx(old_color)).is_true()
	_corridor.set_colors(new_color, Color(0.88, 0.8, 1.0))
	for entry: Vector4 in _corridor.segment_colors(-1.0):
		assert_bool(Color(entry.y, entry.z, entry.w).is_equal_approx(new_color)).is_true()


## Çizginin dikey kısmı: (x, üst y, alt y).
func _inner_run(line: PackedVector2Array) -> Vector3:
	for i: int in line.size() - 1:
		if is_equal_approx(line[i].x, line[i + 1].x):
			return Vector3(line[i].x, minf(line[i].y, line[i + 1].y), maxf(line[i].y, line[i + 1].y))
	return Vector3.INF


## Etkin çarpışma kutularının iç kenarları: (x, üst y, alt y), sıralı.
func _collision_edges(side: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for node: Node in _corridor.find_children("*", "CollisionShape2D", true, false):
		var shape: CollisionShape2D = node as CollisionShape2D
		if shape.disabled or signf(shape.global_position.x) != side:
			continue
		var half: Vector2 = (shape.shape as RectangleShape2D).size * 0.5
		var center: Vector2 = shape.global_position
		result.append(Vector3(center.x - side * half.x, center.y - half.y, center.y + half.y))
	result.sort()
	return result


func _count_nodes() -> int:
	return _corridor.find_children("*", "", true, false).size()
