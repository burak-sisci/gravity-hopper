extends GdUnitTestSuite
## Oyuncu izi (M3-04, architecture.md §9): izin boyu ve süresi ekran yenileme hızından bağımsız
## (60 ve 120 Hz'de aynı), ara karede boy sıçramıyor, baş oyuncunun üstünde, ölünce iz toplanıyor.
## Hızla uzayan iz (M3-13): süre çarpanı değişince iz sıfırlanmaz, yeni boyuna uzar.
## Kozmetik iz (M4-08): TrailDef renk geçişini, kalınlığı, parlamayı ve boyu verir; renkli iz
## sektörün rengini izlemez (saydam parlama rengi dışında); varsayılana dönünce her şey geri gelir.

const TRAILS: TrailCatalog = preload("res://data/trails/trail_catalog.tres")
## Fizik adımı başına tırmanış (px) ve çevirmede yan hız (px/adım).
const CLIMB_PER_TICK: float = 10.0
const SIDE_PER_TICK: float = 40.0
const TICKS: int = 90


func test_trail_same_at_60_and_120_hz() -> void:
	var at_60: Trail = _add_trail()
	var at_120: Trail = _add_trail()
	for tick: int in TICKS:
		var point: Vector2 = _motion(tick)
		at_60.record(point)
		at_120.record(point)
		# 60 Hz'de adım başına bir kare, 120 Hz'de iki kare çizilir.
		at_60._process(1.0 / 60.0)
		at_120._process(1.0 / 120.0)
		at_120._process(1.0 / 120.0)
	assert_array(at_120.points_at(0.0)).is_equal(at_60.points_at(0.0))
	assert_array(at_120.points_at(0.5)).is_equal(at_60.points_at(0.5))


func test_trail_covers_its_duration_without_jumps() -> void:
	var trail: Trail = _add_trail()
	for tick: int in TICKS:
		trail.record(Vector2(0.0, -CLIMB_PER_TICK * tick))
	# Düz tırmanışta iz, süresi kadar adımın yolunu kaplar; ara karede (120 Hz) boyu değişmez.
	var expected: float = trail.tick_count() * CLIMB_PER_TICK
	for fraction: float in [0.0, 0.25, 0.5, 0.99]:
		assert_float(_length(trail.points_at(fraction))).is_equal_approx(expected, 0.001)
	var duration: float = float(trail.tick_count()) / Engine.physics_ticks_per_second
	assert_float(duration).is_equal_approx(Neon.STYLE.trail_duration, 0.5 / 60.0)


func test_stretch_keeps_the_trail_and_grows_it() -> void:
	var trail: Trail = _add_trail()
	for tick: int in TICKS:
		trail.record(Vector2(0.0, -CLIMB_PER_TICK * tick))
	var short_count: int = trail.tick_count()
	var head: Vector2 = trail.points_at(1.0)[0]
	var tail: Vector2 = trail.points_at(0.0)[short_count + 1]
	trail.stretch = 1.5
	assert_int(trail.tick_count()).is_equal(roundi(short_count * 1.5))
	var next: Vector2 = Vector2(0.0, -CLIMB_PER_TICK * TICKS)
	trail.record(next)
	var grown: PackedVector2Array = trail.points_at(1.0)
	# Kayıtlar korunur: baş yeni konumda, eski baş bir adım geride, kuyruk eski kuyrukta.
	assert_int(grown.size()).is_equal(trail.tick_count() + 2)
	assert_vector(grown[0]).is_equal(next)
	assert_vector(grown[1]).is_equal(head)
	assert_vector(grown[grown.size() - 1]).is_equal(tail)
	# Düz tırmanış sürdükçe iz yeni süresinin yolunu kaplar.
	for tick: int in range(TICKS + 1, TICKS * 2):
		trail.record(Vector2(0.0, -CLIMB_PER_TICK * tick))
	assert_float(_length(trail.points_at(0.0))).is_equal_approx(
			trail.tick_count() * CLIMB_PER_TICK, 0.001)


func test_head_is_on_owner() -> void:
	var trail: Trail = _add_trail()
	for tick: int in TICKS:
		trail.record(_motion(tick))
	trail._process(1.0 / 60.0)
	assert_vector(trail.points[0]).is_equal(Vector2.ZERO)
	assert_int(trail.points.size()).is_equal(trail.tick_count() + 2)


func test_trail_builds_its_neon_lines() -> void:
	# Alt sınıf kurucusu NeonLine'ınkini çağırmazsa iz hiç çizilmez (M3-04'te yaşandı).
	var trail: Trail = _add_trail()
	assert_int(trail.get_child_count()).is_equal(Neon.STYLE.max_layer_count() + 1)
	for tick: int in TICKS:
		trail.record(_motion(tick))
	trail._process(1.0 / 60.0)
	for child: Node in trail.get_children():
		assert_int((child as Line2D).points.size()).is_equal(trail.tick_count() + 2)


