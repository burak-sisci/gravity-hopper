extends GdUnitTestSuite
## Sonuç ekranı (M5-03, roadmap "UI kabulü"): iki kipte (sonuç, diriliş teklifi), beş en-boy
## oranında ve iki dilde öğeler çakışmaz, düğmeler dokunulabilir, en kötü değerlerle metinler
## sığar ve en kötü zeminde (karartmanın arkası beyaz) okunur. Gösterilen kazanç cüzdana girenle
## aynıdır; Dirilt yalnızca hak varken görünür ve turu sürdürür. Ölçüler ui_acceptance.gd'de.

const UI: GDScript = preload("res://tests/ui/ui_acceptance.gd")
const SCREEN_SCENE: PackedScene = preload("res://scenes/ui/results_screen.tscn")
## Sığması gereken en kötü değerler.
const WORST_HEIGHT: int = 99999
const WORST_GLIMMERS: int = 999999
## Görünür yaprak öğe sayısı: sonuç (yükseklik, rekor, kazanç, döküm, 3 düğme) ve teklif.
const RESULT_ITEMS: int = 7
const OFFER_ITEMS: int = 4

var _revived: int = 0
var _retries: int = 0
var _menus: int = 0


func before_test() -> void:
	_revived = 0
	_retries = 0
	_menus = 0
	Progression.reset()
	GameManager.reset()
	Events.player_revived.connect(_on_player_revived)
	Events.retry_requested.connect(_on_retry_requested)
	Events.menu_requested.connect(_on_menu_requested)


func after_test() -> void:
	Events.player_revived.disconnect(_on_player_revived)
	Events.retry_requested.disconnect(_on_retry_requested)
	Events.menu_requested.disconnect(_on_menu_requested)
	GameManager.reset()
	Progression.reset()
	Settings.apply_language()


## Her oranda, dilde ve kipte: öğeler ekranın içinde, çakışmıyor; düğmeler ≥ 48 dp, arası ≥ 8 dp.
func test_layout_holds_on_every_aspect_language_and_mode() -> void:
	for aspect: float in UI.ASPECTS:
		for locale: String in UI.LOCALES:
			TranslationServer.set_locale(locale)
			for offer: bool in [false, true]:
				var screen: ResultsScreen = await _open(aspect)
				_fill_worst(offer)
				await get_tree().process_frame
				var items: Array[Control] = UI.leaves(screen)
				assert_int(items.size()).is_equal(OFFER_ITEMS if offer else RESULT_ITEMS)
				var problems: Array[String] = UI.layout_problems(items,
						Rect2(Vector2.ZERO, screen.size))
				assert_array(problems).override_failure_message("%s %.3f teklif=%s: %s" % [
					locale, aspect, offer, problems]).is_empty()
				screen.get_parent().queue_free()


## İki dilde ve iki kipte, en kötü değerlerle: düğme yazıları kutularında, yazılar sütuna sığar
## (tek satır), font her harfi içerir. Yeni rekor ve "rekora X m" satırı ikisi de denenir.
func test_texts_fit_in_both_languages() -> void:
	for locale: String in UI.LOCALES:
		TranslationServer.set_locale(locale)
		for mode: int in 3:
			var screen: ResultsScreen = await _open(UI.ASPECTS[0])
			_fill_worst(mode == 2, mode == 1)
			await get_tree().process_frame
			var column: Control = screen.get_node("Content/Column") as Control
			var room: float = column.offset_right - column.offset_left
			for item: Control in UI.leaves(screen):
				var problems: Array[String] = UI.button_fit_problems(item as Button) \
						if item is Button else UI.label_fit_problems(item as Label, room)
				assert_array(problems).override_failure_message("%s kip %d: %s" % [
					locale, mode, problems]).is_empty()
			screen.get_parent().queue_free()


## Kontrast (WCAG), en kötü zeminde (karartmanın arkasında beyaz): düğme yazısı ≥ 4,5, kapalı
## düğme ≥ 3; her kipte ve her rekor tonunda yazıların çekirdeği ≥ 4,5.
func test_text_contrast_over_the_worst_background() -> void:
	var screen: ResultsScreen = await _open(UI.ASPECTS[0])
	var overlay: Color = (screen.get_node("%Overlay") as ColorRect).color
	var ground: Color = Color.WHITE.blend(overlay)
	assert_array(UI.button_contrast_problems(ground)).is_empty()
	for mode: int in 3:
		_fill_worst(mode == 2, mode == 1)
		for item: Control in UI.leaves(screen):
			if item is Label:
				var problems: Array[String] = UI.label_contrast_problems(item as Label, ground)
				assert_array(problems).override_failure_message("kip %d: %s" % [
					mode, problems]).is_empty()
	screen.get_parent().queue_free()


