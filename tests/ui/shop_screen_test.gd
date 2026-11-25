extends GdUnitTestSuite
## Mağaza (M5-04, roadmap "UI kabulü"): beş en-boy oranında, iki dilde ve iki sekmede öğeler
## çakışmaz, ekranda (liste kaydırılır: kartlar listenin genişliğinde) ve dokunulabilir; her
## seviyenin ve her iz durumunun metni gerçek fontla sığar ve okunur. Davranış Progression'la
## aynı: al, kuşan, cüzdan yetmezse kapalı. İz önizlemesi oyundaki izin kendisi.
## Ölçüler ve eşikler ortak: ui_acceptance.gd.

const UI: GDScript = preload("res://tests/ui/ui_acceptance.gd")
const SHOP_SCENE: PackedScene = preload("res://scenes/ui/shop_screen.tscn")
const WORST_GLIMMERS: int = 999999
## Üst şerit: geri, cüzdan, iki sekme.
const HEADER_ITEMS: int = 4
## Kart başına öğe: yükseltme (ad, seviye, açıklama, etki, düğme), iz (ad, koşul, düğme).
const UPGRADE_ITEMS: int = 5
const TRAIL_ITEMS: int = 3
const MAX_DESC_LINES: int = 2
const MAX_EFFECT_LINES: int = 2
const MAX_STATUS_LINES: int = 2


func before_test() -> void:
	Progression.reset()
	GameManager.reset()


func after_test() -> void:
	GameManager.reset()
	Progression.reset()
	Settings.apply_language()


## Her oranda, dilde ve sekmede: üst şerit ekranın içinde ve çakışmasız; liste ekranın içinde,
## şeridin altında; kartların öğeleri listenin genişliğinde, çakışmasız, düğmeler ≥ 48 dp ve
## aralarında ≥ 8 dp; kartlar listeden geniş değil (sığmayan yazı kartı büyütmez); sürükleme
## listeye ulaşır.
func test_layout_holds_on_every_aspect_language_and_tab() -> void:
	for profile: int in UI.SAFE_PROFILES.size():
		for aspect: float in UI.ASPECTS:
			for locale: String in UI.LOCALES:
				TranslationServer.set_locale(locale)
				for tab: GameTypes.ShopTab in [GameTypes.ShopTab.UPGRADES, GameTypes.ShopTab.TRAILS]:
					var shop: ShopScreen = await _open(aspect, profile)
					shop.select_tab(tab)
					await get_tree().process_frame
					var where: String = "profil %d %s %.3f sekme %d" % [profile, locale, aspect, tab]
					_assert_layout(shop, tab, where, profile)
					shop.get_parent().queue_free()


## Metinler iki dilde gerçek fontla sığar: her yükseltmenin her seviyesinde (0 … en üst) ve her
## izin her durumunda (kilitli, alınabilir, alınamaz, sahip, kuşanılmış). Açıklama ve etki en çok
## iki satır; tek satırlık yazılar kartı büyütmez; yazılar ≥ 36 px; font her harfi içerir.
func test_texts_fit_at_every_level_and_state() -> void:
	for locale: String in UI.LOCALES:
		TranslationServer.set_locale(locale)
		Progression.reset()
		Progression.glimmers = WORST_GLIMMERS
		var shop: ShopScreen = await _open(UI.ASPECTS[0])
		var wallet: Label = shop.get_node("%Wallet") as Label
		assert_array(UI.label_fit_problems(wallet, wallet.offset_right - wallet.offset_left)) \
				.override_failure_message("%s cüzdan" % locale).is_empty()
		for level: int in range(0, 6):
			for card: UpgradeCard in shop.upgrade_cards():
				Progression.set_upgrade_level(card.def.id, level)
			shop.refresh()
			await get_tree().process_frame
			_assert_fit(shop, GameTypes.ShopTab.UPGRADES, "%s Sv%d" % [locale, level])
		shop.select_tab(GameTypes.ShopTab.TRAILS)
		for state: int in 3:
			_set_trail_state(state)
			shop.refresh()
			await get_tree().process_frame
			_assert_fit(shop, GameTypes.ShopTab.TRAILS, "%s iz durumu %d" % [locale, state])
		shop.get_parent().queue_free()


