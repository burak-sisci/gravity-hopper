extends GdUnitTestSuite
## Kıl payı yavaş çekimi (M3-12, architecture.md §9): Engine.time_scale gerçek zamanla sayılan
## süre boyunca düşer, sonunda yumuşakça tabana döner; taban (debug yavaş çekimi) korunur.

const STEP: float = 1.0 / 60.0


func after_test() -> void:
	Engine.time_scale = 1.0


func test_slows_then_returns_to_one() -> void:
	var slow: SlowMotion = SlowMotion.new()
	slow.start(0.5, 0.25, 0.08)
	assert_float(Engine.time_scale).is_equal_approx(0.5, 0.0001)
	var scales: Array[float] = []
	for i: int in 20:
		slow.advance(STEP)
		scales.append(Engine.time_scale)
	assert_bool(slow.is_active()).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)
	# Dönüşe kadar sabit 0,5; dönüşte 1'e doğru artar, hiç 1'i aşmaz.
	assert_float(scales[8]).is_equal_approx(0.5, 0.0001)
	for i: int in range(1, scales.size()):
		assert_float(scales[i]).is_greater_equal(scales[i - 1])
		assert_float(scales[i]).is_less_equal(1.0)
	# 0,25 sn'lik süre gerçek zamanla 15 adımdır (zaman ölçeği adım sayısını değiştirmez).
	assert_int(scales.count(1.0)).is_between(5, 6)


func test_restart_extends_and_keeps_the_base() -> void:
	Engine.time_scale = 0.3
	var slow: SlowMotion = SlowMotion.new()
	slow.start(0.5, 0.25, 0.0)
	assert_float(Engine.time_scale).is_equal_approx(0.15, 0.0001)
	for i: int in 10:
		slow.advance(STEP)
	slow.start(0.5, 0.25, 0.0)
	for i: int in 10:
		slow.advance(STEP)
	assert_bool(slow.is_active()).override_failure_message(
			"Yeniden başlatma süreyi uzatmalı").is_true()
	assert_float(Engine.time_scale).is_equal_approx(0.15, 0.0001)
	for i: int in 10:
		slow.advance(STEP)
	assert_float(Engine.time_scale).override_failure_message(
			"Debug ölçeğine dönmeli").is_equal_approx(0.3, 0.0001)


func test_stop_and_disabled_values() -> void:
	var slow: SlowMotion = SlowMotion.new()
	slow.start(0.5, 0.25, 0.08)
	slow.stop()
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_float(slow.factor()).is_equal(1.0)
	slow.start(1.0, 0.25, 0.08)
	assert_bool(slow.is_active()).is_false()
	slow.start(0.5, 0.0, 0.0)
	assert_bool(slow.is_active()).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)
