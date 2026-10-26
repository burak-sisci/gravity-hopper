class_name EconomyModel
extends RefCounted
## Ekonomi benzetimi (M4-14, GDD §9.3, architecture.md §13.1): beceri profillerine göre tur
## kazançları → "kaç turda, kaç günde ne alınır?". Yalnızca geliştirici aracıdır:
## tools/simulate_economy.gd ve testler kullanır, yayın sürümüne girmez.
##
## Oyunun kendisinden gelen (ölçülen): harita oyundaki ChunkSpawner ile kurulur (gerçek parça
## kütüphanesi, sektörler, turun müzik temposu, RunRng; her başlangıç sektörü ve tohum için ayrı).
## Glimmer'lar parça sahnelerindeki yerleri ve değerleriyle haritaya konur. Kazanç Earnings'in
## formülleriyle, yükseltme etkileri RunLoadout.from_levels ile, fiyatlar UpgradeCatalog'dan
## hesaplanır. Böylece değerler değişince benzetim de kendiliğinden değişir.
##
## Varsayılan (oyuncu modeli, Profile): her parçada ölüm şansı parçanın etkin zorluğuna
## (ChunkInfo.difficulty + sektör hızı payı) ve oyuncunun becerisine bağlıdır; beceri turlarla
## bir tavana doğru artar. Oyuncu riskli yoldaki Glimmer'ların bir kısmını alır; mıknatıs kaçanların
## menzil / koridor yarı genişliği kadarını yakalar. Kalkan bir darbeyi emer (yenilenme mesafesiyle
## geri gelir), İkinci Şans bir kez diriltir, Başlangıç Sıçraması yolundaki her Glimmer'ı toplar
## ve o yolda ölüm yoktur. Oyuncu her tur sonunda gücünün yettiği en ucuz yükseltmeyi alır;
## kozmetik izler hesaba girmez (GDD §9.3'teki ≈ 22.000 yalnızca yükseltmelerdir). Ödüllü reklam
## (M7) yoktur.

## Kontrol noktası seçimi (M4-09): en çok kazandıran (Glimmer / dakika), en yüksek açık sektör ya
## da hep S1.
enum StartPolicy { BEST_RATE, HIGHEST, FIRST }

## Parçanın etkin zorluğu oyuncunun becerisine eşitken o parçada ölme şansı.
const DEATH_AT_SKILL: float = 0.04
## Etkin zorluk bir basamak artınca ölüm şansı bu kadar katlanır.
const DEATH_GROWTH: float = 2.0
## Tek parçada ölüm şansının üst sınırı.
const MAX_DEATH: float = 0.9
## Tırmanış hızının S1'in üstündeki her m/sn'si etkin zorluğa bu kadar ekler (S6: +1,5).
const SPEED_DIFFICULTY: float = 0.15
## Tur başına ölüm, sonuç ekranı ve yeniden başlama (sn).
const RUN_OVERHEAD: float = 4.0
## Haritaların kurulduğu en üst yükseklik (m); bunu aşan tur burada biter sayılır.
const MAP_TOP: float = 12000.0
## Harita kurulurken bir adımda kaydırılan yol ve görünür alan (px).
const SCROLL_STEP_PX: float = 2000.0
const VIEW_HEIGHT_PX: float = 2400.0
## Sektör sınırında kayan nokta payı (m): parçanın alt kenarı kendi sektöründedir.
const EDGE_M: float = 0.01
## Harita tohumları bundan başlar.
const FIRST_SEED: int = 1000
## Kontrol noktası seçimi (BEST_RATE): kaç turda bir, her açık sektör için kaç deneme turuyla.
const CHOICE_EVERY: int = 5
const CHOICE_SAMPLES: int = 8
## Bir oyuncunun en çok kaç gün benzetildiği.
const MAX_DAYS: int = 60
## "Başta" ilk gün, "orta aşamada" 6.–8. gün (GDD §9.3: iki haftalık yolun ortası).
const EARLY_DAYS: Vector2i = Vector2i(1, 1)
const MID_DAYS: Vector2i = Vector2i(6, 8)
## Özetteki en yüksek tur günleri.
const REPORT_DAYS: Array[int] = [1, 3, 7, 14]
const SECONDS_PER_MINUTE: float = 60.0

