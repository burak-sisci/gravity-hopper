extends Node
## Kalıcı ilerleme: Glimmer cüzdanı, rekor, en yüksek sektör, istatistikler ve yükseltme seviyeleri
## (satın alma M4-03). Tur başında yükseltmelerin etkileri tek bir yük olarak verilir (loadout,
## M4-04). Kozmetik izler (M4-08): satın alma, kuşanma ve başarımla açılma; kuşanılan iz yükle
## tura gider. Başarım izleri tur sonunda (toplam kıl payı) ve Büyük Depoya varınca açılır.
##
## Veriyi SaveManager ile saklar (architecture.md §11). Açılışta kaydı yükler; ilk açılışta
## (ya da yalnızca yedek sağlamsa) hemen yazar. Tur sonunda GameManager finish_run'ı çağırır:
## kazanç hesaplanır, cüzdana ve rekora işlenir, kaydedilir. Uygulama arka plana geçerken ya da
## kapanırken kaydedilmemiş bir değişiklik varsa o da yazılır. Kazanç formülleri Earnings'te.

const UPGRADES: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")
const TRAILS: TrailCatalog = preload("res://data/trails/trail_catalog.tres")

## Oyuncunun sahip olduğu Glimmer.
var glimmers: int = 0
## Kalıcı rekor (m). Rekor çizgisi ve HUD'un rekor satırı buradan gelir.
var best_height_m: int = 0
## Ulaşılan en yüksek sektör (kontrol noktaları, M4-09).
var highest_sector: int = 1

var _data: Dictionary[String, Variant] = {}
## Kaydedilmemiş değişiklik var.
var _dirty: bool = false


func _ready() -> void:
	reload()
	if SaveManager.last_source != SaveManager.Source.MAIN:
		save()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, \
				NOTIFICATION_WM_GO_BACK_REQUEST:
			if _dirty:
				save()


## Kaydı yeniden okur (açılış; testlerde uygulamanın yeniden açılması) ve değerleri duyurur.
func reload() -> void:
	_data = SaveManager.load_game()
	glimmers = int(_data["glimmers"])
	best_height_m = int(_data["best_height_m"])
	highest_sector = int(_data["highest_sector"])
	_dirty = false
	_log("loaded glimmers=%d best=%d sector=%d" % [glimmers, best_height_m, highest_sector])
	announce()


## Kaydı siler ve boş kayıtla baştan başlar (debug "kaydı sıfırla", testler).
func reset() -> void:
	SaveManager.delete_save()
	reload()
	save()


## Kalıcı değerleri duyurur. Arayüz ilk değerlerini buradan alır: GameManager her tur başında
## çağırır (UI autoload okumaz, yalnızca Events dinler).
func announce() -> void:
	Events.glimmers_changed.emit(glimmers)
	Events.best_height_changed.emit(best_height_m)


## Cüzdana Glimmer ekler ve yeni toplamı duyurur. Kayıt bir sonraki kayıt anında yazılır.
func add_glimmers(amount: int) -> void:
	glimmers += amount
	_dirty = true
	Events.glimmers_changed.emit(glimmers)


## Tur sonu (GameManager, run_ended'den önce çağırır): kazancı ve rekor durumunu sonuca yazar;
## cüzdanı, rekoru, en yüksek sektörü ve istatistikleri günceller, kaydeder.
func finish_run(result: RunResult) -> void:
	result.sector_bonus = Earnings.sector_bonus(result.start_sector, result.sector_reached)
	var base: int = result.glimmers + result.sector_bonus
	result.boost_bonus = Earnings.boost_bonus(base, result.glimmer_boost)
	result.earned = result.glimmers + result.sector_bonus + result.boost_bonus
	result.new_record = result.height_m > best_height_m
	var stats: Dictionary = _data["stats"]
	stats["runs"] = int(stats["runs"]) + 1
	stats["total_height_m"] = int(stats["total_height_m"]) + result.height_m
	stats["near_misses"] = int(stats["near_misses"]) + result.near_misses
	stats["glimmers_earned"] = int(stats["glimmers_earned"]) + result.earned
	highest_sector = maxi(highest_sector, result.sector_reached)
	if result.new_record:
		best_height_m = result.height_m
		Events.best_height_changed.emit(best_height_m)
	result.best_height_m = best_height_m
	add_glimmers(result.earned)
	_unlock_trails()
	save()
	_log("run earned=%d bonus=%d boost=%d wallet=%d best=%d" % [
		result.earned, result.sector_bonus, result.boost_bonus, glimmers, best_height_m,
	])