## Kontrast (WCAG): kart yazıları kart zemininde ≥ 4,5, düğme yazısı kartın üstündeki dolguda
## ≥ 4,5 (kapalı ≥ 3); cüzdan ve sekmeler ekran zemininde.
func test_text_contrast() -> void:
	Progression.glimmers = WORST_GLIMMERS
	var shop: ShopScreen = await _open(UI.ASPECTS[0])
	var ground: Color = (shop.get_node("Background") as ColorRect).color
	var card_ground: Color = ground.blend(UpgradeCard.FILL)
	assert_array(UI.button_contrast_problems(ground)).is_empty()
	assert_array(UI.button_contrast_problems(card_ground)).is_empty()
	assert_array(UI.label_contrast_problems(shop.get_node("%Wallet") as Label, ground)).is_empty()
	for tab: GameTypes.ShopTab in [GameTypes.ShopTab.UPGRADES, GameTypes.ShopTab.TRAILS]:
		shop.select_tab(tab)
		_set_trail_state(0)
		shop.refresh()
		for item: Control in UI.leaves(_list(shop, tab)):
			if item is Label:
				var problems: Array[String] = UI.label_contrast_problems(item as Label, card_ground)
				assert_array(problems).override_failure_message(str(problems)).is_empty()
	shop.get_parent().queue_free()


## Al: cüzdan fiyatın 1 eksiğiyken düğme kapalı, tam fiyatta açık; basınca Progression'daki gibi
## seviye 1 artar, cüzdan fiyat kadar azalır, düğme sonraki fiyatı yazar. En üstte EN ÜST, kapalı.
func test_buying_upgrades_matches_progression() -> void:
	var shop: ShopScreen = await _open(UI.ASPECTS[0])
	for card: UpgradeCard in shop.upgrade_cards():
		var id: StringName = card.def.id
		var buy: Button = card.get_node("%BuyButton") as Button
		for level: int in card.def.max_level():
			var cost: int = Progression.upgrade_cost(id)
			Progression.glimmers = cost - 1
			shop.refresh()
			assert_bool(buy.disabled).override_failure_message("%s Sv%d: %d eksik cüzdanla açık" % [
				id, level, cost - 1]).is_true()
			buy.pressed.emit()
			assert_int(Progression.upgrade_level(id)).is_equal(level)
			Progression.glimmers = cost
			shop.refresh()
			assert_str(buy.text).is_equal(str(cost))
			assert_bool(buy.disabled).is_false()
			buy.pressed.emit()
			assert_int(Progression.upgrade_level(id)).is_equal(level + 1)
			assert_int(Progression.glimmers).is_equal(0)
		assert_str(buy.text).is_equal("SHOP_MAXED")
		assert_bool(buy.disabled).is_true()
		var label: Label = card.get_node("%EffectLabel") as Label
		assert_str(label.text).is_equal(
				tr("SHOP_NOW") % UpgradeCard.effect_text(card.def, card.def.max_level()))
	shop.get_parent().queue_free()


## Etki metni seviyenin değerini birimiyle yazar: ondalık dilin ayırıcısıyla, oran yüzde, Kalkan
## Sv1 (yenilenme 0) yalnızca başta kalkan.
func test_effect_texts_show_the_level_values() -> void:
	TranslationServer.set_locale("tr")
	var magnet: UpgradeDef = Progression.UPGRADES.get_def(&"magnet")
	assert_str(UpgradeCard.effect_text(magnet, 1)).is_equal(
			tr("UPGRADE_MAGNET_EFFECT") % "1,8")
	var boost: UpgradeDef = Progression.UPGRADES.get_def(&"glimmer_boost")
	assert_str(UpgradeCard.effect_text(boost, 1)).is_equal("+%10 Glimmer")
	var shield: UpgradeDef = Progression.UPGRADES.get_def(&"shield")
	assert_str(UpgradeCard.effect_text(shield, 1)).is_equal(tr("UPGRADE_SHIELD_EFFECT_ZERO"))
	assert_str(UpgradeCard.effect_text(shield, 2)).is_equal(
			tr("UPGRADE_SHIELD_EFFECT") % "1500")
	TranslationServer.set_locale("en")
	assert_str(UpgradeCard.effect_text(magnet, 1)).is_equal(
			tr("UPGRADE_MAGNET_EFFECT") % "1.8")
	assert_str(UpgradeCard.effect_text(boost, 5)).is_equal("+50% Glimmers")


