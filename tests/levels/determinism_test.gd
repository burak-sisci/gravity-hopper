extends GdUnitTestSuite
## Belirlenimcilik (M2-17, architecture.md §8.2): harita yalnızca tohum + başlangıç sektörüne
## bağlıdır. Aynı tohumla kurulan iki gerçek tur, oyuncu hiç dokunmasa da sık sık dokunsa da
## (yol, Glimmer, kıl payı ve çöküş duvarı değişir) aynı parça dizisini ve konumlarını verir.
## Sektörler kısaltılır (150 m) ki 1500 karede sınırlar geçilsin. Ekran boyundan bağımsızlık
## tests/systems/chunk_spawner_test.gd'de.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const FRAMES: int = 1500
## Dokunan oyuncu bu kadar karede bir dokunur.
const TAP_EVERY: int = 23
const SHORT_LENGTH: float = 150.0


func after_test() -> void:
	Events.debug_invincibility_changed.emit(false)


func test_same_seed_same_map_whatever_the_player_does() -> void:
	for sector: int in [1, 2, 3]:
		var idle: Array = await _play(424242, sector, false)
		var busy: Array = await _play(424242, sector, true)
		assert_int((idle[0] as Array).size()).override_failure_message(
				"S%d: az parça yerleşti" % sector).is_greater(5)
		assert_array(busy[0] as Array).override_failure_message(
				"S%d: parça dizisi değişti" % sector).is_equal(idle[0] as Array)
		assert_array(busy[1] as Array).override_failure_message(
				"S%d: parça konumları değişti" % sector).is_equal(idle[1] as Array)
		# Dokunan oyuncu gerçekten başka bir yol izledi.
		assert_int(busy[2] as int).override_failure_message(
				"S%d: dokunuş çevirme yapmadı" % sector).is_greater(5)


func test_sector_boundaries_are_crossed_identically() -> void:
	var idle: Array = await _play(77, 1, false)
	var busy: Array = await _play(77, 1, true)
	assert_array(idle[3] as Array).is_equal([2, 3])
	assert_array(busy[3] as Array).is_equal([2, 3])
	assert_array(busy[1] as Array).is_equal(idle[1] as Array)


func test_different_seed_different_map() -> void:
	var a: Array = await _play(1001, 1, false)
	var b: Array = await _play(1002, 1, false)
	assert_array(b[0] as Array).is_not_equal(a[0] as Array)


## Bir tur oynar: [parça adları, alt kenarlar, çevirme sayısı, girilen sektörler].
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
	for frame: int in FRAMES:
		if taps and frame % TAP_EVERY == 0:
			var touch := InputEventScreenTouch.new()
			touch.pressed = true
			touch.position = Vector2(540, 1200)
			get_tree().root.push_input(touch, true)
		await get_tree().physics_frame
	Events.player_flipped.disconnect(on_flip)
	Events.sector_entered.disconnect(on_sector)
	var spawner: ChunkSpawner = run.get_node("%ChunkSpawner") as ChunkSpawner
	var result: Array = [
		spawner.placed_names.duplicate(), spawner.placed_bottoms.duplicate(), flips[0], entered,
	]
	remove_child(run)
	run.free()
	return result
