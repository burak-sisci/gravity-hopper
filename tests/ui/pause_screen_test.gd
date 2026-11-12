extends GdUnitTestSuite
## Duraklatma ekranı (M5-06, roadmap "UI kabulü"): beş en-boy oranında ve iki dilde öğeler ekranda
## ve çakışmasız, düğmeler ≥ 48 dp, yazılar sığar ve en kötü zeminde okunur. Davranış: DEVAM
## 3-2-1 sayar (gerçek zamanla, ≈ 3 sn) ve bir kez resume_requested yayar; sayım sırasında arka
## plana geçiş sayımı iptal eder; Ayarlar ve Menü niyet yayar. Ölçüler ui_acceptance.gd'de.
## Kare sayan testler check.ps1'deki --fixed-fps 60 ile makineden bağımsızdır.

const UI: GDScript = preload("res://tests/ui/ui_acceptance.gd")
const SCREEN_SCENE: PackedScene = preload("res://scenes/ui/pause_screen.tscn")
## Düğmeli görünüm: başlık ve üç düğme. Sayımda yalnızca sayı.
const MENU_ITEMS: int = 4
const COUNT_ITEMS: int = 1
## Sayım süresi (GDD §20: 3-2-1, her sayı 1 sn) karede (60 Hz) ve ölçüm payı. Ekranın
## sabitlerinden türetilmez: sayımı hızlandıran bir değişiklik bu testte düşmeli.
const COUNT_SECONDS: float = 3.0
const COUNT_FRAMES: int = roundi(COUNT_SECONDS * 60.0)
const FRAME_SLACK: int = 6

var _resumes: int = 0
var _settings: int = 0
var _menus: int = 0


func before_test() -> void:
	_resumes = 0
	_settings = 0
	_menus = 0
	GameManager.reset()
	Events.resume_requested.connect(_on_resume_requested)
	Events.settings_requested.connect(_on_settings_requested)
	Events.menu_requested.connect(_on_menu_requested)


func after_test() -> void:
	Events.resume_requested.disconnect(_on_resume_requested)
	Events.settings_requested.disconnect(_on_settings_requested)
	Events.menu_requested.disconnect(_on_menu_requested)
	GameManager.reset()
	Settings.apply_language()


## Her oranda ve dilde, iki görünümde: öğeler ekranın içinde, çakışmıyor; düğmeler ≥ 48 dp,
## aralarında ≥ 8 dp.
func test_layout_holds_on_every_aspect_and_language() -> void:
	for aspect: float in UI.ASPECTS:
		for locale: String in UI.LOCALES:
			TranslationServer.set_locale(locale)
			for counting: bool in [false, true]:
				var screen: PauseScreen = await _open(aspect)
				if counting:
					screen.start_countdown()
					await get_tree().process_frame
				var items: Array[Control] = UI.leaves(screen)
				assert_int(items.size()).is_equal(COUNT_ITEMS if counting else MENU_ITEMS)
				var problems: Array[String] = UI.layout_problems(items,
						Rect2(Vector2.ZERO, screen.size))
				assert_array(problems).override_failure_message("%s %.3f sayım=%s: %s" % [
					locale, aspect, counting, problems]).is_empty()
				screen.get_parent().queue_free()


## İki dilde: düğme yazıları kutularında, başlık sütuna tek satır sığar, sayının her rakamı
## kutusuna sığar; yazılar ≥ 36 px, font her harfi içerir.
func test_texts_fit_in_both_languages() -> void:
	for locale: String in UI.LOCALES:
		TranslationServer.set_locale(locale)
		var screen: PauseScreen = await _open(UI.ASPECTS[0])
		var column: Control = screen.get_node("%Column") as Control
		var room: float = column.offset_right - column.offset_left
		var items: Array[Control] = UI.leaves(screen)
		assert_array(UI.font_size_problems(items)).is_empty()
		for item: Control in items:
			var problems: Array[String] = UI.button_fit_problems(item as Button) \
					if item is Button else UI.label_fit_problems(item as Label, room)
			assert_array(problems).override_failure_message("%s: %s" % [
				locale, problems]).is_empty()
		var count: Label = screen.get_node("%CountdownLabel") as Label
		for digit: int in range(PauseScreen.COUNTDOWN_FROM, 0, -1):
			count.text = str(digit)
			assert_array(UI.label_fit_problems(count, count.size.x)).is_empty()
			assert_float(count.get_minimum_size().y).is_less_equal(count.size.y)
		screen.get_parent().queue_free()