## İzler: satın alınan iz cüzdan yetmezken kapalı; alınınca cüzdan fiyat kadar azalır, iz
## kuşanılır (KUŞANILDI, kapalı), varsayılan iz KUŞAN'a döner ve basınca yeniden kuşanılır.
## Başarım izi koşulunu yazar, KİLİTLİ ve kapalıdır; açılınca kuşanılabilir.
func test_trails_buy_equip_and_lock_like_progression() -> void:
	var shop: ShopScreen = await _open(UI.ASPECTS[0])
	var bought: TrailCard = _card_with(shop, GameTypes.TrailUnlock.PURCHASE)
	var default_card: TrailCard = shop.trail_cards()[0]
	var action: Button = bought.get_node("%ActionButton") as Button
	Progression.glimmers = bought.def.cost - 1
	shop.refresh()
	assert_bool(action.disabled).is_true()
	assert_str(action.text).is_equal(str(bought.def.cost))
	Progression.glimmers = bought.def.cost
	shop.refresh()
	assert_bool(action.disabled).is_false()
	action.pressed.emit()
	assert_bool(Progression.owns_trail(bought.def.id)).is_true()
	assert_int(Progression.glimmers).is_equal(0)
	assert_str(String(Progression.equipped_trail())).is_equal(String(bought.def.id))
	assert_str(action.text).is_equal("SHOP_EQUIPPED")
	assert_bool(action.disabled).is_true()
	var default_action: Button = default_card.get_node("%ActionButton") as Button
	assert_str(default_action.text).is_equal("SHOP_EQUIP")
	default_action.pressed.emit()
	assert_str(String(Progression.equipped_trail())).is_equal(String(default_card.def.id))
	assert_str(action.text).is_equal("SHOP_EQUIP")
	var locked: TrailCard = _card_with(shop, GameTypes.TrailUnlock.NEAR_MISSES)
	var locked_action: Button = locked.get_node("%ActionButton") as Button
	assert_str(locked_action.text).is_equal("SHOP_LOCKED")
	assert_bool(locked_action.disabled).is_true()
	assert_str((locked.get_node("%StatusLabel") as Label).text).contains(str(locked.def.goal))
	Progression.grant_trail(locked.def.id)
	assert_str(locked_action.text).is_equal("SHOP_EQUIP")
	assert_str((locked.get_node("%StatusLabel") as Label).text).is_empty()
	shop.get_parent().queue_free()


