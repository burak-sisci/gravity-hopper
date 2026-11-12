extends GdUnitTestSuite
## Hakkında / lisanslar (M5-09, GDD §20): CREDITS.md'nin oyuna giren her satırı katalogda ve
## ekranda (eksik atıf lisans ihlalidir); Godot'nun lisans metni, üçüncü taraf bileşenleri ve
## lisans metinleri ekranda. UI kabulü (ui_acceptance.gd): beş oranda ve iki dilde öğeler ekranda,
## çakışmasız; geri ≥ 48 dp; yazılar ≥ 36 px, okunur (≥ 4,5), font her harfi içerir, hiçbiri
## listeden yana taşmaz; liste kaydırılır. İstekle açılır; geri ve durum değişimi kapatır.

const UI: GDScript = preload("res://tests/ui/ui_acceptance.gd")
const ABOUT_SCENE: PackedScene = preload("res://scenes/ui/about_screen.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_screen.tscn")
const CREDITS_PATH: String = "res://CREDITS.md"
## CREDITS.md'de bu başlıktan sonrası oyuna girmez (geliştirme araçları).
const DEV_SECTION: String = "## Geliştirme"
## Kökte görünen öğeler (liste içindekiler kayar, ayrıca denetlenir).
const FRAME_ITEMS: Array[String] = ["%BackButton", "Title", "%List"]
## Liste en geç bu kadar karede tamamlanır (60 FPS'te 10 s).
const MAX_BUILD_FRAMES: int = 600
## Bir karede yazı eklemeye harcanan en uzun süre (ms): bütçe 4 ms + bütçeyi aşan son yazı.
## PC'de ölçülen 6,6 ms (bölmeden önce 250 ms); 60 FPS'te kare 16,7 ms.
const MAX_FRAME_MS: float = 12.0
## Tek yazının en uzun metni: paragraflara bölme olmazsa en uzun lisans ≈ 9 bin karakter tek
## yazıda kalır ve kare bütçesini tek başına aşar.
const MAX_LABEL_CHARS: int = 4000


var _locale: String = ""


func before_test() -> void:
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_locale)
	GameManager.reset()


## Katalog CREDITS.md'nin oyuna giren tablolarıyla birebir: eklenen ya da silinen her satır
## kataloğa da işlenmeli.
func test_catalog_matches_credits_md() -> void:
	var catalog: CreditsCatalog = (auto_free(ABOUT_SCENE.instantiate()) as AboutScreen).catalog
	var rows: Array[String] = []
	for entry: CreditEntry in catalog.entries:
		rows.append(entry.credits_row)
	rows.sort()
	var expected: Array[String] = _shipped_credit_rows()
	expected.sort()
	assert_int(expected.size()).is_greater(0)
	assert_array(rows).is_equal(expected)


## İki dilde: her atıf (başlık, yazar, lisans), Godot lisansı, her bileşen ve her lisans metni
## ekranda; çeviri anahtarı açıkta kalmaz.
func test_shows_every_credit_and_license() -> void:
	for locale: String in UI.LOCALES:
		TranslationServer.set_locale(locale)
		var screen: AboutScreen = await _open(UI.ASPECTS[0])
		var text: String = _flat(screen.shown_text())
		var expected: Array[String] = [_flat(Engine.get_license_text())]
		for entry: CreditEntry in screen.catalog.entries:
			expected.append_array([tr(entry.title), entry.author, tr(entry.license)])
		for component: Dictionary in Engine.get_copyright_info():
			expected.append(String(component["name"]))
		var licenses: Dictionary = Engine.get_license_info()
		for license_name: String in licenses:
			expected.append_array([license_name, _flat(String(licenses[license_name]))])
		for part: String in expected:
			assert_bool(text.contains(part)).override_failure_message("%s: yok '%s'" % [
				locale, part.left(60)]).is_true()
		for key: String in ["ABOUT_", "CREDITS_", "SETTINGS_ABOUT"]:
			assert_bool(text.contains(key)).override_failure_message("%s: açık anahtar %s" % [
				locale, key]).is_false()
		screen.get_parent().queue_free()


## Beş oranda ve iki dilde: geri, başlık ve liste ekranda, çakışmasız; geri ≥ 48 dp; listedeki
## her yazı listenin genişliğinde (yatay taşma yok) ve içerik listeden uzun (kaydırılır).
func test_layout_holds_on_every_aspect_and_language() -> void:
	for aspect: float in UI.ASPECTS:
		for locale: String in UI.LOCALES:
			TranslationServer.set_locale(locale)
			var screen: AboutScreen = await _open(aspect)
			var items: Array[Control] = []
			for path: String in FRAME_ITEMS:
				items.append(screen.get_node(path) as Control)
			var problems: Array[String] = UI.layout_problems(items, Rect2(Vector2.ZERO, screen.size))
			var list: ScrollContainer = screen.get_node("%List") as ScrollContainer
			var box: Control = screen.get_node("%Box") as Control
			for label: Label in _labels(screen):
				if label.size.x > list.size.x + 0.5:
					problems.append("%s taşıyor %.0f > %.0f" % [label.text.left(30), label.size.x,
							list.size.x])
			if box.size.y <= list.size.y:
				problems.append("kaymıyor: içerik %.0f ≤ %.0f" % [box.size.y, list.size.y])
			assert_array(problems).override_failure_message("%s %.3f: %s" % [
				locale, aspect, problems]).is_empty()
			screen.get_parent().queue_free()


