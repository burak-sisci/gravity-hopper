class_name RunResult
extends RefCounted
## Bitmiş bir turun özeti.
##
## GameManager oluşturur; Progression kazancı ve rekor durumunu ekler (M4-02); sonuç ekranı okur.

## Tırmanılan yükseklik (metre). Oyunun skoru budur.
var height_m: int = 0
## Bu turda toplanan Glimmer (kombo çarpanıyla).
var glimmers: int = 0
## Bu turdaki kıl payı geçiş sayısı.
var near_misses: int = 0
## Turun başladığı sektör (kontrol noktası; 1'den başlar).
var start_sector: int = 1
## Ulaşılan en yüksek sektör (1'den başlar).
var sector_reached: int = 1
## Turun bitiş nedeni.
var cause: GameTypes.DeathCause = GameTypes.DeathCause.HAZARD
## Haritayı üreten tohum (günlük meydan okuma ve hata yeniden üretimi için).
var run_seed: int = 0
## Sektör tamamlama bonusu (Progression.sector_bonus).
var sector_bonus: int = 0
## Cüzdana giren toplam kazanç: toplanan Glimmer + sektör bonusu.
var earned: int = 0
## Bu tur rekor kırdı mı.
var new_record: bool = false
## Bu turdan sonraki kalıcı rekor (m); sonuç ekranının "rekora X m" satırı için.
var best_height_m: int = 0
