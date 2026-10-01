class_name RunResult
extends RefCounted
## Bitmiş bir turun özeti.
##
## GameManager oluşturur; sonuç ekranı ve Progression okur.

## Tırmanılan yükseklik (metre). Oyunun skoru budur.
var height_m: int = 0
## Bu turda kazanılan Glimmer.
var glimmers: int = 0
## Bu turdaki kıl payı geçiş sayısı.
var near_misses: int = 0
## Ulaşılan en yüksek sektör (1'den başlar).
var sector_reached: int = 1
## Turun bitiş nedeni.
var cause: GameTypes.DeathCause = GameTypes.DeathCause.HAZARD
## Haritayı üreten tohum (günlük meydan okuma ve hata yeniden üretimi için).
var run_seed: int = 0