## İki dilde: yazılar ≥ 36 px, geri düğmesi ve başlık kutusuna sığar, font her harfi içerir.
func test_texts_fit_and_render() -> void:
	for locale: String in UI.LOCALES:
		TranslationServer.set_locale(locale)
		var screen: AboutScreen = await _open(UI.ASPECTS[0])
		var labels: Array[Control] = []
		for label: Label in _labels(screen):
			labels.append(label)
		var title: Label = screen.get_node("Title") as Label
		labels.append(title)
		var problems: Array[String] = UI.font_size_problems(labels)
		var back: Button = screen.get_node("%BackButton") as Button
		problems.append_array(UI.button_fit_problems(back))
		problems.append_array(UI.label_fit_problems(title, title.size.x))
		for label: Label in _labels(screen):
			problems.append_array(UI.glyph_problems(UI.label_font(label), label.text))
		assert_array(problems).override_failure_message("%s: %s" % [locale, problems]).is_empty()
		screen.get_parent().queue_free()


## Yazılar zeminde ≥ 4,5; geri düğmesi neon düğme kontrastında.
func test_contrast() -> void:
	var screen: AboutScreen = await _open(UI.ASPECTS[0])
	var ground: Color = (screen.get_node("Background") as ColorRect).color
	var problems: Array[String] = UI.button_contrast_problems(ground)
	for label: Label in _labels(screen):
		problems.append_array(UI.label_contrast_problems(label, ground))
	assert_array(problems).is_empty()
	screen.get_parent().queue_free()


## Liste karelere bölünerek kurulur (Redmi'de tek karede 1051 ms donma): açılışta üst kısım
## hemen görünür, kalan kareler boyunca eklenir; hiçbir yazı MAX_LABEL_CHARS'ı aşmaz.
func test_builds_over_frames() -> void:
	var screen: AboutScreen = await _add(ABOUT_SCENE, UI.ASPECTS[0]) as AboutScreen
	screen.open()
	assert_bool(screen.is_built()).is_false()
	var first: int = screen.get_node("%Box").get_child_count()
	assert_int(first).is_greater(0)
	var frames: int = 1
	while not screen.is_built() and frames < MAX_BUILD_FRAMES:
		await get_tree().process_frame
		frames += 1
	assert_bool(screen.is_built()).override_failure_message("%d karede bitmedi" % frames) \
			.is_true()
	assert_int(frames).is_greater(1)
	assert_float(screen.slowest_frame_ms()).is_less_equal(MAX_FRAME_MS)
	for label: Label in _labels(screen):
		assert_int(label.text.length()).override_failure_message("'%s…' %d karakter" % [
			label.text.left(40), label.text.length()]).is_less_equal(MAX_LABEL_CHARS)
	screen.get_parent().queue_free()


## Ayarlardaki Hakkında açar; geri ve durum değişimi kapatır; yeniden açılış başa sarar.
func test_opens_from_settings_and_closes() -> void:
	var screen: AboutScreen = await _add(ABOUT_SCENE, UI.ASPECTS[0]) as AboutScreen
	var settings: SettingsScreen = await _add(SETTINGS_SCENE, UI.ASPECTS[0]) as SettingsScreen
	assert_bool(screen.visible).is_true()
	screen.close()
	var about: NeonButton = settings.get_node("%AboutButton") as NeonButton
	assert_bool(about.disabled).is_false()
	about.pressed.emit()
	assert_bool(screen.visible).is_true()
	await get_tree().process_frame
	var list: ScrollContainer = screen.get_node("%List") as ScrollContainer
	list.scroll_vertical = 500
	(screen.get_node("%BackButton") as Button).pressed.emit()
	assert_bool(screen.visible).is_false()
	Events.about_requested.emit()
	assert_int(list.scroll_vertical).is_equal(0)
	assert_bool(GameManager.change_state(GameTypes.AppState.MENU)).is_true()
	assert_bool(screen.visible).is_false()
	screen.get_parent().queue_free()
	settings.get_parent().queue_free()


## CREDITS.md'de oyuna giren tablo satırlarının ilk hücresi (başlık, ayraç ve "—" satırları hariç).
func _shipped_credit_rows() -> Array[String]:
	var text: String = FileAccess.get_file_as_string(CREDITS_PATH)
	text = text.substr(0, text.find(DEV_SECTION))
	var rows: Array[String] = []
	var lines: PackedStringArray = text.split("\n")
	for index: int in lines.size():
		var line: String = lines[index]
		if not line.begins_with("| ") or line.begins_with("| ---"):
			continue
		if index + 1 < lines.size() and lines[index + 1].begins_with("| ---"):
			continue
		var cell: String = line.split("|")[1].strip_edges()
		if cell != "—":
			rows.append(cell)
	return rows


## Paragraflar ayrı yazılara bölündüğü için satır sonları karşılaştırmada tek boşluğa iner.
func _flat(text: String) -> String:
	return " ".join(text.strip_edges().split("\n", false))


func _labels(screen: AboutScreen) -> Array[Label]:
	var found: Array[Label] = []
	for child: Node in screen.get_node("%Box").get_children():
		found.append(child as Label)
	return found


func _open(aspect: float) -> AboutScreen:
	var screen: AboutScreen = await _add(ABOUT_SCENE, aspect) as AboutScreen
	screen.open()
	screen.finish_build()
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


## Oranı verilen ekranda (stretch "expand", taban 1080 × 1920) sahneyi kurar.
func _add(scene: PackedScene, aspect: float) -> Control:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = UI.canvas_size(aspect)
	add_child(viewport)
	var control: Control = scene.instantiate() as Control
	viewport.add_child(control)
	await get_tree().process_frame
	await get_tree().process_frame
	return control
