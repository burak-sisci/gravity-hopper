extends GdUnitTestSuite
## Titreşim (M5-08, GDD §19): olay → titreşim tablosu (çevirme çok hafif, kıl payı kısa, ölüm
## belirgin; sıra süre ve güçte korunur), olay sinyalleri tablodaki değerle tam bir çağrı yapar,
## ayar kapalıyken hiç çağrı yok, duraklatmadan menüye dönüş titremez. Gerçek titreşim yerine
## kaydedici bir backend kullanılır.

## "Çok hafif": tek dokunuşta hissedilir ama sık dokunuşta yormaz (Android'in en kısa tık
## titreşimleri ~10 ms). "Belirgin": ölüm, öteki her şeyden açıkça uzun ve tam güçte.
const MAX_FLIP_MS: int = 15
const MIN_DEATH_MS: int = 80

var _calls: Array[Vector2] = []
var _backend: Callable
var _vibration: bool


func before_test() -> void:
	_calls.clear()
	_backend = Haptics.backend
	_vibration = Settings.vibration
	Haptics.backend = _record
	Haptics.reset_counts()
	Settings.vibration = true


func after_test() -> void:
	Haptics.backend = _backend
	Settings.vibration = _vibration
	Haptics.reset_counts()


func test_table_orders_light_short_and_strong() -> void:
	var flip: Vector2 = Haptics.PATTERNS[GameTypes.Haptic.FLIP]
	var near: Vector2 = Haptics.PATTERNS[GameTypes.Haptic.NEAR_MISS]
	var death: Vector2 = Haptics.PATTERNS[GameTypes.Haptic.DEATH]
	assert_int(Haptics.PATTERNS.size()).is_equal(GameTypes.Haptic.size())
	assert_int(roundi(flip.x)).is_less_equal(MAX_FLIP_MS)
	assert_int(roundi(death.x)).is_greater_equal(MIN_DEATH_MS)
	assert_float(flip.x).is_less(near.x)
	assert_float(near.x).is_less(death.x)
	assert_float(flip.y).is_less(near.y)
	assert_float(near.y).is_less_equal(death.y)
	for pattern: Vector2 in Haptics.PATTERNS.values():
		assert_float(pattern.y).is_greater(0.0)
		assert_float(pattern.y).is_less_equal(1.0)


func test_events_send_their_pattern_once() -> void:
	Events.player_flipped.emit()
	Events.near_miss.emit(1, 1)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_array(_calls).is_equal([
		_pattern(GameTypes.Haptic.FLIP),
		_pattern(GameTypes.Haptic.NEAR_MISS),
		_pattern(GameTypes.Haptic.DEATH),
	])
	for event: GameTypes.Haptic in GameTypes.Haptic.values():
		assert_int(Haptics.count(event)).is_equal(1)


func test_setting_off_sends_nothing() -> void:
	Settings.vibration = false
	Events.player_flipped.emit()
	Events.near_miss.emit(2, 2)
	for cause: GameTypes.DeathCause in GameTypes.DeathCause.values():
		Events.player_died.emit(cause)
	assert_array(_calls).is_empty()


func test_quitting_from_pause_does_not_vibrate() -> void:
	Events.player_died.emit(GameTypes.DeathCause.QUIT)
	assert_array(_calls).is_empty()
	for cause: GameTypes.DeathCause in [GameTypes.DeathCause.HAZARD, GameTypes.DeathCause.FELL,
			GameTypes.DeathCause.WALL]:
		Events.player_died.emit(cause)
	assert_int(_calls.size()).is_equal(3)


func _pattern(event: GameTypes.Haptic) -> Vector2:
	var pattern: Vector2 = Haptics.PATTERNS[event]
	return Vector2(roundi(pattern.x), pattern.y)


func _record(duration_ms: int, amplitude: float) -> void:
	_calls.append(Vector2(duration_ms, amplitude))
