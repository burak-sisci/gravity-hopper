class_name PressureSystem
extends Node
## Çöküş duvarının mantığı (architecture.md §8.4, M2-15; GDD §14). Duvar oyuncudan biraz daha hızlı
## tırmanır: aradaki mesafe (distance_m) her adımda sektörün sürünme hızı kadar azalır. Glimmer ve
## kıl payı duvarı iter, kalkanla darbe almak çeker (M2-16). Mesafe sıfıra inince yukarı
## wall_reached yayar; Run oyuncuyu öldürür. Görsel ve yakınlık yayını Run'dadır.

signal wall_reached

## Oyuncunun altındaki mesafe (m).
var distance_m: float = 0.0
## Sürünme hızı (m/sn; sektörden).
var creep: float = 0.0

var _max_distance: float = 0.0
var _reached: bool = false


## Turun başında mesafeyi ve sınırı kurar.
func setup(start_distance: float, max_distance: float, creep_speed: float) -> void:
	distance_m = start_distance
	_max_distance = max_distance
	creep = creep_speed
	_reached = false


## Run her fizik adımında çağırır (oyuncu canlıyken).
func advance(delta: float) -> void:
	if _reached:
		return
	distance_m -= creep * delta
	_check()


## Duvarı iter (Glimmer, kıl payı); en fazla sınıra kadar.
func push(meters: float) -> void:
	if not _reached:
		distance_m = minf(distance_m + meters, _max_distance)


## Diriliş (M4-07): duvar en az meters uzağa (en çok sınıra) geri itilir; yakalanma sıfırlanır.
func revive(meters: float) -> void:
	distance_m = maxf(distance_m, minf(meters, _max_distance))
	_reached = false


## Duvarı çeker (kalkanla darbe).
func pull(meters: float) -> void:
	if _reached:
		return
	distance_m -= meters
	_check()


func _check() -> void:
	if distance_m <= 0.0:
		distance_m = 0.0
		_reached = true
		wall_reached.emit()