## Gerçek tur sonu (GameManager + Progression): ekranda yazan kazanç cüzdana girenle aynı, döküm
## toplanan ve bonusun toplamı; ilk tur yeni rekor, alçak tur "rekora X m" ile farkı gösterir.
func test_shown_earnings_equal_the_wallet() -> void:
	var screen: ResultsScreen = await _open(UI.ASPECTS[0])
	GameManager.begin_run(21, 1, RunLoadout.new())
	Events.height_changed.emit(130)
	Events.glimmer_collected.emit(9)
	Events.sector_entered.emit(3)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	var earned: Label = screen.get_node("%EarnedLabel") as Label
	var shown: Array[int] = _numbers(earned.text)
	assert_array(shown).is_equal([Progression.glimmers])
	assert_int(Progression.glimmers).is_greater(9)
	var parts: Array[int] = _numbers((screen.get_node("%BreakdownLabel") as Label).text)
	assert_int(parts.size()).is_equal(2)
	assert_int(parts[0]).is_equal(9)
	assert_int(parts[0] + parts[1]).is_equal(Progression.glimmers)
	var record: NeonLabel = screen.get_node("%RecordLabel") as NeonLabel
	assert_str(record.text).is_equal(tr("RESULTS_NEW_RECORD"))
	assert_int(record.tone).is_equal(GameTypes.NeonTone.RECORD)
	assert_array(_numbers((screen.get_node("%HeightLabel") as Label).text)).is_equal([130])
	var wallet_before: int = Progression.glimmers
	GameManager.begin_run(22, 1, RunLoadout.new())
	Events.height_changed.emit(45)
	Events.glimmer_collected.emit(4)
	Events.player_died.emit(GameTypes.DeathCause.WALL)
	assert_array(_numbers(earned.text)).is_equal([Progression.glimmers - wallet_before])
	assert_array(_numbers(record.text)).is_equal([130 - 45])
	assert_int(record.tone).is_not_equal(GameTypes.NeonTone.RECORD)
	screen.get_parent().queue_free()


## Hak varken ölüm teklif kipini açar (Dirilt ve Vazgeç; Tekrar ve Menü yok), Dirilt turu sürdürür;
## ikinci ölüm sonuç kipini açar, Dirilt görünmez. Vazgeç turu bitirir; düğmeler niyet yayar.
func test_revive_shows_only_with_a_right_and_continues_the_run() -> void:
	var screen: ResultsScreen = await _open(UI.ASPECTS[0])
	var revive: Button = screen.get_node("%ReviveButton") as Button
	var retry: Button = screen.get_node("%RetryButton") as Button
	var give_up: Button = screen.get_node("%GiveUpButton") as Button
	GameManager.begin_run(31, 1, _loadout(1))
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_bool(screen.is_offering()).is_true()
	assert_bool(revive.visible and give_up.visible).is_true()
	assert_bool(retry.visible or (screen.get_node("%MenuButton") as Button).visible).is_false()
	revive.pressed.emit()
	assert_int(_revived).is_equal(1)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.RUNNING)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_bool(screen.is_offering()).is_false()
	assert_bool(revive.visible).is_false()
	assert_bool(retry.visible).is_true()
	retry.pressed.emit()
	assert_int(_retries).is_equal(1)
	(screen.get_node("%MenuButton") as Button).pressed.emit()
	assert_int(_menus).is_equal(1)
	# Vazgeç: tur biter, kazanç cüzdanda, ekran sonuç kipine geçer.
	GameManager.begin_run(32, 1, _loadout(1))
	Events.glimmer_collected.emit(6)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	var wallet_before: int = Progression.glimmers
	give_up.pressed.emit()
	assert_bool(screen.is_offering()).is_false()
	assert_int(Progression.glimmers).is_greater(wallet_before)
	assert_array(_numbers((screen.get_node("%EarnedLabel") as Label).text)).is_equal([
		Progression.glimmers - wallet_before])
	assert_int(_revived).is_equal(1)
	# Hak yokken Dirilt hiç görünmez.
	GameManager.begin_run(33, 1, RunLoadout.new())
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_bool(revive.visible).is_false()
	screen.get_parent().queue_free()


## İçerik ölümden SHOW_DELAY sonra belirir (o ana dek görünmez, dokunuş almaz), sonra tam opak.
func test_content_appears_after_the_show_delay() -> void:
	var screen: ResultsScreen = await _open(UI.ASPECTS[0])
	var content: Control = screen.get_node("%Content") as Control
	screen.open()
	assert_bool(screen.visible).is_true()
	assert_bool(content.visible).is_false()
	await get_tree().create_timer(ResultsScreen.SHOW_DELAY * 0.8).timeout
	assert_bool(content.visible).is_false()
	await get_tree().create_timer(
			ResultsScreen.SHOW_DELAY * 0.2 + ResultsScreen.FADE_TIME + 0.1).timeout
	assert_bool(content.visible).is_true()
	assert_float(content.modulate.a).is_equal(1.0)
	screen.get_parent().queue_free()


## Oranı verilen ekranda sonuç ekranını kurar, içeriği beklemeden gösterir.
func _open(aspect: float) -> ResultsScreen:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = UI.canvas_size(aspect)
	add_child(viewport)
	var screen: ResultsScreen = SCREEN_SCENE.instantiate() as ResultsScreen
	viewport.add_child(screen)
	screen.open()
	screen.show_now()
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


## En kötü değerlerle doldurur: teklif kipi ya da sonuç kipi (yeni rekor ya da rekora uzak).
func _fill_worst(offer: bool, new_record: bool = false) -> void:
	if offer:
		Events.revive_offered.emit(WORST_HEIGHT)
		return
	var result: RunResult = RunResult.new()
	result.height_m = WORST_HEIGHT
	result.glimmers = WORST_GLIMMERS
	result.sector_bonus = WORST_GLIMMERS
	result.earned = WORST_GLIMMERS
	result.new_record = new_record
	result.best_height_m = WORST_HEIGHT * 2
	Events.run_ended.emit(result)


func _loadout(revives: int) -> RunLoadout:
	var loadout: RunLoadout = RunLoadout.new()
	loadout.revives = revives
	return loadout


## Yazıdaki sayılar (ekranda gösterilen değerler).
func _numbers(text: String) -> Array[int]:
	var found: Array[int] = []
	var pattern: RegEx = RegEx.create_from_string("\\d+")
	for hit: RegExMatch in pattern.search_all(text):
		found.append(int(hit.get_string()))
	return found


func _on_player_revived() -> void:
	_revived += 1


func _on_retry_requested() -> void:
	_retries += 1


func _on_menu_requested() -> void:
	_menus += 1
