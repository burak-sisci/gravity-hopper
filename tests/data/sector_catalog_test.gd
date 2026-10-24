extends GdUnitTestSuite
## Sektör kataloğu (M2-08, GDD §12): S1–S6 değerleri, başlangıç ve bitiş yükseklikleri.
## Paletler (M3-02): her sektörün paleti var, çevre ve vurgu rengi kırmızı ya da yeşil değil.
## M4-11: renk kuralı ölçülür (ADR-076): çevre rengi tehlike kırmızısından, Glimmer yeşilinden ve
## rekor sarısından OKLab farkıyla, renk körlüğü benzetiminde de kırmızıdan ayrılır; tehlike
## kırmızısı zeminde okunur; komşu sektörler renk dalgasında ayrılır. Eşikler onaylı paletlerden.
## M4-12: S5'in bozulma bantları tehlikeyi okunmaz kılmaz (renkler anlam renklerinden uzak,
## bandın üstünde de kontrast yeterli).
## M4-13: S6 Taşma son sektördür, bitmez ve Büyük Depolama Birimi'dir (final); paleti önceki
## sektörlerinkini döngüyle dolaşır. Renk kuralları katalogda görünebilen bütün paletlere
## (SectorCatalog.palettes) uygulanır; komşuluk renk dalgasında art arda gelen paletlerdir.

const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
## Bir rengin tehlike kırmızısına ya da Glimmer yeşiline en az bu kadar uzak tonda olması
## gerekir (renk çemberinde, 0–1 = 0–360°). Doygunluğu düşük renkler (beyaz, gri) serbesttir.
const MIN_HUE_DISTANCE: float = 30.0 / 360.0
const MIN_SATURATION: float = 0.2
## Arka plan koyu olmalı; yoksa neon parlamaz.
const MAX_BACKGROUND_VALUE: float = 0.2
## Çevre rengi ile tehlike kırmızısı / Glimmer yeşili arasında en az OKLab farkı. Onaylı en yakın
## çiftler: S3 turuncusu ~ kırmızı 0,195, S1 camgöbeği ~ yeşil 0,226 (M3-17).
const MIN_MEANING_DIFFERENCE: float = 0.19
## Çevre rengi ile rekor sarısı arasında en az fark. Kullanıcının "karışıyor" dediği eski S3
## kehribarı (1, 0,72, 0,25) 0,144 idi; yerine onaylanan turuncu 0,212.
const MIN_RECORD_DIFFERENCE: float = 0.2
## Renk körlüğü benzetiminde (protan, deutan, tritan) çevre rengi ~ tehlike kırmızısı en az farkı
## (kritik çift; onaylı paletlerde en düşük S3 deutan 0,126).
const MIN_CVD_HAZARD_DIFFERENCE: float = 0.1
## Tehlike kırmızısının sektör zeminindeki WCAG kontrastı (onaylı paletler 5,43–5,58).
const MIN_HAZARD_CONTRAST: float = 5.0
## Renk dalgasında art arda gelen paletlerin (sektör geçişi ve Taşma'nın döngüsü) çevre renkleri
## yan yana görünür: ayrı kategori farkı. Diğerleri (S2 moru ~ S4 eflatunu 0,20) yalnızca aynı
## ailenin değişkeni kadar ayrılır.
const MIN_NEIGHBOR_DIFFERENCE: float = 0.25
const MIN_SECTOR_DIFFERENCE: float = 0.15
## Bozulma bandının üstünde tehlike kırmızısının kontrastı. Bant kısa süreli ve ekranın küçük
## bir kısmı; WCAG AA normal metin eşiği yeter (zemindeki 5'in altında kalabilir).
const MIN_BAND_CONTRAST: float = 4.5


