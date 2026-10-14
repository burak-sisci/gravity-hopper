extends GdUnitTestSuite
## HUD (M1-10, architecture.md §12): yalnızca Events'i dinler; metinler çeviri anahtarlarından
## gelir ve dil değişince yenilenir.

const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const TUNING: TuningConfig = preload("res://data/tuning/default_tuning.tres")

var _hud: Control
var _locale: String


func before_test() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_hud = auto_free(HUD_SCENE.instantiate()) as Control
	add_child(_hud)


func after_test() -> void:
	TranslationServer.set_locale(_locale)


func test_height_follows_events() -> void:
	Events.run_started.emit(1, 1)
	Events.height_changed.emit(37)
	assert_str(_height_label().text).is_equal("37 m")
	assert_bool(_best_label().visible).is_false()


func test_best_appears_after_first_run() -> void:
	Events.run_started.emit(1, 1)
	Events.height_changed.emit(37)
	Events.run_ended.emit(_result(37))
	assert_bool(_best_label().visible).is_true()
	assert_str(_best_label().text).is_equal("BEST 37 m")
	Events.run_started.emit(2, 1)
	assert_str(_height_label().text).is_equal("0 m")
	Events.run_ended.emit(_result(12))
	assert_str(_best_label().text).override_failure_message(
			"Daha kısa tur rekoru düşürmemeli").is_equal("BEST 37 m")


func test_language_change_rewrites_text() -> void:
	Events.run_ended.emit(_result(37))
	TranslationServer.set_locale("tr")
	await get_tree().process_frame
	assert_str(_best_label().text).is_equal("EN İYİ 37 m")


func test_glimmer_counter() -> void:
	Events.run_started.emit(1, 1)
	assert_str(_glimmer_label().text).is_equal("0 GLIMMER")
	Events.glimmer_collected.emit(1)
	Events.glimmer_collected.emit(3)
	assert_str(_glimmer_label().text).is_equal("4 GLIMMER")
	Events.run_started.emit(2, 1)
	assert_str(_glimmer_label().text).is_equal("0 GLIMMER")


func test_wall_vignette_follows_proximity() -> void:
	var vignette: Control = _hud.get_node("%WallVignette") as Control
	assert_float(vignette.modulate.a).is_equal(0.0)
	Events.wall_proximity_changed.emit(0.5)
	assert_float(vignette.modulate.a).is_equal_approx(0.5, 0.0001)
	assert_int(vignette.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	Events.run_started.emit(3, 1)
	assert_float(vignette.modulate.a).is_equal(0.0)


## İnceltilmiş vinyet (M3-09): iki kenar şeridi, koridorun içine taşmıyor, dokunuş yutmuyor.
func test_wall_vignette_stays_outside_corridor() -> void:
	var strips: Array[Node] = _hud.get_node("%WallVignette").get_children()
	assert_int(strips.size()).is_equal(2)
	var width: float = _hud.get_viewport_rect().size.x
	var margin: float = (width - TuningConfig.to_px(TUNING.corridor_width)) * 0.5
	for node: Node in strips:
		var strip: Control = node as Control
		var rect: Rect2 = strip.get_global_rect()
		assert_int(strip.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		assert_float(rect.size.x).is_greater(0.0)
		assert_bool(rect.end.x <= margin or rect.position.x >= width - margin).override_failure_message(
				"%s koridorun içine taşıyor: %s" % [strip.name, rect]).is_true()


func test_sector_banner_shows_name_and_fades() -> void:
	Events.run_started.emit(1, 1)
	assert_bool(_banner().visible).is_false()
	Events.sector_entered.emit(2)
	# Afiş dalgayla gelir (M3-08): renk dalgası ekranın altından afişin hizasına varınca.
	assert_bool(_banner().visible).is_false()
	var waited: int = 0
	while not _banner().visible and waited < 120:
		await get_tree().process_frame
		waited += 1
	assert_int(waited).is_greater(1)
	assert_float(waited / 60.0).is_less_equal(Neon.STYLE.wave_time + 0.1)
	assert_str(_banner().text).is_equal("SECTOR 2 · DATA STREAM")
	TranslationServer.set_locale("tr")
	await get_tree().process_frame
	assert_str(_banner().text).is_equal("SEKTÖR 2 · VERİ AKIŞI")
	# Büyüyerek oturur (0,25 sn), 2 sn görünür, 0,4 sn'de söner (60 Hz'de 159 kare).
	for i: int in 170:
		await get_tree().process_frame
	assert_bool(_banner().visible).is_false()


func test_banner_on_start_from_later_sector() -> void:
	Events.run_started.emit(1, 3)
	assert_bool(_banner().visible).is_true()
	assert_str(_banner().text).is_equal("SECTOR 3 · FIREWALL")
	Events.run_started.emit(2, 1)
	assert_bool(_banner().visible).is_false()


## Kıl payı yazısı ve kombo göstergesi (M3-12): iki dilde; yazı söner, gösterge zincirle biter.
func test_near_miss_text_and_combo() -> void:
	Events.run_started.emit(1, 1)
	assert_bool(_near_miss().visible).is_false()
	assert_bool(_combo().visible).is_false()
	Events.near_miss.emit(1, 1)
	assert_bool(_near_miss().visible).is_true()
	assert_str(_near_miss().text).is_equal("NEAR MISS!")
	assert_bool(_combo().visible).is_false()
	Events.near_miss.emit(3, 2)
	assert_bool(_combo().visible).is_true()
	assert_str(_combo().text).is_equal("×2")
	TranslationServer.set_locale("tr")
	await get_tree().process_frame
	assert_str(_near_miss().text).is_equal("KIL PAYI!")
	Events.near_miss.emit(6, 3)
	assert_str(_combo().text).is_equal("×3")
	# Yazı 0,15 + 0,45 + 0,3 sn sonra söner; gösterge zincir bitene kadar kalır.
	for i: int in 60:
		await get_tree().process_frame
	assert_bool(_near_miss().visible).is_false()
	assert_bool(_combo().visible).is_true()
	Events.combo_ended.emit()
	assert_bool(_combo().visible).is_false()
	Events.near_miss.emit(3, 2)
	Events.run_started.emit(2, 1)
	assert_bool(_combo().visible).is_false()
	assert_bool(_near_miss().visible).is_false()


func _result(height_m: int) -> RunResult:
	var result: RunResult = RunResult.new()
	result.height_m = height_m
	return result


func _height_label() -> Label:
	return _hud.get_node("%HeightLabel") as Label


func _best_label() -> Label:
	return _hud.get_node("%BestLabel") as Label


func _glimmer_label() -> Label:
	return _hud.get_node("%GlimmerLabel") as Label


func _banner() -> Label:
	return _hud.get_node("%SectorBanner") as Label


func _near_miss() -> Label:
	return _hud.get_node("%NearMissLabel") as Label


func _combo() -> Label:
	return _hud.get_node("%ComboLabel") as Label
