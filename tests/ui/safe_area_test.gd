extends GdUnitTestSuite
## Güvenli alan (M6-01, architecture.md §5.3): cihazın bildirdiği güvenli alan tuval pikseline
## doğru çevrilir; ekranlar içeri alınırken zeminleri ve karartmaları bütün ekranı kaplamaya
## devam eder. Ekranların öğeleri iki kötü telefon profilinin güvenli alanında ve köşelerden uzakta:
## her ekran testinin yerleşim denetimi (`UI.apply_safe_profile`, `UI.profile_problems`).

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
## Kabul kriterinin (roadmap M6-01, ADR-102) en küçük profilleri: (a) üst 150, yan ve alt 60;
## (b) üst 150, yan ve alt 40 + 150 px köşe. UI kabulünün profilleri bunlardan küçük olamaz.
const REQUIRED_PROFILES: Array[Vector4] = [Vector4(60.0, 150.0, 60.0, 60.0),
		Vector4(40.0, 150.0, 40.0, 40.0)]
const REQUIRED_CORNERS: Array[float] = [0.0, 150.0]


func after_test() -> void:
	SafeArea.simulate = false
	SafeArea.simulated_insets = Vector4.ZERO


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


## Kötü telefon profilleri kabul kriterinin altına inmez: küçültülürse ekranların yerleşim
## testleri daha kolay bir telefonda ölçer (ADR-102'deki 60 → 40 px indirimi gibi).
func test_profiles_are_not_weaker_than_required() -> void:
	assert_int(UI.SAFE_PROFILES.size()).is_equal(REQUIRED_PROFILES.size())
	for i: int in REQUIRED_PROFILES.size():
		var have: Vector4 = UI.SAFE_PROFILES[i]
		var need: Vector4 = REQUIRED_PROFILES[i]
		for side: int in 4:
			assert_float(have[side]).override_failure_message("profil %d kenar %d: %.0f < %.0f" % [
				i, side, have[side], need[side]]).is_greater_equal(need[side])
		assert_float(UI.PROFILE_CORNERS[i]).is_greater_equal(REQUIRED_CORNERS[i])
	# Profil (a) yanlarda tasarım payını aşar: içerik gerçekten daralır (yoksa ölçü boşa geçer).
	var shift: Vector4 = SafeArea.content_insets(UI.SAFE_PROFILES[0])
	assert_float(minf(shift.x, minf(shift.z, shift.w))).is_greater(0.0)


## Her ekranda ve profilde: içerik güvenli alana iner, zemin (FULL_BLEED_GROUP) yine bütün
## ekranı kaplar; pay sıfırken ekran tam ekrandır (güvenli alanı olmayan cihazda yerleşim
## değişmez).
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
			var bleeds: Array[Control] = _bleeds(screen)
			assert_int(bleeds.size()).override_failure_message("%s zeminsiz" % screen.name) \
					.is_greater_equal(1)
			for profile: int in UI.SAFE_PROFILES.size():
				UI.apply_safe_profile(screen, profile)
				var shift: Vector4 = SafeArea.content_insets(UI.SAFE_PROFILES[profile])
				assert_object(screen.get_global_rect()).is_equal(_shrunk(full, shift))
				for bleed: Control in bleeds:
					assert_object(bleed.get_global_rect()).override_failure_message("%s/%s %s" % [
						screen.name, bleed.name, bleed.get_global_rect()]).is_equal(full)
			viewport.queue_free()


## Sütun (COLUMN_GROUP): yer yetince sahnedeki tasarım genişliğinde, ortada; ekran daralınca
## yanlarda DESIGN_MARGINS kadar pay bırakarak daralır; pay kalkınca tasarım genişliğine döner
## (tekrarlanan sığdırma genişliği kaydırmaz). Geniş ekranda büyümez.
func test_columns_shrink_only_when_the_screen_is_narrow() -> void:
	for width: int in [1080, 3413]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(width, 1920)
		add_child(viewport)
		var screen: Control = Control.new()
		viewport.add_child(screen)
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		var column: Control = Control.new()
		screen.add_child(column)
		column.add_to_group(SafeArea.COLUMN_GROUP)
		column.anchor_left = 0.5
		column.anchor_right = 0.5
		column.offset_left = -500.0
		column.offset_right = 500.0
		var margins: float = SafeArea.DESIGN_MARGINS.x + SafeArea.DESIGN_MARGINS.z
		for shift: Vector4 in [Vector4.ZERO, Vector4(20, 90, 20, 20), Vector4(100, 0, 60, 0),
				Vector4.ZERO]:
			SafeArea.fit(screen, shift)
			var room: float = width - shift.x - shift.z - margins
			var rect: Rect2 = column.get_global_rect()
			assert_float(rect.size.x).override_failure_message("%d %s: %.0f" % [width, shift,
					rect.size.x]).is_equal_approx(minf(1000.0, room), 0.01)
			assert_float(rect.get_center().x).is_equal_approx(
					shift.x + (width - shift.x - shift.z) * 0.5, 0.01)
		viewport.queue_free()