func test_values_match_design() -> void:
	assert_int(SECTORS.count()).is_equal(6)
	# Hız (m/sn) ve boy (m; Taşma'da yalnızca zorluk eğrisinin boyu). Tempo sektörde değil, turun
	# müzik parçasında (M2-20).
	var expected: Array[Vector2] = [
		Vector2(12, 750), Vector2(14, 1000), Vector2(16, 1500), Vector2(18, 1750),
		Vector2(20, 2500), Vector2(22, 2500),
	]
	for i: int in expected.size():
		var def: SectorDef = SECTORS.def_at(i + 1)
		assert_float(def.climb_speed).is_equal(expected[i].x)
		assert_float(def.length).is_equal(expected[i].y)
		assert_str(String(def.name_key)).is_equal("SECTOR_%d_NAME" % (i + 1))
		assert_int(def.min_difficulty).is_less_equal(def.max_difficulty)
	# Çöküş duvarının sürünmesi GDD §14 (S1 0,3 → S5 0,8; Taşma tavanda kalır).
	assert_float(SECTORS.def_at(4).wall_creep).is_equal_approx(0.675, 0.0001)
	assert_float(SECTORS.def_at(5).wall_creep).is_equal_approx(0.8, 0.0001)
	assert_float(SECTORS.def_at(6).wall_creep).is_equal_approx(0.8, 0.0001)
	# Dönen şekil ve hareketli blok S4'te gelir (GDD §6); S5 ve Taşma bütün tehlikeleri karıştırır.
	for hazard: StringName in [&"rotor", &"moving_block"]:
		assert_bool(SECTORS.def_at(3).allowed_hazards.has(hazard)).is_false()
		assert_bool(SECTORS.def_at(4).allowed_hazards.has(hazard)).is_true()
	for hazard: StringName in [&"spike", &"gap", &"block", &"laser", &"rotor", &"moving_block"]:
		assert_bool(SECTORS.def_at(5).allowed_hazards.has(hazard)).is_true()
		assert_bool(SECTORS.def_at(6).allowed_hazards.has(hazard)).is_true()
	# Hız ve zorluk sektörle artar: hız her sektörde büyür, zorluk aralığı aşağı inmez.
	for i: int in range(2, SECTORS.count() + 1):
		assert_float(SECTORS.def_at(i).climb_speed).is_greater(SECTORS.def_at(i - 1).climb_speed)
		assert_int(SECTORS.def_at(i).min_difficulty).is_greater_equal(
				SECTORS.def_at(i - 1).min_difficulty)
		assert_int(SECTORS.def_at(i).max_difficulty).is_greater_equal(
				SECTORS.def_at(i - 1).max_difficulty)


func test_heights_chain() -> void:
	assert_float(SECTORS.start_height(1)).is_equal(0.0)
	assert_float(SECTORS.start_height(2)).is_equal(750.0)
	assert_float(SECTORS.start_height(3)).is_equal(1750.0)
	assert_float(SECTORS.end_height(2)).is_equal(1750.0)
	# GDD §12: S3 3250 m'de, S4 5000 m'de, S5 7500 m'de biter; S6 Taşma (son sektör) bitmez.
	assert_float(SECTORS.end_height(3)).is_equal(3250.0)
	assert_float(SECTORS.start_height(4)).is_equal(3250.0)
	assert_float(SECTORS.end_height(4)).is_equal(5000.0)
	assert_float(SECTORS.start_height(5)).is_equal(5000.0)
	assert_float(SECTORS.end_height(5)).is_equal(7500.0)
	assert_float(SECTORS.start_height(6)).is_equal(7500.0)
	assert_float(SECTORS.end_height(6)).is_equal(INF)
	assert_int(SECTORS.sector_at(0.0)).is_equal(1)
	assert_int(SECTORS.sector_at(749.9)).is_equal(1)
	assert_int(SECTORS.sector_at(750.0)).is_equal(2)
	assert_int(SECTORS.sector_at(3249.9)).is_equal(3)
	assert_int(SECTORS.sector_at(3250.0)).is_equal(4)
	assert_int(SECTORS.sector_at(4999.9)).is_equal(4)
	assert_int(SECTORS.sector_at(5000.0)).is_equal(5)
	assert_int(SECTORS.sector_at(7499.9)).is_equal(5)
	assert_int(SECTORS.sector_at(7500.0)).is_equal(6)
	assert_int(SECTORS.sector_at(99999.0)).is_equal(6)


## Taşma (M4-13): tek final sektörü ve en sonda; paleti önceki sektörlerin paletlerini birer kez
## dolaşıp başa döner. Sıra renk dalgası ayrılsın diye ölçülerek seçildi (S5 → S2, S3, S1, S4, S5;
## art arda en yakın çift 0,284). S1 ile başlamak S5'ten geçişi 0,157'de bırakıyordu.
func test_overflow_is_the_finale_and_cycles_every_palette() -> void:
	var last: SectorDef = SECTORS.def_at(SECTORS.count())
	for i: int in SECTORS.count():
		var def: SectorDef = SECTORS.def_at(i + 1)
		assert_bool(def.finale).override_failure_message("S%d final" % (i + 1)).is_equal(def == last)
		if def != last:
			assert_bool(def.cycles_palette()).is_false()
	var cycle: Array[SectorPalette] = []
	for step: int in last.palette_cycle.size() + 1:
		cycle.append(last.palette_at(step))
	var previous: Array[SectorPalette] = []
	for i: int in range(1, SECTORS.count()):
		previous.append(SECTORS.def_at(i).palette)
	assert_array(cycle).contains_exactly_in_any_order(previous)
	# Döngü başa sarar; geri adım sondakini verir.
	assert_object(last.palette_at(cycle.size())).is_same(cycle[0])
	assert_object(last.palette_at(-1)).is_same(cycle[-1])
	assert_float(last.palette_cycle_length).is_equal(500.0)
	assert_int(SECTORS.palettes().size()).is_equal(previous.size())


