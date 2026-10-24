extends GdUnitTestSuite
## Büyük Depolama Birimi ve Taşma (M4-13, architecture.md §8.2): son sektöre (Taşma) varış finaldir.
## Events.great_storage_reached bir kez ve sector_entered ile aynı adımda yayılır; final patlaması
## oyuncunun yerinde bütün paletlerin renkleriyle çıkar ve oyuncuyla taşınır; kamera sarsılır;
## Progression başarım izini açar (dosyaya tur sonunda yazılır). Taşma'dan başlayan turda final
## yoktur. Taşma'da palet her palette_cycle_length'te renk dalgasıyla sıradakine geçer ve başa
## sarar; hız sabit kalır. Tur boyunca düğüm oluşmaz. Gerçek sektörler kısa boylarla (150 m) ve
## kısa palet adımıyla denenir.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const GREAT_STORAGE_TRAIL: StringName = &"trail_great_storage"
const SHORT_LENGTH: float = 150.0
## Kısa palet adımı (m): Taşma'nın hızıyla 2,7 sn; renk dalgası bundan önce biter.
const SHORT_CYCLE: float = 60.0
const DT: float = 1.0 / 60.0
const SETTLE_FRAMES: int = 2

var _run: Run
var _pools: ChunkPools
## Olayların yayıldığı fizik adımları.
var _sector_frames: Dictionary[int, int] = {}
var _finale_frames: Array[int] = []


func before_test() -> void:
	Progression.reset()
	_sector_frames.clear()
	_finale_frames.clear()
	Events.sector_entered.connect(_on_sector_entered)
	Events.great_storage_reached.connect(_on_great_storage_reached)


func after_test() -> void:
	Events.sector_entered.disconnect(_on_sector_entered)
	Events.great_storage_reached.disconnect(_on_great_storage_reached)
	Events.debug_invincibility_changed.emit(false)
	# Tur havuzdan önce silinir (oyunda da World, ChunkPools'tan önce gelir).
	if is_instance_valid(_run):
		remove_child(_run)
		_run.free()
	Progression.reset()


func test_reaching_overflow_plays_the_finale_once() -> void:
	_start(5)
	var player: Player = _run.get_node("%Player") as Player
	var effects: Effects = _run.get_node("%Effects") as Effects
	var camera: GameCamera = _run.get_node("%GameCamera") as GameCamera
	await _frames(SETTLE_FRAMES)
	var nodes: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	assert_bool(Progression.owns_trail(GREAT_STORAGE_TRAIL)).is_false()
	var entry: int = -1
	for frame: int in ceili((SHORT_LENGTH / SECTORS.def_at(5).climb_speed + 2.0) / DT):
		await get_tree().physics_frame
		if entry < 0 and _run.sector == 6:
			entry = frame
			# Patlama girişin adımında, oyuncunun yerinde, her yayıcı bir paletin renginde.
			var colors: Array[Color] = []
			for palette: SectorPalette in _run.sectors.palettes():
				colors.append(palette.ambient)
			var finale: Array[CPUParticles2D] = effects.finale_emitters()
			for i: int in finale.size():
				assert_bool(finale[i].emitting).is_true()
				assert_vector(finale[i].global_position).is_equal_approx(
						player.global_position, Vector2.ONE * 0.01)
				assert_that(finale[i].color_ramp.colors[1]).is_equal(colors[i % colors.size()])
			assert_float(camera.trauma()).is_greater(0.0)
	assert_int(entry).override_failure_message("Taşma'ya girilmedi").is_greater_equal(0)
	assert_array(_finale_frames).has_size(1)
	assert_int(_finale_frames[0]).is_equal(_sector_frames[6])
	# Yayıcılar oyuncuyla taşındı (2 sn sonra hâlâ onun yerinde).
	for emitter: CPUParticles2D in effects.finale_emitters():
		assert_vector(emitter.global_position).is_equal_approx(
				player.global_position, Vector2.ONE * 0.01)
	assert_bool(Progression.owns_trail(GREAT_STORAGE_TRAIL)).is_true()
	# Tur sırasında dosya yazılmaz (finalin karesi kısa kalsın); kayıt tur sonunda.
	assert_bool(SaveManager.load_game()["great_storage_reached"]).is_false()
	assert_float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)).is_equal(nodes)
	assert_int((_run.get_node("%ChunkSpawner") as ChunkSpawner).pools_grown()).is_equal(0)


