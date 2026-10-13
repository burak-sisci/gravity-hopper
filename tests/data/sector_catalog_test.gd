extends GdUnitTestSuite
## Sektör kataloğu (M2-08, GDD §12): S1–S3 değerleri, başlangıç ve bitiş yükseklikleri.
## Paletler (M3-02): her sektörün paleti var, çevre ve vurgu rengi kırmızı ya da yeşil değil.

const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
## Bir rengin tehlike kırmızısına ya da Glimmer yeşiline en az bu kadar uzak tonda olması
## gerekir (renk çemberinde, 0–1 = 0–360°). Doygunluğu düşük renkler (beyaz, gri) serbesttir.
const MIN_HUE_DISTANCE: float = 30.0 / 360.0
const MIN_SATURATION: float = 0.2
## Arka plan koyu olmalı; yoksa neon parlamaz.
const MAX_BACKGROUND_VALUE: float = 0.2


func test_values_match_design() -> void:
	assert_int(SECTORS.count()).is_equal(3)
	# Hız (m/sn) ve boy (m). Tempo sektörde değil, turun müzik parçasında (M2-20).
	var expected: Array[Vector2] = [Vector2(12, 750), Vector2(14, 1000), Vector2(16, 1500)]
	for i: int in expected.size():
		var def: SectorDef = SECTORS.def_at(i + 1)
		assert_float(def.climb_speed).is_equal(expected[i].x)
		assert_float(def.length).is_equal(expected[i].y)
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


func test_palettes_avoid_hazard_and_glimmer_colors() -> void:
	var forbidden: Array[Color] = [Neon.STYLE.hazard_color, Neon.STYLE.glimmer_color]
	var ambients: Array[Color] = []
	for i: int in SECTORS.count():
		var palette: SectorPalette = SECTORS.def_at(i + 1).palette
		assert_object(palette).override_failure_message("S%d paleti yok" % (i + 1)).is_not_null()
		if palette == null:
			continue
		for color: Color in [palette.ambient, palette.accent]:
			for fixed: Color in forbidden:
				assert_bool(_hues_apart(color, fixed)).override_failure_message(
						"S%d: %s, %s tonuna çok yakın" % [i + 1, color, fixed]).is_true()
		assert_float(palette.background.v).is_less_equal(MAX_BACKGROUND_VALUE)
		assert_bool(ambients.has(palette.ambient)).is_false()
		ambients.append(palette.ambient)


func test_hue_rule_catches_red_and_green() -> void:
	assert_bool(_hues_apart(Color(0.95, 0.3, 0.25), Neon.STYLE.hazard_color)).is_false()
	assert_bool(_hues_apart(Color(0.4, 0.9, 0.35), Neon.STYLE.glimmer_color)).is_false()
	assert_bool(_hues_apart(Color(0.3, 0.85, 0.95), Neon.STYLE.hazard_color)).is_true()
	assert_bool(_hues_apart(Color(0.95, 0.95, 0.95), Neon.STYLE.hazard_color)).is_true()


func test_names_are_translated() -> void:
	var locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("tr")
	assert_str(tr(SECTORS.def_at(2).name_key)).is_equal("VERİ AKIŞI")
	TranslationServer.set_locale("en")
	assert_str(tr(SECTORS.def_at(2).name_key)).is_equal("DATA STREAM")
	TranslationServer.set_locale(locale)


func test_beat_sizes() -> void:
	# S1 100 BPM: 600 px/sn × 0,6 sn = 360 px; S3 120 BPM: 800 px/sn × 0,5 sn = 400 px.
	assert_float(SECTORS.def_at(1).beat_px(100.0)).is_equal_approx(360.0, 0.001)
	assert_float(SECTORS.def_at(3).beat_px(120.0)).is_equal_approx(400.0, 0.001)
	# En kısa vuruş en yavaş sektörde: 120 BPM'de S1 600 px/sn × 0,5 sn.
	assert_float(SECTORS.min_beat_px(120.0)).is_equal_approx(300.0, 0.001)


## Renk, sabit renkten tonca yeterince uzak mı (ya da tonu sayılmayacak kadar soluk mu).
func _hues_apart(color: Color, fixed: Color) -> bool:
	if color.s < MIN_SATURATION:
		return true
	var distance: float = absf(color.h - fixed.h)
	return minf(distance, 1.0 - distance) >= MIN_HUE_DISTANCE