var _library: ChunkLibrary
var _sectors: SectorCatalog
var _music: MusicCatalog
var _tuning: TuningConfig
var _upgrades: UpgradeCatalog
## Başlangıç sektörüne göre kurulmuş haritalar (MapSample dizileri).
var _maps: Dictionary[int, Array] = {}
## Parça sahnesinin adına göre boyu (vuruş) ve Glimmer'larının yeri (vuruş) ve değeri.
var _lengths: Dictionary[StringName, int] = {}
var _glimmer_beats: Dictionary[StringName, PackedFloat64Array] = {}
var _glimmer_values: Dictionary[StringName, PackedInt32Array] = {}


## Oyuncu profili. Beceri, ölüm şansı DEATH_AT_SKILL olan etkin zorluktur.
class Profile:
	var id: String = ""
	## İlk turdaki beceri ve becerinin tavanı.
	var start_skill: float = 1.0
	var skill_cap: float = 1.0
	## Becerinin tavana kalan yolun %63'ünü aldığı tur sayısı.
	var learn_runs: float = 1.0
	## Riskli yoldaki bir Glimmer'ı (mıknatıssız) alma oranı.
	var collect_rate: float = 0.5
	## Kıl payı kombosunun Glimmer'a ortalama etkisi (×).
	var combo_factor: float = 1.0
	## Günde oynanan süre (dk).
	var minutes_per_day: float = 20.0

	func _init(new_id: String, start: float, cap: float, learn: float, collect: float,
			combo: float, minutes: float) -> void:
		id = new_id
		start_skill = start
		skill_cap = cap
		learn_runs = learn
		collect_rate = collect
		combo_factor = combo
		minutes_per_day = minutes

	## runs tur oynamış oyuncunun becerisi.
	func skill_after(runs: int) -> float:
		return skill_cap - (skill_cap - start_skill) * exp(-float(runs) / learn_runs)


## Bir başlangıç sektörü ve tohum için kurulmuş harita: parçalar alttan üste, Glimmer'lar.
class MapSample:
	var start_sector: int = 1
	## Parçaların alt ve üst kenarı (m, mutlak yükseklik) ve etkin zorluğu.
	var bottoms: PackedFloat64Array = PackedFloat64Array()
	var tops: PackedFloat64Array = PackedFloat64Array()
	var difficulties: PackedFloat64Array = PackedFloat64Array()
	## Glimmer'ların yüksekliği (m) ve değeri.
	var glimmer_heights: PackedFloat64Array = PackedFloat64Array()
	var glimmer_values: PackedInt32Array = PackedInt32Array()


## Bir turun sonucu.
class RunOutcome:
	## Turun bittiği yükseklik (m, mutlak) ve sektör.
	var height: float = 0.0
	var reached: int = 1
	## Toplanan Glimmer ve tur sonu kazancı (Glimmer + sektör bonusu + Çarpan).
	var glimmers: int = 0
	var earned: int = 0
	## Oyun süresi (sn): tırmanış + tur arası.
	var duration: float = 0.0


## Bir oyuncunun turları ve yükseltme anları.
class PlayerLog:
	var earned: PackedInt32Array = PackedInt32Array()
	var heights: PackedFloat64Array = PackedFloat64Array()
	var days: PackedInt32Array = PackedInt32Array()
	var starts: PackedInt32Array = PackedInt32Array()
	## İlk yükseltmenin alındığı tur (1'den) ve bütün yükseltmelerin bittiği tur ve gün; hiç
	## olmadıysa -1.
	var first_upgrade_run: int = -1
	var all_upgrades_run: int = -1
	var all_upgrades_day: int = -1

	## Gün aralığındaki turların ortalama kazancı; o günlerde tur yoksa -1.
	func mean_earned(first_day: int, last_day: int) -> float:
		var total: int = 0
		var count: int = 0
		for i: int in earned.size():
			if days[i] >= first_day and days[i] <= last_day:
				total += earned[i]
				count += 1
		return float(total) / count if count > 0 else -1.0

	## Günün sonuna kadarki en yüksek tur (m); o güne kadar tur yoksa 0.
	func best_height(last_day: int) -> float:
		var result: float = 0.0
		for i: int in heights.size():
			if days[i] <= last_day:
				result = maxf(result, heights[i])
		return result

	## Gün aralığında günde ortalama tur sayısı.
	func runs_per_day(first_day: int, last_day: int) -> float:
		var count: int = 0
		for day: int in days:
			if day >= first_day and day <= last_day:
				count += 1
		return float(count) / (last_day - first_day + 1)