## Köşe ölçüsünün kendisi: köşe karesinde ve çeyrek dairenin dışında kalan öğe yakalanır;
## dairenin içinde ya da köşe karesinin dışında kalan, kaydırılan listedeki ve ekran dışındaki
## öğe sayılmaz. Yarıçap 0 köşe ölçmez.
func test_corner_metric_catches_only_cut_items() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 2400)
	add_child(viewport)
	# En büyük profil köşesiyle (profiller değişirse ölçünün kendi testi de onu izler).
	var r: float = float(UI.PROFILE_CORNERS.max())
	var cut: Array[Rect2] = [Rect2(0, 0, 100, 100), Rect2(1000, 2320, 80, 80),
			Rect2(20, 2300, 200, 80)]
	var fine: Array[Rect2] = [Rect2(r, 0, 300, 100), Rect2(60, 60, 200, 200),
			Rect2(0, r, 100, 300), Rect2(0, 2500, 100, 100)]
	for rect: Rect2 in cut:
		var control: Control = _control(viewport, rect)
		assert_array(UI.corner_problems([control], r)) \
				.override_failure_message("yakalanmadı %s" % rect).is_not_empty()
		assert_array(UI.corner_problems([control], 0.0)).is_empty()
	for rect: Rect2 in fine:
		assert_array(UI.corner_problems([_control(viewport, rect)], r)) \
				.override_failure_message("yanlış alarm %s" % rect).is_empty()
	var list: ScrollContainer = ScrollContainer.new()
	viewport.add_child(list)
	var inside: Control = Control.new()
	list.add_child(inside)
	inside.position = Vector2.ZERO
	inside.size = Vector2(100, 100)
	assert_array(UI.corner_problems([inside], r)).is_empty()
	viewport.queue_free()


## Ekransızda pay sıfır: Main'in bütün arayüz ekranları tam ekran.
func test_main_without_insets_keeps_screens_full() -> void:
	GameManager.reset()
	var main: Node = auto_free(MAIN_SCENE.instantiate()) as Node
	add_child(main)
	await get_tree().process_frame
	var full: Rect2 = Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size)
	for screen: Node in main.get_node("%UI").get_children():
		assert_object((screen as Control).get_global_rect()).is_equal(full)
	GameManager.reset()


## Cihaz güvenli alan bildirince (debug taklidi, gerçek açılış yolu): Main her arayüz ekranını
## tasarım payını aşan kısım kadar içeri alır, zeminleri tam ekran kalır; pencere boyu değişince
## (size_changed) yeni pay uygulanır. `_apply_safe_area` çağrısı ya da bağlantısı kalkarsa düşer.
func test_main_applies_device_insets_and_follows_changes() -> void:
	GameManager.reset()
	SafeArea.simulated_insets = UI.SAFE_PROFILES[0]
	SafeArea.simulate = true
	var main: Node = auto_free(MAIN_SCENE.instantiate()) as Node
	add_child(main)
	await get_tree().process_frame
	var full: Rect2 = Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size)
	var screens: Array[Node] = main.get_node("%UI").get_children()
	assert_int(screens.size()).is_greater_equal(SCREENS.size() - 2)
	_assert_main_fitted(screens, full, SafeArea.content_insets(UI.SAFE_PROFILES[0]))
	var later: Vector4 = Vector4(0.0, 200.0, 0.0, 100.0)
	SafeArea.simulated_insets = later
	main.get_viewport().size_changed.emit()
	await get_tree().process_frame
	_assert_main_fitted(screens, full, SafeArea.content_insets(later))
	GameManager.reset()


func _assert_main_fitted(screens: Array[Node], full: Rect2, shift: Vector4) -> void:
	assert_float(shift.length()).is_greater(0.0)
	for screen: Node in screens:
		var control: Control = screen as Control
		assert_object(control.get_global_rect()).override_failure_message("%s %s ≠ %s" % [
			control.name, control.get_global_rect(), _shrunk(full, shift)]) \
				.is_equal(_shrunk(full, shift))
		for bleed: Control in _bleeds(control):
			assert_object(bleed.get_global_rect()).override_failure_message("%s/%s %s" % [
				control.name, bleed.name, bleed.get_global_rect()]).is_equal(full)


func _shrunk(full: Rect2, shift: Vector4) -> Rect2:
	return Rect2(shift.x, shift.y, full.size.x - shift.x - shift.z,
			full.size.y - shift.y - shift.w)


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
