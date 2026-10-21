extends GdUnitTestSuite
## Başlangıç Sıçraması turda (M4-06, architecture.md §8.1): ek yol seviyeyle büyür ve tam vuruşa
## yuvarlanır; sıçramada ölüm ve kıl payı yok, geçilen Glimmer'lar toplanır; sıçramadan sonra
## dikenler yine yarım vuruşta geçilir; harita aynı kalır, tur sırasında düğüm oluşmaz ve havuz
## büyümez (.clauderules §6). Gerçek parça kütüphanesi, dokunuşsuz oyuncu.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const DT: float = 1.0 / 60.0
const RUN_SEED: int = 77
## Sıçrama en uzun seviyede ≈ 6 sn sürer.
const MAX_FRAMES: int = 1200
const BEAT_FRAMES: int = 900
const MAP_FRAMES: int = 900
const SETTLE_FRAMES: int = 40
## Sıçramanın sonunda oyuncunun bu kadar altındaki (px) Glimmer'lar toplanmış olmalı.
const SWEPT_MARGIN: float = 50.0

var _run: Run
var _player: Player
var _start_y: float = 0.0
var _deaths: Array[GameTypes.DeathCause] = []
var _dash_events: Array[bool] = []
## Sayılmış Glimmer'lar: örnek kimliği @ parçanın yeri.
var _swept: Dictionary[String, bool] = {}


func before_test() -> void:
	_deaths.clear()
	_dash_events.clear()
	_swept.clear()
	Events.player_died.connect(_on_player_died)
	Events.head_start_changed.connect(_on_head_start_changed)


func after_test() -> void:
	Events.player_died.disconnect(_on_player_died)
	Events.head_start_changed.disconnect(_on_head_start_changed)
	Events.debug_invincibility_changed.emit(false)


func test_dash_grows_with_level_and_is_safe() -> void:
	var previous: float = 0.0
	for level: int in [1, 3, 5]:
		var head_start_m: float = CATALOG.get_def(&"head_start").value_at(level)
		_dash_events.clear()
		_start(head_start_m, null)
		assert_array(_dash_events).is_empty()
		# Her adımda: oyuncunun geçtiği her Glimmer toplanmış (öbür duvarın yanındakiler de).
		var passed: int = 0
		while _run.is_dashing():
			await get_tree().physics_frame
			passed += _count_swept()
		assert_array(_deaths).is_empty()
		assert_array(_dash_events).is_equal([true, false])
		assert_int(_run.stats.near_misses).is_equal(0)
		assert_bool(_player.is_protected()).is_true()
		# Ek yol: sıçramanın sonundaki yükseklik − aynı sürede normal tırmanış; tam vuruşa yuvarlı.
		var speed: float = _run.sectors.def_at(1).climb_speed
		var beat: float = _conductor().beat_length()
		var climbed_m: float = (_start_y - _player.position.y) / TuningConfig.PX_PER_M
		var extra_m: float = climbed_m - speed * _conductor().run_time
		assert_float(extra_m).is_between(
				head_start_m - speed * beat * 0.5, head_start_m + speed * beat * 0.5)
		var beats: float = extra_m / (speed * beat)
		assert_float(absf(beats - roundf(beats))).is_less(0.001)
		assert_float(extra_m).is_greater(previous)
		previous = extra_m
		assert_int(passed).is_greater(0)
		assert_int(_run.stats.glimmers).is_greater_equal(passed)
		# Dokunulmazlık biter.
		await _frames(roundi(_run.tuning.head_start_grace / DT) + 1)
		assert_bool(_player.is_protected()).is_false()
		_free_run()