func test_starting_in_overflow_has_no_finale() -> void:
	_start(6)
	await _frames(120)
	assert_int(_run.sector).is_equal(6)
	assert_array(_finale_frames).is_empty()
	assert_bool(Progression.owns_trail(GREAT_STORAGE_TRAIL)).is_false()


## Taşma'da palet her SHORT_CYCLE m'de dalgayla sıradakine geçer; döngünün bütün paletleri birer
## kez görünür ve başa sarar. Hız ve çöküş duvarının sürünmesi değişmez.
func test_overflow_cycles_palettes_at_constant_speed() -> void:
	_start(6)
	var player: Player = _run.get_node("%Player") as Player
	var corridor: Corridor = _run.get_node("%Corridor") as Corridor
	var background: Background = _run.get_node("%Background") as Background
	var def: SectorDef = _run.sectors.def_at(6)
	var steps: int = def.palette_cycle.size() + 1
	await _frames(SETTLE_FRAMES)
	assert_bool(corridor.ambient().is_equal_approx(def.palette_at(0).ambient)).is_true()
	var seen: Array[SectorPalette] = [def.palette_at(0)]
	var previous_step: int = 0
	var previous_y: float = player.position.y
	var step_px: float = def.climb_px() * DT
	for frame: int in ceili((steps * SHORT_CYCLE + 20.0) / def.climb_speed / DT):
		await get_tree().physics_frame
		assert_float(previous_y - player.position.y).is_equal_approx(step_px, 0.002)
		previous_y = player.position.y
		var step: int = _run.palette_step()
		if step == previous_step:
			continue
		# Yeni adım: dalga başladı; bir önceki palet dalga bitmeden önce tamamen gelmişti.
		assert_int(step).is_equal(previous_step + 1)
		assert_bool(background.is_wave_active()).is_true()
		seen.append(def.palette_at(step))
		previous_step = step
	assert_int(previous_step).is_equal(steps)
	# Bütün paletler göründü, son adım başa sardı.
	assert_object(seen[steps]).is_same(seen[0])
	var cycle: Array[SectorPalette] = def.palette_cycle.duplicate()
	cycle.append(def.palette)
	assert_array(seen.slice(0, steps)).contains_exactly_in_any_order(cycle)
	await _frames(roundi(Neon.STYLE.wave_time / DT) + 2)
	assert_bool(corridor.ambient().is_equal_approx(def.palette_at(steps).ambient)).is_true()
	assert_int(_run.sector).is_equal(6)
	assert_array(_finale_frames).is_empty()


## Turu kısa sektörlerle ve kısa palet adımıyla, ölümsüz oyuncuyla kurar.
func _start(sector: int) -> void:
	_pools = auto_free(ChunkPools.new()) as ChunkPools
	add_child(_pools)
	_run = RUN_SCENE.instantiate() as Run
	_run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	var sectors: SectorCatalog = SectorCatalog.new()
	for i: int in SECTORS.count():
		var def: SectorDef = SECTORS.def_at(i + 1).duplicate() as SectorDef
		def.length = SHORT_LENGTH
		def.palette_cycle_length = SHORT_CYCLE
		sectors.sectors.append(def)
	_run.sectors = sectors
	_run.run_seed = 77
	_run.start_sector = sector
	_run.chunk_pools = _pools
	add_child(_run)
	Events.debug_invincibility_changed.emit(true)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _on_sector_entered(index: int) -> void:
	_sector_frames[index] = Engine.get_physics_frames()


func _on_great_storage_reached() -> void:
	_finale_frames.append(Engine.get_physics_frames())
