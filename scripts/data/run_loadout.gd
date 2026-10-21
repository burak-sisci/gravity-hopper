class_name RunLoadout
extends RefCounted
## Turun yükseltme yükü (ADR-066, M4-04): oynanışı etkileyen yükseltmelerin etkileri tur başında
## bir kez alınır ve tur boyunca değişmez. Main, Progression.loadout()'tan alıp Run'a ve
## GameManager'a verir. Boş yük (yeni nesne) yükseltmesiz turdur: tek başına çalışan sahne,
## testler, günlük meydan okuma (M7-03). Birimler UpgradeDef'teki gibidir.

## Mıknatıs menzili (m): oyuncunun toplama alanının ötesine eklenir. 0 = mıknatıs yok.
var magnet_m: float = 0.0
## Glimmer Çarpanı: tur sonu kazancına eklenen oran (0,1 = +%10).
var glimmer_boost: float = 0.0
