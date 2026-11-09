extends GdUnitTestSuite
## Ana menü (M5-02, roadmap "UI kabulü"): beş en-boy oranında ve iki dilde görünür öğeler
## çakışmaz ve ekrandadır, düğmeler dokunulabilir, metinler gerçek fontla sığar ve okunur.
## Davranış: yalnızca açık sektör seçilir, Başla niyet yayar.

const MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
## En-boy oranları (genişlik / yükseklik): 9:16, 9:19,5, 9:21, 3:4 (tablet), 4:3 (yatay tablet).
const ASPECTS: Array[float] = [9.0 / 16.0, 9.0 / 19.5, 9.0 / 21.0, 3.0 / 4.0, 4.0 / 3.0]
## 48 dp'nin tuval pikseli (taban genişlik 1080, stretch "expand": telefonda tuval genişliği
## ekran genişliğidir). 360 dp genişliğindeki telefonda 1 dp = 1080 / 360 = 3 px → 48 dp = 144 px.
## Redmi (≈ 393 dp) 132 px ister; 360 dp yaygın küçük telefonların genişliği.
const MIN_TOUCH_PX: float = 144.0
## Komşu düğmeler arası 8 dp = 24 px (aynı hesap).
const MIN_GAP_PX: float = 24.0
## WCAG: normal metin 4,5; kapalı düğme yazısı (etkileşimsiz arayüz öğesi) 3.
const MIN_CONTRAST: float = 4.5
const MIN_DISABLED_CONTRAST: float = 3.0
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
	for aspect: float in ASPECTS:
		for locale: String in ["en", "tr"]:
			TranslationServer.set_locale(locale)
			var menu: MainMenu = await _open(aspect)
			var tag: String = "%s %.3f" % [locale, aspect]
			var screen: Rect2 = Rect2(Vector2.ZERO, menu.size)
			var items: Array[Control] = _leaves(menu)
			assert_int(items.size()).is_equal(9)
			for item: Control in items:
				var rect: Rect2 = item.get_global_rect()
				assert_bool(screen.encloses(rect)).override_failure_message("%s: %s ekran dışı %s" % [
					tag, item.name, rect]).is_true()
				for other: Control in items:
					if other == item:
						continue
					var overlap: Rect2 = rect.intersection(other.get_global_rect())
					assert_float(overlap.get_area()).override_failure_message("%s: %s ~ %s çakışıyor" % [
						tag, item.name, other.name]).is_equal(0.0)
			var buttons: Array[Control] = items.filter(func(c: Control) -> bool: return c is Button)
			for button: Control in buttons:
				var size: Vector2 = button.get_global_rect().size
				assert_float(minf(size.x, size.y)).override_failure_message("%s: %s %s < %.0f px" % [
					tag, button.name, size, MIN_TOUCH_PX]).is_greater_equal(MIN_TOUCH_PX)
				for other: Control in buttons:
					if other != button:
						var gap: float = _gap(button.get_global_rect(), other.get_global_rect())
						assert_float(gap).override_failure_message("%s: %s ~ %s arası %.0f px" % [
							tag, button.name, other.name, gap]).is_greater_equal(MIN_GAP_PX)
			menu.get_parent().queue_free()


## Metinler iki dilde gerçek fontla sığar: düğme yazısı kutusunda, başlık ve her sektörün adı
## en çok iki satır ve kutusunun içinde (düğme tasarlanan boyunda kalır), en kötü cüzdan
## değeri kendi kutusunda. Font her harfi içerir.
func test_texts_fit_in_both_languages() -> void:
	Events.sector_entered.emit(6)
	Progression.glimmers = WORST_GLIMMERS
	for locale: String in ["en", "tr"]:
		TranslationServer.set_locale(locale)
		var menu: MainMenu = await _open(ASPECTS[0])
		for item: Control in _leaves(menu):
			if item is Button:
				var button: Button = item as Button
				var text: String = button.tr(button.text) if button.auto_translate_mode != \
						Node.AUTO_TRANSLATE_MODE_DISABLED else button.text
				var font: Font = button.get_theme_font(&"font")
				var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
						button.get_theme_font_size(&"font_size")).x
				# Tasarlanan genişliğe göre: sığmayan yazı düğmeyi büyütür, ölçüyü gizlerdi.
				var room: float = button.custom_minimum_size.x - 2.0 * NeonButton.BORDER_PX * 4.0
				assert_float(width).override_failure_message("%s: '%s' %.0f px > %.0f" % [
					locale, text, width, room]).is_less_equal(room)
				_assert_glyphs(font, text)
				assert_vector(button.size).override_failure_message("%s: %s büyüdü" % [
					locale, button.name]).is_equal(button.custom_minimum_size)
		var wallet: Label = menu.get_node("%Wallet") as Label
		var box: float = wallet.size.x
		assert_float(wallet.get_minimum_size().x).override_failure_message("%s: cüzdan '%s'" % [
			locale, wallet.text]).is_less_equal(box)
		_assert_wrapped(menu.get_node("%Title") as Label, MAX_TITLE_LINES, locale)
		var sector: Label = menu.get_node("%SectorLabel") as Label
		for index: int in range(1, 7):
			Progression.select_start_sector(index)
			menu.refresh()
			await get_tree().process_frame
			_assert_wrapped(sector, MAX_SECTOR_LINES, locale)
			_assert_glyphs(sector.get_theme_font(&"font"), sector.text)
		menu.get_parent().queue_free()


