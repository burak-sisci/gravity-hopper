extends GdUnitTestSuite
## Otomatik kalite kuralı (M6-11, ADR-112): ölçülen koşullar (architecture.md §16.1) kaliteyi
## düşürmez; 60 FPS'i 30 sn tutamayan cihaz düşürür. Kare dizileri ölçümlerin özetinden kurulur.

## 120 Hz'de bir kare (ms).
const FRAME_120_MS: float = 8.33
## 60 Hz'de bir kare (ms).
const FRAME_60_MS: float = 16.67
## M6-10 yapay yük evresinde takılmasız karelerin ortalaması (ms).
const BURST_OTHER_MS: float = 10.17


## Redmi, yüksek kalite (M6-03 / M6-10): en kötü evre ortalaması takılmasız 11,4 ms, takılma
## kümeli 13,3 ms; 5 dk boyunca en kötüsü sürse bile düşmez.
func test_reference_phone_never_lowers() -> void:
	assert_int(_feed(_steady(13.3, 300.0))).is_equal(-1)


## Başka uygulamaların CPU yükü (M6-10): yapay 8 çekirdekli 10 sn'de 137 takılma, 6509 ms fazla
## süre; aynı evrede takılmasız kareler ort. 10,17 ms (pencere ortalaması ≈ 27 ms); öncesi ve
## sonrası normal. Kalite düşmez.
func test_cpu_burst_from_other_apps_never_lowers() -> void:
	var frames: Array[float] = _steady(9.3, 60.0)
	var spike_ms: float = FRAME_120_MS + 6509.0 / 137.0
	for i: int in 137:
		frames.append(spike_ms)
	frames.append_array(_steady(BURST_OTHER_MS, (10000.0 - 137 * spike_ms) / 1000.0))
	frames.append_array(_steady(9.3, 60.0))
	assert_int(_feed(frames)).is_equal(-1)


## M6-03'ün en uzun doğal kümesi ≈ 15 sn: her kare 33 ms olsa bile, pencereler nereden bölerse
## bölsün en çok 2 yavaş pencere eder; kalite düşmez.
func test_longest_cluster_never_lowers_at_any_offset() -> void:
	for offset_sec: float in [0.0, 2.0, 5.0, 8.0, 9.9]:
		var frames: Array[float] = _steady(9.3, 30.0 + offset_sec)
		frames.append_array(_steady(33.0, 15.0))
		frames.append_array(_steady(9.3, 30.0))
		assert_int(_feed(frames)).override_failure_message("kayma %.1f sn" % offset_sec) \
				.is_equal(-1)


## Emülatör, 60 Hz (M6-04): dalgasız 16,9 ms; her ≈ 70 sn'de 1,2 sn'lik dalga 38,2 ms.
func test_emulator_with_sector_waves_never_lowers() -> void:
	var frames: Array[float] = []
	for sector: int in 5:
		frames.append_array(_steady(16.9, 68.8))
		frames.append_array(_steady(38.2, 1.2))
	assert_int(_feed(frames)).is_equal(-1)


## 60 FPS'i tutamayan cihaz (40 FPS): 30. sn'de düşer, 29,9. sn'den önce değil (kayan nokta
## toplamı pencereyi bir kare kaydırabilir).
func test_weak_device_lowers_after_thirty_seconds() -> void:
	var lowered_at: int = _feed(_steady(25.0, 40.0))
	assert_int(lowered_at).is_between(roundi(29900.0 / 25.0), roundi(30100.0 / 25.0))


## Dikey eşitlemede GPU payı biraz aşınca kareler 16,7 / 33,3 ms dönüşür (ort. 25 ms): düşer.
func test_alternating_missed_vsync_lowers() -> void:
	var frames: Array[float] = []
	for i: int in 1200:
		frames.append(FRAME_60_MS if i % 2 == 0 else FRAME_60_MS * 2.0)
	assert_int(_feed(frames)).is_greater_equal(0)


## Arada normal bir pencere sayacı sıfırlar: yavaş 20 sn + normal 10 sn + yavaş 20 sn düşmez.
func test_a_good_window_resets_the_streak() -> void:
	var frames: Array[float] = _steady(25.0, 20.0)
	frames.append_array(_steady(FRAME_60_MS, 10.0))
	frames.append_array(_steady(25.0, 20.0))
	assert_int(_feed(frames)).is_equal(-1)


## Tur açılış karesi (1,4–1,5 sn) ve duraklatmadan dönüş sayılmaz.
func test_long_hitches_are_ignored() -> void:
	var rule: AutoQuality = AutoQuality.new()
	for i: int in 100:
		assert_bool(rule.add_frame(1.5)).is_false()
	assert_bool(rule.add_frame(0.0)).is_false()
	assert_float(rule.last_window_ms).is_equal(0.0)


## Düşürdükten sonra sayaç baştan: bir sonraki kademe için yine 30 sn gerekir.
func test_next_step_needs_another_thirty_seconds() -> void:
	var rule: AutoQuality = AutoQuality.new()
	var hits: Array[int] = []
	var frames: Array[float] = _steady(25.0, 60.0)
	for i: int in frames.size():
		if rule.add_frame(frames[i] / 1000.0):
			hits.append(i)
	assert_int(hits.size()).is_equal(2)
	assert_int(hits[1] - hits[0]).is_between(roundi(29900.0 / 25.0), roundi(30100.0 / 25.0))


func test_lowered_steps_down_to_low() -> void:
	assert_int(AutoQuality.lowered(GameTypes.Quality.HIGH)).is_equal(GameTypes.Quality.MEDIUM)
	assert_int(AutoQuality.lowered(GameTypes.Quality.MEDIUM)).is_equal(GameTypes.Quality.LOW)
	assert_int(AutoQuality.lowered(GameTypes.Quality.LOW)).is_equal(GameTypes.Quality.LOW)


## Kuralı baştan çalıştırır; ilk düşürmenin kare sırası, düşürme yoksa -1.
func _feed(frames_ms: Array[float]) -> int:
	var rule: AutoQuality = AutoQuality.new()
	for i: int in frames_ms.size():
		if rule.add_frame(frames_ms[i] / 1000.0):
			return i
	return -1


## seconds süre boyunca frame_ms'lik kareler.
func _steady(frame_ms: float, seconds: float) -> Array[float]:
	var frames: Array[float] = []
	frames.resize(maxi(roundi(seconds * 1000.0 / frame_ms), 0))
	frames.fill(frame_ms)
	return frames
