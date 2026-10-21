extends Node
## Kalıcı ilerleme: Glimmer cüzdanı, rekor, en yüksek sektör, istatistikler ve yükseltme seviyeleri
## (satın alma M4-03); izler M4-08. Tur başında yükseltmelerin etkileri tek bir yük olarak verilir
## (loadout, M4-04).
##
## Veriyi SaveManager ile saklar (architecture.md §11). Açılışta kaydı yükler; ilk açılışta
## (ya da yalnızca yedek sağlamsa) hemen yazar. Tur sonunda GameManager finish_run'ı çağırır:
## kazanç hesaplanır, cüzdana ve rekora işlenir, kaydedilir. Uygulama arka plana geçerken ya da
## kapanırken kaydedilmemiş bir değişiklik varsa o da yazılır.

const TUNING: TuningConfig = preload("res://data/tuning/default_tuning.tres")
const UPGRADES: UpgradeCatalog = preload("res://data/upgrades/upgrade_catalog.tres")

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
	result.sector_bonus = sector_bonus(result.start_sector, result.sector_reached)
	result.boost_bonus = boost_bonus(result.glimmers + result.sector_bonus, result.glimmer_boost)
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
	_log("loadout magnet=%.1f boost=%.1f shield=%s regen=%d" % [result.magnet_m,
			result.glimmer_boost, result.start_shield, roundi(result.shield_regen_m)])
	return result


## Yükseltmenin seviyesini doğrudan koyar (debug `--upgrade=` argümanı, testler); 0 ile en üst
## seviye arasına sınırlanır, bilinmeyen yükseltme yok sayılır. Bir sonraki kayıt anında yazılır.
func set_upgrade_level(id: StringName, level: int) -> void:
	var def: UpgradeDef = UPGRADES.get_def(id)
	if def == null:
		return
	(_data["upgrades"] as Dictionary)[String(id)] = clampi(level, 0, def.max_level())
	_dirty = true


## Glimmer Çarpanının tur sonu kazancına eklediği (GDD §9.1: +%10 / seviye), en yakın tam sayıya
## yuvarlanır.
func boost_bonus(base: int, boost: float) -> int:
	return roundi(base * boost)


## Turda tamamlanan sektörlerin bonusu: start_sector'dan reached'e kadar geçilen her sektör
## için sector_bonus × sektör numarası (GDD §9.1).
func sector_bonus(start_sector: int, reached: int) -> int:
	var total: int = 0
	for index: int in range(start_sector, reached):
		total += TUNING.sector_bonus * index
	return total


## Değerleri kayda işler ve yazar.
func save() -> bool:
	_data["glimmers"] = glimmers
	_data["best_height_m"] = best_height_m
	_data["highest_sector"] = highest_sector
	var ok: bool = SaveManager.save_game(_data)
	if ok:
		_dirty = false
	return ok


func _log(line: String) -> void:
	if OS.is_debug_build():
		print("PROGRESS ", line)