## Bir profilden oyuncuların ortanca değerleri.
class Summary:
	var players: int = 0
	## Bütün yükseltmeleri MAX_DAYS içinde alan oyuncu sayısı.
	var finished: int = 0
	var first_upgrade_run: float = -1.0
	## EARLY_DAYS ve MID_DAYS'teki turların ortalama kazancı.
	var early_earned: float = 0.0
	var mid_earned: float = 0.0
	## İlk gün ile MID_DAYS'in sonu arasında günde tur.
	var runs_per_day: float = 0.0
	## Bütün yükseltmeler: gün ve tur (bitirenlerin ortancası; kimse bitirmediyse -1).
	var all_upgrades_day: float = -1.0
	var all_upgrades_run: float = -1.0
	var first_run_height: float = 0.0
	## REPORT_DAYS'teki günlerin sonuna kadarki en yüksek tur (m).
	var best_heights: PackedFloat64Array = PackedFloat64Array()


func _init(library: ChunkLibrary, sectors: SectorCatalog, music: MusicCatalog,
		tuning: TuningConfig, upgrades: UpgradeCatalog) -> void:
	_library = library
	_sectors = sectors
	_music = music
	_tuning = tuning
	_upgrades = upgrades
	_read_chunks()


## Varsayılan profiller (architecture.md §13.1'deki tablo). Beceri ölçeği: S1 parçaları 1–3,
## S5 parçaları 4–7 zorlukta (+ hız payı).
static func profiles() -> Array[Profile]:
	return [
		Profile.new("casual", -0.5, 4.5, 250.0, 0.4, 1.0, 10.0),
		Profile.new("regular", 0.0, 6.5, 200.0, 0.6, 1.1, 20.0),
		Profile.new("skilled", 1.0, 8.5, 120.0, 0.8, 1.3, 30.0),
	]


## Etkin zorluğu difficulty olan bir parçada becerisi skill olan oyuncunun ölme şansı.
static func death_chance(difficulty: float, skill: float) -> float:
	return minf(DEATH_AT_SKILL * pow(DEATH_GROWTH, difficulty - skill), MAX_DEATH)


## Her başlangıç sektörü için seed_count harita kurar: oyundaki ChunkSpawner parent'ın altında
## gerçek seçimle parça yerleştirir (havuzlar haritalar arasında paylaşılır, Main'deki gibi).
func sample_maps(parent: Node, seed_count: int) -> void:
	_maps.clear()
	var pools: ChunkPools = ChunkPools.new()
	parent.add_child(pools)
	for start: int in range(1, _sectors.count() + 1):
		var list: Array = []
		for i: int in seed_count:
			list.append(_sample_map(parent, pools, start, FIRST_SEED + i))
		_maps[start] = list
	parent.remove_child(pools)
	pools.free()


## Başlangıç sektörünün kurulmuş haritaları.
func maps(start_sector: int) -> Array:
	return _maps.get(start_sector, [])


## S1'den başlayan haritalarda sektörün 100 m'sine düşen Glimmer değeri (ortalama).
func glimmers_per_100m(sector: int) -> float:
	var bottom: float = _sectors.start_height(sector)
	var top: float = minf(_sectors.end_height(sector), MAP_TOP)
	var total: int = 0
	var list: Array = maps(1)
	for item: Variant in list:
		var map: MapSample = item as MapSample
		for i: int in map.glimmer_heights.size():
			if map.glimmer_heights[i] >= bottom and map.glimmer_heights[i] < top:
				total += map.glimmer_values[i]
	return 100.0 * total / ((top - bottom) * list.size()) if not list.is_empty() else 0.0


