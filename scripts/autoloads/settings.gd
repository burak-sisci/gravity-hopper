extends Node
## Oyuncu ayarları: ses, müzik, titreşim, dil, efekt kalitesi, FPS sınırı.
##
## user://settings.cfg dosyasında şifresiz saklanır. Açılışta okunur ve uygulanır: dil, ses yolları
## (Music / SFX; 0'da yol susturulur), FPS sınırı. Efekt kalitesini Main uygular (settings_changed).
## Titreşimi M5-08 okur. Ayarlar ekranı (M5-05) set_… işlevleriyle değiştirir: hemen uygulanır
## ve yazılır.
## Efekt kalitesi (M6-11): oyuncu ayarlar ekranından seçmediyse (quality_chosen) Main, cihaz uzun
## süre 60 FPS'i tutamayınca lower_quality_automatically ile bir kademe düşürür (AutoQuality).
## Oyuncunun seçtiği kalite hiç değişmez. Debug kaliteyi elle değiştirince auto_quality kapanır.
## Dil seçimi: oyuncunun seçtiği dil → yoksa cihaz dili → desteklenmiyorsa İngilizce.

const SETTINGS_PATH: String = "user://settings.cfg"
const SUPPORTED_LANGUAGES: Array[String] = ["tr", "en"]
const FALLBACK_LANGUAGE: String = "en"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
## FPS sınırı açıkken Engine.max_fps; kapalıyken 0 (ekranın yenileme hızı).
const LIMITED_FPS: int = 60
## Oyuncu seçmediyse başlangıç kalitesi.
const DEFAULT_QUALITY: GameTypes.Quality = GameTypes.Quality.HIGH
## Debug: tur başladıktan bu kadar sonra yolların tepe düzeyi günlüğe yazılır (cihazda ölçüm).
const PEAK_LOG_DELAY: float = 2.0

## Müzik ses düzeyi (0–1).
var music_volume: float = 0.8
## Efekt ses düzeyi (0–1).
var sfx_volume: float = 1.0
## Titreşim açık mı.
var vibration: bool = true
## Oyuncunun seçtiği dil kodu ("tr", "en"). Boşsa cihaz dili kullanılır.
var language: String = ""
## Efekt kalitesi.
var effect_quality: GameTypes.Quality = DEFAULT_QUALITY
## Oyuncu kaliteyi ayarlar ekranından kendisi seçti mi (seçtiyse otomatik düşürme yapılmaz).
var quality_chosen: bool = false
## Otomatik kalite düşürme açık mı (kaydedilmez; auto_quality_allowed). Debug ölçümü ve --quality=
## de kapatır.
var auto_quality: bool = true
## Açıksa oyun 60 FPS ile sınırlanır (pil tasarrufu).
var limit_fps_60: bool = false
## Ayar dosyası (testler geçici dosyaya çevirir).
var path: String = SETTINGS_PATH


func _ready() -> void:
	auto_quality = auto_quality_allowed(DisplayServer.get_name(), OS.has_feature("movie"),
			OS.has_feature("web"))
	load_settings()
	apply_language()
	apply()
	if OS.is_debug_build():
		Events.run_started.connect(_on_run_started)


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
	if cfg.load(path) != OK:
		return
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	vibration = bool(cfg.get_value("feedback", "vibration", vibration))
	language = str(cfg.get_value("general", "language", language))
	var stored_quality: int = int(cfg.get_value("video", "effect_quality", effect_quality))
	var quality: int = clampi(stored_quality, 0, GameTypes.Quality.size() - 1)
	effect_quality = quality as GameTypes.Quality
	# Bayraktan önceki dosyalarda (M6-11 öncesi) varsayılandan farklı kalite oyuncunun seçimidir.
	var legacy_chosen: bool = effect_quality != DEFAULT_QUALITY
	quality_chosen = bool(cfg.get_value("video", "quality_chosen", legacy_chosen))
	limit_fps_60 = bool(cfg.get_value("video", "limit_fps_60", limit_fps_60))


