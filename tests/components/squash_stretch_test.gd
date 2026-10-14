extends GdUnitTestSuite
## Sıkışma-uzama yayı (M3-11, architecture.md §9): vuruşla sapar, alanı korur, tam 1'e döner ve
## sonucu adım boyundan bağımsızdır. Görselin kayması duvardaki (sıkışma) ya da arkada kalan
## (uzama) kenarı yerinde tutar.

## Çekirdeğin yarı genişliği (oyuncu gövdesi 60 px).
const HALF_WIDTH: float = 30.0


func test_kick_deforms_then_returns_to_exact_rest() -> void:
	var squash: SquashStretch = SquashStretch.new()
	assert_vector(squash.visual_scale()).is_equal(Vector2.ONE)
	squash.kick(0.25)
	assert_float(squash.deformation()).is_equal_approx(0.25, 0.0001)
	assert_vector(squash.visual_scale()).is_equal_approx(Vector2(1.25, 0.8), Vector2(0.0001, 0.0001))
	for i: int in 120:
		squash.advance(1.0 / 60.0)
	assert_bool(squash.is_resting()).is_true()
	assert_vector(squash.visual_scale()).is_equal(Vector2.ONE)
	assert_vector(squash.visual_offset(HALF_WIDTH, -1.0)).is_equal(Vector2.ZERO)


func test_overshoots_once_and_keeps_area() -> void:
	var squash: SquashStretch = SquashStretch.new()
	squash.kick(-0.22)
	var widest: float = 0.0
	while not squash.is_resting():
		squash.advance(1.0 / 60.0)
		var scale: Vector2 = squash.visual_scale()
		assert_float(scale.x * scale.y).is_equal_approx(1.0, 0.0001)
		widest = maxf(widest, squash.deformation())
	# Sıkışmadan sonra sönümlü bir geri yaylanma: biraz uzar ama ilk sapmadan çok azdır.
	assert_float(widest).is_greater(0.0)
	assert_float(widest).is_less(0.22 * 0.5)


func test_step_size_does_not_change_the_result() -> void:
	var at_60: SquashStretch = SquashStretch.new()
	var at_120: SquashStretch = SquashStretch.new()
	at_60.kick(0.25)
	at_120.kick(0.25)
	for i: int in 9:
		at_60.advance(1.0 / 60.0)
	for i: int in 18:
		at_120.advance(1.0 / 120.0)
	assert_float(at_120.deformation()).is_equal_approx(at_60.deformation(), 0.0001)


func test_offset_keeps_the_anchored_edge_in_place() -> void:
	var squash: SquashStretch = SquashStretch.new()
	# İnişte sol duvara basılır: sol kenar (−30) yerinde kalır.
	squash.kick(-0.22)
	var left_edge: float = squash.visual_offset(HALF_WIDTH, -1.0).x \
			- HALF_WIDTH * squash.visual_scale().x
	assert_float(left_edge).is_equal_approx(-HALF_WIDTH, 0.0001)
	# Sol duvara doğru çevirmede (sağ duvardan kalkış) uzar: arkada kalan sağ kenar yerinde.
	squash.kick(0.25)
	var right_edge: float = squash.visual_offset(HALF_WIDTH, -1.0).x \
			+ HALF_WIDTH * squash.visual_scale().x
	assert_float(right_edge).is_equal_approx(HALF_WIDTH, 0.0001)
