extends GdUnitTestSuite
## Oyuncu hareketi ve girdi kuralları (M1-04, M1-05; architecture.md §8.1). M1'in geçici deneme
## betiklerinden taşındı (M2-02). Testler --fixed-fps 60 ile koşar: her karede bir fizik adımı.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
## Oyuncunun başlangıçta sol duvara yerleşmesi için beklenen kare sayısı.
const SETTLE_FRAMES: int = 40
## `await physics_frame` adım işlenmeden önce döner; dokunuşun etkisi için iki kare beklenir.
const INPUT_SETTLE_FRAMES: int = 2
## Oyuncu merkezinin duvara yaslanınca durduğu x: duvar iç kenarı (9 m = 450 px) − gövde yarısı.
const WALL_X: float = 420.0
const MAX_TRANSIT_FRAMES: int = 120

var _run: Run
var _player: Player


func test_settles_on_left_wall() -> void:
	await _start_run()
	assert_bool(_player.is_on_wall()).is_true()
	assert_float(_player.position.x).is_equal_approx(-WALL_X, 0.5)
	assert_bool(_player.is_gravity_right()).is_false()


func test_climb_speed_is_exact() -> void:
	# Engeller vuruş ızgarasına göre yerleşir; tırmanış duvarda da havada da tam sabit olmalı.
	await _start_run()
	var start_y: float = _player.position.y
	_tap()
	await _frames(60)
	assert_float(start_y - _player.position.y).is_equal_approx(600.0, 0.01)


func test_tap_on_wall_flips_to_other_wall() -> void:
	await _start_run()
	_tap()
	await _frames(INPUT_SETTLE_FRAMES)
	assert_bool(_player.is_gravity_right()).is_true()
	await _frames_until_on_wall()
	assert_float(_player.position.x).is_equal_approx(WALL_X, 0.5)


func test_fast_double_tap_goes_and_comes_back() -> void:
	await _start_run()
	_tap()
	await _frames(INPUT_SETTLE_FRAMES + 4)
	# Geçişin başındaki ikinci dokunuş saklanır (tampon geçişten uzun) ve inişte uygulanır:
	# oyuncu sağ duvara varıp hemen sola döner (ADR-036).
	_tap()
	await _frames_until_on_wall()
	await _frames(INPUT_SETTLE_FRAMES)
	assert_bool(_player.is_gravity_right()).is_false()
	await _frames_until_on_wall()
	assert_float(_player.position.x).is_equal_approx(-WALL_X, 0.5)


func test_tap_just_before_landing_is_buffered() -> void:
	await _start_run()
	var transit: int = await _measure_transit()
	_tap()
	await _frames(transit - 4)
	_tap()
	await _frames_until_on_wall()
	await _frames(1)
	# İnişte uygulanan çevirme oyuncuyu hemen geri, sağa gönderir.
	assert_bool(_player.is_gravity_right()).is_true()
	await _frames_until_on_wall()
	assert_float(_player.position.x).is_equal_approx(WALL_X, 0.5)


func test_tap_outside_buffer_window_is_dropped() -> void:
	await _start_run()
	# Kısa tamponla (M1'deki 0,12 sn) inişten 12 kare önceki dokunuş pencerenin dışında kalır.
	_run.tuning.input_buffer_time = 0.12
	var transit: int = await _measure_transit()
	_tap()
	await _frames(transit - 12)
	_tap()
	await _frames_until_on_wall()
	await _frames(10)
	assert_bool(_player.is_gravity_right()).is_false()
	assert_float(_player.position.x).is_equal_approx(-WALL_X, 0.5)


func test_buffer_time_comes_from_tuning() -> void:
	await _start_run()
	_run.tuning.input_buffer_time = 0.0
	var transit: int = await _measure_transit()
	_tap()
	await _frames(transit - 4)
	_tap()
	await _frames_until_on_wall()
	await _frames(10)
	assert_bool(_player.is_gravity_right()).is_false()


func test_is_tap_rules() -> void:
	assert_bool(Player.is_tap(_touch(0, true))).is_true()
	assert_bool(Player.is_tap(_touch(1, true))).override_failure_message(
			"İkinci parmağın basışı da sayılmalı").is_true()
	assert_bool(Player.is_tap(_touch(0, false))).is_false()
	assert_bool(Player.is_tap(_mouse(true, 0))).is_true()
	assert_bool(Player.is_tap(_mouse(true, InputEvent.DEVICE_ID_EMULATION))).override_failure_message(
			"Dokunuştan türetilen sahte fare olayı sayılmamalı").is_false()
	assert_bool(Player.is_tap(_mouse(false, 0))).is_false()
	assert_bool(Player.is_tap(_key(KEY_SPACE, false))).is_true()
	assert_bool(Player.is_tap(_key(KEY_SPACE, true))).override_failure_message(
			"Tuş basılı tutma tekrarı sayılmamalı").is_false()
	assert_bool(Player.is_tap(_key(KEY_A, false))).is_false()


## Diskteki varsayılan ayarların taze bir kopyasıyla tur kurar: testler paylaşılan örneği
## (canlı panelin ya da kayıtlı ayar dosyasının değiştirdiği) ne okur ne değiştirir.
func _start_run() -> void:
	_run = auto_free(RUN_SCENE.instantiate()) as Run
	_run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	_run.run_seed = 12345
	add_child(_run)
	_player = _run.get_node("Player") as Player
	await _frames(SETTLE_FRAMES)


## Oyuncu duvardayken bir geçişin kaç kare sürdüğünü ölçer; oyuncuyu öbür duvarda bırakır.
func _measure_transit() -> int:
	_tap()
	await _frames(INPUT_SETTLE_FRAMES)
	var frames: int = INPUT_SETTLE_FRAMES + await _frames_until_on_wall()
	return frames


func _frames_until_on_wall() -> int:
	var count: int = 0
	while not _player.is_on_wall() and count < MAX_TRANSIT_FRAMES:
		await get_tree().physics_frame
		count += 1
	return count


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _tap() -> void:
	get_tree().root.push_input(_touch(0, true), true)


func _touch(index: int, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = Vector2(540, 1200)
	return event


func _mouse(pressed: bool, device: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.device = device
	return event


func _key(keycode: Key, echo: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = echo
	return event
