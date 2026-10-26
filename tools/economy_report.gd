extends RefCounted
## Ekonomi benzetiminin raporu (M4-14): tools/simulate_economy.gd ilk karede yükler. Tablolar
## Markdown'dır; architecture.md §13.1'e olduğu gibi konur.

const LIBRARY_PATH: String = "res://data/chunks/chunk_library.tres"
const SECTORS_PATH: String = "res://data/sectors/sector_catalog.tres"
const MUSIC_PATH: String = "res://data/music/music_catalog.tres"
const UPGRADES_PATH: String = "res://data/upgrades/upgrade_catalog.tres"
const DEFAULT_PLAYERS: int = 200
const DEFAULT_SEEDS: int = 48
## Oyuncu tohumları bundan başlar (testler başka tohum kullanır).
const FIRST_PLAYER_SEED: int = 1
const TABLE_HEADER: String = "| Profil | Günde (dk) | Tur / gün | İlk yükseltme (tur) " \
		+ "| Kazanç / tur: 1. gün | 6.–8. gün | Hepsi: gün | Hepsi: tur | Bitiren |"
const TABLE_RULE: String = "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"


## Raporu basar; çıkış kodu döndürür.
func run(root: Node, args: PackedStringArray) -> int:
	var players: int = DEFAULT_PLAYERS
	var seeds: int = DEFAULT_SEEDS
	# Benzetim Earnings'in ayar kaynağını kullanır (aynı nesne): "ya şöyle olsaydı" denemeleri
	# ikisinde birden, yalnızca bellekte değişir, dosyaya yazılmaz.
	var tuning: TuningConfig = Earnings.TUNING
	for arg: String in args:
		var value: int = arg.get_slice("=", 1).to_int()
		if arg.begins_with("--players="):
			players = value
		elif arg.begins_with("--seeds="):
			seeds = value
		elif arg.begins_with("--glimmer-value="):
			tuning.glimmer_value = value
		elif arg.begins_with("--sector-bonus="):
			tuning.sector_bonus = value
	var sectors: SectorCatalog = load(SECTORS_PATH) as SectorCatalog
	var model: EconomyModel = EconomyModel.new(load(LIBRARY_PATH) as ChunkLibrary, sectors,
			load(MUSIC_PATH) as MusicCatalog, tuning, load(UPGRADES_PATH) as UpgradeCatalog)
	print("Glimmer değeri %d, sektör bonusu %d × sektör." % [
		tuning.glimmer_value, tuning.sector_bonus,
	])
	var started: int = Time.get_ticks_msec()
	model.sample_maps(root, seeds)
	print("Harita: %d tohum × %d başlangıç sektörü (%d ms)" % [
		seeds, sectors.count(), Time.get_ticks_msec() - started,
	])
	print("")
	print("| Sektör | Glimmer / 100 m | Sektör bonusu |")
	print("| --- | --- | --- |")
	for sector: int in range(1, sectors.count() + 1):
		print("| S%d | %.2f | %d |" % [
			sector, model.glimmers_per_100m(sector), Earnings.sector_bonus(sector, sector + 1),
		])
	print("")
	print("Yükseltmelerin toplamı %d, en ucuzu %d. Oyuncu: profil başına %d." % [
		model.total_upgrade_cost(), model.cheapest_cost(), players,
	])
	print("")
	print(TABLE_HEADER)
	print(TABLE_RULE)
	var summaries: Array[EconomyModel.Summary] = []
	for profile: EconomyModel.Profile in EconomyModel.profiles():
		var summary: EconomyModel.Summary = model.summarize(profile, players, FIRST_PLAYER_SEED)
		summaries.append(summary)
		_print_row(profile.id, profile, summary)
	print("")
	print("Kontrol noktası seçiminin etkisi (regular):")
	print("")
	print(TABLE_HEADER)
	print(TABLE_RULE)
	var regular: EconomyModel.Profile = EconomyModel.profiles()[1]
	for policy: EconomyModel.StartPolicy in [EconomyModel.StartPolicy.HIGHEST,
			EconomyModel.StartPolicy.FIRST]:
		var name: String = "%s (%s)" % [regular.id, EconomyModel.StartPolicy.keys()[policy]]
		_print_row(name, regular, model.summarize(regular, players, FIRST_PLAYER_SEED, policy))
	print("")
	print("Ortanca en yüksek tur (m):")
	print("")
	var header: String = "| Profil | İlk tur |"
	for day: int in EconomyModel.REPORT_DAYS:
		header += " %d. gün |" % day
	print(header)
	print("|" + " --- |".repeat(EconomyModel.REPORT_DAYS.size() + 2))
	var profiles: Array[EconomyModel.Profile] = EconomyModel.profiles()
	for i: int in profiles.size():
		var row: String = "| %s | %d |" % [profiles[i].id, roundi(summaries[i].first_run_height)]
		for height: float in summaries[i].best_heights:
			row += " %d |" % roundi(height)
		print(row)
	print("")
	print("Süre: %d ms" % (Time.get_ticks_msec() - started))
	return 0


func _print_row(name: String, profile: EconomyModel.Profile,
		summary: EconomyModel.Summary) -> void:
	print("| %s | %d | %d | %d | %d | %d | %s | %s | %d / %d |" % [
		name, roundi(profile.minutes_per_day), roundi(summary.runs_per_day),
		roundi(summary.first_upgrade_run), roundi(summary.early_earned),
		roundi(summary.mid_earned), _count_text(summary.all_upgrades_day),
		_count_text(summary.all_upgrades_run), summary.finished, summary.players,
	])


func _count_text(value: float) -> String:
	return "%d" % roundi(value) if value >= 0.0 else "—"
