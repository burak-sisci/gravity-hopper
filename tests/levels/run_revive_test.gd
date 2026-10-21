extends GdUnitTestSuite
## İkinci Şans turda (M4-07, architecture.md §7.3): hak varsa ölüm turu bitirmez, GameManager kısa
## bir bekleyişten sonra dirilişi duyurur ve oyuncu kaldığı yerde canlanır. Ölümde saat durur:
## oyuncu ile vuruş ızgarası ölümde de dirilişten sonra da aynı yerdedir (müzik kaldığı yerden).
## Yakındaki tehlikeler temizlenir, çöküş duvarı geri itilir, dokunulmazlık gelir; ikinci ölüm
## turu bitirir; tur sırasında düğüm oluşmaz. Dokunuşsuz oyuncu, GameManager gerçek.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const RUN_SEED: int = 77
const GAP_SEED: int = 4
const MAX_FRAMES: int = 1800
const SETTLE_FRAMES: int = 20
## Oyuncunun yeri ile vuruş saatinin tırmanışı arasındaki izinli fark (px; kayan nokta birikimi).
const SYNC_TOLERANCE: float = 0.05

var _run: Run
var _player: Player
var _start_y: float = 0.0
var _deaths: Array[GameTypes.DeathCause] = []
var _revived: int = 0
var _results: Array[RunResult] = []


func before_test() -> void:
	_deaths.clear()
	_revived = 0
	_results.clear()
	Progression.reset()
	Events.player_died.connect(_on_player_died)
	Events.player_revived.connect(_on_player_revived)
	Events.run_ended.connect(_on_run_ended)


func after_test() -> void:
	Events.player_died.disconnect(_on_player_died)
	Events.player_revived.disconnect(_on_player_revived)
	Events.run_ended.disconnect(_on_run_ended)
	# Bekleyen bir diriliş ya da süren tur sonraki testlere taşmasın.
	GameManager.change_state(GameManager.AppState.BOOT)
	Progression.reset()


func test_revive_continues_the_run_and_the_second_death_ends_it() -> void:
	_start(1, null)
	await _frames(SETTLE_FRAMES)
	var nodes: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	await _until(func() -> bool: return not _deaths.is_empty())
	assert_array(_deaths).is_equal([GameTypes.DeathCause.HAZARD])
	assert_array(_results).is_empty()
	assert_int(GameManager.revives_left()).is_equal(0)
	_assert_on_grid()
	var death_y: float = _player.position.y
	var death_height: int = _height()
	await _until_revived()
	assert_bool(_player.is_alive()).is_true()
	assert_bool(_player.is_protected()).is_true()
	assert_float(_player.position.y).is_equal(death_y)
	_assert_on_grid()
	# Önündeki ve hemen altındaki tehlikeler temizlendi (öldüren de); ötekiler yerinde.
	await get_tree().physics_frame
	assert_int(_check_cleared(death_y)).is_greater(0)
	# Dokunulmazlıkta ölüm yok; tur vuruş ızgarasında sürüyor.
	await _frames(roundi(_run.tuning.revive_grace * Engine.physics_ticks_per_second) - 2)
	assert_int(_deaths.size()).is_equal(1)
	assert_bool(_player.is_alive()).is_true()
	assert_int(_height()).is_greater(death_height)
	_assert_on_grid()
	# İkinci ölüm turu bitirir; yeni diriliş yok.
	await _until(func() -> bool: return _deaths.size() == 2)
	assert_int(_results.size()).is_equal(1)
	await _frames(_delay_frames() + 10)
	assert_int(_revived).is_equal(1)
	assert_int(_results.size()).is_equal(1)
	assert_int(_results[0].height_m).is_greater(death_height)
	assert_float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)).is_equal(nodes)
	_free_run()


## Düşülen adımda oyuncu tırmanmaz, saat de ilerlemez: dirilişten sonra ızgaradaki yerindedir ve
## duvar çizgisine geri konur; dokunulmazlıkta boşlukta düşmez.
func test_fall_revive_puts_the_player_back_on_the_wall_line() -> void:
	var library: ChunkLibrary = ChunkLibrary.new()
	library.chunks = [_gap_chunk()]
	_start(1, library)
	await _until(func() -> bool: return not _deaths.is_empty())
	assert_array(_deaths).is_equal([GameTypes.DeathCause.FELL])
	_assert_on_grid()
	var half_width: float = TuningConfig.to_px(_run.tuning.corridor_width) * 0.5
	assert_float(absf(_player.position.x)).is_greater(half_width)
	await _until_revived()
	assert_float(absf(_player.position.x)).is_less(half_width)
	_assert_on_grid()
	await _frames(roundi(_run.tuning.revive_grace * Engine.physics_ticks_per_second) - 2)
	assert_int(_deaths.size()).is_equal(1)
	_assert_on_grid()
	await _until(func() -> bool: return _deaths.size() == 2)
	assert_int(_results.size()).is_equal(1)
	_free_run()


