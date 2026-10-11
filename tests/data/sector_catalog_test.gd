extends GdUnitTestSuite
## Sektör kataloğu (M2-08, GDD §12): S1–S3 değerleri, başlangıç ve bitiş yükseklikleri.

const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")


func test_values_match_design() -> void:
	assert_int(SECTORS.count()).is_equal(3)
	var expected: Array[Vector3] = [
		Vector3(100, 12, 750), Vector3(110, 14, 1000), Vector3(120, 16, 1500),
	]
	for i: int in expected.size():
		var def: SectorDef = SECTORS.def_at(i + 1)
		assert_float(def.bpm).is_equal(expected[i].x)
		assert_float(def.climb_speed).is_equal(expected[i].y)
		assert_float(def.length).is_equal(expected[i].z)
		assert_str(String(def.name_key)).is_equal("SECTOR_%d_NAME" % (i + 1))
		assert_int(def.min_difficulty).is_less_equal(def.max_difficulty)


func test_heights_chain() -> void:
	assert_float(SECTORS.start_height(1)).is_equal(0.0)
	assert_float(SECTORS.start_height(2)).is_equal(750.0)
	assert_float(SECTORS.start_height(3)).is_equal(1750.0)
	assert_float(SECTORS.end_height(2)).is_equal(1750.0)
	# Son sektör bitmez (S4–S5 M4-07'de).
	assert_float(SECTORS.end_height(3)).is_equal(INF)
	assert_int(SECTORS.sector_at(0.0)).is_equal(1)
	assert_int(SECTORS.sector_at(749.9)).is_equal(1)
	assert_int(SECTORS.sector_at(750.0)).is_equal(2)
	assert_int(SECTORS.sector_at(99999.0)).is_equal(3)


func test_names_are_translated() -> void:
	var locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("tr")
	assert_str(tr(SECTORS.def_at(2).name_key)).is_equal("VERİ AKIŞI")
	TranslationServer.set_locale("en")
	assert_str(tr(SECTORS.def_at(2).name_key)).is_equal("DATA STREAM")
	TranslationServer.set_locale(locale)


func test_beat_sizes() -> void:
	# S1: 600 px/sn × 0,6 sn = 360 px; S3: 800 px/sn × 0,5 sn = 400 px.
	assert_float(SECTORS.def_at(1).beat_px()).is_equal_approx(360.0, 0.001)
	assert_float(SECTORS.def_at(3).beat_px()).is_equal_approx(400.0, 0.001)
	assert_float(SECTORS.min_beat_px()).is_equal_approx(360.0, 0.001)
