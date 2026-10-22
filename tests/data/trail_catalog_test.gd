extends GdUnitTestSuite
## Kozmetik iz kataloğu (M4-08, GDD §11, architecture.md §10): ilki varsayılan (herkeste açık,
## kayıttaki "trail_default"); 4–6 satın alınan iz 300–3000 Glimmer arasında, artan fiyatla;
## başarım izleri (Büyük Depo, toplam 500 kıl payı) satılmaz. Renkler (geçişin ara tonları ve
## parlama dahil) tehlike kırmızısından ve Glimmer yeşilinden uzak; adlar TR/EN çevrili.
## İzler birbirinden ve her sektörde varsayılan Neon izden gözle ayırt edilir (OKLab farkı,
## ADR-075): yeni iz ya da sektör eklenince renkler yine çakışmasın.

const TRAILS: TrailCatalog = preload("res://data/trails/trail_catalog.tres")
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
## Sektör paletleriyle aynı ton kuralı (sector_catalog_test).
const MIN_HUE_DISTANCE: float = 30.0 / 360.0
const MIN_SATURATION: float = 0.2
## Renk geçişinde iki renk arası örnek sayısı.
const GRADIENT_SAMPLES: int = 16
const MIN_PRICE: int = 300
const MAX_PRICE: int = 3000
const NEAR_MISS_GOAL: int = 500
## İki iz arasında en az görünüş farkı (OKLab; gözün ayırdığı en küçük fark ~0.02). Kullanıcının
## "çok yakın" bulduğu eski Ayaz ~ Kuyruklu Yıldız 0.13, Altın ~ Kıl Payı 0.17 idi.
const MIN_TRAIL_DIFFERENCE: float = 0.25
## İzle aynı sektördeki varsayılan Neon iz arasında en az fark (eski Ametist ~ S2 Neon 0.05 idi).
const MIN_NEON_DIFFERENCE: float = 0.15
## Görünüş farkında renk geçişinden alınan örnek sayısı.
const LOOK_SAMPLES: int = 32


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


func test_trails_look_different_in_every_sector() -> void:
	# Sektör numaraları 1'den başlar.
	for sector: int in range(1, SECTORS.count() + 1):
		var ambient: Color = SECTORS.def_at(sector).palette.ambient
		var trails: Array[Trail] = []
		for def: TrailDef in TRAILS.trails:
			trails.append(_trail(def, ambient))
		for i: int in trails.size():
			for j: int in range(i + 1, trails.size()):
				var neon: bool = TRAILS.trails[i].follows_ambient() \
						or TRAILS.trails[j].follows_ambient()
				var difference: float = _difference(trails[i], trails[j])
				assert_float(difference).override_failure_message(
						"sektör %d: %s ~ %s farkı %.3f" % [
							sector, TRAILS.trails[i].id, TRAILS.trails[j].id, difference,
						]).is_greater_equal(MIN_NEON_DIFFERENCE if neon else MIN_TRAIL_DIFFERENCE)


## Ölçü, kullanıcının "çok yakın" bulduğu eski renkleri yakalar; aynı iz kendisinden farksızdır.
func test_difference_catches_the_old_close_pairs() -> void:
	var ambient: Color = SECTORS.def_at(1).palette.ambient
	var frost: Trail = _trail(_def([Color(0.55, 0.82, 1.0)], Color(0.35, 0.7, 1.0)), ambient)
	var comet: Trail = _trail(_def([Color(0.45, 0.95, 1.0), Color(0.45, 0.5, 1.0)],
			Color(0.4, 0.8, 1.0)), ambient)
	var gold: Trail = _trail(_def([Color(1.0, 0.82, 0.35)], Color(1.0, 0.7, 0.2)), ambient)
	var close_call: Trail = _trail(_def([Color(1.0, 0.68, 0.2), Color(1.0, 0.85, 0.4)],
			Color(1.0, 0.55, 0.1)), ambient)
	assert_float(_difference(frost, comet)).is_less(MIN_TRAIL_DIFFERENCE)
	assert_float(_difference(gold, close_call)).is_less(MIN_TRAIL_DIFFERENCE)
	assert_float(_difference(frost, gold)).is_greater_equal(MIN_TRAIL_DIFFERENCE)
	assert_float(_difference(gold, gold)).is_equal_approx(0.0, 0.0001)


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


## Sektör renginde, verilen izi kuşanmış iz düğümü (renk geçişi ve parlama Trail'in kendisinden).
func _trail(def: TrailDef, ambient: Color) -> Trail:
	var trail: Trail = auto_free(Trail.new()) as Trail
	trail.apply_def(def)
	trail.set_ambient(ambient)
	return trail


## Beyaz başla başlayan renkli iz tanımı.
func _def(colors: Array[Color], glow: Color) -> TrailDef:
	var def: TrailDef = TrailDef.new()
	def.colors = PackedColorArray([Color.WHITE] + colors)
	def.glow_color = glow
	return def


## İki izin görünüş farkı: renk geçişinin aynı yerlerindeki OKLab farklarının, ikisinin de görünür
## olduğu ölçüde (saydamlık) ağırlıklı ortalaması + parlama renklerinin OKLab farkı.
func _difference(a: Trail, b: Trail) -> float:
	var total: float = 0.0
	var weight: float = 0.0
	for step: int in LOOK_SAMPLES:
		var offset: float = (step + 0.5) / LOOK_SAMPLES
		var color_a: Color = a.gradient.sample(offset)
		var color_b: Color = b.gradient.sample(offset)
		var visible: float = minf(color_a.a, color_b.a)
		total += ColorMetrics.difference(color_a, color_b) * visible
		weight += visible
	return total / weight + ColorMetrics.difference(a.glow_color, b.glow_color)