## Önizleme oyundaki izin kendisi: aynı tanım ve seçili sektörün çevre rengiyle kurulan Trail'le
## renk geçişi, parlama rengi ve kalınlıkları aynı (oyundaki izler arası OKLab ayrımı
## trail_catalog_test'te; önizleme aynı olduğu için o ayrım ekranda da geçerli). Noktalar
## önizleme kutusunun içinde.
func test_previews_equal_the_game_trails() -> void:
	Events.sector_entered.emit(4)
	Progression.select_start_sector(4)
	var shop: ShopScreen = await _open(UI.ASPECTS[0])
	shop.select_tab(GameTypes.ShopTab.TRAILS)
	await get_tree().process_frame
	var ambient: Color = shop.sectors.def_at(4).palette.ambient
	for card: TrailCard in shop.trail_cards():
		var game: Trail = auto_free(Trail.new()) as Trail
		game.apply_def(card.def)
		game.set_ambient(ambient)
		var preview: Trail = card.preview_trail()
		assert_array(Array(preview.gradient.colors)).override_failure_message(
				"%s renk geçişi" % card.def.id).is_equal(Array(game.gradient.colors))
		assert_array(Array(preview.gradient.offsets)).is_equal(Array(game.gradient.offsets))
		assert_that(preview.glow_color).override_failure_message(
				"%s parlama" % card.def.id).is_equal(game.glow_color)
		assert_float(preview.width).is_equal(game.width)
		assert_float(preview.glow_width_scale).is_equal(game.glow_width_scale)
		var box: Rect2 = (card.get_node("%Preview") as Control).get_global_rect()
		for point: Vector2 in preview.points:
			assert_bool(box.has_point(preview.to_global(point))).override_failure_message(
					"%s noktası %s kutu dışında" % [card.def.id, point]).is_true()
	shop.get_parent().queue_free()


## Gezinme: menüden mağaza istenen sekmeyle açılır (durum SHOP), geri menüye döner; sonuç
## ekranından da açılır. Sekme düğmeleri listeyi değiştirir.
func test_navigation_between_menu_results_and_shop() -> void:
	var shop: ShopScreen = await _open(UI.ASPECTS[0])
	GameManager.change_state(GameTypes.AppState.MENU)
	Events.shop_requested.emit(GameTypes.ShopTab.TRAILS)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.SHOP)
	assert_int(shop.tab).is_equal(GameTypes.ShopTab.TRAILS)
	assert_bool((shop.get_node("%TrailsList") as Control).visible).is_true()
	assert_bool((shop.get_node("%UpgradesList") as Control).visible).is_false()
	(shop.get_node("%UpgradesTab") as Button).pressed.emit()
	assert_bool((shop.get_node("%UpgradesList") as Control).visible).is_true()
	(shop.get_node("%BackButton") as Button).pressed.emit()
	assert_int(GameManager.state).is_equal(GameTypes.AppState.MENU)
	GameManager.change_state(GameTypes.AppState.RUNNING)
	GameManager.change_state(GameTypes.AppState.RESULTS)
	Events.shop_requested.emit(GameTypes.ShopTab.UPGRADES)
	assert_int(GameManager.state).is_equal(GameTypes.AppState.SHOP)
	assert_int(shop.tab).is_equal(GameTypes.ShopTab.UPGRADES)
	shop.get_parent().queue_free()


## Oranı verilen ekranda (stretch "expand", taban 1080 × 1920) mağazayı kurar.
func _open(aspect: float, profile: int = 0) -> ShopScreen:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = UI.canvas_size(aspect)
	add_child(viewport)
	var shop: ShopScreen = SHOP_SCENE.instantiate() as ShopScreen
	viewport.add_child(shop)
	UI.apply_safe_profile(shop, profile)
	shop.open()
	await get_tree().process_frame
	await get_tree().process_frame
	return shop


func _list(shop: ShopScreen, tab: GameTypes.ShopTab) -> ScrollContainer:
	var list_name: String = "%UpgradesList" if tab == GameTypes.ShopTab.UPGRADES else "%TrailsList"
	return shop.get_node(list_name) as ScrollContainer


func _header(shop: ShopScreen) -> Array[Control]:
	var items: Array[Control] = []
	for item_name: String in ["%BackButton", "%Wallet", "%UpgradesTab", "%TrailsTab"]:
		items.append(shop.get_node(item_name) as Control)
	return items


