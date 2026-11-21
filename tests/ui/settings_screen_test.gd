extends GdUnitTestSuite
## Ayarlar ekranı (M5-05, roadmap "UI kabulü"): beş en-boy oranında ve iki dilde öğeler ekranda
## ve çakışmasız, düğme ve kaydırıcılar ≥ 48 dp, metinler gerçek fontla sığar ve okunur.
## Davranış: her denetim Settings'i değiştirir; dil değişince açık ekranların (ayarlar, menü,
## mağaza) bütün yazıları yeni dile geçer. Ölçüler ve eşikler ortak: ui_acceptance.gd.

const UI: GDScript = preload("res://tests/ui/ui_acceptance.gd")
const SETTINGS_STATE: GDScript = preload("res://tests/autoloads/settings_test.gd")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_screen.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const SHOP_SCENE: PackedScene = preload("res://scenes/ui/shop_screen.tscn")
const TEST_PATH: String = "user://settings_screen_test.cfg"
## Başlık, 6 satır adı, geri, 2 kaydırıcı, 7 seçenek düğmesi, Hakkında.
const LEAF_COUNT: int = 18
const MAX_LABEL_LINES: int = 2
## WCAG 1.4.11: arayüz öğesinin görünen parçası komşusuna karşı ≥ 3.
const MIN_GRAPHIC_CONTRAST: float = 3.0
const QUALITY_BUTTONS: Array[String] = ["%LowButton", "%MediumButton", "%HighButton"]

var _saved: Dictionary[String, Variant] = {}


func before_test() -> void:
	_saved = SETTINGS_STATE.snapshot()
	Settings.path = TEST_PATH
	Progression.reset()
	GameManager.reset()


func after_test() -> void:
	SETTINGS_STATE.restore(_saved)
	Settings.apply_language()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	GameManager.reset()
	Progression.reset()


## Her oranda ve dilde: öğeler ekranın içinde, çakışmıyor; düğmeler ve kaydırıcılar ≥ 48 dp,
## aralarında ≥ 8 dp.
func test_layout_holds_on_every_aspect_and_language() -> void:
	for aspect: float in UI.ASPECTS:
		for locale: String in UI.LOCALES:
			TranslationServer.set_locale(locale)
			var screen: SettingsScreen = await _open(aspect)
			var items: Array[Control] = UI.leaves(screen)
			assert_int(items.size()).is_equal(LEAF_COUNT)
			var problems: Array[String] = UI.layout_problems(items, UI.worst_safe_rect(screen))
			assert_array(problems).override_failure_message("%s %.3f: %s" % [
				locale, aspect, problems]).is_empty()
			screen.get_parent().queue_free()


## İki dilde ve iki anahtar durumunda (AÇIK / KAPALI): düğme yazıları kutusunda, satır adları en
## çok iki satır ve kutularında, yazılar ≥ 36 px, font her harfi içerir.
func test_texts_fit_in_both_languages() -> void:
	for locale: String in UI.LOCALES:
		TranslationServer.set_locale(locale)
		for on: bool in [true, false]:
			Settings.vibration = on
			Settings.limit_fps_60 = on
			var screen: SettingsScreen = await _open(UI.ASPECTS[0])
			var items: Array[Control] = UI.leaves(screen)
			assert_array(UI.font_size_problems(items)).is_empty()
			for item: Control in items:
				if item is Button:
					var problems: Array[String] = UI.button_fit_problems(item as Button)
					assert_array(problems).override_failure_message("%s: %s" % [
						locale, problems]).is_empty()
				elif item is Label:
					_assert_wrapped(item as Label, locale)
			screen.get_parent().queue_free()


## Yazılar zeminde ≥ 4,5 (kapalı Hakkında ≥ 3); kaydırıcının dolu kısmı zeminde, tutamacı izde ≥ 3.
func test_contrast() -> void:
	var screen: SettingsScreen = await _open(UI.ASPECTS[0])
	var ground: Color = (screen.get_node("Background") as ColorRect).color
	assert_array(UI.button_contrast_problems(ground)).is_empty()
	for item: Control in UI.leaves(screen):
		if item is Label:
			assert_array(UI.label_contrast_problems(item as Label, ground)).is_empty()
	var slider: NeonSlider = screen.get_node("%MusicSlider") as NeonSlider
	var fill: float = ColorMetrics.contrast_ratio(slider.accent, ground)
	assert_float(fill).override_failure_message("dolu iz %.2f" % fill).is_greater_equal(
			MIN_GRAPHIC_CONTRAST)
	var grabber: Texture2D = slider.get_theme_icon(&"grabber")
	var knob: Color = grabber.get_image().get_pixelv(Vector2i(grabber.get_size() * 0.5))
	var on_track: float = ColorMetrics.contrast_ratio(knob, NeonSlider.TRACK_FILL)
	assert_float(on_track).override_failure_message("tutamaç %.2f" % on_track).is_greater_equal(
			MIN_GRAPHIC_CONTRAST)
	screen.get_parent().queue_free()


