extends GdUnitTestSuite
## Debug katmanı ve canlı ayar paneli (M1-02, M1-11; architecture.md §13). Telefondaki DBG
## dokunuşu çevirmeye dönüşmemeli; tuşlar ve düğmeler aynı durumu göstermeli.
## Testler genel durumu (zaman ölçeği, çarpışma çizimi, ölümsüzlük) geri bırakır.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SETTLE_FRAMES: int = 40
## DBG düğmesinin ortası (debug_layer.tscn: 16,12 – 156,84).
const DEBUG_BUTTON_CENTER: Vector2 = Vector2(86, 48)
## Oyun alanında, hiçbir düğmenin olmadığı bir nokta.
const PLAY_AREA_POINT: Vector2 = Vector2(540, 1700)

var _main: Node


func before_test() -> void:
	_main = auto_free(MAIN_SCENE.instantiate()) as Node
	add_child(_main)
	await _frames(SETTLE_FRAMES)


func after_test() -> void:
	Engine.time_scale = 1.0
	get_tree().debug_collisions_hint = false
	Events.debug_invincibility_changed.emit(false)


func test_tap_on_debug_button_does_not_flip() -> void:
	_push_touch(DEBUG_BUTTON_CENTER)
	await _frames(2)
	assert_bool(_player().is_gravity_right()).is_false()
	# Karşılaştırma: aynı dokunuş oyun alanında çevirir (dokunuş yolu gerçekten çalışıyor).
	_push_touch(PLAY_AREA_POINT)
	await _frames(2)
	assert_bool(_player().is_gravity_right()).is_true()


func test_debug_button_toggles_panel() -> void:
	assert_bool(_panel().visible).is_false()
	_push_click(DEBUG_BUTTON_CENTER)
	await _frames(1)
	assert_bool(_panel().visible).is_true()
	_push_click(DEBUG_BUTTON_CENTER)
	await _frames(1)
	assert_bool(_panel().visible).is_false()


