extends GdUnitTestSuite
## Sektör ilerleyişi (M2-08, architecture.md §8.2–8.3): hız basamağı, Events.sector_entered,
## tempo değişimi ve her sektörde dikenlerin yarım vuruş anında geçmesi. Gerçek S1–S3'ün hız ve
## temposu, kısa boylarla (150 m) denenir.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SHORT_LENGTH: float = 150.0
const DT: float = 1.0 / 60.0

var _entered: Array[int] = []


func before_test() -> void:
	_entered.clear()
	Events.sector_entered.connect(_on_sector_entered)


func after_test() -> void:
	Events.sector_entered.disconnect(_on_sector_entered)
	Events.debug_invincibility_changed.emit(false)


func test_speed_steps_and_spikes_stay_on_beat() -> void:
	var run: Run = _start(1)
	var player: Node2D = run.get_node("%Player") as Node2D
	var conductor: Conductor = run.get_node("%Conductor") as Conductor
	var spawner: ChunkSpawner = run.get_node("%ChunkSpawner") as ChunkSpawner
	var speeds: Dictionary[int, float] = {}
	var passes: Dictionary[int, int] = {1: 0, 2: 0, 3: 0}
	# await physics_frame adım işlenmeden döner; ölçüm ilk tam adımdan sonra başlar.
	await _frames(2)
	var previous_y: float = player.position.y
	var previous_sector: int = run.sector
	for frame: int in 2100:
		await get_tree().physics_frame
		# Run oyuncudan sonra çalışır: bu karedeki adımı, önceki karenin sonundaki sektörün hızı
		# belirler (sınır karesinde oyuncu hâlâ eski hızla ilerlemiştir).
		var step: float = previous_y - player.position.y
		if not speeds.has(previous_sector):
			speeds[previous_sector] = step
		else:
			# Adım tam sabit (Player, kaymanın dikey payını geri alır; M2-10).
			assert_float(step).is_equal_approx(speeds[previous_sector], 0.002)
		previous_sector = run.sector
		var half_beat: float = conductor.beat_length() * 0.5
		for chunk: ChunkInfo in spawner.active_chunks():
			for item: Node2D in chunk.items():
				var y: float = chunk.position.y + item.position.y
				if previous_y > y and player.position.y <= y:
					passes[run.sector] += 1
					var t: float = conductor.beat_time()
					# Nefes alma (M2-09): yeni sektörün ilk 2,5 sn'sinde diken geçmez.
					if run.sector > 1:
						assert_float(t).override_failure_message(
								"S%d'ye girdikten %.2f sn sonra diken" % [run.sector, t]
						).is_greater_equal(2.5)
					var off: float = absf(t - roundf(t / half_beat) * half_beat)
					assert_float(off).override_failure_message(
							"S%d: %s yarım vuruştan %.4f sn uzak" % [run.sector, item.name, off]
					).is_less_equal(DT + 0.0001)
		previous_y = player.position.y
	assert_array(_entered).is_equal([2, 3])
	for sector: int in [1, 2, 3]:
		assert_float(speeds.get(sector, 0.0)).override_failure_message(
				"S%d adım hızı" % sector).is_equal_approx(
				SECTORS.def_at(sector).climb_px() * DT, 0.001)
		assert_int(passes[sector]).override_failure_message(
				"S%d'de diken geçişi yok" % sector).is_greater(0)
	assert_float(conductor.bpm).is_equal(SECTORS.def_at(3).bpm)
	# Geçici palet tonu S3'ün rengine geçti (geçiş 0,6 sn, S3'e çok önce girildi).
	var corridor: Corridor = run.get_node("%Corridor") as Corridor
	assert_bool(corridor.tint().is_equal_approx(SECTORS.def_at(3).ambient_color)).is_true()


func test_start_sector_sets_height_and_speed() -> void:
	var heights: Array[int] = []
	var on_height: Callable = func(meters: int) -> void: heights.append(meters)
	Events.height_changed.connect(on_height)
	var run: Run = _start(2)
	var player: Node2D = run.get_node("%Player") as Node2D
	await _frames(1)
	var y0: float = player.position.y
	await _frames(60)
	Events.height_changed.disconnect(on_height)
	assert_int(run.sector).is_equal(2)
	# 1 sn'de S2 hızıyla 14 m; yükseklik S2'nin başından (150 m) sayılır.
	assert_float(y0 - player.position.y).is_equal_approx(SECTORS.def_at(2).climb_px(), 0.01)
	assert_int(heights[0]).is_equal(int(SHORT_LENGTH))
	assert_int(heights[heights.size() - 1]).is_equal(int(SHORT_LENGTH) + 14)


func _start(sector: int) -> Run:
	var run: Run = auto_free(RUN_SCENE.instantiate()) as Run
	run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	var sectors: SectorCatalog = SectorCatalog.new()
	for i: int in SECTORS.count():
		var def: SectorDef = SECTORS.def_at(i + 1).duplicate() as SectorDef
		def.length = SHORT_LENGTH
		sectors.sectors.append(def)
	run.sectors = sectors
	run.run_seed = 31
	run.start_sector = sector
	add_child(run)
	Events.debug_invincibility_changed.emit(true)
	return run


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _on_sector_entered(index: int) -> void:
	_entered.append(index)