## Her denetim Settings'i değiştirir ve ekran yeni durumu gösterir.
func test_controls_change_settings() -> void:
	Settings.vibration = true
	Settings.limit_fps_60 = false
	var screen: SettingsScreen = await _open(UI.ASPECTS[0])
	var music: NeonSlider = screen.get_node("%MusicSlider") as NeonSlider
	music.value = 0.25
	assert_float(Settings.music_volume).is_equal_approx(0.25, 0.0001)
	(screen.get_node("%SfxSlider") as NeonSlider).value = 0.0
	assert_float(Settings.sfx_volume).is_equal(0.0)
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()
	music.drag_ended.emit(true)
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_true()
	var vibration: NeonButton = screen.get_node("%VibrationButton") as NeonButton
	vibration.pressed.emit()
	assert_bool(Settings.vibration).is_false()
	assert_str(vibration.text).is_equal("SETTINGS_OFF")
	assert_that(vibration.accent).is_equal(SettingsScreen.IDLE)
	var fps: NeonButton = screen.get_node("%FpsButton") as NeonButton
	fps.pressed.emit()
	assert_bool(Settings.limit_fps_60).is_true()
	assert_str(fps.text).is_equal("SETTINGS_ON")
	for pressed: String in QUALITY_BUTTONS:
		(screen.get_node(pressed) as NeonButton).pressed.emit()
		for other: String in QUALITY_BUTTONS:
			var accent: Color = (screen.get_node(other) as NeonButton).accent
			assert_that(accent).is_equal(
					SettingsScreen.ACTIVE if other == pressed else SettingsScreen.IDLE)
	assert_int(Settings.effect_quality).is_equal(GameTypes.Quality.HIGH)
	(screen.get_node("%TurkishButton") as NeonButton).pressed.emit()
	assert_str(Settings.language).is_equal("tr")
	assert_that((screen.get_node("%TurkishButton") as NeonButton).accent).is_equal(
			SettingsScreen.ACTIVE)
	assert_that((screen.get_node("%EnglishButton") as NeonButton).accent).is_equal(
			SettingsScreen.IDLE)
	screen.get_parent().queue_free()


## Dil değişince açık ayarlar, menü ve mağaza ekranındaki her yazı, o dilde yeni açılan ekranla
## aynıdır (kodla yazılan metinler de yenilenir).
func test_language_change_rewrites_open_screens() -> void:
	Events.sector_entered.emit(3)
	for pair: Array in [["en", "tr"], ["tr", "en"]]:
		var from: String = pair[0]
		var to: String = pair[1]
		Settings.set_language(from)
		var open_screens: Array[Control] = await _open_all()
		var settings: SettingsScreen = open_screens[0] as SettingsScreen
		var target: String = "%TurkishButton" if to == "tr" else "%EnglishButton"
		(settings.get_node(target) as NeonButton).pressed.emit()
		await get_tree().process_frame
		var fresh: Array[Control] = await _open_all()
		for index: int in open_screens.size():
			var shown: Array[String] = _shown_texts(open_screens[index])
			var expected: Array[String] = _shown_texts(fresh[index])
			assert_array(shown).override_failure_message("%s → %s, %s: %s ≠ %s" % [
				from, to, open_screens[index].name, shown, expected]).is_equal(expected)
		for control: Control in open_screens + fresh:
			control.get_parent().queue_free()


## İstekle açılır, geri ve durum değişimi kapatır.
func test_opens_on_request_and_closes() -> void:
	var screen: SettingsScreen = await _open(UI.ASPECTS[0])
	screen.visible = false
	Events.settings_requested.emit()
	assert_bool(screen.visible).is_true()
	(screen.get_node("%BackButton") as Button).pressed.emit()
	assert_bool(screen.visible).is_false()
	Events.settings_requested.emit()
	assert_bool(GameManager.change_state(GameTypes.AppState.MENU)).is_true()
	assert_bool(screen.visible).is_false()
	screen.get_parent().queue_free()


func _open(aspect: float) -> SettingsScreen:
	var screen: SettingsScreen = await _add(SETTINGS_SCENE, aspect) as SettingsScreen
	screen.open()
	return screen


func _open_all() -> Array[Control]:
	var settings: SettingsScreen = await _open(UI.ASPECTS[0])
	var menu: MainMenu = await _add(MENU_SCENE, UI.ASPECTS[0]) as MainMenu
	menu.open()
	var shop: ShopScreen = await _add(SHOP_SCENE, UI.ASPECTS[0]) as ShopScreen
	shop.open()
	await get_tree().process_frame
	return [settings, menu, shop]


## Oranı verilen ekranda (stretch "expand", taban 1080 × 1920) sahneyi kurar.
func _add(scene: PackedScene, aspect: float) -> Control:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = UI.canvas_size(aspect)
	add_child(viewport)
	var control: Control = scene.instantiate() as Control
	viewport.add_child(control)
	UI.apply_worst_safe_area(control)
	await get_tree().process_frame
	await get_tree().process_frame
	return control


## Ekranda görünen yazılar: otomatik çevrilen öğede çevirisi, ötekilerde metnin kendisi.
func _shown_texts(root: Control) -> Array[String]:
	var texts: Array[String] = []
	for node: Node in root.find_children("*", "Control", true, false):
		var text: String = ""
		if node is Label:
			text = (node as Label).text
		elif node is Button:
			text = (node as Button).text
		else:
			continue
		texts.append(node.atr(text) if node.can_auto_translate() else text)
	return texts


func _assert_wrapped(label: Label, locale: String) -> void:
	var lines: int = label.get_line_count()
	assert_int(lines).override_failure_message("%s: '%s' %d satır" % [
		locale, label.text, lines]).is_less_equal(MAX_LABEL_LINES)
	assert_int(label.get_visible_line_count()).override_failure_message(
			"%s: '%s' kutuya sığmıyor" % [locale, label.text]).is_equal(lines)
