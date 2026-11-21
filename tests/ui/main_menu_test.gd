extends GdUnitTestSuite
## Ana menü (M5-02, roadmap "UI kabulü"): beş en-boy oranında ve iki dilde görünür öğeler
## çakışmaz ve ekrandadır, düğmeler dokunulabilir, metinler gerçek fontla sığar ve okunur.
## Davranış: yalnızca açık sektör seçilir, Başla niyet yayar.
## Ölçüler ve eşikler ortak: ui_acceptance.gd.

const UI: GDScript = preload("res://tests/ui/ui_acceptance.gd")
const MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
## Cüzdanın sığması gereken en kötü değer.
const WORST_GLIMMERS: int = 999999
const MAX_TITLE_LINES: int = 2
const MAX_SECTOR_LINES: int = 2

var _played: int = 0


func before_test() -> void:
	_played = 0
	Progression.reset()
	Events.play_requested.connect(_on_play_requested)


func after_test() -> void:
	Events.play_requested.disconnect(_on_play_requested)
	Progression.reset()
	Settings.apply_language()


## Her oranda ve dilde: öğeler ekranın içinde, çakışmıyor; düğmeler ≥ 48 dp ve aralarında ≥ 8 dp.
func test_layout_holds_on_every_aspect_and_language() -> void:
	Events.sector_entered.emit(6)
	for aspect: float in UI.ASPECTS:
		for locale: String in UI.LOCALES:
			TranslationServer.set_locale(locale)
			var menu: MainMenu = await _open(aspect)
			var items: Array[Control] = UI.leaves(menu)
			assert_int(items.size()).is_equal(9)
			var problems: Array[String] = UI.layout_problems(items, UI.worst_safe_rect(menu))
			assert_array(problems).override_failure_message("%s %.3f: %s" % [
				locale, aspect, problems]).is_empty()
			menu.get_parent().queue_free()


## Metinler iki dilde gerçek fontla sığar: düğme yazısı kutusunda, başlık ve her sektörün adı
## en çok iki satır ve kutusunun içinde (düğme tasarlanan boyunda kalır), en kötü cüzdan
## değeri kendi kutusunda. Font her harfi içerir.
func test_texts_fit_in_both_languages() -> void:
	Events.sector_entered.emit(6)
	Progression.glimmers = WORST_GLIMMERS
	for locale: String in UI.LOCALES:
		TranslationServer.set_locale(locale)
		var menu: MainMenu = await _open(UI.ASPECTS[0])
		assert_array(UI.font_size_problems(UI.leaves(menu))).is_empty()
		for item: Control in UI.leaves(menu):
			if item is Button:
				var problems: Array[String] = UI.button_fit_problems(item as Button)
				assert_array(problems).override_failure_message("%s: %s" % [
					locale, problems]).is_empty()
		var wallet: Label = menu.get_node("%Wallet") as Label
		assert_array(UI.label_fit_problems(wallet, wallet.size.x)).override_failure_message(
				"%s: cüzdan '%s'" % [locale, wallet.text]).is_empty()
		_assert_wrapped(menu.get_node("%Title") as Label, MAX_TITLE_LINES, locale)
		var sector: Label = menu.get_node("%SectorLabel") as Label
		for index: int in range(1, 7):
			Progression.select_start_sector(index)
			menu.refresh()
			await get_tree().process_frame
			_assert_wrapped(sector, MAX_SECTOR_LINES, locale)
			assert_array(UI.glyph_problems(UI.label_font(sector), sector.text)).is_empty()
		menu.get_parent().queue_free()


## Kontrast (WCAG): düğme yazısı dolgunun (menü zemininin üstünde) üstünde ≥ 4,5, kapalı düğme
## ≥ 3; başlık, cüzdan ve her sektör renginde seçim yazısının çekirdeği zeminde ≥ 4,5.
func test_text_contrast() -> void:
	Events.sector_entered.emit(6)
	var menu: MainMenu = await _open(UI.ASPECTS[0])
	var ground: Color = (menu.get_node("Background") as ColorRect).color
	assert_array(UI.button_contrast_problems(ground)).is_empty()
	var labels: Array[Label] = [menu.get_node("%Title") as Label, menu.get_node("%Wallet") as Label]
	for index: int in range(1, 7):
		Progression.select_start_sector(index)
		menu.refresh()
		labels.append(menu.get_node("%SectorLabel") as Label)
		for label: Label in labels:
			var problems: Array[String] = UI.label_contrast_problems(label, ground)
			assert_array(problems).override_failure_message("S%d: %s" % [index, problems]).is_empty()
	menu.get_parent().queue_free()


## Seçim yalnızca açık sektörler arasında; uçlarda oklar kapalı. Başla niyet yayar.
func test_checkpoint_choice_and_play() -> void:
	var menu: MainMenu = await _open(UI.ASPECTS[0])
	var prev: Button = menu.get_node("%PrevButton") as Button
	var next: Button = menu.get_node("%NextButton") as Button
	assert_bool(prev.disabled and next.disabled).is_true()
	Events.sector_entered.emit(3)
	assert_bool(next.disabled).is_false()
	next.pressed.emit()
	next.pressed.emit()
	assert_int(Progression.start_sector).is_equal(3)
	assert_bool(next.disabled).is_true()
	next.pressed.emit()
	assert_int(Progression.start_sector).is_equal(3)
	assert_str((menu.get_node("%SectorLabel") as Label).text).is_equal(menu.sector_text(3))
	prev.pressed.emit()
	assert_int(Progression.start_sector).is_equal(2)
	(menu.get_node("%PlayButton") as Button).pressed.emit()
	assert_int(_played).is_equal(1)
	menu.get_parent().queue_free()


## Oranı verilen ekranda (stretch "expand", taban 1080 × 1920) menüyü kurar.
func _open(aspect: float) -> MainMenu:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = UI.canvas_size(aspect)
	add_child(viewport)
	var menu: MainMenu = MENU_SCENE.instantiate() as MainMenu
	viewport.add_child(menu)
	UI.apply_worst_safe_area(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	return menu


func _assert_wrapped(label: Label, max_lines: int, locale: String) -> void:
	var lines: int = label.get_line_count()
	assert_int(lines).override_failure_message("%s: '%s' %d satır" % [
		locale, label.text, lines]).is_less_equal(max_lines)
	assert_int(label.get_visible_line_count()).override_failure_message("%s: '%s' kutuya sığmıyor" % [
		locale, label.text]).is_equal(lines)


func _on_play_requested() -> void:
	_played += 1
