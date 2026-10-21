extends GdUnitTestSuite
## Yükseltme verisi (M4-03, GDD §10): katalogdaki yükseltmeler kayıt şemasıyla aynı; fiyatlar
## GDD tablosuyla ve taban × 2^(seviye - 1) formülüyle aynı; etkiler GDD'deki değerler; ad ve
## açıklama iki dilde çevrili.

const CATALOG: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
## GDD §10 tablosu: fiyatlar ve etkiler (Mıknatıs 90–250 px = 1,8–5 m; Kalkan Sv1 yenilenmez).
const EXPECTED_COSTS: Dictionary[StringName, Array] = {
	&"magnet": [100, 200, 400, 800, 1600],
	&"shield": [150, 300, 600, 1200, 2400],
	&"head_start": [120, 240, 480, 960, 1920],
	&"glimmer_boost": [200, 400, 800, 1600, 3200],
	&"second_chance": [5000],
}
const EXPECTED_VALUES: Dictionary[StringName, Array] = {
	&"magnet": [1.8, 2.6, 3.4, 4.2, 5.0],
	&"shield": [0.0, 1500.0, 1200.0, 900.0, 600.0],
	&"head_start": [100.0, 200.0, 300.0, 400.0, 500.0],
	&"glimmer_boost": [0.1, 0.2, 0.3, 0.4, 0.5],
	&"second_chance": [1.0],
}


func test_catalog_matches_the_save_schema() -> void:
	var keys: Array[StringName] = []
	for key: String in (SaveManager.default_data()["upgrades"] as Dictionary):
		keys.append(StringName(key))
	assert_array(CATALOG.ids()).contains_exactly_in_any_order(keys)
	assert_array(CATALOG.ids()).contains_exactly_in_any_order(EXPECTED_COSTS.keys())


func test_costs_follow_the_gdd() -> void:
	for def: UpgradeDef in CATALOG.upgrades:
		assert_array(def.costs).override_failure_message(String(def.id)).is_equal(
				EXPECTED_COSTS[def.id])
		for level: int in range(1, def.max_level() + 1):
			assert_int(def.cost_for(level)).is_equal(def.costs[0] * int(pow(2, level - 1)))
		assert_int(def.cost_for(0)).is_equal(-1)
		assert_int(def.cost_for(def.max_level() + 1)).is_equal(-1)


func test_values_follow_the_gdd() -> void:
	for def: UpgradeDef in CATALOG.upgrades:
		var expected: Array = EXPECTED_VALUES[def.id]
		assert_int(def.values.size()).is_equal(def.max_level())
		for level: int in range(1, def.max_level() + 1):
			assert_float(def.value_at(level)).override_failure_message(
					"%s seviye %d" % [def.id, level]).is_equal_approx(expected[level - 1], 0.0001)
		assert_float(def.value_at(0)).is_equal(0.0)
	# Mıknatıs GDD'de piksel: 90 px = 1,8 m.
	assert_float(TuningConfig.to_px(CATALOG.get_def(&"magnet").value_at(1))).is_equal_approx(
			90.0, 0.001)


func test_names_are_translated() -> void:
	var locale: String = TranslationServer.get_locale()
	for lang: String in ["en", "tr"]:
		TranslationServer.set_locale(lang)
		for def: UpgradeDef in CATALOG.upgrades:
			for key: String in [def.name_key, def.desc_key]:
				assert_str(tr(key)).override_failure_message(
						"%s: %s çevrilmemiş" % [lang, key]).is_not_equal(key)
	TranslationServer.set_locale("tr")
	assert_str(tr(CATALOG.get_def(&"second_chance").name_key)).is_equal("İKİNCİ ŞANS")
	TranslationServer.set_locale(locale)


func test_unknown_id_has_no_def() -> void:
	assert_object(CATALOG.get_def(&"laser_eyes")).is_null()
