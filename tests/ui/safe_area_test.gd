extends GdUnitTestSuite
## Güvenli alan (M6-01, architecture.md §5.3): cihazın bildirdiği güvenli alan tuval pikseline
## doğru çevrilir; ekranlar içeri alınırken zeminleri ve karartmaları bütün ekranı kaplamaya
## devam eder. Ekranların öğeleri kötü telefonun güvenli alanında ve köşelerden uzakta: her ekran
## testinin yerleşim denetimi (`UI.apply_worst_safe_area`, `UI.corner_problems`).

const UI := preload("res://tests/ui/ui_acceptance.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
## Zemini olan arayüz ekranları (HUD'un zemini duvar vinyetidir).
const SCREENS: Array[PackedScene] = [
	preload("res://scenes/ui/hud.tscn"),
	preload("res://scenes/ui/main_menu.tscn"),
	preload("res://scenes/ui/results_screen.tscn"),
	preload("res://scenes/ui/shop_screen.tscn"),
	preload("res://scenes/ui/pause_screen.tscn"),
	preload("res://scenes/ui/settings_screen.tscn"),
	preload("res://scenes/ui/about_screen.tscn"),
]


## Redmi Note 12 (adb dumpsys: kamera deliği 94 px, Godot da aynı güvenli alanı bildirdi):
## tuval ekranla aynı boyda, üst pay 94. 1440 px genişlikli ekranda tuval 1080 genişliğinde:
## ekran pikseli 0,75 ile küçülür. Masaüstünde pencere güvenli alanın içinde: pay yok.
func test_insets_convert_device_pixels_to_canvas() -> void:
	var redmi: Vector4 = SafeArea.insets_for(Rect2(0, 94, 1080, 2306), Rect2(0, 0, 1080, 2400),
			Vector2(1080, 2400))
	assert_vector(redmi).is_equal(Vector4(0, 94, 0, 0))
	# İçerik yalnızca tasarım payını (üstte 60) aşan kısım kadar iner.
	assert_vector(SafeArea.content_insets(redmi)).is_equal(Vector4(0, 34, 0, 0))
	assert_vector(SafeArea.content_insets(Vector4(10, 50, 0, 100))).is_equal(Vector4(0, 0, 0, 60))
	var qhd: Vector4 = SafeArea.insets_for(Rect2(0, 140, 1440, 3060), Rect2(0, 0, 1440, 3200),
			Vector2(1080, 2400))
	assert_vector(qhd).is_equal_approx(Vector4(0, 105, 0, 0), Vector4.ONE * 0.01)
	var desktop: Vector4 = SafeArea.insets_for(Rect2(0, 0, 1920, 1040), Rect2(700, 100, 450, 800),
			Vector2(1080, 1920))
	assert_vector(desktop).is_equal(Vector4.ZERO)
	assert_vector(SafeArea.insets_for(Rect2(), Rect2(0, 0, 1080, 2400), Vector2(1080, 2400))) \
			.is_equal(Vector4.ZERO)


## Her ekranda: içerik güvenli alana iner, zemin (FULL_BLEED_GROUP) yine bütün ekranı kaplar; pay
## sıfırken ekran tam ekrandır (güvenli alanı olmayan cihazda yerleşim değişmez).
func test_screens_shrink_but_backgrounds_stay_full_screen() -> void:
	for scene: PackedScene in SCREENS:
		for aspect: float in UI.ASPECTS:
			var viewport: SubViewport = SubViewport.new()
			viewport.size = UI.canvas_size(aspect)
			add_child(viewport)
			var screen: Control = scene.instantiate() as Control
			viewport.add_child(screen)
			var full: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size))
			SafeArea.fit(screen, Vector4.ZERO)
			assert_object(screen.get_global_rect()).is_equal(full)
			UI.apply_worst_safe_area(screen)
			var bleeds: Array[Control] = _bleeds(screen)
			assert_int(bleeds.size()).override_failure_message("%s zeminsiz" % screen.name) \
					.is_greater_equal(1)
			var shift: Vector4 = SafeArea.content_insets(UI.WORST_INSETS)
			assert_object(screen.get_global_rect()).is_equal(Rect2(shift.x, shift.y,
					full.size.x - shift.x - shift.z, full.size.y - shift.y - shift.w))
			for bleed: Control in bleeds:
				assert_object(bleed.get_global_rect()).override_failure_message("%s/%s %s" % [
					screen.name, bleed.name, bleed.get_global_rect()]).is_equal(full)
			viewport.queue_free()


## Köşe ölçüsünün kendisi: köşe karesinde ve çeyrek dairenin dışında kalan öğe yakalanır;
## dairenin içinde ya da köşe karesinin dışında kalan, kaydırılan listedeki ve ekran dışındaki
## öğe sayılmaz.
func test_corner_metric_catches_only_cut_items() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 2400)
	add_child(viewport)
	var r: float = UI.CORNER_RADIUS_PX
	var cut: Array[Rect2] = [Rect2(0, 0, 100, 100), Rect2(1000, 2320, 80, 80),
			Rect2(20, 2300, 200, 80)]
	var fine: Array[Rect2] = [Rect2(r, 0, 300, 100), Rect2(60, 60, 200, 200),
			Rect2(0, r, 100, 300), Rect2(0, 2500, 100, 100)]
	for rect: Rect2 in cut:
		assert_array(UI.corner_problems([_control(viewport, rect)])) \
				.override_failure_message("yakalanmadı %s" % rect).is_not_empty()
	for rect: Rect2 in fine:
		assert_array(UI.corner_problems([_control(viewport, rect)])) \
				.override_failure_message("yanlış alarm %s" % rect).is_empty()
	var list: ScrollContainer = ScrollContainer.new()
	viewport.add_child(list)
	var inside: Control = Control.new()
	list.add_child(inside)
	inside.position = Vector2.ZERO
	inside.size = Vector2(100, 100)
	assert_array(UI.corner_problems([inside])).is_empty()
	viewport.queue_free()


## Main güvenli alanı her arayüz ekranına uygular (ekransızda pay sıfır: ekranlar tam ekran).
func test_main_fits_every_ui_screen() -> void:
	GameManager.reset()
	var main: Node = auto_free(MAIN_SCENE.instantiate()) as Node
	add_child(main)
	await get_tree().process_frame
	var full: Rect2 = Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size)
	for screen: Node in main.get_node("%UI").get_children():
		assert_object((screen as Control).get_global_rect()).is_equal(full)
	GameManager.reset()


func _control(viewport: SubViewport, rect: Rect2) -> Control:
	var control: Control = Control.new()
	viewport.add_child(control)
	control.position = rect.position
	control.size = rect.size
	return control


func _bleeds(screen: Control) -> Array[Control]:
	var found: Array[Control] = []
	for node: Node in screen.find_children("*", "Control", true, false):
		if node.is_in_group(SafeArea.FULL_BLEED_GROUP):
			found.append(node as Control)
	return found
