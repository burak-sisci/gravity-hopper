extends GdUnitTestSuite
## Çöküş duvarı (M2-15, architecture.md §8.4): sürünme, itme/çekme, duvar ölümü; gerçek turda
## görselin yeri, yakınlık yayını, Glimmer ve kıl payı itmesi.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
const GLIMMER_SCENE: PackedScene = preload("res://scenes/entities/glimmer.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const DT: float = 1.0 / 60.0

var _deaths: Array[GameTypes.DeathCause] = []
var _proximities: Array[float] = []


func before_test() -> void:
	_deaths.clear()
	_proximities.clear()
	Events.player_died.connect(_on_player_died)
	Events.wall_proximity_changed.connect(_on_proximity)


func after_test() -> void:
	Events.player_died.disconnect(_on_player_died)
	Events.wall_proximity_changed.disconnect(_on_proximity)
	Events.debug_invincibility_changed.emit(false)


func test_creep_push_pull_and_reach() -> void:
	var pressure: PressureSystem = auto_free(PressureSystem.new()) as PressureSystem
	var reached: Array[bool] = []
	pressure.wall_reached.connect(func() -> void: reached.append(true))
	pressure.setup(20.0, 30.0, 0.3)
	for i: int in 60:
		pressure.advance(DT)
	assert_float(pressure.distance_m).is_equal_approx(19.7, 0.0001)
	pressure.push(50.0)
	assert_float(pressure.distance_m).is_equal(30.0)
	pressure.pull(8.0)
	assert_float(pressure.distance_m).is_equal(22.0)
	pressure.pull(30.0)
	assert_float(pressure.distance_m).is_equal(0.0)
	pressure.advance(DT)
	pressure.pull(1.0)
	assert_array(reached).is_equal([true])


func test_wall_catches_a_slow_player() -> void:
	var run: Run = _start(10.0, [])
	var player: Node2D = run.get_node("%Player") as Node2D
	var wall: Node2D = run.get_node("%CollapseWall") as Node2D
	var pressure: PressureSystem = run.get_node("%PressureSystem") as PressureSystem
	# Görsel ilk karesinden yerinde (M3-10): tur kurulur kurulmaz, fizik adımı beklemeden.
	assert_float(wall.position.y - player.position.y).is_equal_approx(
			TuningConfig.to_px(pressure.distance_m), 0.5)
	await _frames(30)
	# Görsel, oyuncunun mesafe × 50 px altında.
	assert_float(wall.position.y - player.position.y).is_equal_approx(
			TuningConfig.to_px(pressure.distance_m), 0.5)
	var step: int = (wall as CollapseWall).glitch_step()
	# 20 m ÷ 10 m/sn = 2 sn.
	await _frames(110)
	# Glitch deseni müziğin vuruşuyla değişiyor (M3-09; Run vuruşu verir).
	assert_int((wall as CollapseWall).glitch_step()).is_not_equal(step)
	assert_array(_deaths).is_equal([GameTypes.DeathCause.WALL])
	assert_float(_proximities.back()).is_equal_approx(1.0, 0.0001)
	# Yakınlık duvar yaklaştıkça artar.
	for i: int in range(1, _proximities.size()):
		assert_float(_proximities[i]).is_greater_equal(_proximities[i - 1])


func test_invincible_player_is_not_caught() -> void:
	var run: Run = _start(10.0, [])
	Events.debug_invincibility_changed.emit(true)
	await _frames(200)
	assert_array(_deaths).is_empty()
	assert_bool((run.get_node("%Player") as Player).is_alive()).is_true()


func test_glimmer_pushes_the_wall() -> void:
	var run: Run = _start(0.0, [Vector2(-400, -200)])
	var pressure: PressureSystem = run.get_node("%PressureSystem") as PressureSystem
	var collected: Array[int] = []
	Events.glimmer_collected.connect(func(value: int) -> void: collected.append(value))
	for i: int in 300:
		await get_tree().physics_frame
		if not collected.is_empty():
			break
	assert_int(collected.size()).is_equal(1)
	assert_float(pressure.distance_m).is_equal_approx(21.0, 0.0001)


func test_near_miss_pushes_the_wall() -> void:
	var run: Run = _start(0.0, [])
	var player: Node2D = run.get_node("%Player") as Node2D
	var pressure: PressureSystem = run.get_node("%PressureSystem") as PressureSystem
	await _frames(40)
	var hazard: Area2D = Area2D.new()
	hazard.collision_layer = 4
	hazard.collision_mask = 0
	hazard.monitoring = false
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	hazard.add_child(shape)
	hazard.position = player.position + Vector2(60, -200)
	run.add_child(hazard)
	await _frames(60)
	assert_float(pressure.distance_m).is_equal_approx(23.0, 0.0001)


## Sürünmesi creep m/sn olan S1 kopyasıyla ve verilen Glimmer'lı tek parçayla tur kurar.
func _start(creep: float, glimmers: Array[Vector2]) -> Run:
	var run: Run = auto_free(RUN_SCENE.instantiate()) as Run
	run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	run.run_seed = 8
	var sectors: SectorCatalog = SectorCatalog.new()
	var def: SectorDef = SECTORS.def_at(1).duplicate() as SectorDef
	def.wall_creep = creep
	sectors.sectors.append(def)
	run.sectors = sectors
	var root: ChunkInfo = ChunkInfo.new()
	root.length_beats = 6
	for at: Vector2 in glimmers:
		var glimmer: Glimmer = GLIMMER_SCENE.instantiate() as Glimmer
		glimmer.position = at
		root.add_child(glimmer)
		glimmer.owner = root
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	var library: ChunkLibrary = ChunkLibrary.new()
	library.chunks = [scene]
	(run.get_node("%ChunkSpawner") as ChunkSpawner).library = library
	add_child(run)
	return run


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _on_player_died(cause: GameTypes.DeathCause) -> void:
	_deaths.append(cause)


func _on_proximity(ratio: float) -> void:
	_proximities.append(ratio)