## Glimmer alma oranı: mıknatıs kaçanların menzil / koridor yarı genişliği kadarını yakalar.
func collect_rate(profile: Profile, loadout: RunLoadout) -> float:
	var reach: float = clampf(loadout.magnet_m / (_tuning.corridor_width / 2.0), 0.0, 1.0)
	return 1.0 - (1.0 - profile.collect_rate) * (1.0 - reach)


## Bir tur: harita alttan üste geçilir; her parçada ölüm şansı denenir (kalkan ve diriliş emer).
func simulate_run(map: MapSample, skill: float, loadout: RunLoadout, profile: Profile,
		rng: RandomNumberGenerator) -> RunOutcome:
	var start_height: float = _sectors.start_height(map.start_sector)
	var dash_top: float = start_height + loadout.head_start_m
	var shield: bool = loadout.start_shield
	var shield_broken_at: float = 0.0
	var revives: int = loadout.revives
	var death: float = MAP_TOP
	for i: int in map.bottoms.size():
		var bottom: float = map.bottoms[i]
		var top: float = map.tops[i]
		if not shield and loadout.shield_regen_m > 0.0 \
				and bottom - shield_broken_at >= loadout.shield_regen_m:
			shield = true
		var exposed: float = maxf(bottom, dash_top)
		if exposed >= top:
			continue
		var chance: float = death_chance(map.difficulties[i], skill) \
				* (top - exposed) / (top - bottom)
		if rng.randf() >= chance:
			continue
		var hit: float = lerpf(exposed, top, rng.randf())
		if shield:
			shield = false
			shield_broken_at = hit
		elif revives > 0:
			revives -= 1
		else:
			death = hit
			break
	var rate: float = collect_rate(profile, loadout)
	var total: float = 0.0
	for j: int in map.glimmer_heights.size():
		var height: float = map.glimmer_heights[j]
		if height >= death:
			continue
		if height < dash_top:
			total += map.glimmer_values[j]
		elif rng.randf() < rate:
			total += map.glimmer_values[j] * profile.combo_factor
	var outcome: RunOutcome = RunOutcome.new()
	outcome.height = death
	outcome.reached = _sectors.sector_at(death)
	outcome.glimmers = roundi(total)
	var base: int = outcome.glimmers + Earnings.sector_bonus(map.start_sector, outcome.reached)
	outcome.earned = base + Earnings.boost_bonus(base, loadout.glimmer_boost)
	var dash_end: float = minf(dash_top, death)
	outcome.duration = _climb_time(start_height, dash_end) / _tuning.head_start_speedup \
			+ _climb_time(dash_end, death) + RUN_OVERHEAD
	return outcome


## Bir oyuncunun ilk turundan bütün yükseltmeleri alana (ya da MAX_DAYS'e) kadar turları.
func simulate_player(profile: Profile, player_seed: int,
		policy: StartPolicy = StartPolicy.BEST_RATE) -> PlayerLog:
	var history: PlayerLog = PlayerLog.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = player_seed
	var levels: Dictionary[StringName, int] = {}
	var wallet: int = 0
	var highest: int = 1
	var start: int = 1
	var played: float = 0.0
	var day_length: float = profile.minutes_per_day * SECONDS_PER_MINUTE
	var runs: int = 0
	while floori(played / day_length) < MAX_DAYS:
		var skill: float = profile.skill_after(runs)
		var loadout: RunLoadout = RunLoadout.from_levels(_upgrades, levels)
		match policy:
			StartPolicy.BEST_RATE:
				if runs % CHOICE_EVERY == 0:
					start = _best_start(profile, skill, loadout, highest, rng)
			StartPolicy.HIGHEST:
				start = highest
		var outcome: RunOutcome = simulate_run(_random_map(start, rng), skill, loadout, profile,
				rng)
		runs += 1
		played += outcome.duration
		wallet += outcome.earned
		highest = maxi(highest, outcome.reached)
		var day: int = floori(played / day_length) + 1
		history.earned.append(outcome.earned)
		history.heights.append(outcome.height)
		history.days.append(day)
		history.starts.append(start)
		wallet = _buy_upgrades(levels, wallet)
		if history.first_upgrade_run < 0 and not levels.is_empty():
			history.first_upgrade_run = runs
		if _all_bought(levels):
			history.all_upgrades_run = runs
			history.all_upgrades_day = day
			break
	return history