func test_spikes_pass_on_half_beats_after_the_dash() -> void:
	_start(CATALOG.get_def(&"head_start").value_at(1), null)
	Events.debug_invincibility_changed.emit(true)
	await _until_dash_ends()
	var conductor: Conductor = _conductor()
	var half_beat: float = conductor.beat_length() * 0.5
	var passes: int = 0
	var previous_y: float = _player.position.y
	for frame: int in BEAT_FRAMES:
		await get_tree().physics_frame
		for chunk: ChunkInfo in _spawner().active_chunks():
			for item: Node2D in chunk.items():
				if item is Glimmer:
					continue
				var y: float = chunk.position.y + item.position.y
				if previous_y > y and _player.position.y <= y:
					passes += 1
					var off: float = absf(conductor.run_time
							- roundf(conductor.run_time / half_beat) * half_beat)
					assert_float(off).override_failure_message(
							"%s %.3f sn'de geçti, yarım vuruştan %.3f sn uzak" % [
								item.name, conductor.run_time, off,
							]).is_less_equal(DT + 0.0001)
		previous_y = _player.position.y
	assert_int(passes).is_greater(10)
	_free_run()


func test_map_unchanged_and_no_nodes_created() -> void:
	_start(0.0, null)
	Events.debug_invincibility_changed.emit(true)
	await _frames(MAP_FRAMES)
	var plain: Array[StringName] = _spawner().placed_names.duplicate()
	_free_run()
	var pools: ChunkPools = auto_free(ChunkPools.new()) as ChunkPools
	add_child(pools)
	_start(CATALOG.get_def(&"head_start").value_at(5), pools)
	Events.debug_invincibility_changed.emit(true)
	await _frames(SETTLE_FRAMES)
	var nodes: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	await _until_dash_ends()
	await _frames(SETTLE_FRAMES)
	assert_float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)).is_equal(nodes)
	assert_int(_spawner().pools_grown()).is_equal(0)
	var dashed: Array[StringName] = _spawner().placed_names
	assert_int(dashed.size()).is_greater(plain.size())
	assert_array(dashed.slice(0, plain.size())).is_equal(plain)
	# Tur havuzdan önce silinir (oyunda da World, ChunkPools'tan önce gelir).
	_free_run()


## Dokunuşsuz bir tur başlatır (gerçek parça kütüphanesi, sabit tohum); head_start_m 0 ise
## sıçrama yok.
func _start(head_start_m: float, pools: ChunkPools) -> void:
	_run = RUN_SCENE.instantiate() as Run
	_run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	_run.run_seed = RUN_SEED
	_run.chunk_pools = pools
	var loadout: RunLoadout = RunLoadout.new()
	loadout.head_start_m = head_start_m
	_run.loadout = loadout
	_player = _run.get_node("%Player") as Player
	add_child(_run)
	_start_y = _player.position.y


## Bu adımda oyuncunun geçtiği (SWEPT_MARGIN altında kalan) yeni Glimmer'ların sayısı; her biri
## toplanmış olmalı. Havuzdan dönen parçanın Glimmer'ı yeni yerinde yeniden sayılır.
func _count_swept() -> int:
	var count: int = 0
	for chunk: ChunkInfo in _spawner().active_chunks():
		for item: Node2D in chunk.items():
			if not item is Glimmer or item.global_position.y <= _player.position.y + SWEPT_MARGIN:
				continue
			var key: String = "%d@%d" % [item.get_instance_id(), roundi(chunk.position.y)]
			if _swept.has(key):
				continue
			_swept[key] = true
			count += 1
			assert_bool((item as Glimmer).is_taken()).override_failure_message(
					"%s (x %.0f) geçildi ama toplanmadı" % [item.name, item.global_position.x]) 					.is_true()
	return count


func _until_dash_ends() -> void:
	var frames: int = 0
	while _run.is_dashing() and frames < MAX_FRAMES:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES)


func _conductor() -> Conductor:
	return _run.get_node("%Conductor") as Conductor


func _spawner() -> ChunkSpawner:
	return _run.get_node("%ChunkSpawner") as ChunkSpawner


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _free_run() -> void:
	remove_child(_run)
	_run.free()


func _on_player_died(cause: GameTypes.DeathCause) -> void:
	_deaths.append(cause)


func _on_head_start_changed(active: bool) -> void:
	_dash_events.append(active)