func test_trail_collapses_when_owner_stops() -> void:
	var trail: Trail = _add_trail()
	for tick: int in TICKS:
		trail.record(_motion(tick))
	assert_float(_length(trail.points_at(0.0))).is_greater(0.0)
	var stop: Vector2 = _motion(TICKS)
	for tick: int in trail.tick_count() + 2:
		trail.record(stop)
	assert_float(_length(trail.points_at(0.5))).is_equal(0.0)


func test_trail_fades_to_ambient() -> void:
	var trail: Trail = _add_trail()
	var ambient: Color = Color(0.65, 0.45, 1.0)
	trail.set_ambient(ambient)
	assert_bool(trail.glow_color.is_equal_approx(ambient)).is_true()
	assert_bool(trail.gradient.get_color(0).is_equal_approx(Neon.STYLE.player_color)).is_true()
	assert_bool(trail.gradient.get_color(1).is_equal_approx(Color(ambient, 0.0))).is_true()


func test_trail_def_sets_colors_width_glow_and_length() -> void:
	var trail: Trail = _add_trail()
	var plain_ticks: int = trail.tick_count()
	var ambient: Color = Color(1.0, 0.6, 0.2)
	var def: TrailDef = TRAILS.get_def(&"trail_plasma")
	trail.apply_def(def)
	trail.set_ambient(ambient)
	assert_object(trail.trail_def()).is_same(def)
	var last: int = def.colors.size() - 1
	assert_int(trail.gradient.get_point_count()).is_equal(def.colors.size())
	for i: int in def.colors.size():
		var expected: Color = def.colors[i] if i < last else Color(def.colors[i], 0.0)
		assert_bool(trail.gradient.get_color(i).is_equal_approx(expected)).is_true()
		assert_float(trail.gradient.get_offset(i)).is_equal_approx(float(i) / last, 0.0001)
	assert_bool(trail.glow_color.is_equal_approx(def.glow_color)).is_true()
	assert_float(trail.width).is_equal_approx(Neon.STYLE.trail_width * def.width_scale, 0.0001)
	assert_int(trail.tick_count()).is_equal(roundi(plain_ticks * def.length_scale))
	_assert_halos(trail, def.glow_scale)
	# Varsayılana dönüş: beyazdan çevre rengine, ilk kalınlık, boy ve parlama.
	trail.apply_def(null)
	assert_int(trail.gradient.get_point_count()).is_equal(2)
	assert_bool(trail.gradient.get_color(1).is_equal_approx(Color(ambient, 0.0))).is_true()
	assert_bool(trail.glow_color.is_equal_approx(ambient)).is_true()
	assert_float(trail.width).is_equal(Neon.STYLE.trail_width)
	assert_int(trail.tick_count()).is_equal(plain_ticks)
	_assert_halos(trail, 1.0)


## Renkli izin renkleri sektörle değişmez; saydam parlama rengi sektörü izler.
func test_colored_trail_keeps_its_colors_across_sectors() -> void:
	var trail: Trail = _add_trail()
	var def: TrailDef = TrailDef.new()
	def.colors = PackedColorArray([Color.WHITE, Color(0.4, 0.5, 1.0)])
	trail.apply_def(def)
	for ambient: Color in [Color(0.3, 0.9, 1.0), Color(0.7, 0.4, 1.0)]:
		trail.set_ambient(ambient)
		assert_bool(trail.gradient.get_color(1).is_equal_approx(Color(0.4, 0.5, 1.0, 0.0))) 				.is_true()
		assert_bool(trail.glow_color.is_equal_approx(ambient)).is_true()
	# Katalogdaki varsayılan iz tanımı, tanımsızla aynı.
	trail.apply_def(TRAILS.default_def())
	assert_bool(trail.gradient.get_color(0).is_equal_approx(Neon.STYLE.player_color)).is_true()
	assert_bool(trail.gradient.get_color(1).is_equal_approx(Color(0.7, 0.4, 1.0, 0.0))).is_true()


## Görünen parlama kopyaları geçerli kalitenin katmanları, kalınlıkları çarpanla.
func _assert_halos(trail: Trail, scale: float) -> void:
	var widths: Array[float] = []
	for child: Node in trail.get_children():
		var line: Line2D = child as Line2D
		if line.material != null and line.visible:
			widths.append(line.width)
	var layers: Array[Vector2] = Neon.STYLE.layers_for(Neon.quality)
	assert_int(widths.size()).is_equal(layers.size())
	for i: int in mini(widths.size(), layers.size()):
		assert_float(widths[i]).is_equal_approx(layers[i].x * scale, 0.001)


func _add_trail() -> Trail:
	var trail: Trail = auto_free(Trail.new()) as Trail
	add_child(trail)
	# Yalnızca elle çağrılan _process sayılsın.
	trail.set_process(false)
	return trail


## Tırmanış + her 20 adımda yön değiştiren yan hareket (çevirmeler).
func _motion(tick: int) -> Vector2:
	var leg: int = tick % 40
	var x: float = SIDE_PER_TICK * (leg if leg < 20 else 40 - leg)
	return Vector2(x, -CLIMB_PER_TICK * tick)


func _length(line: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	return total
