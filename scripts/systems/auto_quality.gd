class_name AutoQuality
extends RefCounted
## Otomatik kalite düşürme (M6-11, architecture.md §16.1, ADR-112). Main tur sürerken her karenin
## gerçek süresini verir; ekran uzun süre 60 FPS'i tutamıyorsa kalite bir kademe düşmelidir.
## Yalnızca düşürür, yükseltmez. Oyuncu kaliteyi kendisi seçtiyse hiç sorulmaz (Settings).
##
## Eşikler ölçümden (architecture.md §16.1):
## - Redmi Note 12, yüksek kalite: en kötü evre ortalaması takılmasız 11,4 ms, başka uygulamaların
##   CPU yüküyle gelen takılma kümeli 13,3 ms (M6-03 / M6-10); doğal küme ≤ 15 sn, yapay 8 çekirdek
##   yükünün en kötü 10 sn'si ≈ 27 ms. Küme kalite düşürmekle geçmez: kural tetiklenmemeli.
## - Emülatör, 60 Hz (M6-04): her kalitede 16,7–16,9 ms; sektör girişinde 1,2 sn'lik dalga
##   38 ms'ye çıkıyor, 10 sn'lik pencerede ≈ 18,1 ms.
## Web'de kapalı (Settings.auto_quality_allowed): tarayıcının FPS tavanı zayıf GPU sanılır.
## Bu yüzden pencere 10 sn, eşik 20 ms (50 FPS), üst üste 3 pencere (30 sn): ölçülen hiçbir
## koşul tetiklemiyor, 60 FPS'i 30 sn tutamayan cihaz tetikliyor.

## Pencere uzunluğu (sn; yalnızca tur süresi sayılır).
const WINDOW_SEC: float = 10.0
## Penceredeki ortalama kare süresi bunu aşarsa pencere yavaştır (ms; 50 FPS).
const SLOW_FRAME_MS: float = 20.0
## Üst üste bu kadar yavaş pencere kaliteyi bir kademe düşürür.
const SLOW_WINDOWS: int = 3
## Bundan uzun tek kare yükleme, duraklatma ya da uygulamaya dönüştür; sayılmaz (ms; tur açılış
## karesi 1,4–1,5 sn, M6-03).
const HITCH_MS: float = 250.0

## Son biten pencerenin ortalama kare süresi (ms; günlük için).
var last_window_ms: float = 0.0

var _time: float = 0.0
var _frames: int = 0
var _slow_streak: int = 0


## Bir karenin gerçek süresini (sn) ekler. Kalite şimdi bir kademe düşmeliyse true döner; sayaç
## yeniden başlar (bir sonraki kademe için yine 30 sn gerekir).
func add_frame(frame_sec: float) -> bool:
	if frame_sec <= 0.0 or frame_sec * 1000.0 > HITCH_MS:
		return false
	_time += frame_sec
	_frames += 1
	if _time < WINDOW_SEC:
		return false
	last_window_ms = _time / _frames * 1000.0
	_time = 0.0
	_frames = 0
	_slow_streak = _slow_streak + 1 if last_window_ms > SLOW_FRAME_MS else 0
	if _slow_streak < SLOW_WINDOWS:
		return false
	_slow_streak = 0
	return true


## Bir kademe düşük kalite; en düşükte aynı kalır.
static func lowered(quality: GameTypes.Quality) -> GameTypes.Quality:
	return maxi(quality - 1, GameTypes.Quality.LOW) as GameTypes.Quality
