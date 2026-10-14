class_name SlowMotion
extends RefCounted
## Kıl payı yavaş çekimi (M3-12, GDD §15): Engine.time_scale'i kısa süre düşürür. Süre gerçek
## zamanla sayılır: Run her fizik adımında adımın gerçek süresini verir (adımlar zaman ölçeğinden
## bağımsız olarak saniyede physics_ticks_per_second kez çalışır, yalnızca delta küçülür).
## Sürenin son return_time'ında ölçek yumuşakça tabana döner. Taban, yavaş çekimin başladığı
## andaki ölçektir (debug yavaş çekimi bozulmaz). Müzik Engine.time_scale'i AudioManager'da
## izler (pitch_scale, ADR-008). Oynanış delta ile ilerlediği için harita değişmez.

var _active: bool = false
var _base: float = 1.0
var _scale: float = 1.0
var _duration: float = 0.0
var _return_time: float = 0.0
var _elapsed: float = 0.0


## Yavaş çekimi başlatır; sürüyorsa baştan başlatır (taban korunur). Süre 0 ya da ölçek 1 ise
## yavaş çekim kapalıdır.
func start(scale: float, duration: float, return_time: float) -> void:
	if duration <= 0.0 or scale >= 1.0:
		return
	if not _active:
		_base = Engine.time_scale
	_active = true
	_scale = scale
	_duration = duration
	_return_time = clampf(return_time, 0.0, duration)
	_elapsed = 0.0
	Engine.time_scale = _base * scale


## Gerçek zamanla ilerletir; süre dolunca taban ölçeğe döner.
func advance(real_delta: float) -> void:
	if not _active:
		return
	_elapsed += real_delta
	if _elapsed >= _duration:
		stop()
	else:
		Engine.time_scale = _base * factor()


## Hemen taban ölçeğe döner (ölüm, tur bitişi).
func stop() -> void:
	if not _active:
		return
	_active = false
	Engine.time_scale = _base


func is_active() -> bool:
	return _active


## Tabana göre anlık ölçek (yavaş çekim yokken 1).
func factor() -> float:
	if not _active:
		return 1.0
	var hold: float = _duration - _return_time
	if _elapsed <= hold:
		return _scale
	return lerpf(_scale, 1.0, smoothstep(0.0, 1.0, (_elapsed - hold) / _return_time))