## Profilden count oyuncu (tohumlar first_seed'den) oynatır; ortanca değerleri döndürür.
func summarize(profile: Profile, count: int, first_seed: int,
		policy: StartPolicy = StartPolicy.BEST_RATE) -> Summary:
	var first_runs: Array[float] = []
	var early: Array[float] = []
	var mid: Array[float] = []
	var per_day: Array[float] = []
	var all_days: Array[float] = []
	var all_runs: Array[float] = []
	var first_heights: Array[float] = []
	var best: Array[Array] = []
	for day: int in REPORT_DAYS:
		best.append([] as Array[float])
	var result: Summary = Summary.new()
	result.players = count
	for i: int in count:
		var history: PlayerLog = simulate_player(profile, first_seed + i, policy)
		first_runs.append(float(history.first_upgrade_run))
		early.append(history.mean_earned(EARLY_DAYS.x, EARLY_DAYS.y))
		mid.append(history.mean_earned(MID_DAYS.x, MID_DAYS.y))
		per_day.append(history.runs_per_day(EARLY_DAYS.x, MID_DAYS.y))
		first_heights.append(history.heights[0])
		for k: int in REPORT_DAYS.size():
			best[k].append(history.best_height(REPORT_DAYS[k]))
		if history.all_upgrades_day > 0:
			result.finished += 1
			all_days.append(float(history.all_upgrades_day))
			all_runs.append(float(history.all_upgrades_run))
	result.first_upgrade_run = median(first_runs)
	result.early_earned = median(early)
	result.mid_earned = median(mid)
	result.runs_per_day = median(per_day)
	result.first_run_height = median(first_heights)
	for list: Array in best:
		var values: Array[float] = []
		values.assign(list)
		result.best_heights.append(median(values))
	if not all_days.is_empty():
		result.all_upgrades_day = median(all_days)
		result.all_upgrades_run = median(all_runs)
	return result


## Ortanca; boş dizide 0.
static func median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var middle: int = floori(sorted.size() / 2.0)
	if sorted.size() % 2 == 1:
		return sorted[middle]
	return (sorted[middle - 1] + sorted[middle]) / 2.0


## Bütün yükseltmelerin toplam fiyatı.
func total_upgrade_cost() -> int:
	var total: int = 0
	for def: UpgradeDef in _upgrades.upgrades:
		for cost: int in def.costs:
			total += cost
	return total


## En ucuz yükseltmenin ilk seviyesi.
func cheapest_cost() -> int:
	var result: int = -1
	for def: UpgradeDef in _upgrades.upgrades:
		var cost: int = def.cost_for(1)
		if result < 0 or cost < result:
			result = cost
	return result


## Parça sahnelerinin boyunu ve Glimmer'larını (tasarımdaki yer, değer) okur.
func _read_chunks() -> void:
	for scene: PackedScene in _library.chunks:
		var info: ChunkInfo = scene.instantiate() as ChunkInfo
		var id: StringName = StringName(scene.resource_path.get_file().get_basename())
		var beats: PackedFloat64Array = PackedFloat64Array()
		var values: PackedInt32Array = PackedInt32Array()
		for item: Node2D in info.items():
			if item is Glimmer:
				beats.append(-item.position.y / ChunkInfo.BEAT_GRID_PX)
				values.append((item as Glimmer).value)
		_lengths[id] = info.length_beats
		_glimmer_beats[id] = beats
		_glimmer_values[id] = values
		info.free()


