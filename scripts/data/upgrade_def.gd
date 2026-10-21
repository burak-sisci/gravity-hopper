class_name UpgradeDef
extends Resource
## Kalıcı yükseltme (GDD §10, architecture.md §10): seviye fiyatları ve etkileri.
##
## Seviye 0 alınmamış demektir; seviye n'nin fiyatı costs[n - 1], etkisi values[n - 1].
## Fiyatlar GDD'nin formülünü izler (taban × 2^(seviye - 1)); test denetler.

## Kayıttaki anahtar (kaydın "upgrades" sözlüğü) ve kodun kullandığı ad.
@export var id: StringName
## Adın ve açıklamanın çeviri anahtarları (mağaza, M5).
@export var name_key: String = ""
@export var desc_key: String = ""
## Her seviyenin fiyatı (Glimmer). Uzunluğu en üst seviyedir.
@export var costs: Array[int] = []
## Her seviyenin etkisi, `unit` biriminde (Mıknatıs: çekim yarıçapı m; Kalkan: yenilenme
## mesafesi m, 0 = yenilenmez; Başlangıç Sıçraması: m; Glimmer Çarpanı: ek oran; İkinci Şans: adet).
@export var values: Array[float] = []
## Etkinin birimi: "m", "ratio" ya da "count".
@export var unit: String = ""


func max_level() -> int:
	return costs.size()


## Seviyenin fiyatı (1'den başlar); geçersiz seviyede -1.
func cost_for(level: int) -> int:
	if level < 1 or level > costs.size():
		return -1
	return costs[level - 1]


## Seviyenin etkisi; seviye 0'da (ya da geçersizse) 0.
func value_at(level: int) -> float:
	if level < 1 or level > values.size():
		return 0.0
	return values[level - 1]
