extends GdUnitTestSuite
## Rekor çizgisi (M3-14, architecture.md §9): yerleşene dek görünmez; yerleşince koridoru boydan
## boya geçer. Oyuncu yaklaştıkça kalınlaşıp parlar, vuruşta beyaza çekilir; çizgiye varınca bir
## kez beyaz parlayıp söner ve o turda bir daha görünmez.

const STEP: float = 1.0 / 60.0
const LINE_Y: float = -2000.0
const HALF_WIDTH: float = 450.0
## Vuruşun ortası: nabız yok.
const OFF_BEAT: float = 0.5


func test_hidden_until_placed() -> void:
	var line: RecordLine = _add_line()
	assert_bool(line.visible).is_false()
	line.track(0.0, 0.0)
	assert_bool(line.visible).is_false()
	assert_bool(line.is_passed()).is_false()


func test_spans_the_corridor_at_its_height() -> void:
	var line: RecordLine = _add_line()
	line.place(LINE_Y, HALF_WIDTH)
	assert_bool(line.visible).is_true()
	assert_float(line.position.y).is_equal(LINE_Y)
	assert_int(line.points.size()).is_equal(2)
	assert_vector(line.points[0]).is_equal(Vector2(-HALF_WIDTH, 0.0))
	assert_vector(line.points[1]).is_equal(Vector2(HALF_WIDTH, 0.0))
	assert_bool(line.is_in_group(Neon.GROUP)).is_true()


func test_grows_and_brightens_as_player_approaches() -> void:
	var style: NeonStyle = Neon.STYLE
	var line: RecordLine = _add_line()
	line.place(LINE_Y, HALF_WIDTH)
	line.track(_below_m(style.record_heat_distance * 2.0), OFF_BEAT)
	assert_float(line.heat()).is_equal(0.0)
	assert_float(line.width).is_equal_approx(style.record_width.x, 0.001)
	assert_float(line.modulate.a).is_equal_approx(style.record_alpha.x, 0.001)
	assert_bool(line.color.is_equal_approx(style.record_color)).is_true()
	line.track(_below_m(style.record_heat_distance * 0.5), OFF_BEAT)
	assert_float(line.heat()).is_equal_approx(0.5, 0.001)
	assert_float(line.width).is_equal_approx(
			lerpf(style.record_width.x, style.record_width.y, 0.5), 0.001)
	line.track(LINE_Y + 1.0, OFF_BEAT)
	assert_float(line.heat()).is_greater(0.99)
	assert_float(line.width).is_equal_approx(style.record_width.y, 0.01)
	assert_float(line.modulate.a).is_equal_approx(style.record_alpha.y, 0.01)
	assert_bool(line.is_passed()).is_false()


func test_pulses_on_the_beat() -> void:
	var style: NeonStyle = Neon.STYLE
	var line: RecordLine = _add_line()
	line.place(LINE_Y, HALF_WIDTH)
	line.track(_below_m(10.0), 0.0)
	var on_beat: Color = style.record_color.lerp(Color.WHITE, style.record_pulse_gain)
	assert_bool(line.color.is_equal_approx(on_beat)).is_true()
	line.track(_below_m(10.0), OFF_BEAT)
	assert_bool(line.color.is_equal_approx(style.record_color)).is_true()


func test_flashes_once_when_reached_then_fades() -> void:
	var style: NeonStyle = Neon.STYLE
	var line: RecordLine = _add_line()
	line.place(LINE_Y, HALF_WIDTH)
	line.track(_below_m(1.0), OFF_BEAT)
	line.track(LINE_Y - 1.0, OFF_BEAT)
	assert_bool(line.is_passed()).is_true()
	assert_bool(line.color.is_equal_approx(Color.WHITE)).is_true()
	assert_float(line.width).is_equal_approx(style.record_flash_width, 0.001)
	assert_float(line.modulate.a).is_equal_approx(style.record_alpha.y, 0.001)
	var fade_frames: int = ceili(style.record_fade / STEP)
	var half_frames: int = floori(fade_frames / 2.0)
	_advance(line, half_frames)
	assert_bool(line.visible).is_true()
	assert_float(line.modulate.a).is_between(0.3, 0.7)
	assert_float(line.width).is_between(style.record_width.y, style.record_flash_width)
	_advance(line, fade_frames - half_frames + 1)
	assert_bool(line.visible).is_false()
	assert_bool(line.is_processing()).is_false()
	# Oyuncu çizginin altına düşse de (yerçekimi) çizgi bu turda geri gelmez.
	line.track(_below_m(1.0), 0.0)
	assert_bool(line.visible).is_false()
	assert_bool(line.is_passed()).is_true()


func _add_line() -> RecordLine:
	var line: RecordLine = auto_free(RecordLine.new()) as RecordLine
	add_child(line)
	return line


## Çizginin bu kadar metre altındaki dünya y'si.
func _below_m(meters: float) -> float:
	return LINE_Y + TuningConfig.to_px(meters)


func _advance(line: RecordLine, frames: int) -> void:
	for i: int in frames:
		line._process(STEP)