## Kontrast (WCAG): düğmeli görünümde en kötü zemin karartmanın arkasında beyaz (düğme ≥ 4,5,
## başlık ≥ 4,5). Sayımda perde açık, arkada oyun: zemin oyunun arka plan rengi.
func test_contrast() -> void:
	var screen: PauseScreen = await _open(UI.ASPECTS[0])
	var overlay: ColorRect = screen.get_node("%Overlay") as ColorRect
	var ground: Color = Color.WHITE.blend(overlay.color)
	assert_array(UI.button_contrast_problems(ground)).is_empty()
	for item: Control in UI.leaves(screen):
		if item is Label:
			assert_array(UI.label_contrast_problems(item as Label, ground)).is_empty()
	screen.start_countdown()
	var game: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	var count_ground: Color = game.blend(overlay.color)
	var count: Label = screen.get_node("%CountdownLabel") as Label
	assert_array(UI.label_contrast_problems(count, count_ground)).is_empty()
	screen.get_parent().queue_free()


## DEVAM: düğmeler gizlenir, 3-2-1 sırayla görünür; ≈ 3 sn sonra tek bir resume_requested.
func test_countdown_counts_down_and_asks_to_resume_once() -> void:
	var screen: PauseScreen = await _open(UI.ASPECTS[0])
	var count: Label = screen.get_node("%CountdownLabel") as Label
	(screen.get_node("%ResumeButton") as Button).pressed.emit()
	assert_bool(screen.counting()).is_true()
	assert_bool((screen.get_node("%Column") as Control).visible).is_false()
	var seen: Array[String] = []
	for frame: int in COUNT_FRAMES - FRAME_SLACK:
		await get_tree().process_frame
		if seen.is_empty() or seen[-1] != count.text:
			seen.append(count.text)
	assert_array(seen).is_equal(["3", "2", "1"])
	assert_int(_resumes).is_equal(0)
	await _frames(FRAME_SLACK * 2)
	assert_int(_resumes).is_equal(1)
	assert_bool(screen.counting()).is_false()
	await _frames(COUNT_FRAMES)
	assert_int(_resumes).is_equal(1)
	screen.get_parent().queue_free()


## Sayım sırasında arka plana geçiş sayımı iptal eder: düğmeler geri gelir, devam istenmez.
func test_going_to_background_cancels_the_countdown() -> void:
	for what: int in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]:
		var screen: PauseScreen = await _open(UI.ASPECTS[0])
		screen.start_countdown()
		await _frames(30)
		screen.notification(what)
		assert_bool(screen.counting()).is_false()
		assert_bool((screen.get_node("%Column") as Control).visible).is_true()
		await _frames(COUNT_FRAMES + FRAME_SLACK)
		assert_int(_resumes).is_equal(0)
		screen.get_parent().queue_free()


## Ayarlar ve Menü niyet yayar; yeniden açılış düğmeli görünümle başlar.
func test_buttons_emit_intents_and_open_resets() -> void:
	var screen: PauseScreen = await _open(UI.ASPECTS[0])
	(screen.get_node("%SettingsButton") as Button).pressed.emit()
	assert_int(_settings).is_equal(1)
	(screen.get_node("%MenuButton") as Button).pressed.emit()
	assert_int(_menus).is_equal(1)
	screen.start_countdown()
	screen.open()
	assert_bool(screen.counting()).is_false()
	assert_bool((screen.get_node("%Column") as Control).visible).is_true()
	await _frames(COUNT_FRAMES + FRAME_SLACK)
	assert_int(_resumes).is_equal(0)
	screen.get_parent().queue_free()


## Oranı verilen ekranda (stretch "expand", taban 1080 × 1920) duraklatma ekranını açar.
func _open(aspect: float) -> PauseScreen:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = UI.canvas_size(aspect)
	add_child(viewport)
	var screen: PauseScreen = SCREEN_SCENE.instantiate() as PauseScreen
	viewport.add_child(screen)
	screen.open()
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _on_resume_requested() -> void:
	_resumes += 1


func _on_settings_requested() -> void:
	_settings += 1


func _on_menu_requested() -> void:
	_menus += 1
