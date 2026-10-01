extends Node
## Oyuncu ayarları: ses, müzik, titreşim, dil, efekt kalitesi, FPS sınırı.
##
## user://settings.cfg dosyasında şifresiz saklanır.
## M0-06 iskeleti: varsayılan değerler. Okuma/yazma ve dil seçimi M0-07'de eklenecek.

const SETTINGS_PATH: String = "user://settings.cfg"

## Müzik ses düzeyi (0–1).
var music_volume: float = 0.8
## Efekt ses düzeyi (0–1).
var sfx_volume: float = 1.0
## Titreşim açık mı.
var vibration: bool = true
## Seçili dil kodu ("tr", "en"). Boşsa cihaz dili kullanılır.
var language: String = ""
## Efekt kalitesi.
var effect_quality: GameTypes.Quality = GameTypes.Quality.HIGH
## Açıksa oyun 60 FPS ile sınırlanır (pil tasarrufu).
var limit_fps_60: bool = false