func test_palettes_avoid_hazard_and_glimmer_colors() -> void:
	var forbidden: Array[Color] = [Neon.STYLE.hazard_color, Neon.STYLE.glimmer_color]
	var ambients: Array[Color] = []
	for i: int in SECTORS.count():
		assert_object(SECTORS.def_at(i + 1).palette).override_failure_message(
				"S%d paleti yok" % (i + 1)).is_not_null()
	for palette: SectorPalette in SECTORS.palettes():
		for color: Color in [palette.ambient, palette.accent]:
			for fixed: Color in forbidden:
				assert_bool(_hues_apart(color, fixed)).override_failure_message(
						"%s: %s, %s tonuna çok yakın" % [_name(palette), color, fixed]).is_true()
		assert_float(palette.background.v).is_less_equal(MAX_BACKGROUND_VALUE)
		assert_bool(ambients.has(palette.ambient)).is_false()
		ambients.append(palette.ambient)


func test_ambients_are_apart_from_meaning_colors_in_oklab() -> void:
	var meanings: Dictionary[String, Color] = {
		"tehlike kırmızısı": Neon.STYLE.hazard_color,
		"Glimmer yeşili": Neon.STYLE.glimmer_color,
	}
	for palette: SectorPalette in SECTORS.palettes():
		var label: String = _name(palette)
		for meaning: String in meanings:
			var gap: float = ColorMetrics.difference(palette.ambient, meanings[meaning])
			assert_float(gap).override_failure_message("%s çevre rengi ~ %s: OKLab %.3f < %.2f" % [
				label, meaning, gap, MIN_MEANING_DIFFERENCE]).is_greater_equal(MIN_MEANING_DIFFERENCE)
		var record: float = ColorMetrics.difference(palette.ambient, Neon.STYLE.record_color)
		assert_float(record).override_failure_message("%s çevre rengi ~ rekor sarısı: %.3f < %.2f" % [
			label, record, MIN_RECORD_DIFFERENCE]).is_greater_equal(MIN_RECORD_DIFFERENCE)
		for kind: ColorMetrics.Cvd in ColorMetrics.Cvd.values():
			var seen: float = ColorMetrics.cvd_difference(
					palette.ambient, Neon.STYLE.hazard_color, kind)
			assert_float(seen).override_failure_message(
					"%s çevre rengi ~ tehlike kırmızısı (%s): %.3f < %.2f" % [
						label, ColorMetrics.Cvd.keys()[kind], seen, MIN_CVD_HAZARD_DIFFERENCE,
					]).is_greater_equal(MIN_CVD_HAZARD_DIFFERENCE)
		var contrast: float = ColorMetrics.contrast_ratio(
				Neon.STYLE.hazard_color, palette.background)
		assert_float(contrast).override_failure_message("%s zemininde tehlike kontrastı %.2f" % [
			label, contrast]).is_greater_equal(MIN_HAZARD_CONTRAST)


func test_sectors_are_apart_from_each_other() -> void:
	var palettes: Array[SectorPalette] = SECTORS.palettes()
	var neighbors: Array[Array] = _neighbor_pairs()
	# Sağlama: geçişler (S1→…→S6) ve Taşma'nın döngüsü (başa sarma dahil) komşu sayılır.
	assert_int(neighbors.size()).is_greater_equal(SECTORS.count() + 1)
	for pair: Array in neighbors:
		assert_object(pair[0]).override_failure_message("Aynı palet art arda: %s" % _name(
				pair[0])).is_not_same(pair[1])
	for i: int in palettes.size():
		for j: int in range(i + 1, palettes.size()):
			var a: SectorPalette = palettes[i]
			var b: SectorPalette = palettes[j]
			var gap: float = ColorMetrics.difference(a.ambient, b.ambient)
			var neighbor: bool = neighbors.has([a, b]) or neighbors.has([b, a])
			var least: float = MIN_NEIGHBOR_DIFFERENCE if neighbor else MIN_SECTOR_DIFFERENCE
			assert_float(gap).override_failure_message("%s ~ %s çevre rengi: %.3f < %.2f" % [
				_name(a), _name(b), gap, least]).is_greater_equal(least)


