extends GdUnitTestSuite
## Debug İlerleme sayfası (M4-03, architecture.md §13): cüzdanı, seviyeleri ve fiyatları
## gösterir; satın alma düğmesi cüzdan yetmezse kapalı; +1000 Glimmer ve kaydı sıfırlama
## kayda iner. İzler sayfası (M4-08): satın alma, kuşanma ve başarım izini debug için açma.
## Kontrol noktası (M4-09): başlangıç sektörü yalnızca açık sektörler arasında döner.
## Testler geçici kayıtla çalışır.

var _panel: ProgressPanel
var _locale: String


func before_test() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	Progression.reset()
	_panel = auto_free(ProgressPanel.new()) as ProgressPanel
	add_child(_panel)


func after_test() -> void:
	Progression.reset()
	TranslationServer.set_locale(_locale)


func test_shows_wallet_levels_and_prices() -> void:
	assert_str(_panel.summary_label().text).contains("Cüzdan 0 Glimmer")
	assert_str(_panel.level_label(&"magnet").text).is_equal("MAGNET  0/5")
	assert_str(_panel.buy_button(&"magnet").text).is_equal("Al 100")
	assert_bool(_panel.buy_button(&"magnet").disabled).is_true()
	assert_str(_panel.level_label(&"second_chance").text).is_equal("SECOND CHANCE  0/1")


func test_gift_then_buy_updates_the_page_and_the_save() -> void:
	_press("+1000 Glimmer")
	assert_int(Progression.glimmers).is_equal(1000)
	assert_int(SaveManager.load_game()["glimmers"]).is_equal(1000)
	assert_bool(_panel.buy_button(&"magnet").disabled).is_false()
	_panel.buy_button(&"magnet").pressed.emit()
	assert_int(Progression.upgrade_level(&"magnet")).is_equal(1)
	assert_str(_panel.level_label(&"magnet").text).is_equal("MAGNET  1/5")
	assert_str(_panel.buy_button(&"magnet").text).is_equal("Al 200")
	assert_str(_panel.summary_label().text).contains("Cüzdan 900 Glimmer")
	# İkinci Şans 5000: cüzdan yetmiyor.
	assert_bool(_panel.buy_button(&"second_chance").disabled).is_true()
	for i: int in 5:
		_press("+1000 Glimmer")
	_panel.buy_button(&"second_chance").pressed.emit()
	assert_str(_panel.buy_button(&"second_chance").text).is_equal("En üst")
	assert_bool(_panel.buy_button(&"second_chance").disabled).is_true()


func test_reset_clears_the_save() -> void:
	_press("+1000 Glimmer")
	_panel.buy_button(&"shield").pressed.emit()
	_press("Kaydı sıfırla")
	assert_int(Progression.glimmers).is_equal(0)
	assert_int(Progression.upgrade_level(&"shield")).is_equal(0)
	assert_int(SaveManager.load_game()["glimmers"]).is_equal(0)
	assert_str(_panel.level_label(&"shield").text).is_equal("SHIELD  0/5")


func test_trail_page_buys_equips_and_grants() -> void:
	assert_bool(_panel.showing_trails()).is_false()
	_panel.page_button().pressed.emit()
	assert_bool(_panel.showing_trails()).is_true()
	assert_str(_panel.page_button().text).is_equal("Yükseltmeler ›")
	assert_str(_panel.trail_label(&"trail_default").text).is_equal("NEON  · kuşanılı")
	assert_str(_panel.trail_button(&"trail_default").text).is_equal("Kuşanılı")
	assert_bool(_panel.trail_button(&"trail_default").disabled).is_true()
	assert_str(_panel.trail_label(&"trail_frost").text).is_equal("FROST  · 300 Glimmer")
	assert_str(_panel.trail_button(&"trail_frost").text).is_equal("Al 300")
	assert_bool(_panel.trail_button(&"trail_frost").disabled).is_true()
	_press("+1000 Glimmer")
	_panel.trail_button(&"trail_frost").pressed.emit()
	assert_bool(Progression.owns_trail(&"trail_frost")).is_true()
	assert_int(Progression.glimmers).is_equal(700)
	assert_str(_panel.trail_button(&"trail_frost").text).is_equal("Kuşan")
	assert_str(_panel.trail_label(&"trail_frost").text).is_equal("FROST  · sahip")
	_panel.trail_button(&"trail_frost").pressed.emit()
	assert_str(String(Progression.equipped_trail())).is_equal("trail_frost")
	assert_str(_panel.trail_button(&"trail_frost").text).is_equal("Kuşanılı")
	assert_str(_panel.trail_button(&"trail_default").text).is_equal("Kuşan")
	# Başarım izi satılmaz; debug düğmesi bedelsiz açar ve kaydeder.
	var close_call: String = _panel.trail_label(&"trail_close_call").text
	assert_str(close_call).is_equal("CLOSE CALL  · başarım: 500 kıl payı")
	assert_str(_panel.trail_button(&"trail_close_call").text).is_equal("Aç (debug)")
	_panel.trail_button(&"trail_close_call").pressed.emit()
	assert_int(Progression.glimmers).is_equal(700)
	var owned: Array = (SaveManager.load_game()["trails"] as Dictionary)["owned"]
	assert_array(owned).contains(["trail_close_call"])
	_panel.page_button().pressed.emit()
	assert_bool(_panel.showing_trails()).is_false()
	assert_str(_panel.page_button().text).is_equal("İzler ›")


func test_start_sector_cycles_through_unlocked_sectors() -> void:
	assert_str(_panel.sector_label().text).is_equal("Başlangıç: S1  · açık 1 sektör")
	assert_bool(_panel.sector_button().disabled).is_true()
	Events.sector_entered.emit(2)
	Events.sector_entered.emit(3)
	assert_str(_panel.sector_label().text).is_equal("Başlangıç: S1  · açık 3 sektör")
	assert_bool(_panel.sector_button().disabled).is_false()
	var picked: Array[int] = []
	for i: int in 3:
		_panel.sector_button().pressed.emit()
		picked.append(Progression.start_sector)
	assert_array(picked).is_equal([2, 3, 1])
	_panel.sector_button().pressed.emit()
	assert_str(_panel.sector_label().text).is_equal("Başlangıç: S2  · açık 3 sektör")
	assert_int(SaveManager.load_game()["start_sector"]).is_equal(2)


func _press(text: String) -> void:
	for node: Node in _panel.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			(node as Button).pressed.emit()
			return
	fail("Düğme yok: %s" % text)
