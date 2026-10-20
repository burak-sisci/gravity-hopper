extends GdUnitTestSuite
## Belirlenimcilik (M2-17, architecture.md §8.2): harita yalnızca tohum + başlangıç sektörüne
## bağlıdır. Aynı tohumla kurulan iki gerçek tur, oyuncu hiç dokunmasa da sık sık dokunsa da
## (yol, Glimmer, kıl payı ve çöküş duvarı değişir) aynı parça dizisini ve konumlarını verir.
## Sektörler kısaltılır (150 m) ki 35 sn'de sınırlar geçilsin; bu süre en yavaş parçada da
## (90 BPM, M3-21) her başlangıç sektöründe yeterince parça yerleştirir. Ekran boyundan bağımsızlık
## tests/systems/chunk_spawner_test.gd'de.
## Kıl payı yavaş çekimi (M3-12) oyun zamanını yavaşlatır: turlar aynı oyun zamanı kadar oynanır
## ve yerleşen parçaların ortak başı karşılaştırılır (son adımın farkı bir parça ekleyebilir).

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
## Bir turun oynandığı oyun zamanı (sn) ve güvenlik için kare sınırı.
const PLAY_TIME: float = 35.0
const MAX_FRAMES: int = 3000
## Dokunan oyuncu bu kadar karede bir dokunur.
const TAP_EVERY: int = 23
const SHORT_LENGTH: float = 150.0


func after_test() -> void:
	Events.debug_invincibility_changed.emit(false)
	Engine.time_scale = 1.0


func test_same_seed_same_map_whatever_the_player_does() -> void:
	var slowed: int = 0
	for sector: int in [1, 2, 3]:
		var idle: Array = await _play(424242, sector, false)
		var busy: Array = await _play(424242, sector, true)
		assert_int((idle[0] as Array).size()).override_failure_message(
				"S%d: az parça yerleşti" % sector).is_greater(5)
		_assert_same_start(busy[0] as Array, idle[0] as Array, "S%d: parça dizisi" % sector)
		_assert_same_start(busy[1] as Array, idle[1] as Array, "S%d: parça konumları" % sector)
		# Dokunan oyuncu gerçekten başka bir yol izledi.
		assert_int(busy[2] as int).override_failure_message(
				"S%d: dokunuş çevirme yapmadı" % sector).is_greater(5)
		slowed += busy[4] as int
	# Yavaş çekim gerçekten oldu; harita yine de değişmedi.
	assert_int(slowed).override_failure_message("Yavaş çekim hiç olmadı").is_greater(0)


func test_sector_boundaries_are_crossed_identically() -> void:
	var idle: Array = await _play(77, 1, false)
	var busy: Array = await _play(77, 1, true)
	assert_array(idle[3] as Array).is_equal([2, 3])
	assert_array(busy[3] as Array).is_equal([2, 3])
	_assert_same_start(busy[1] as Array, idle[1] as Array, "Parça konumları")


func test_different_seed_different_map() -> void:
	var a: Array = await _play(1001, 1, false)
	var b: Array = await _play(1002, 1, false)
	assert_array(b[0] as Array).is_not_equal(a[0] as Array)


## İki tur aynı oyun zamanında durur, ama son adımda biri bir parça fazla yerleştirmiş olabilir.
func _assert_same_start(busy: Array, idle: Array, label: String) -> void:
	var count: int = mini(busy.size(), idle.size())
	assert_int(absi(busy.size() - idle.size())).override_failure_message(
			"%s: uzunluk farkı %d" % [label, busy.size() - idle.size()]).is_less_equal(1)
	assert_array(busy.slice(0, count)).override_failure_message(
			"%s değişti" % label).is_equal(idle.slice(0, count))


## Bir tur oynar: [parça adları, alt kenarlar, çevirme sayısı, girilen sektörler, yavaş kare].
func _play(run_seed: int, sector: int, taps: bool) -> Array:
	var run: Run = RUN_SCENE.instantiate() as Run
	run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	var sectors: SectorCatalog = SectorCatalog.new()
	for i: int in SECTORS.count():
		var def: SectorDef = SECTORS.def_at(i + 1).duplicate() as SectorDef
		def.length = SHORT_LENGTH
		sectors.sectors.append(def)
	run.sectors = sectors
	run.run_seed = run_seed
	run.start_sector = sector
	var flips: Array[int] = [0]
	var entered: Array[int] = []
	var on_flip: Callable = func() -> void: flips[0] += 1
	var on_sector: Callable = func(index: int) -> void: entered.append(index)
	Events.player_flipped.connect(on_flip)
	Events.sector_entered.connect(on_sector)
	add_child(run)
	Events.debug_invincibility_changed.emit(true)
	var conductor: Conductor = run.get_node("%Conductor") as Conductor
	var slow_frames: int = 0
	var frame: int = 0
	while conductor.run_time < PLAY_TIME and frame < MAX_FRAMES:
		if taps and frame % TAP_EVERY == 0:
			var touch := InputEventScreenTouch.new()
			touch.pressed = true
			touch.position = Vector2(540, 1200)
			get_tree().root.push_input(touch, true)
		await get_tree().physics_frame
		if Engine.time_scale < 1.0:
			slow_frames += 1
		frame += 1
	Events.player_flipped.disconnect(on_flip)
	Events.sector_entered.disconnect(on_sector)
	var spawner: ChunkSpawner = run.get_node("%ChunkSpawner") as ChunkSpawner
	var result: Array = [
		spawner.placed_names.duplicate(), spawner.placed_bottoms.duplicate(), flips[0], entered,
		slow_frames,
	]
	remove_child(run)
	run.free()
	return result