func test_only_s5_glitches() -> void:
	var corrupt: SectorPalette = SECTORS.def_at(5).palette
	assert_float(corrupt.glitch).is_greater(0.0)
	for palette: SectorPalette in SECTORS.palettes():
		if palette != corrupt:
			assert_float(palette.glitch).override_failure_message("%s bozuluyor" % _name(
					palette)).is_equal(0.0)


## Bozulma bantlarının renkleri (camgöbeği, eflatun) tehlike kırmızısına ve Glimmer yeşiline
## karışmaz (renk körlüğünde de); bant bozulan sektörün zeminine karışınca tehlike yine okunur.
func test_glitch_keeps_hazards_readable() -> void:
	var style: NeonStyle = Neon.STYLE
	var red: Color = style.hazard_color
	for color: Color in [style.glitch_color_a, style.glitch_color_b]:
		for meaning: Color in [red, style.glimmer_color]:
			var gap: float = ColorMetrics.difference(color, meaning)
			assert_float(gap).override_failure_message("bozulma %s ~ %s: OKLab %.3f" % [
				color, meaning, gap]).is_greater_equal(MIN_MEANING_DIFFERENCE)
		for kind: ColorMetrics.Cvd in ColorMetrics.Cvd.values():
			var seen: float = ColorMetrics.cvd_difference(color, red, kind)
			assert_float(seen).override_failure_message("bozulma %s ~ kırmızı (%s): %.3f" % [
				color, ColorMetrics.Cvd.keys()[kind], seen]).is_greater_equal(
					MIN_CVD_HAZARD_DIFFERENCE)
		for palette: SectorPalette in SECTORS.palettes():
			if palette.glitch <= 0.0:
				continue
			# Bant zemine glitch_band_alpha saydamlıkla karışır (sRGB'de, ekrandaki gibi).
			var band: Color = palette.background.lerp(color, style.glitch_band_alpha)
			var contrast: float = ColorMetrics.contrast_ratio(red, band)
			assert_float(contrast).override_failure_message("%s bozulma bandında (%s) %.2f" % [
				_name(palette), color, contrast]).is_greater_equal(MIN_BAND_CONTRAST)


func test_hue_rule_catches_red_and_green() -> void:
	assert_bool(_hues_apart(Color(0.95, 0.3, 0.25), Neon.STYLE.hazard_color)).is_false()
	assert_bool(_hues_apart(Color(0.4, 0.9, 0.35), Neon.STYLE.glimmer_color)).is_false()
	assert_bool(_hues_apart(Color(0.3, 0.85, 0.95), Neon.STYLE.hazard_color)).is_true()
	assert_bool(_hues_apart(Color(0.95, 0.95, 0.95), Neon.STYLE.hazard_color)).is_true()


func test_oklab_rules_catch_known_bad_colors() -> void:
	# Sağlama: beyaz → (1, 0, 0), saf kırmızı → (0,628, 0,225, 0,126).
	assert_vector(ColorMetrics.oklab(Color.WHITE)).is_equal_approx(
			Vector3(1.0, 0.0, 0.0), Vector3.ONE * 0.001)
	assert_vector(ColorMetrics.oklab(Color.RED)).is_equal_approx(
			Vector3(0.628, 0.225, 0.126), Vector3.ONE * 0.001)
	# Eski S3 kehribarı rekor sarısına çok yakındı; yerine gelen turuncu değil.
	assert_float(ColorMetrics.difference(Color(1.0, 0.72, 0.25), Neon.STYLE.record_color)) \
			.is_less(MIN_RECORD_DIFFERENCE)
	assert_float(ColorMetrics.difference(Color(1.0, 0.6, 0.12), Neon.STYLE.record_color)) \
			.is_greater_equal(MIN_RECORD_DIFFERENCE)
	# Kırmızıya kayan pembe (ton kuralını 35° ile geçer) OKLab kuralına takılır (0,167).
	var pink: Color = Color(1.0, 0.3, 0.8)
	assert_bool(_hues_apart(pink, Neon.STYLE.hazard_color)).is_true()
	assert_float(ColorMetrics.difference(pink, Neon.STYLE.hazard_color)) \
			.is_less(MIN_MEANING_DIFFERENCE)
	# Renk körlüğü: kırmızı ~ turuncu deutan görüşte yakınlaşır, kırmızı ~ camgöbeği değil.
	var red: Color = Neon.STYLE.hazard_color
	assert_float(ColorMetrics.cvd_difference(Color(1.0, 0.45, 0.2), red, ColorMetrics.Cvd.DEUTAN)) \
			.is_less(MIN_CVD_HAZARD_DIFFERENCE)
	assert_float(ColorMetrics.cvd_difference(Color(0.0, 0.85, 1.0), red, ColorMetrics.Cvd.DEUTAN)) \
			.is_greater_equal(MIN_CVD_HAZARD_DIFFERENCE)
	# WCAG sağlaması: beyaz ~ siyah 21.
	assert_float(ColorMetrics.contrast_ratio(Color.WHITE, Color.BLACK)).is_equal_approx(21.0, 0.01)


