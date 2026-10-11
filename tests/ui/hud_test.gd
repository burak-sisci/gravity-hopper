extends GdUnitTestSuite
## HUD (M1-10, architecture.md §12): yalnızca Events'i dinler; metinler çeviri anahtarlarından
## gelir ve dil değişince yenilenir.

const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")

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


func _result(height_m: int) -> RunResult:
	var result: RunResult = RunResult.new()
	result.height_m = height_m
	return result


func _height_label() -> Label:
	return _hud.get_node("%HeightLabel") as Label


func _best_label() -> Label:
	return _hud.get_node("%BestLabel") as Label
