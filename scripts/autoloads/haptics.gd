extends Node
## Titreşim (M5-08, GDD §19, architecture.md §6): çevirmede çok hafif, kıl payında kısa, ölümde
## belirgin (duraklatmadan menüye dönüş hariç). Olayları Events'ten dinler; sahne düğümlerine
## erişmez. Ayardan (Settings.vibration) kapalıysa hiç çağrı yapılmaz. Titreşim
## Input.vibrate_handheld ile gelir (Android'de VIBRATE izni, export_presets.cfg); masaüstünde
## çağrı etkisizdir. Debug derlemede her çağrı günlüğe yazılır (HAPTIC …): Redmi'de adb
## günlüğünden sayılır.

## Olay → [süre (ms), güç (0–1)]. Güç Android 8+ cihazlarda uygulanır; eski cihazlar yalnızca
## süreyi kullanır. Çevirme her dokunuşta geldiği için ancak hissedilecek kadar (10 ms, %20);
## kıl payı kısa bir tık (25 ms, %50); ölüm tam güçte, belirgin (120 ms).
const PATTERNS: Dictionary[GameTypes.Haptic, Vector2] = {
	GameTypes.Haptic.FLIP: Vector2(10.0, 0.2),
	GameTypes.Haptic.NEAR_MISS: Vector2(25.0, 0.5),
	GameTypes.Haptic.DEATH: Vector2(120.0, 1.0),
}

## Titreşimi uygulayan çağrı: (süre ms, güç). Testler kaydedici bir Callable koyar.
var backend: Callable = Input.vibrate_handheld

## Bu oturumda gönderilen titreşim sayısı (olay başına; testler ve günlük için).
var _counts: Dictionary[GameTypes.Haptic, int] = {}


func _ready() -> void:
	Events.player_flipped.connect(pulse.bind(GameTypes.Haptic.FLIP))
	Events.near_miss.connect(_on_near_miss)
	Events.player_died.connect(_on_player_died)


## Olayın titreşimini gönderir; ayar kapalıysa hiçbir şey yapmaz.
func pulse(event: GameTypes.Haptic) -> void:
	if not Settings.vibration:
		return
	var pattern: Vector2 = PATTERNS[event]
	backend.call(roundi(pattern.x), pattern.y)
	_counts[event] = count(event) + 1
	if OS.is_debug_build():
		print("HAPTIC %s ms=%d amp=%.2f" % [
			GameTypes.Haptic.keys()[event], roundi(pattern.x), pattern.y])


## Olayın bu oturumdaki titreşim sayısı.
func count(event: GameTypes.Haptic) -> int:
	return _counts.get(event, 0)


func reset_counts() -> void:
	_counts.clear()


func _on_near_miss(_combo: int, _multiplier: int) -> void:
	pulse(GameTypes.Haptic.NEAR_MISS)


## Duraklatmadan menüye dönüş (QUIT) bir ölüm değildir; titremez.
func _on_player_died(cause: GameTypes.DeathCause) -> void:
	if cause != GameTypes.DeathCause.QUIT:
		pulse(GameTypes.Haptic.DEATH)