func test_names_are_translated() -> void:
	var locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("tr")
	assert_str(tr(SECTORS.def_at(2).name_key)).is_equal("VERİ AKIŞI")
	assert_str(tr(SECTORS.def_at(4).name_key)).is_equal("ÇEKİRDEK")
	assert_str(tr(SECTORS.def_at(5).name_key)).is_equal("BOZULMA")
	assert_str(tr(SECTORS.def_at(6).name_key)).is_equal("TAŞMA")
	TranslationServer.set_locale("en")
	assert_str(tr(SECTORS.def_at(2).name_key)).is_equal("DATA STREAM")
	assert_str(tr(SECTORS.def_at(4).name_key)).is_equal("KERNEL")
	assert_str(tr(SECTORS.def_at(5).name_key)).is_equal("CORRUPTION")
	assert_str(tr(SECTORS.def_at(6).name_key)).is_equal("OVERFLOW")
	TranslationServer.set_locale(locale)


func test_beat_sizes() -> void:
	# S1 100 BPM: 600 px/sn × 0,6 sn = 360 px; S3 120 BPM: 800 px/sn × 0,5 sn = 400 px.
	assert_float(SECTORS.def_at(1).beat_px(100.0)).is_equal_approx(360.0, 0.001)
	assert_float(SECTORS.def_at(3).beat_px(120.0)).is_equal_approx(400.0, 0.001)
	# S4 90 BPM: 900 px/sn × 0,667 sn = 600 px.
	assert_float(SECTORS.def_at(4).beat_px(90.0)).is_equal_approx(600.0, 0.001)
	# S5 120 BPM: 1000 px/sn × 0,5 sn = 500 px; Taşma 1100 px/sn × 0,5 sn = 550 px.
	assert_float(SECTORS.def_at(5).beat_px(120.0)).is_equal_approx(500.0, 0.001)
	assert_float(SECTORS.def_at(6).beat_px(120.0)).is_equal_approx(550.0, 0.001)
	# En kısa vuruş en yavaş sektörde: 120 BPM'de S1 600 px/sn × 0,5 sn.
	assert_float(SECTORS.min_beat_px(120.0)).is_equal_approx(300.0, 0.001)


## Renk dalgasında art arda gelebilen palet çiftleri: sektörden sonrakine geçiş (döngülü sektörün
## her paletinden) ve döngünün içindeki adımlar (sondan başa sarma dahil).
func _neighbor_pairs() -> Array[Array]:
	var pairs: Array[Array] = []
	for i: int in range(1, SECTORS.count() + 1):
		var def: SectorDef = SECTORS.def_at(i)
		for step: int in def.palette_cycle.size() + 1:
			if def.cycles_palette():
				pairs.append([def.palette_at(step), def.palette_at(step + 1)])
			if i < SECTORS.count():
				pairs.append([def.palette_at(step), SECTORS.def_at(i + 1).palette])
	return pairs


## Paletin hata mesajındaki adı: ilk göründüğü sektör.
func _name(palette: SectorPalette) -> String:
	for i: int in SECTORS.count():
		if SECTORS.def_at(i + 1).palette == palette:
			return "S%d paleti" % (i + 1)
	return palette.resource_path.get_file()


## Renk, sabit renkten tonca yeterince uzak mı (ya da tonu sayılmayacak kadar soluk mu).
func _hues_apart(color: Color, fixed: Color) -> bool:
	if color.s < MIN_SATURATION:
		return true
	var distance: float = absf(color.h - fixed.h)
	return minf(distance, 1.0 - distance) >= MIN_HUE_DISTANCE
