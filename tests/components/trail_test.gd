extends GdUnitTestSuite
## Oyuncu izi (M3-04, architecture.md §9): izin boyu ve süresi ekran yenileme hızından bağımsız
## (60 ve 120 Hz'de aynı), ara karede boy sıçramıyor, baş oyuncunun üstünde, ölünce iz toplanıyor.

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
