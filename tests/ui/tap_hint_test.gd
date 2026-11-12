extends GdUnitTestSuite
## İlk açılışın "dokun" eli (M5-07, GDD §18, roadmap "UI kabulü"): beş en-boy oranında el ve
## halkası ekranın içinde, kendi kutusunda ve HUD'un üst şeridiyle çakışmıyor; dolgu ve kenar oyun
## zemininde ≥ 3:1 (arayüz öğesi, WCAG). Davranış: dokunuşu yutmaz, nabız ilerler, ilk çevirmede
## ve yeni turda söner. Ölçüler ui_acceptance.gd ve ColorMetrics'te.

const UI: GDScript = preload("res://tests/ui/ui_acceptance.gd")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
## Arayüz öğesinin zemine en düşük kontrastı (WCAG 1.4.11).
const MIN_GRAPHIC_CONTRAST: float = 3.0
## HUD'da hep görünen üst şerit öğeleri; el bunlarla çakışmamalı.
const TOP_ITEMS: Array[String] = ["%HeightLabel", "%BestLabel", "%GlimmerLabel", "%PauseButton"]
## Nabzın ilerlediği gözlenen süre (kare).
const PULSE_FRAMES: int = 20
const CLEAR_COLOR: String = "rendering/environment/defaults/default_clear_color"


func test_hint_fits_and_stays_clear_of_the_hud() -> void:
	for aspect: float in UI.ASPECTS:
		var viewport: SubViewport = auto_free(SubViewport.new()) as SubViewport
		viewport.size = UI.canvas_size(aspect)
		add_child(viewport)
		var hud: Hud = HUD_SCENE.instantiate() as Hud
		viewport.add_child(hud)
		await get_tree().process_frame
		hud.show_tap_hint()
		var hint: TapHint = hud.get_node("%TapHint") as TapHint
		var bounds: Rect2 = hint.drawn_bounds()
		assert_bool(Rect2(Vector2.ZERO, hint.size).encloses(bounds)) \
				.override_failure_message("kutu %s, çizim %s" % [hint.size, bounds]).is_true()
		var drawn: Rect2 = Rect2(hint.get_global_rect().position + bounds.position, bounds.size)
		assert_bool(Rect2(Vector2.ZERO, hud.size).encloses(drawn)) \
				.override_failure_message("%.3f: el ekran dışında %s" % [aspect, drawn]).is_true()
		for path: String in TOP_ITEMS:
			var item: Rect2 = (hud.get_node(path) as Control).get_global_rect()
			assert_bool(item.intersects(drawn)) \
					.override_failure_message("%.3f: el %s ile çakışıyor" % [aspect, path]) \
					.is_false()
		hud.queue_free()


## Android'de pencere açılıştan sonra boyut değiştirir; el gizliyken gelen boyut değişikliğinden
## sonra da ekranın ortasında görünmeli (M5-07 Redmi: el sol üst köşede kalmıştı).
func test_hint_follows_a_resize_while_hidden() -> void:
	var viewport: SubViewport = auto_free(SubViewport.new()) as SubViewport
	viewport.size = UI.canvas_size(UI.ASPECTS[0])
	add_child(viewport)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	viewport.add_child(hud)
	await get_tree().process_frame
	viewport.size = UI.canvas_size(UI.ASPECTS[1])
	await get_tree().process_frame
	hud.show_tap_hint()
	await get_tree().process_frame
	var hint: TapHint = hud.get_node("%TapHint") as TapHint
	var center_x: float = hint.get_global_rect().get_center().x
	assert_float(center_x).is_equal_approx(hud.size.x * 0.5, 1.0)
	hud.queue_free()


## Dışa aktarma (M5-07 Redmi): layout_mode yazılmamış kök düğümün anchor'ları yayın paketinde
## kayboldu, el (0, 0)'a düştü; ekransız testte görünmez. Kök düğüm layout_mode = 3, HUD'daki örnek
## layout_mode = 1 ve anchor'larıyla yazılır (editörün yazdığı biçim).
func test_scenes_spell_out_the_layout_mode() -> void:
	var root: String = FileAccess.get_file_as_string("res://scenes/ui/tap_hint.tscn")
	assert_str(_block(root, '[node name="TapHint" type="Control"]')).contains("layout_mode = 3")
	var hud: String = FileAccess.get_file_as_string("res://scenes/ui/hud.tscn")
	var block: String = _block(hud, '[node name="TapHint" parent="."')
	assert_str(block).contains("layout_mode = 1")
	assert_str(block).contains("anchor_top = 0.62")


func test_hint_reads_on_the_game_background() -> void:
	var ground: Color = ProjectSettings.get_setting(CLEAR_COLOR)
	var hint: TapHint = auto_free(TapHint.new()) as TapHint
	for color: Color in [TapHint.FILL, hint.accent]:
		var ratio: float = ColorMetrics.contrast_ratio(color, ground)
		assert_float(ratio).override_failure_message("%s: %.2f" % [color, ratio]) \
				.is_greater_equal(MIN_GRAPHIC_CONTRAST)


func test_hint_pulses_lets_taps_through_and_hides() -> void:
	var hud: Hud = auto_free(HUD_SCENE.instantiate()) as Hud
	add_child(hud)
	await get_tree().process_frame
	var hint: TapHint = hud.get_node("%TapHint") as TapHint
	assert_bool(hud.tap_hint_visible()).is_false()
	assert_int(hint.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	hud.show_tap_hint()
	assert_bool(hud.tap_hint_visible()).is_true()
	assert_float(hint.phase()).is_equal(0.0)
	for i: int in PULSE_FRAMES:
		await get_tree().process_frame
	assert_float(hint.phase()).is_greater(0.0)
	Events.player_flipped.emit()
	assert_bool(hud.tap_hint_visible()).is_false()
	hud.show_tap_hint()
	Events.run_started.emit(1, 1)
	assert_bool(hud.tap_hint_visible()).is_false()


## Sahne metninde başlığı head ile başlayan düğüm bloğu (sonraki "[" başlığına dek).
func _block(text: String, head: String) -> String:
	var start: int = text.find(head)
	if start < 0:
		return ""
	var end: int = text.find("\n[", start + head.length())
	return text.substr(start, end - start if end >= 0 else -1)
