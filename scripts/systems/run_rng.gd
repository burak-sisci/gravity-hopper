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
## 0 döndürmez: Run'da 0 "tohum verilmedi" anlamına gelir.
static func make_seed() -> int:
	var source: RandomNumberGenerator = RandomNumberGenerator.new()
	source.randomize()
	var value: int = 0
	while value == 0:
		value = source.randi()
	return value


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


## Ağırlıklara göre bir sıra numarası seçer (ağırlığı 0 olan hiç seçilmez). Tek çekiliş kullanır.
## Ağırlıkların toplamı 0 ise -1 döndürür.
func weighted_index(weights: Array[float]) -> int:
	var total: float = 0.0
	for weight: float in weights:
		total += maxf(weight, 0.0)
	if total <= 0.0:
		return -1
	var pick: float = _rng.randf() * total
	var last: int = -1
	for i: int in weights.size():
		if weights[i] <= 0.0:
			continue
		last = i
		pick -= weights[i]
		if pick < 0.0:
			return i
	# Yuvarlama payı: çekiliş toplamın tam ucuna düşerse son geçerli seçenek.
	return last
