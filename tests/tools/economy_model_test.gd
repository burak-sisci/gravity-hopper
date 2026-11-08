extends GdUnitTestSuite
## Ekonomi temposu (M4-14, GDD §9.3, architecture.md §13.1; ölçülebilir doğrulama, ADR-076):
## oyunun gerçek ayarı, parça kütüphanesi ve fiyatlarıyla benzetilen düzenli oyuncu GDD'nin tempo
## hedeflerinde kalır. Fiyat, Glimmer değeri, sektör bonusu ya da parçalardaki Glimmer'lar
## değişip tempo bozulursa bu test düşer. Bantlar GDD §9.3'ten; "yaklaşık 2 hafta" ± 2 gün.

const LIBRARY: ChunkLibrary = preload("res://data/chunks/chunk_library.tres")
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
const MUSIC: MusicCatalog = preload("res://data/music/music_catalog.tres")
const UPGRADES: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
## Benzetimin boyu: rapordan (200 × 48) küçük ama ortanca kararlı (seçilen değerlerde rapor ile
## en çok 1 tur / 1 gün / %10 fark).
const PLAYERS: int = 60
const SEEDS: int = 12
const FIRST_PLAYER_SEED: int = 1
## GDD §9.3 tempo hedefleri.
const FIRST_UPGRADE_RUNS: Vector2 = Vector2(2.0, 3.0)
const EARLY_EARNED: Vector2 = Vector2(30.0, 60.0)
const MID_EARNED: Vector2 = Vector2(100.0, 200.0)
const ALL_UPGRADES_DAYS: Vector2 = Vector2(12.0, 16.0)
## Yükseltmelerin toplamı "≈ 22.000" (± %10).
const TOTAL_COST: Vector2i = Vector2i(19800, 24200)


func test_regular_player_meets_the_pace_targets() -> void:
	var model: EconomyModel = EconomyModel.new(LIBRARY, SECTORS, MUSIC, Earnings.tuning, UPGRADES)
	model.sample_maps(self, SEEDS)
	var regular: EconomyModel.Profile = _profile("regular")
	var summary: EconomyModel.Summary = model.summarize(regular, PLAYERS, FIRST_PLAYER_SEED)
	_assert_within("ilk yükseltme (tur)", summary.first_upgrade_run, FIRST_UPGRADE_RUNS)
	_assert_within("1. gün kazanç / tur", summary.early_earned, EARLY_EARNED)
	_assert_within("6.–8. gün kazanç / tur", summary.mid_earned, MID_EARNED)
	_assert_within("bütün yükseltmeler (gün)", summary.all_upgrades_day, ALL_UPGRADES_DAYS)
	assert_int(summary.finished).override_failure_message("bitiren %d / %d" % [
		summary.finished, PLAYERS]).is_equal(PLAYERS)


func test_upgrade_total_is_about_22000() -> void:
	var model: EconomyModel = EconomyModel.new(LIBRARY, SECTORS, MUSIC, Earnings.tuning, UPGRADES)
	assert_int(model.total_upgrade_cost()).is_between(TOTAL_COST.x, TOTAL_COST.y)


## Oyuncu modelinin kendi sınaması: ölüm şansı zorlukla artar, beceriyle azalır, tavanı aşmaz.
func test_death_chance_follows_difficulty_and_skill() -> void:
	var at_skill: float = EconomyModel.death_chance(3.0, 3.0)
	assert_float(at_skill).is_equal_approx(EconomyModel.DEATH_AT_SKILL, 0.0001)
	assert_float(EconomyModel.death_chance(4.0, 3.0)).is_greater(at_skill)
	assert_float(EconomyModel.death_chance(3.0, 4.0)).is_less(at_skill)
	assert_float(EconomyModel.death_chance(20.0, 0.0)).is_equal(EconomyModel.MAX_DEATH)


func _profile(id: String) -> EconomyModel.Profile:
	for profile: EconomyModel.Profile in EconomyModel.profiles():
		if profile.id == id:
			return profile
	return null


func _assert_within(what: String, value: float, band: Vector2) -> void:
	assert_float(value).override_failure_message("%s %.1f, hedef %.0f–%.0f" % [
		what, value, band.x, band.y]).is_between(band.x, band.y)
