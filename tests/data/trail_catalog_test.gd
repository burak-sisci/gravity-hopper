extends GdUnitTestSuite
## Kozmetik iz kataloğu (M4-08, GDD §11, architecture.md §10): ilki varsayılan (herkeste açık,
## kayıttaki "trail_default"); 4–6 satın alınan iz 300–3000 Glimmer arasında, artan fiyatla;
## başarım izleri (Büyük Depo, toplam 500 kıl payı) satılmaz. Renkler (geçişin ara tonları ve
## parlama dahil) tehlike kırmızısından ve Glimmer yeşilinden uzak; adlar TR/EN çevrili.

const TRAILS: TrailCatalog = preload("res://data/trails/trail_catalog.tres")
## Sektör paletleriyle aynı ton kuralı (sector_catalog_test).
const MIN_HUE_DISTANCE: float = 30.0 / 360.0
const MIN_SATURATION: float = 0.2
## Renk geçişinde iki renk arası örnek sayısı.
const GRADIENT_SAMPLES: int = 16
const MIN_PRICE: int = 300
const MAX_PRICE: int = 3000
const NEAR_MISS_GOAL: int = 500


func test_default_trail_comes_first_and_matches_the_save() -> void:
	var first: TrailDef = TRAILS.default_def()
	assert_str(String(first.id)).is_equal("trail_default")
	assert_int(first.unlock).is_equal(GameTypes.TrailUnlock.FREE)
	assert_bool(first.follows_ambient()).is_true()
	var saved: Dictionary = SaveManager.default_data()["trails"]
	assert_str(String(saved["equipped"])).is_equal(String(first.id))
	assert_array(saved["owned"]).contains([String(first.id)])
	var free: int = 0
	for def: TrailDef in TRAILS.trails:
		if def.unlock == GameTypes.TrailUnlock.FREE:
			free += 1
	assert_int(free).is_equal(1)


func test_purchases_and_achievements() -> void:
	var prices: Array[int] = []
	var achievements: Array[GameTypes.TrailUnlock] = []
	for def: TrailDef in TRAILS.trails:
		match def.unlock:
			GameTypes.TrailUnlock.PURCHASE:
				prices.append(def.cost)
			GameTypes.TrailUnlock.NEAR_MISSES:
				achievements.append(def.unlock)
				assert_int(def.goal).is_equal(NEAR_MISS_GOAL)
			GameTypes.TrailUnlock.GREAT_STORAGE:
				achievements.append(def.unlock)
		if def.unlock != GameTypes.TrailUnlock.PURCHASE:
			assert_int(def.cost).is_equal(0)
	assert_int(prices.size()).is_between(4, 6)
	assert_int(prices.min()).is_greater_equal(MIN_PRICE)
	assert_int(prices.max()).is_equal(MAX_PRICE)
	var sorted: Array[int] = prices.duplicate()
	sorted.sort()
	assert_array(prices).is_equal(sorted)
	assert_array(achievements).contains_exactly_in_any_order([
		GameTypes.TrailUnlock.NEAR_MISSES, GameTypes.TrailUnlock.GREAT_STORAGE,
	])


func test_ids_are_unique_and_looks_differ() -> void:
	var ids: Array[StringName] = TRAILS.ids()
	var looks: Array[PackedColorArray] = []
	for def: TrailDef in TRAILS.trails:
		assert_int(ids.count(def.id)).is_equal(1)
		assert_str(String(def.id)).starts_with("trail_")
		assert_object(TRAILS.get_def(def.id)).is_same(def)
		assert_float(def.width_scale).is_between(0.5, 2.0)
		assert_float(def.glow_scale).is_between(0.5, 2.0)
		assert_float(def.length_scale).is_between(0.5, 2.0)
		if def.follows_ambient():
			continue
		assert_int(def.colors.size()).is_greater_equal(2)
		assert_bool(looks.has(def.colors)).is_false()
		looks.append(def.colors)
	assert_object(TRAILS.get_def(&"trail_missing")).is_null()


func test_colors_avoid_hazard_and_glimmer_hues() -> void:
	var forbidden: Array[Color] = [Neon.STYLE.hazard_color, Neon.STYLE.glimmer_color]
	for def: TrailDef in TRAILS.trails:
		var samples: Array[Color] = []
		if def.glow_color.a > 0.0:
			samples.append(def.glow_color)
		for i: int in range(def.colors.size() - 1):
			for step: int in GRADIENT_SAMPLES + 1:
				samples.append(def.colors[i].lerp(def.colors[i + 1], float(step) / GRADIENT_SAMPLES))
		for color: Color in samples:
			for fixed: Color in forbidden:
				assert_bool(_hues_apart(color, fixed)).override_failure_message(
						"%s: %s, %s tonuna çok yakın" % [def.id, color, fixed]).is_true()


func test_hue_rule_catches_red_and_green() -> void:
	assert_bool(_hues_apart(Color(1.0, 0.4, 0.5), Neon.STYLE.hazard_color)).is_false()
	assert_bool(_hues_apart(Color(0.5, 1.0, 0.6), Neon.STYLE.glimmer_color)).is_false()
	assert_bool(_hues_apart(Color(1.0, 0.82, 0.35), Neon.STYLE.hazard_color)).is_true()


func test_names_are_translated() -> void:
	var locale: String = TranslationServer.get_locale()
	for def: TrailDef in TRAILS.trails:
		for key: String in [def.name_key, def.desc_key]:
			if key.is_empty():
				continue
			for lang: String in ["en", "tr"]:
				TranslationServer.set_locale(lang)
				assert_str(tr(key)).override_failure_message(
						"%s (%s) çevrilmemiş" % [key, lang]).is_not_equal(key)
		var achievement: bool = def.unlock in [
			GameTypes.TrailUnlock.NEAR_MISSES, GameTypes.TrailUnlock.GREAT_STORAGE,
		]
		assert_bool(def.desc_key.is_empty()).is_equal(not achievement)
	TranslationServer.set_locale("tr")
	assert_str(tr("TRAIL_GOLD")).is_equal("ALTIN")
	assert_str(tr("TRAIL_CLOSE_CALL_DESC") % NEAR_MISS_GOAL).is_equal("Toplam 500 kıl payı yap.")
	TranslationServer.set_locale("en")
	assert_str(tr("TRAIL_GOLD")).is_equal("GOLD")
	TranslationServer.set_locale(locale)


## Renk, sabit renkten tonca yeterince uzak mı (ya da tonu sayılmayacak kadar soluk mu).
func _hues_apart(color: Color, fixed: Color) -> bool:
	if color.s < MIN_SATURATION:
		return true
	var distance: float = absf(color.h - fixed.h)
	return minf(distance, 1.0 - distance) >= MIN_HUE_DISTANCE