func _assert_layout(shop: ShopScreen, tab: GameTypes.ShopTab, where: String, profile: int) -> void:
	var screen: Rect2 = UI.safe_rect(shop, profile)
	var header: Array[Control] = _header(shop)
	var problems: Array[String] = UI.layout_problems(header, screen, UI.PROFILE_CORNERS[profile])
	var list: ScrollContainer = _list(shop, tab)
	var list_rect: Rect2 = list.get_global_rect()
	if not screen.encloses(list_rect):
		problems.append("liste ekran dışı %s" % list_rect)
	for item: Control in header:
		if item.get_global_rect().intersects(list_rect):
			problems.append("%s listeyle çakışıyor" % item.name)
	var items: Array[Control] = UI.leaves(list)
	var per_card: int = UPGRADE_ITEMS if tab == GameTypes.ShopTab.UPGRADES else TRAIL_ITEMS
	var cards: int = Progression.UPGRADES.upgrades.size() \
			if tab == GameTypes.ShopTab.UPGRADES else Progression.TRAILS.trails.size()
	assert_int(items.size()).override_failure_message(where).is_equal(cards * per_card)
	# Liste dikeyde kayar: yalnızca yatay sınır listenin kenarlarıdır.
	var column: Rect2 = Rect2(list_rect.position.x, -1.0e6, list_rect.size.x, 2.0e6)
	problems.append_array(UI.layout_problems(items, column, UI.PROFILE_CORNERS[profile]))
	problems.append_array(_drag_blockers(items, list))
	var content: Control = list.get_child(0) as Control
	if content.size.x > list_rect.size.x:
		problems.append("kartlar listeden geniş: %.0f > %.0f" % [content.size.x, list_rect.size.x])
	assert_int(header.size()).is_equal(HEADER_ITEMS)
	assert_array(problems).override_failure_message("%s: %s" % [where, problems]).is_empty()


func _assert_fit(shop: ShopScreen, tab: GameTypes.ShopTab, where: String) -> void:
	var list: ScrollContainer = _list(shop, tab)
	var items: Array[Control] = UI.leaves(list)
	items.append_array(_header(shop))
	var problems: Array[String] = UI.font_size_problems(items)
	for item: Control in items:
		if item is Button:
			problems.append_array(UI.button_fit_problems(item as Button))
			continue
		var label: Label = item as Label
		problems.append_array(UI.glyph_problems(UI.label_font(label), label.text))
		var lines: int = label.get_line_count()
		var limit: int = 1
		match String(label.name):
			"DescLabel":
				limit = MAX_DESC_LINES
			"EffectLabel":
				limit = MAX_EFFECT_LINES
			"StatusLabel":
				limit = MAX_STATUS_LINES
		if lines > limit or label.get_visible_line_count() < lines:
			problems.append("'%s' %d satır (en çok %d)" % [label.text, lines, limit])
	var content: Control = list.get_child(0) as Control
	if content.size.x > list.size.x:
		problems.append("kartlar listeden geniş: %.0f > %.0f" % [content.size.x, list.size.x])
	assert_array(problems).override_failure_message("%s: %s" % [where, problems]).is_empty()


## Sürükleme listeye ulaşır: öğeden listeye kadar hiçbir düğüm dokunuşu durdurmaz (STOP). Redmi'de
## (M5-04) STOP düğmenin üstünde başlayan kaydırma listeyi kaydırmadı.
func _drag_blockers(items: Array[Control], list: ScrollContainer) -> Array[String]:
	var problems: Array[String] = []
	for item: Control in items:
		var node: Node = item
		while node != list:
			var control: Control = node as Control
			if control != null and control.mouse_filter == Control.MOUSE_FILTER_STOP:
				problems.append("%s sürüklemeyi durduruyor" % control.name)
				break
			node = node.get_parent()
	return problems


## 0: hiçbiri alınmamış; 1: satın alınan izler alınmış, başarım izleri açık; 2: sonuncusu kuşanılı.
func _set_trail_state(state: int) -> void:
	if state == 0:
		return
	for def: TrailDef in Progression.TRAILS.trails:
		Progression.grant_trail(def.id)
	if state == 2:
		Progression.equip_trail(Progression.TRAILS.trails[-1].id)


func _card_with(shop: ShopScreen, unlock: GameTypes.TrailUnlock) -> TrailCard:
	for card: TrailCard in shop.trail_cards():
		if card.def.unlock == unlock:
			return card
	return null
