class_name Earnings
extends RefCounted
## Tur sonu kazanç formülleri (GDD §9.1, architecture.md §10): sektör bonusu ve Glimmer Çarpanı.
## Durum tutmaz: Progression.finish_run ve ekonomi benzetimi (M4-14) aynı formülü kullanır.
## Autoload'a bağlı değildir; ekransız araç betikleri sınıfı adıyla derler.

const TUNING: TuningConfig = preload("res://data/tuning/default_tuning.tres")


## Glimmer Çarpanının tur sonu kazancına eklediği (GDD §9.1: +%10 / seviye), en yakın tam sayıya
## yuvarlanır.
static func boost_bonus(base: int, boost: float) -> int:
	return roundi(base * boost)


## Turda tamamlanan sektörlerin bonusu: start_sector'dan reached'e kadar geçilen her sektör
## için sector_bonus × sektör numarası (GDD §9.1).
static func sector_bonus(start_sector: int, reached: int) -> int:
	var total: int = 0
	for index: int in range(start_sector, reached):
		total += TUNING.sector_bonus * index
	return total