## Kontrast (WCAG): düğme yazısı dolgunun (menü zemininin üstünde) üstünde ≥ 4,5, kapalı düğme
## ≥ 3; başlık, cüzdan ve her sektör renginde seçim yazısının çekirdeği zeminde ≥ 4,5.
func test_text_contrast() -> void:
	Events.sector_entered.emit(6)
	var menu: MainMenu = await _open(ASPECTS[0])
	var ground: Color = (menu.get_node("Background") as ColorRect).color
	var fill: Color = ground.blend(NeonButton.FILL)
	var normal: float = ColorMetrics.contrast_ratio(NeonButton.TEXT, fill)
	assert_float(normal).override_failure_message("düğme %.2f" % normal).is_greater_equal(MIN_CONTRAST)
	var off: float = ColorMetrics.contrast_ratio(NeonButton.TEXT_DISABLED, fill)
	assert_float(off).override_failure_message("kapalı %.2f" % off).is_greater_equal(
			MIN_DISABLED_CONTRAST)
	var labels: Array[Label] = [menu.get_node("%Title") as Label, menu.get_node("%Wallet") as Label]
	for index: int in range(1, 7):
		Progression.select_start_sector(index)
		menu.refresh()
		labels.append(menu.get_node("%SectorLabel") as Label)
		for label: Label in labels:
			var ratio: float = ColorMetrics.contrast_ratio(label.label_settings.font_color, ground)
			assert_float(ratio).override_failure_message("%s (S%d) %.2f" % [
				label.name, index, ratio]).is_greater_equal(MIN_CONTRAST)
	menu.get_parent().queue_free()


## Seçim yalnızca açık sektörler arasında; uçlarda oklar kapalı. Başla niyet yayar.
func test_checkpoint_choice_and_play() -> void:
	var menu: MainMenu = await _open(ASPECTS[0])
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
	var base: Vector2 = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	var size: Vector2 = Vector2(base.x, base.x / aspect)
	if aspect > base.x / base.y:
		size = Vector2(base.y * aspect, base.y)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(size.round())
	add_child(viewport)
	var menu: MainMenu = MENU_SCENE.instantiate() as MainMenu
	viewport.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	return menu


## Görünür yaprak öğeler: düğmeler ve yazılar (kaplar ve zemin değil).
func _leaves(menu: Control) -> Array[Control]:
	var leaves: Array[Control] = []
	for node: Node in menu.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.is_visible_in_tree() and (control is Button or control is Label):
			leaves.append(control)
	return leaves


## İki dikdörtgen arasındaki en kısa boşluk (çakışıyorsa 0).
func _gap(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy: float = maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()


func _assert_wrapped(label: Label, max_lines: int, locale: String) -> void:
	var lines: int = label.get_line_count()
	assert_int(lines).override_failure_message("%s: '%s' %d satır" % [
		locale, label.text, lines]).is_less_equal(max_lines)
	assert_int(label.get_visible_line_count()).override_failure_message("%s: '%s' kutuya sığmıyor" % [
		locale, label.text]).is_equal(lines)


func _assert_glyphs(font: Font, text: String) -> void:
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		assert_bool(code == 32 or font.has_char(code)).override_failure_message("fontta yok: '%s'" % [
			text[index]]).is_true()


func _on_play_requested() -> void:
	_played += 1
