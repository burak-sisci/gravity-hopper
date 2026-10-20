extends GdUnitTestSuite
## Oyunun içindeki performans ölçümü (M3-19, architecture.md §16.1): kare süresi özeti, evre
## başına kalite sırası (yüksek → orta → düşük), duvar ve dalga karelerinin ayrı sayılması,
## takılmalar.
## Testler efekt kalitesini geri bırakır.

## Kare süresi (sn): ikili sayıda tam, toplamlar kaymaz.
const TICK_SEC: float = 0.125
## Takılma testi için uzun ve kısa kare (ms).
const LONG_FRAME_MS: float = 62.5
const SHORT_FRAME_MS: float = 15.625

var _quality: GameTypes.Quality


func before_test() -> void:
	_quality = Settings.effect_quality


func after_test() -> void:
	Settings.effect_quality = _quality
	Events.settings_changed.emit()


func test_summarize_gives_average_p95_and_worst() -> void:
	var frames: Array[float] = []
	for i: int in 100:
		frames.append(8.0)
	frames[10] = 30.0
	for i: int in range(20, 26):
		frames[i] = 12.0
	var summary: Vector3 = PerfProbe.summarize(frames)
	assert_float(summary.x).is_equal_approx((93 * 8.0 + 6 * 12.0 + 30.0) / 100.0, 0.0001)
	assert_float(summary.y).is_equal(12.0)
	assert_float(summary.z).is_equal(30.0)
	assert_object(PerfProbe.summarize([] as Array[float])).is_equal(Vector3.ZERO)


func test_quality_steps_down_each_phase_and_wraps() -> void:
	var probe: PerfProbe = _add_probe(2.0)
	assert_int(Settings.effect_quality).is_equal(GameTypes.Quality.HIGH)
	var seen: Array[GameTypes.Quality] = []
	for phase: int in 4:
		seen.append(Settings.effect_quality)
		for i: int in roundi(2.0 / TICK_SEC):
			probe.tick(TICK_SEC * 1000.0)
	assert_array(seen).is_equal([
		GameTypes.Quality.HIGH, GameTypes.Quality.MEDIUM, GameTypes.Quality.LOW,
		GameTypes.Quality.HIGH,
	])


func test_wall_and_wave_frames_are_counted_apart() -> void:
	var probe: PerfProbe = _add_probe(5.0)
	# Isınma (1 sn) ölçülmez.
	_ticks(probe, roundi(PerfProbe.WARMUP_SEC / TICK_SEC))
	assert_int(_count(probe, "_frames")).is_equal(0)
	Events.wall_proximity_changed.emit(0.4)
	Events.sector_entered.emit(3)
	_ticks(probe, 5)
	assert_int(_count(probe, "_wall_frames")).is_equal(5)
	assert_int(_count(probe, "_wave_frames")).is_equal(5)
	# Dalga wave_time sonra biter; duvar ekranda kalır, sonra ekrandan çıkar.
	_ticks(probe, 20)
	Events.wall_proximity_changed.emit(0.0)
	_ticks(probe, 1)
	var wave_frames: int = 0
	var left: float = Neon.STYLE.wave_time
	while left > 0.0:
		left = maxf(left - TICK_SEC, 0.0)
		if left > 0.0:
			wave_frames += 1
	assert_int(_count(probe, "_frames")).is_equal(26)
	assert_int(_count(probe, "_wall_frames")).is_equal(25)
	assert_int(_count(probe, "_wave_frames")).is_equal(wave_frames)
	assert_int(wave_frames).is_less(25)


func test_long_frames_count_as_spikes_after_warmup() -> void:
	var probe: PerfProbe = _add_probe(5.0)
	# Isınmadaki uzun kareler sayılmaz (süreler ikili sayıda tam: ısınma tam 1 sn'de biter).
	probe.tick(LONG_FRAME_MS)
	probe.tick(PerfProbe.WARMUP_SEC * 1000.0 - LONG_FRAME_MS)
	probe.tick(LONG_FRAME_MS)
	probe.tick(PerfProbe.SPIKE_MS)
	probe.tick(SHORT_FRAME_MS)
	assert_int(probe.get("_spikes") as int).is_equal(1)
	assert_int(_count(probe, "_frames")).is_equal(3)


func _add_probe(phase_sec: float) -> PerfProbe:
	var probe: PerfProbe = auto_free(PerfProbe.new()) as PerfProbe
	probe.phase_sec = phase_sec
	add_child(probe)
	# Kare süresini test sürer; motorun kareleri karışmasın.
	probe.set_process(false)
	return probe


func _ticks(probe: PerfProbe, count: int) -> void:
	for i: int in count:
		probe.tick(TICK_SEC * 1000.0)


func _count(probe: PerfProbe, field: StringName) -> int:
	return (probe.get(field) as Array).size()