## Yükseltmenin seviyesi (0 = alınmamış).
func upgrade_level(id: StringName) -> int:
	var levels: Dictionary = _data["upgrades"]
	return int(levels.get(String(id), 0))


## Yükseltmenin şu anki etkisi (UpgradeDef.values; alınmamışsa 0).
func upgrade_value(id: StringName) -> float:
	var def: UpgradeDef = UPGRADES.get_def(id)
	return def.value_at(upgrade_level(id)) if def != null else 0.0


## Sonraki seviyenin fiyatı; en üst seviyedeyse ya da yükseltme bilinmiyorsa -1.
func upgrade_cost(id: StringName) -> int:
	var def: UpgradeDef = UPGRADES.get_def(id)
	return def.cost_for(upgrade_level(id) + 1) if def != null else -1


func can_buy(id: StringName) -> bool:
	var cost: int = upgrade_cost(id)
	return cost >= 0 and glimmers >= cost


## Yükseltmenin sonraki seviyesini satın alır. Cüzdan yetmezse ya da en üst seviyedeyse olmaz
## (false). Alınınca hemen kaydedilir, cüzdan ve yeni seviye duyurulur.
func buy_upgrade(id: StringName) -> bool:
	if not can_buy(id):
		return false
	var cost: int = upgrade_cost(id)
	var level: int = upgrade_level(id) + 1
	glimmers -= cost
	(_data["upgrades"] as Dictionary)[String(id)] = level
	save()
	Events.glimmers_changed.emit(glimmers)
	Events.upgrade_purchased.emit(id, level)
	_log("bought %s level=%d cost=%d wallet=%d" % [id, level, cost, glimmers])
	return true


## Turun yükseltme yükü (ADR-066): oynanışı etkileyen yükseltmelerin şu anki etkileri. Main her
## tur başında alır; tur boyunca değişmez (tur sırasında alınan seviye sonraki turda geçerli).
func loadout() -> RunLoadout:
	var result: RunLoadout = RunLoadout.new()
	result.magnet_m = upgrade_value(&"magnet")
	result.glimmer_boost = upgrade_value(&"glimmer_boost")
	# Kalkan Sv1'in değeri 0'dır (yenilenmez); her seviye turu kalkanla başlatır (M4-05).
	result.start_shield = upgrade_level(&"shield") > 0
	result.shield_regen_m = upgrade_value(&"shield")
	result.head_start_m = upgrade_value(&"head_start")
	result.revives = roundi(upgrade_value(&"second_chance"))
	result.trail = TRAILS.get_def(equipped_trail())
	_log("loadout magnet=%.1f boost=%.1f shield=%s regen=%d head_start=%d revives=%d trail=%s" % [
		result.magnet_m, result.glimmer_boost, result.start_shield, roundi(result.shield_regen_m),
		roundi(result.head_start_m), result.revives, result.trail.id,
	])
	return result


## İz oyuncunun mu: baştan açık iz ya da satın alınmış / başarımla açılmış.
func owns_trail(id: StringName) -> bool:
	var def: TrailDef = TRAILS.get_def(id)
	if def == null:
		return false
	return def.unlock == GameTypes.TrailUnlock.FREE or _owned_trails().has(String(id))


## Kuşanılan iz; kayıttaki iz bilinmiyorsa ya da oyuncunun değilse varsayılan iz.
func equipped_trail() -> StringName:
	var id: StringName = StringName(String((_data["trails"] as Dictionary)["equipped"]))
	return id if owns_trail(id) else TRAILS.default_def().id


