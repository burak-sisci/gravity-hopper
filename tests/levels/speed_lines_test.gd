extends GdUnitTestSuite
## Hız çizgileri (M3-13, architecture.md §9): hız verilmeden yok; tırmanış hızıyla sayıları,
## boyları ve düşüş hızları artar; his yeni sektöre yavaşça gider ve yeni çizgiler ekranın
## üstünden girer; ölümde yeniden doğmazlar. Sayı kaliteyle azalır.

const STEP: float = 1.0 / 60.0
## Bir karede en çok düşüş (tavan hız 22 m/sn × 2,6 × 1,3 sapma ≈ 62 px).
const MAX_STEP_FALL: float = 65.0

var _quality: GameTypes.Quality


func before_test() -> void:
	_quality = Neon.quality
	Neon.quality = GameTypes.Quality.HIGH


func after_test() -> void:
	Neon.quality = _quality


func test_no_lines_without_speed() -> void:
	var lines: SpeedLines = _add_lines()
	assert_bool(lines.visible).is_false()
	lines.set_speed(12.0, true)
	assert_bool(lines.visible).is_true()
	lines.set_speed(0.0, true)
	assert_bool(lines.visible).is_false()


func test_faster_sector_more_longer_faster_lines() -> void:
	var slow: SpeedLines = _add_lines()
	var fast: SpeedLines = _add_lines()
	slow.set_speed(12.0, true)
	fast.set_speed(16.0, true)
	assert_float(slow.feel()).is_equal(0.0)
	assert_float(fast.feel()).is_equal_approx(0.4, 0.0001)
	assert_int(slow.active_count()).is_equal(Neon.STYLE.speed_line_count.x)
	assert_int(fast.active_count()).is_equal(12)
	assert_float(_mean_length(fast)).is_greater(_mean_length(slow))
	# Düşüş: tırmanış hızının 1,6 katı (± sapma) ve hızlı sektörde daha hızlı. En üstteki çizgi
	# ölçülür: konumlar rastgele, alttaki bir çizgi 10 karede ekrandan çıkıp yeniden doğabilir.
	var top: int = _topmost(slow)
	var start_y: float = slow.head_y(top)
	_advance(slow, 10)
	var fall: float = slow.head_y(top) - start_y
	var expected: float = TuningConfig.to_px(12.0) * Neon.STYLE.speed_line_speed.x * 10.0 * STEP
	var jitter: float = Neon.STYLE.speed_line_jitter
	assert_float(fall).is_between(expected * (1.0 - jitter) - 0.01, expected * (1.0 + jitter) + 0.01)


func test_feel_rises_gradually_and_new_lines_enter_from_the_top() -> void:
	var lines: SpeedLines = _add_lines()
	lines.set_speed(12.0, true)
	lines.set_speed(22.0, false)
	assert_float(lines.feel()).is_equal(0.0)
	var start: int = lines.active_count()
	# Her yeni çizgi ekranın üstünde doğar; doğduğu karede en çok bir karelik yol alır.
	for frame: int in 30:
		var shown: int = lines.active_count()
		_advance(lines, 1)
		for i: int in range(shown, lines.active_count()):
			assert_float(lines.head_y(i)).override_failure_message(
					"Yeni çizgi %d ekranın içinde doğdu" % i).is_less_equal(MAX_STEP_FALL)
	assert_int(lines.active_count()).is_greater(start)
	assert_float(lines.feel()).is_equal_approx(0.5, 0.02)
	_advance(lines, 40)
	assert_float(lines.feel()).is_equal(1.0)
	assert_int(lines.active_count()).is_equal(Neon.STYLE.speed_line_count.y)


func test_stopped_lines_fall_away() -> void:
	var lines: SpeedLines = _add_lines()
	lines.set_speed(16.0, true)
	lines.stop()
	_advance(lines, 180)
	var bottom: float = lines.get_viewport_rect().size.y
	for i: int in lines.active_count():
		assert_float(lines.head_y(i) - lines.line_length(i)).override_failure_message(
				"Durunca çizgi %d yeniden doğdu" % i).is_greater(bottom)


func test_lower_quality_fewer_lines() -> void:
	var lines: SpeedLines = _add_lines()
	Neon.quality = GameTypes.Quality.LOW
	lines.set_speed(22.0, true)
	assert_int(lines.active_count()).is_equal(
			roundi(Neon.STYLE.speed_line_count.y * Neon.STYLE.particle_low_ratio))


func test_style_maps_speed_to_feel() -> void:
	var style: NeonStyle = Neon.STYLE
	assert_float(style.speed_feel(8.0)).is_equal(0.0)
	assert_float(style.speed_feel(12.0)).is_equal(0.0)
	assert_float(style.speed_feel(14.0)).is_equal_approx(0.2, 0.0001)
	assert_float(style.speed_feel(22.0)).is_equal(1.0)
	assert_float(style.speed_feel(30.0)).is_equal(1.0)
	assert_float(style.trail_stretch(0.0)).is_equal(1.0)
	assert_float(style.trail_stretch(1.0)).is_equal_approx(1.0 + style.trail_speed_stretch, 0.0001)


func _add_lines() -> SpeedLines:
	var lines: SpeedLines = auto_free(SpeedLines.new()) as SpeedLines
	add_child(lines)
	# Yalnızca elle çağrılan _process sayılsın.
	lines.set_process(false)
	return lines


func _advance(lines: SpeedLines, frames: int) -> void:
	for i: int in frames:
		lines._process(STEP)


func _topmost(lines: SpeedLines) -> int:
	var top: int = 0
	for i: int in lines.active_count():
		if lines.head_y(i) < lines.head_y(top):
			top = i
	return top


func _mean_length(lines: SpeedLines) -> float:
	var total: float = 0.0
	for i: int in lines.active_count():
		total += lines.line_length(i)
	return total / lines.active_count()