## Çöküş duvarına yakalanan oyuncu dirilince duvar revive_wall_distance'a geri itilir ve tur sürer.
func test_wall_death_revive_pushes_the_wall_back() -> void:
	_start(1, null)
	await _frames(SETTLE_FRAMES)
	var pressure: PressureSystem = _run.get_node("%PressureSystem") as PressureSystem
	pressure.pull(_run.tuning.wall_max_distance * 2.0)
	assert_array(_deaths).is_equal([GameTypes.DeathCause.WALL])
	await _until_revived()
	assert_float(pressure.distance_m).is_equal(_run.tuning.revive_wall_distance)
	await _frames(SETTLE_FRAMES)
	assert_int(_deaths.size()).is_equal(1)
	assert_float(pressure.distance_m).is_greater(_run.tuning.revive_wall_distance - 1.0)
	# Duvar yine yakalayabilir: ikinci yakalanma turu bitirir.
	pressure.pull(_run.tuning.wall_max_distance * 2.0)
	assert_array(_deaths).is_equal([GameTypes.DeathCause.WALL, GameTypes.DeathCause.WALL])
	assert_int(_results.size()).is_equal(1)
	_free_run()


func test_without_a_revive_the_first_death_ends_the_run() -> void:
	_start(0, null)
	await _until(func() -> bool: return not _deaths.is_empty())
	assert_int(_results.size()).is_equal(1)
	await _frames(_delay_frames() + 10)
	assert_int(_revived).is_equal(0)
	assert_bool(_player.is_alive()).is_false()
	_free_run()


## Dokunuşsuz bir tur kurar (sabit tohum) ve GameManager'a başlatır; library null ise gerçek
## parça kütüphanesi.
func _start(revives: int, library: ChunkLibrary) -> void:
	_run = RUN_SCENE.instantiate() as Run
	_run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	_run.run_seed = RUN_SEED if library == null else GAP_SEED
	var loadout: RunLoadout = RunLoadout.new()
	loadout.revives = revives
	_run.loadout = loadout
	if library != null:
		(_run.get_node("%ChunkSpawner") as ChunkSpawner).library = library
	_player = _run.get_node("%Player") as Player
	add_child(_run)
	_start_y = _player.position.y
	GameManager.begin_run(_run.run_seed, 1, loadout)


## Oyuncu, turun başından beri vuruş saati kadar tırmanmış yerdedir (S1, sıçrama yok).
func _assert_on_grid() -> void:
	var climbed: float = _start_y - _player.position.y
	var expected: float = _run.sectors.def_at(1).climb_px() * _conductor().run_time
	assert_float(absf(climbed - expected)).override_failure_message(
			"tırmanış %.2f px, saate göre %.2f px" % [climbed, expected]).is_less(SYNC_TOLERANCE)


## Diriliş gelene dek bekler; bu sürede saat ve oyuncu yerinde durur. Bekleyiş anında değildir.
func _until_revived() -> void:
	var time: float = _conductor().run_time
	var y: float = _player.position.y
	var waited: int = 0
	while _revived == 0 and waited < MAX_FRAMES:
		await get_tree().physics_frame
		waited += 1
		if _revived == 0:
			assert_float(_conductor().run_time).is_equal(time)
			assert_float(_player.position.y).is_equal(y)
	assert_int(_revived).is_equal(1)
	assert_int(waited).is_greater_equal(_delay_frames() - 2)
	assert_array(_results).is_empty()


## Temizlenmesi gereken her tehlike temizlenmiş (gizli, çarpışmaya kapalı), ötekiler yerinde;
## temizlenenlerin sayısı döner.
func _check_cleared(death_y: float) -> int:
	var ahead: float = _run.sectors.def_at(1).climb_px() * _run.tuning.revive_clear_time
	var behind: float = TuningConfig.to_px(_run.tuning.revive_clear_behind)
	var cleared: int = 0
	for chunk: ChunkInfo in _spawner().active_chunks():
		for item: Node2D in chunk.items():
			if not item is Area2D or item is Glimmer:
				continue
			var y: float = chunk.position.y + item.position.y
			var inside: bool = y >= death_y - ahead and y <= death_y + behind
			assert_bool(chunk.is_cleared(item)).override_failure_message(
					"%s (y %.0f, ölüm %.0f) temizlenme: %s bekleniyordu" % [
						item.name, y, death_y, inside,
					]).is_equal(inside)
			assert_bool(item.visible).is_equal(not inside)
			assert_bool((item as Area2D).monitorable).is_equal(not inside)
			if inside:
				cleared += 1
	return cleared


func _height() -> int:
	return floori((_start_y - _player.position.y) / TuningConfig.PX_PER_M)


func _delay_frames() -> int:
	return roundi(GameManager.AUTO_REVIVE_DELAY * Engine.physics_ticks_per_second)


## 8 vuruşluk parça; sol duvarda 1. vuruştan 5. vuruşa boşluk (player_fall_test'teki gibi).
func _gap_chunk() -> PackedScene:
	var root: ChunkInfo = ChunkInfo.new()
	root.length_beats = 8
	var gap: WallGap = WallGap.new()
	gap.position = Vector2(-450, -100)
	gap.length = 400.0
	root.add_child(gap)
	gap.owner = root
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _until(condition: Callable) -> void:
	var frames: int = 0
	while not condition.call() and frames < MAX_FRAMES:
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


func _on_player_revived() -> void:
	_revived += 1


func _on_run_ended(result: RunResult) -> void:
	_results.append(result)