func can_buy_trail(id: StringName) -> bool:
	var def: TrailDef = TRAILS.get_def(id)
	if def == null or def.unlock != GameTypes.TrailUnlock.PURCHASE or owns_trail(id):
		return false
	return glimmers >= def.cost


## Satın alınan izi alır: cüzdan yetmezse, iz zaten alınmışsa ya da başarım iziyse olmaz (false).
## Alınınca hemen kaydedilir; cüzdan ve iz duyurulur. Kuşanmak ayrı adımdır (equip_trail).
func buy_trail(id: StringName) -> bool:
	if not can_buy_trail(id):
		return false
	var cost: int = TRAILS.get_def(id).cost
	glimmers -= cost
	_own_trail(id)
	save()
	Events.glimmers_changed.emit(glimmers)
	Events.trail_unlocked.emit(id)
	_log("bought trail %s cost=%d wallet=%d" % [id, cost, glimmers])
	return true


## Oyuncunun izini kuşanır, hemen kaydeder ve duyurur; iz oyuncunun değilse olmaz (false).
## Sonraki turda görünür (tur yükü tur başında alınır).
func equip_trail(id: StringName) -> bool:
	if not owns_trail(id):
		return false
	(_data["trails"] as Dictionary)["equipped"] = String(id)
	save()
	Events.trail_equipped.emit(id)
	_log("equipped trail %s" % id)
	return true


## İzi bedelsiz verir (debug `--trail=` argümanı ve İlerleme sayfası, testler). Bilinmeyen iz
## yok sayılır. Bir sonraki kayıt anında yazılır.
func grant_trail(id: StringName) -> void:
	if TRAILS.get_def(id) == null or owns_trail(id):
		return
	_own_trail(id)
	_dirty = true
	Events.trail_unlocked.emit(id)


## Büyük Depolama Birimi'ne varıldı (tur akışı M4-13'te çağırır; şimdilik debug ve testler):
## kayda işlenir, başarım izi açılır, kaydedilir.
func mark_great_storage_reached() -> void:
	_data["great_storage_reached"] = true
	_unlock_trails()
	save()


## Yükseltmenin seviyesini doğrudan koyar (debug `--upgrade=` argümanı, testler); 0 ile en üst
## seviye arasına sınırlanır, bilinmeyen yükseltme yok sayılır. Bir sonraki kayıt anında yazılır.
func set_upgrade_level(id: StringName, level: int) -> void:
	var def: UpgradeDef = UPGRADES.get_def(id)
	if def == null:
		return
	(_data["upgrades"] as Dictionary)[String(id)] = clampi(level, 0, def.max_level())
	_dirty = true


## Değerleri kayda işler ve yazar.
func save() -> bool:
	_data["glimmers"] = glimmers
	_data["best_height_m"] = best_height_m
	_data["highest_sector"] = highest_sector
	var ok: bool = SaveManager.save_game(_data)
	if ok:
		_dirty = false
	return ok


## Başarım izlerinden koşulu sağlananları açar ve duyurur (GDD §11). Kayıt çağıranın işi.
func _unlock_trails() -> void:
	var near_misses: int = int((_data["stats"] as Dictionary)["near_misses"])
	for def: TrailDef in TRAILS.trails:
		if owns_trail(def.id):
			continue
		var reached: bool = false
		match def.unlock:
			GameTypes.TrailUnlock.NEAR_MISSES:
				reached = near_misses >= def.goal
			GameTypes.TrailUnlock.GREAT_STORAGE:
				reached = bool(_data["great_storage_reached"])
		if reached:
			_own_trail(def.id)
			Events.trail_unlocked.emit(def.id)
			_log("trail unlocked %s" % def.id)


func _owned_trails() -> Array:
	return (_data["trails"] as Dictionary)["owned"]


func _own_trail(id: StringName) -> void:
	_owned_trails().append(String(id))


func _log(line: String) -> void:
	if OS.is_debug_build():
		print("PROGRESS ", line)
