class_name RunRng
extends RefCounted
## Turun tohumlu rastgelelik kaynağı (architecture.md §8.2). Oynanışı etkileyen her rastgele
## karar yalnızca buradan gelir (.clauderules §5); aynı tohum her cihazda aynı diziyi verir.
## Metot adları genel randf()/randi()/seed() fonksiyonlarını gölgelemesin diye farklıdır.

var run_seed: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(new_seed: int) -> void:
	run_seed = new_seed
	_rng.seed = new_seed


## Tohum belirtilmeyen turlar için yeni bir tohum üretir (oynanışın kendisi değil, tohum seçimi).
static func make_seed() -> int:
	var source: RandomNumberGenerator = RandomNumberGenerator.new()
	source.randomize()
	return source.randi()


## [0, 1) aralığında sayı.
func next_float() -> float:
	return _rng.randf()


## [from, to] aralığında tam sayı (iki uç dahil).
func range_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## [from, to] aralığında ondalık sayı.
func range_float(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## Olasılık p (0–1) ile true.
func chance(p: float) -> bool:
	return _rng.randf() < p