## Ayarları dosyaya yazar ve değişikliği duyurur.
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("feedback", "vibration", vibration)
	cfg.set_value("general", "language", language)
	cfg.set_value("video", "effect_quality", effect_quality)
	cfg.set_value("video", "quality_chosen", quality_chosen)
	cfg.set_value("video", "limit_fps_60", limit_fps_60)
	var err: Error = cfg.save(path)
	if err != OK:
		push_error("Ayarlar kaydedilemedi: %s" % error_string(err))
	_log("saved music=%.2f sfx=%.2f vibration=%s language=%s quality=%d chosen=%s fps60=%s" % [
		music_volume, sfx_volume, vibration, language, effect_quality, quality_chosen,
		limit_fps_60])
	Events.settings_changed.emit()


## Ses düzeylerini ve FPS sınırını uygular (dil apply_language'de, kalite Main'de).
func apply() -> void:
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)
	Engine.max_fps = LIMITED_FPS if limit_fps_60 else 0


## Müzik düzeyini değiştirir ve uygular; save yanlışsa yazmaz (kaydırıcı sürüklenirken).
func set_music_volume(value: float, save: bool = true) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_changed(save)


func set_sfx_volume(value: float, save: bool = true) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_changed(save)


func set_vibration(on: bool) -> void:
	vibration = on
	_changed(true)


## Oyuncunun seçimi (ayarlar ekranı): kalıcıdır, otomatik düşürme artık dokunmaz.
func set_effect_quality(quality: GameTypes.Quality) -> void:
	effect_quality = quality
	quality_chosen = true
	_changed(true)


## Otomatik kalite bu ortamda çalışabilir mi. Ekransız kipte (testler) ve kare yakalamada (Movie
## Maker) kare süresi GPU'yu ölçmez. Web'de tarayıcı kare hızına tavan koyabilir (pil tasarrufu
## 30 FPS): kural tavanı zayıf GPU sanır, kaliteyi boşuna düşürür (M6-11 doğrulaması).
static func auto_quality_allowed(display_server: String, is_movie: bool, is_web: bool) -> bool:
	return display_server != "headless" and not is_movie and not is_web


## Otomatik düşürme kaliteye dokunabilir mi: oyuncu seçmedi, kapatılmadı, en düşükte değil.
func can_lower_quality() -> bool:
	return auto_quality and not quality_chosen and effect_quality != GameTypes.Quality.LOW


## Kaliteyi bir kademe düşürür, kaydeder ve duyurur (seçim sayılmaz). Düşürdüyse true.
func lower_quality_automatically() -> bool:
	if not can_lower_quality():
		return false
	effect_quality = AutoQuality.lowered(effect_quality)
	_log("auto quality lowered to %d" % effect_quality)
	_changed(true)
	return true


func set_limit_fps_60(on: bool) -> void:
	limit_fps_60 = on
	_changed(true)


## Kullanılacak dili belirler ve oyuna uygular.
func apply_language() -> void:
	TranslationServer.set_locale(resolve_language(language, OS.get_locale_language()))


## Dili değiştirir, uygular ve kaydeder. Boş metin cihaz diline döner.
func set_language(code: String) -> void:
	language = code
	apply_language()
	save_settings()


func _changed(save: bool) -> void:
	apply()
	if save:
		save_settings()


## Yolun düzeyi doğrusal değerden dB'ye; 0'da yol susturulur (linear_to_db(0) = -inf).
func _apply_bus(bus_name: StringName, value: float) -> void:
	var bus: int = AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, value <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value, 0.0001)))


## Debug: turda yolların gerçekten çalıp çalmadığı (tepe dB; susturulan yol -200 dB'de kalır).
func _on_run_started(_run_seed: int, _start_sector: int) -> void:
	await get_tree().create_timer(PEAK_LOG_DELAY).timeout
	for bus_name: StringName in [MUSIC_BUS, SFX_BUS]:
		var bus: int = AudioServer.get_bus_index(bus_name)
		_log("bus %s peak=%.1f dB mute=%s volume=%.1f dB" % [bus_name,
			AudioServer.get_bus_peak_volume_left_db(bus, 0), AudioServer.is_bus_mute(bus),
			AudioServer.get_bus_volume_db(bus)])


func _log(line: String) -> void:
	if OS.is_debug_build():
		print("SETTINGS ", line)