func test_panel_has_a_slider_per_tuning_value() -> void:
	var tuning: TuningConfig = load("res://data/tuning/default_tuning.tres") as TuningConfig
	var expected: Array[StringName] = []
	for info: Dictionary in tuning.get_property_list():
		if int(info["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE \
				and int(info["hint"]) == PROPERTY_HINT_RANGE:
			expected.append(info["name"])
	var rows: Array[Node] = _main.get_node("%Debug").find_children("Rows", "", true, false)
	assert_int(rows.size()).is_equal(1)
	var sliders: Array[HSlider] = []
	var previous_was_header: bool = false
	for child: Node in rows[0].get_children():
		if child is HSlider:
			sliders.append(child as HSlider)
		# Başlık satırları boş kalmaz: başlığın ardından değer etiketi ve kaydırıcı gelir.
		var is_header: bool = child is Label and not (child as Label).text.contains(":")
		assert_bool(previous_was_header and is_header).override_failure_message(
				"Boş başlık: %s" % (child as Label).text if child is Label else "").is_false()
		previous_was_header = is_header
	assert_int(sliders.size()).is_equal(expected.size())
	for i: int in sliders.size():
		assert_float(sliders[i].value).is_equal_approx(float(tuning.get(expected[i])), 0.0001)


func test_keys_toggle_panel_invincibility_and_slow_motion() -> void:
	_push_key(KEY_1)
	assert_bool(_panel().visible).is_true()
	_push_key(KEY_1)
	assert_bool(_panel().visible).is_false()

	_push_key(KEY_2)
	await _frames(1)
	assert_float(_player().modulate.a).is_less(1.0)
	_push_key(KEY_2)
	await _frames(1)
	assert_float(_player().modulate.a).is_equal(1.0)

	_push_key(KEY_KP_4)
	assert_float(Engine.time_scale).is_equal_approx(0.3, 0.0001)
	_push_key(KEY_4)
	assert_float(Engine.time_scale).is_equal(1.0)

	_push_key(KEY_3)
	assert_bool(get_tree().debug_collisions_hint).is_true()
	_push_key(KEY_3)
	assert_bool(get_tree().debug_collisions_hint).is_false()


## İlerleme sayfası (M4-03): ayar panelindeki düğmeyle ya da 0 tuşuyla açılır, ayar paneliyle
## aynı anda açık kalmaz.
func test_progress_page_opens_from_the_panel_and_key_0() -> void:
	var progress: Control = _main.get_node("%Debug").find_children(
			"ProgressPanel", "", true, false)[0] as Control
	assert_bool(progress.visible).is_false()
	_push_key(KEY_1)
	(_panel().find_child("ProgressButton", true, false) as Button).pressed.emit()
	assert_bool(progress.visible).is_true()
	assert_bool(_panel().visible).is_false()
	_push_key(KEY_0)
	assert_bool(progress.visible).is_false()
	_push_key(KEY_0)
	assert_bool(progress.visible).is_true()
	_push_key(KEY_1)
	assert_bool(_panel().visible).is_true()
	assert_bool(progress.visible).is_false()


func test_key_5_starts_next_sector() -> void:
	var sectors: Array[int] = []
	var on_started: Callable = func(_seed: int, start_sector: int) -> void:
		sectors.append(start_sector)
	Events.run_started.connect(on_started)
	_push_key(KEY_5)
	_push_key(KEY_KP_5)
	# Son sektörden sonra (S3) aynı sektör yeniden başlar.
	_push_key(KEY_5)
	Events.run_started.disconnect(on_started)
	assert_array(sectors).is_equal([2, 3, 3])
	await _frames(1)
	assert_int((_main.get_node("%World").get_child(0) as Run).sector).is_equal(3)


func test_key_9_cycles_quality_for_the_session() -> void:
	var stored: GameTypes.Quality = Settings.effect_quality
	Settings.effect_quality = GameTypes.Quality.HIGH
	Events.settings_changed.emit()
	var grid: Node2D = _run().get_node("%Background").get_node("%Grid") as Node2D
	var button: Button = _main.get_node("%Debug").find_children("QualityButton", "", true,
			false)[0] as Button
	_push_key(KEY_9)
	assert_int(Neon.quality).is_equal(GameTypes.Quality.MEDIUM)
	assert_str(button.text).is_equal("Kalite O")
	_push_key(KEY_KP_9)
	assert_int(Neon.quality).is_equal(GameTypes.Quality.LOW)
	assert_bool(grid.visible).is_false()
	_push_key(KEY_9)
	assert_int(Neon.quality).is_equal(GameTypes.Quality.HIGH)
	assert_bool(grid.visible).is_true()
	Settings.effect_quality = stored
	Events.settings_changed.emit()


func test_invincibility_survives_restart() -> void:
	_push_key(KEY_2)
	Events.retry_requested.emit()
	await _frames(1)
	assert_float(_player().modulate.a).is_less(1.0)
	_push_key(KEY_2)


func _player() -> Player:
	return _run().get_node("Player") as Player


func _run() -> Node:
	return _main.get_node("%World").get_child(0)


func _panel() -> Control:
	return _main.get_node("%Debug").find_children("TuningPanel", "", true, false)[0] as Control


## Telefondaki gibi: önce dokunuş olayı, ardından ondan türetilen sahte fare tıklaması.
func _push_touch(at: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = true
	get_tree().root.push_input(touch, true)
	var release: InputEventScreenTouch = touch.duplicate() as InputEventScreenTouch
	release.pressed = false
	get_tree().root.push_input(release, true)


func _push_click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = at
		click.global_position = at
		click.pressed = pressed
		click.device = InputEvent.DEVICE_ID_EMULATION
		get_tree().root.push_input(click, true)


func _push_key(keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	get_tree().root.push_input(key, true)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