func _sample_map(parent: Node, pools: ChunkPools, start: int, run_seed: int) -> MapSample:
	var spawner: ChunkSpawner = ChunkSpawner.new()
	spawner.library = _library
	spawner.shared_pools = pools
	parent.add_child(spawner)
	var bpm: float = _music.pick(run_seed).bpm
	spawner.setup(RunRng.new(run_seed), _tuning, _sectors, start, 0.0, bpm)
	var base: float = _sectors.start_height(start)
	var top_px: float = TuningConfig.to_px(MAP_TOP - base)
	var half_width: float = TuningConfig.to_px(_tuning.corridor_width) / 2.0
	var climbed: float = 0.0
	while climbed < top_px:
		var view_top: float = -climbed - VIEW_HEIGHT_PX
		spawner.update_view(view_top, view_top + VIEW_HEIGHT_PX, half_width)
		climbed += SCROLL_STEP_PX
	var map: MapSample = MapSample.new()
	map.start_sector = start
	var first_speed: float = _sectors.def_at(1).climb_speed
	for i: int in spawner.placed_names.size():
		var bottom: float = base - spawner.placed_bottoms[i] / TuningConfig.PX_PER_M
		if bottom >= MAP_TOP:
			break
		var def: SectorDef = _sectors.def_at(_sectors.sector_at(bottom + EDGE_M))
		var beat_m: float = def.beat_px(bpm) / TuningConfig.PX_PER_M
		var id: StringName = spawner.placed_names[i]
		map.bottoms.append(bottom)
		map.tops.append(bottom + _lengths[id] * beat_m)
		map.difficulties.append(spawner.placed_difficulties[i]
				+ SPEED_DIFFICULTY * (def.climb_speed - first_speed))
		for k: int in _glimmer_beats[id].size():
			map.glimmer_heights.append(bottom + _glimmer_beats[id][k] * beat_m)
			map.glimmer_values.append(_glimmer_values[id][k] * _tuning.glimmer_value)
	# Ağaçtan çıkan yerleştirici etkin parçaları paylaşılan havuzlara geri verir.
	parent.remove_child(spawner)
	spawner.free()
	return map


func _random_map(start: int, rng: RandomNumberGenerator) -> MapSample:
	var list: Array = maps(start)
	return list[rng.randi_range(0, list.size() - 1)] as MapSample


## En çok Glimmer / dakika getiren açık başlangıç sektörü (deneme turlarıyla).
func _best_start(profile: Profile, skill: float, loadout: RunLoadout, highest: int,
		rng: RandomNumberGenerator) -> int:
	var best: int = 1
	var best_rate: float = -1.0
	for start: int in range(1, highest + 1):
		var earned: int = 0
		var duration: float = 0.0
		for i: int in CHOICE_SAMPLES:
			var outcome: RunOutcome = simulate_run(_random_map(start, rng), skill, loadout,
					profile, rng)
			earned += outcome.earned
			duration += outcome.duration
		if earned / duration > best_rate:
			best_rate = earned / duration
			best = start
	return best


## Gücün yettikçe en ucuz sonraki seviyeyi alır; kalan cüzdanı döndürür.
func _buy_upgrades(levels: Dictionary[StringName, int], wallet: int) -> int:
	while true:
		var best_id: StringName = &""
		var best_cost: int = -1
		for def: UpgradeDef in _upgrades.upgrades:
			var cost: int = def.cost_for(levels.get(def.id, 0) + 1)
			if cost >= 0 and (best_cost < 0 or cost < best_cost):
				best_cost = cost
				best_id = def.id
		if best_cost < 0 or best_cost > wallet:
			return wallet
		wallet -= best_cost
		levels[best_id] = levels.get(best_id, 0) + 1
	return wallet


func _all_bought(levels: Dictionary[StringName, int]) -> bool:
	for def: UpgradeDef in _upgrades.upgrades:
		if levels.get(def.id, 0) < def.max_level():
			return false
	return true


## from'dan to'ya (m) sektör hızlarıyla tırmanma süresi (sn).
func _climb_time(from: float, to: float) -> float:
	var result: float = 0.0
	var height: float = from
	while height < to:
		var sector: int = _sectors.sector_at(height)
		var end: float = minf(_sectors.end_height(sector), to)
		result += (end - height) / _sectors.def_at(sector).climb_speed
		height = end
	return result
