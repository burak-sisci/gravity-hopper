class_name RunStats
extends RefCounted
## Turun istatistikleri (architecture.md §8.6, M2-13). Run'a aittir. Toplanan Glimmer'ın değeri
## burada hesaplanır: temel değer × kombo çarpanı (kombo M2-14'te; o zamana kadar 1).

## Bu turda kazanılan Glimmer.
var glimmers: int = 0
## Glimmer değerinin çarpanı (kıl payı kombosu, M2-14).
var multiplier: int = 1
## Bu turdaki kıl payı sayısı.
var near_misses: int = 0


## Bir Glimmer'ı sayar; kazanılan değeri döndürür.
func add_glimmer(base_value: int) -> int:
	var awarded: int = base_value * multiplier
	glimmers += awarded
	return awarded
