extends GdUnitTestSuite
## RunRng: oynanıştaki tek rastgelelik kaynağı (architecture.md §8.2). Aynı tohum her zaman
## aynı diziyi vermeli; günlük meydan okuma ve hata yeniden üretimi buna dayanır.

const SEQUENCE_LENGTH: int = 50


func test_same_seed_gives_same_sequence() -> void:
	var a: RunRng = RunRng.new(42)
	var b: RunRng = RunRng.new(42)
	for i: int in SEQUENCE_LENGTH:
		assert_float(a.next_float()).is_equal(b.next_float())


func test_different_seeds_give_different_sequences() -> void:
	assert_array(_draws(42)).is_not_equal(_draws(43))


func test_all_methods_are_deterministic() -> void:
	var a: RunRng = RunRng.new(7)
	var b: RunRng = RunRng.new(7)
	for i: int in SEQUENCE_LENGTH:
		assert_int(a.range_int(0, 9)).is_equal(b.range_int(0, 9))
		assert_float(a.range_float(-1.0, 1.0)).is_equal(b.range_float(-1.0, 1.0))
		assert_bool(a.chance(0.5)).is_equal(b.chance(0.5))


func test_run_seed_is_kept() -> void:
	assert_int(RunRng.new(1234).run_seed).is_equal(1234)


func test_make_seed_is_never_zero() -> void:
	# Run'da 0 "tohum verilmedi" anlamına gelir; üretilen tohum hiç 0 olmamalı.
	for i: int in 200:
		assert_int(RunRng.make_seed()).is_not_equal(0)


func test_range_int_stays_in_bounds() -> void:
	var rng: RunRng = RunRng.new(99)
	for i: int in 500:
		assert_int(rng.range_int(3, 5)).is_between(3, 5)


func _draws(seed_value: int) -> Array[float]:
	var rng: RunRng = RunRng.new(seed_value)
	var out: Array[float] = []
	for i: int in SEQUENCE_LENGTH:
		out.append(rng.next_float())
	return out


func test_weighted_index_skips_zero_weights_and_follows_ratio() -> void:
	var rng: RunRng = RunRng.new(5)
	var weights: Array[float] = [0.0, 1.0, 3.0, 0.0]
	var counts: Array[int] = [0, 0, 0, 0]
	for i: int in 4000:
		counts[rng.weighted_index(weights)] += 1
	assert_int(counts[0] + counts[3]).is_equal(0)
	# 1:3 oranı; 4000 çekilişte ±%10 pay.
	assert_float(float(counts[2]) / counts[1]).is_between(2.7, 3.3)


func test_weighted_index_is_deterministic_and_handles_empty() -> void:
	var a: RunRng = RunRng.new(11)
	var b: RunRng = RunRng.new(11)
	var weights: Array[float] = [2.0, 1.0, 0.5]
	for i: int in SEQUENCE_LENGTH:
		assert_int(a.weighted_index(weights)).is_equal(b.weighted_index(weights))
	var none: Array[float] = [0.0, 0.0]
	assert_int(a.weighted_index(none)).is_equal(-1)
