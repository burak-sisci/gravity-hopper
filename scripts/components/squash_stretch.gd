class_name SquashStretch
extends RefCounted
## Çekirdeğin sıkışma-uzaması (M3-11, architecture.md §9; yalnızca görsel). Sahibi kick() ile
## yana bir sapma verir, her fizik adımında advance() çağırır ve visual_scale() /
## visual_offset() değerlerini görsel düğümüne uygular; çarpışma şekilleri değişmez. Sapma bir
## yayla 1'e döner (sönümlü salınım, değerler NeonStyle'da). Kapalı biçimde hesaplanır: sonuç
## adım boyundan bağımsızdır (60 ve 120 Hz'de aynı).

## Salınımın zarfı bunun altına inince yay durur ve ölçek tam 1 olur.
const REST_EPSILON: float = 0.002

## Son vuruşun sapması (0 = dinlenmede) ve vuruştan beri geçen süre.
var _amplitude: float = 0.0
var _elapsed: float = 0.0


## Yana sapma verir: artı uzama (çevirme), eksi sıkışma (iniş). Önceki salınımın yerini alır.
func kick(amount: float) -> void:
	_amplitude = amount
	_elapsed = 0.0


func advance(delta: float) -> void:
	if _amplitude == 0.0:
		return
	_elapsed += delta
	var omega: float = TAU * Neon.STYLE.squash_frequency
	if absf(_amplitude) * exp(-Neon.STYLE.squash_damping * omega * _elapsed) < REST_EPSILON:
		_amplitude = 0.0


func is_resting() -> bool:
	return _amplitude == 0.0


## Şu anki yana sapma (0 dinlenme, artı uzama, eksi sıkışma). Başlangıç hızı sıfır olan
## sönümlü salınım.
func deformation() -> float:
	if _amplitude == 0.0:
		return 0.0
	var omega: float = TAU * Neon.STYLE.squash_frequency
	var zeta: float = Neon.STYLE.squash_damping
	var damped: float = omega * sqrt(1.0 - zeta * zeta)
	var envelope: float = _amplitude * exp(-zeta * omega * _elapsed)
	return envelope * (cos(damped * _elapsed) + zeta * omega / damped * sin(damped * _elapsed))


## Görsel ölçek: yana 1 + sapma, dikeyde alanı koruyacak kadar.
func visual_scale() -> Vector2:
	var width: float = 1.0 + deformation()
	return Vector2(width, 1.0 / width)


## Görselin yana kayması (side: aktif duvarın yönü, -1 sol / +1 sağ). Yarı genişliği half_width
## olan şeklin sıkışırken duvardaki kenarı, uzarken arkada kalan kenarı yerinde durur; ikisinde
## de kayma aktif duvara doğrudur. Böylece inişte çekirdek duvardan kopmuş görünmez.
func visual_offset(half_width: float, side: float) -> Vector2:
	return Vector2(side * half_width * absf(deformation()), 0.0)
