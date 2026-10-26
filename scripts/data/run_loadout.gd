class_name RunLoadout
extends RefCounted
## Turun yükseltme yükü (ADR-066, M4-04): oynanışı etkileyen yükseltmelerin etkileri tur başında
## bir kez alınır ve tur boyunca değişmez. Main, Progression.loadout()'tan alıp Run'a ve
## GameManager'a verir. Boş yük (yeni nesne) yükseltmesiz turdur: tek başına çalışan sahne,
## testler, günlük meydan okuma (M7-03). Birimler UpgradeDef'teki gibidir. Kuşanılan kozmetik iz
## de yükle gelir (M4-08); oynanışı etkilemez, günlük meydan okumada da kalır.

## Mıknatıs menzili (m): oyuncunun toplama alanının ötesine eklenir. 0 = mıknatıs yok.
var magnet_m: float = 0.0
## Glimmer Çarpanı: tur sonu kazancına eklenen oran (0,1 = +%10).
var glimmer_boost: float = 0.0
## Kalkan yükseltmesi (M4-05): tur kalkanla başlar (Sv1 ve üstü).
var start_shield: bool = false
## Kırılan kalkanın yeniden gelmesi için tırmanılacak yol (m; Sv2–5). 0 = yenilenmez.
var shield_regen_m: float = 0.0
## Başlangıç Sıçraması (M4-06): tur başındaki sıçramanın ek yolu (m). 0 = sıçrama yok.
var head_start_m: float = 0.0
## İkinci Şans (M4-07): turdaki ücretsiz diriliş hakkı (0 ya da 1).
var revives: int = 0
## Kuşanılan kozmetik iz (M4-08). null = varsayılan iz.
var trail: TrailDef = null


## Yükseltme seviyelerinin oynanış etkileri (iz hariç). Progression.loadout ve ekonomi benzetimi
## (M4-14) aynı hesabı kullanır. levels'ta olmayan yükseltme alınmamış (seviye 0) sayılır.
static func from_levels(upgrades: UpgradeCatalog,
		levels: Dictionary[StringName, int]) -> RunLoadout:
	var result: RunLoadout = RunLoadout.new()
	result.magnet_m = _value(upgrades, levels, &"magnet")
	result.glimmer_boost = _value(upgrades, levels, &"glimmer_boost")
	# Kalkan Sv1'in değeri 0'dır (yenilenmez); her seviye turu kalkanla başlatır (M4-05).
	result.start_shield = levels.get(&"shield", 0) > 0
	result.shield_regen_m = _value(upgrades, levels, &"shield")
	result.head_start_m = _value(upgrades, levels, &"head_start")
	result.revives = roundi(_value(upgrades, levels, &"second_chance"))
	return result


## Yükseltmenin seviyesindeki etki (UpgradeDef.values; alınmamışsa ya da bilinmiyorsa 0).
static func _value(upgrades: UpgradeCatalog, levels: Dictionary[StringName, int],
		id: StringName) -> float:
	var def: UpgradeDef = upgrades.get_def(id)
	return def.value_at(levels.get(id, 0)) if def != null else 0.0
