extends Node
## Oyuncu ayarları: ses, müzik, titreşim, dil, efekt kalitesi, FPS sınırı.
##
## user://settings.cfg dosyasında şifresiz saklanır. Açılışta okunur ve dil uygulanır.
## Dil seçimi: oyuncunun seçtiği dil → yoksa cihaz dili → desteklenmiyorsa İngilizce.

const SETTINGS_PATH: String = "user://settings.cfg"
const SUPPORTED_LANGUAGES: Array[String] = ["tr", "en"]
const FALLBACK_LANGUAGE: String = "en"

## Müzik ses düzeyi (0–1).
var music_volume: float = 0.8
## Efekt ses düzeyi (0–1).
var sfx_volume: float = 1.0
## Titreşim açık mı.
var vibration: bool = true
## Oyuncunun seçtiği dil kodu ("tr", "en"). Boşsa cihaz dili kullanılır.
var language: String = ""
## Efekt kalitesi.
var effect_quality: GameTypes.Quality = GameTypes.Quality.HIGH
## Açıksa oyun 60 FPS ile sınırlanır (pil tasarrufu).
var limit_fps_60: bool = false


func _ready() -> void:
	load_settings()
	apply_language()


## Seçili dile, cihaz diline ve desteklenen dillere göre kullanılacak dili döndürür.
static func resolve_language(preferred: String, device_language: String) -> String:
	if preferred in SUPPORTED_LANGUAGES:
		return preferred
	if device_language in SUPPORTED_LANGUAGES:
		return device_language
	return FALLBACK_LANGUAGE


## Ayarları dosyadan okur. Dosya yoksa ya da bozuksa varsayılanlar kalır.
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	vibration = bool(cfg.get_value("feedback", "vibration", vibration))
	language = str(cfg.get_value("general", "language", language))
	var quality: int = clampi(int(cfg.get_value("video", "effect_quality", effect_quality)), 0, GameTypes.Quality.size() - 1)
	effect_quality = quality as GameTypes.Quality
	limit_fps_60 = bool(cfg.get_value("video", "limit_fps_60", limit_fps_60))


## Ayarları dosyaya yazar ve değişikliği duyurur.
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("feedback", "vibration", vibration)
	cfg.set_value("general", "language", language)
	cfg.set_value("video", "effect_quality", effect_quality)
	cfg.set_value("video", "limit_fps_60", limit_fps_60)
	var err: Error = cfg.save(SETTINGS_PATH)
	if err != OK:
		push_error("Ayarlar kaydedilemedi: %s" % error_string(err))
	Events.settings_changed.emit()


## Kullanılacak dili belirler ve oyuna uygular.
func apply_language() -> void:
	TranslationServer.set_locale(resolve_language(language, OS.get_locale_language()))


## Dili değiştirir, uygular ve kaydeder. Boş metin cihaz diline döner.
func set_language(code: String) -> void:
	language = code
	apply_language()
	save_settings()
