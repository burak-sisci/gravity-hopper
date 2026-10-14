extends GdUnitTestSuite
## Turdaki görsel his (M3-11, architecture.md §9): iniş bir kez bildirilir ve kıvılcım çıkar,
## çevirmede ve inişte yalnızca görsel esner (çarpışma şekilleri değişmez), Glimmer toplandığı
## yerde patlar, ölüm donmasının sonunda çekirdek gizlenip patlar. Çevirme, iniş, Glimmer ve ölüm
## dolu bir turda düğüm sayısı sabittir (.clauderules §6).
## Hız hissi (M3-13): S3'te iz S1'dekinden uzun, hız çizgileri daha çok.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SETTLE_FRAMES: int = 40
## İlk desen parçası 28,8 m ileride: oyuncu ondan önce (≈ 140 kare) tehlikesiz duvardadır.
const REST_FRAMES: int = 90
const TRANSIT_FRAMES: int = 40
## Duvarın iç kenarı (koridor 18 m → yarısı 9 m = 450 px).
const WALL_EDGE_X: float = 450.0
## Fizik motorunun duvar payı (safe_margin) kadar sapma.
const POSITION_TOLERANCE: float = 0.5

var _run: Run
var _player: Player
var _landings: Array[Vector2] = []
var _sides: Array[float] = []


func after_test() -> void:
	_landings.clear()
	_sides.clear()
	Events.debug_invincibility_changed.emit(false)


func test_landing_is_reported_once_per_arrival() -> void:
	await _start_run()
	# Oyuncu tur başında koridorun ortasından sol duvara iner.
	assert_int(_landings.size()).is_equal(1)
	assert_float(_landings[0].x).is_equal_approx(-WALL_EDGE_X, POSITION_TOLERANCE)
	assert_array(_sides).is_equal([-1.0])
	# Duvarda kayarken (parça birleşim yerleri dahil) yeni iniş sayılmaz.
	await _frames(REST_FRAMES)
	assert_int(_landings.size()).is_equal(1)
	_tap()
	await _frames(TRANSIT_FRAMES)
	assert_int(_landings.size()).is_equal(2)
	assert_float(_landings[1].x).is_equal_approx(WALL_EDGE_X, POSITION_TOLERANCE)
	assert_float(_sides[1]).is_equal(1.0)
	# Kıvılcım yayıcısı değilen noktada.
	var spark: CPUParticles2D = (_run.get_node("%Effects") as Effects).emitters()[1]
	assert_vector(spark.global_position).is_equal(_landings[1])


func test_flip_and_landing_deform_only_the_visual() -> void:
	await _start_run()
	var visual: Node2D = _player.get_node("Visual") as Node2D
	var body: Vector2 = (_shape("Body") as RectangleShape2D).size
	var hurt: Vector2 = (_shape("Hurtbox/Shape") as RectangleShape2D).size
	_tap()
	await _frames(3)
	assert_float(visual.scale.x).is_greater(1.0)
	assert_float(visual.scale.y).is_less(1.0)
	await _frames(TRANSIT_FRAMES)
	assert_int(_landings.size()).is_equal(2)
	await _frames(60)
	assert_vector(visual.scale).is_equal(Vector2.ONE)
	assert_vector(visual.position).is_equal(Vector2.ZERO)
	assert_vector(_player.scale).is_equal(Vector2.ONE)
	assert_vector((_shape("Body") as RectangleShape2D).size).is_equal(body)
	assert_vector((_shape("Hurtbox/Shape") as RectangleShape2D).size).is_equal(hurt)


func test_glimmer_bursts_where_it_was_collected() -> void:
	await _start_run()
	var at: Vector2 = Vector2(120.0, _player.position.y - 300.0)
	(_run.get_node("%ChunkSpawner") as ChunkSpawner).glimmer_collected.emit(1, at)
	var burst: CPUParticles2D = (_run.get_node("%Effects") as Effects).emitters()[
			Effects.SPARK_EMITTERS]
	assert_vector(burst.global_position).is_equal(at)
	assert_bool(burst.emitting).is_true()


func test_core_shatters_when_the_death_freeze_ends() -> void:
	await _start_run()
	var visual: Node2D = _player.get_node("Visual") as Node2D
	var death: CPUParticles2D = (_run.get_node("%Effects") as Effects).emitters().back()
	_player.die(GameTypes.DeathCause.WALL)
	await _frames(2)
	assert_bool(visual.visible).is_true()
	assert_bool(death.emitting).is_false()
	await _frames(roundi(_run.tuning.death_freeze * Engine.physics_ticks_per_second) + 2)
	assert_bool(visual.visible).is_false()
	assert_bool(death.emitting).is_true()
	assert_vector(death.global_position).is_equal(_player.global_position)


func test_node_count_stays_constant_during_a_run() -> void:
	var pools: ChunkPools = auto_free(ChunkPools.new()) as ChunkPools
	add_child(pools)
	await _start_run(pools)
	# Ölümsüz: tur parçalara ve tehlikelere kadar sürer.
	Events.debug_invincibility_changed.emit(true)
	var nodes: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var spawner: ChunkSpawner = _run.get_node("%ChunkSpawner") as ChunkSpawner
	for i: int in 8:
		_tap()
		await _frames(TRANSIT_FRAMES)
		spawner.glimmer_collected.emit(1, _player.position + Vector2(0.0, -200.0))
	Events.debug_invincibility_changed.emit(false)
	_player.die(GameTypes.DeathCause.WALL)
	await _frames(30)
	assert_int(_landings.size()).is_greater_equal(9)
	assert_bool(_player.is_alive()).is_false()
	assert_float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)).is_equal(nodes)
	assert_int(spawner.pools_grown()).is_equal(0)
	# Tur havuzdan önce silinir (oyunda da World, ChunkPools'tan önce gelir).
	remove_child(_run)
	_run.free()


func test_faster_sector_longer_trail_and_more_speed_lines() -> void:
	await _start_run()
	var s1: Array[int] = _speed_feel()
	remove_child(_run)
	_run.free()
	await _start_run(null, 3)
	var s3: Array[int] = _speed_feel()
	assert_int(s3[0]).override_failure_message("İz uzamadı").is_greater(s1[0])
	assert_int(s3[1]).override_failure_message("Hız çizgisi artmadı").is_greater(s1[1])


## İzin adım sayısı ve görünen hız çizgisi sayısı.
func _speed_feel() -> Array[int]:
	var lines: SpeedLines = _run.get_node("%Background").get_node("%SpeedLines") as SpeedLines
	return [(_player.get_node("Trail") as Trail).tick_count(), lines.active_count()]


## Diskteki varsayılan ayarların taze bir kopyasıyla tur kurar (paylaşılan örnek değişmez).
func _start_run(pools: ChunkPools = null, sector: int = 1) -> void:
	_run = RUN_SCENE.instantiate() as Run
	if pools == null:
		auto_free(_run)
	_run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	_run.run_seed = 12345
	_run.start_sector = sector
	_run.chunk_pools = pools
	_player = _run.get_node("Player") as Player
	_player.landed.connect(_on_landed)
	add_child(_run)
	await _frames(SETTLE_FRAMES)


func _shape(path: String) -> Shape2D:
	return (_player.get_node(path) as CollisionShape2D).shape


func _on_landed(at: Vector2, side: float) -> void:
	_landings.append(at)
	_sides.append(side)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _tap() -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.pressed = true
	event.position = Vector2(540, 1200)
	get_tree().root.push_input(event, true)
