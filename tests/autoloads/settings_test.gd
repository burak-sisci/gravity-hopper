extends GdUnitTestSuite
## Settings (M5-05, roadmap "her ayar kaydedilir ve yeniden açılışta geri gelir"): her ayar
## dosyaya yazılır ve yeni bir Settings örneği aynı değerleri okur; ses düzeyi yolun dB'sine
## çevrilir, 0'da yol susturulur; FPS sınırı Engine.max_fps'e yansır.
## Otomatik kalite (M6-11): oyuncunun seçtiği kalite hiç düşürülmez; seçilmemiş kalite bir kademe
## düşer, kaydedilir ve seçim sayılmaz; bayraktan önceki dosyalarda varsayılandan farklı kalite
## seçim sayılır.

const SETTINGS_SCRIPT: GDScript = preload("res://scripts/autoloads/settings.gd")
const TEST_PATH: String = "user://settings_test.cfg"
## dB karşılaştırma payı.
const DB_TOLERANCE: float = 0.01

var _saved: Dictionary[String, Variant] = {}


func before_test() -> void:
	_saved = snapshot()
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func after_test() -> void:
	restore(_saved)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


## Her ayar değiştirilir; yeni bir örnek dosyadan aynı değerleri okur.
func test_every_setting_survives_a_restart() -> void:
	Settings.set_music_volume(0.35)
	Settings.set_sfx_volume(0.6)
	Settings.set_vibration(false)
	Settings.set_language("tr")
	Settings.set_effect_quality(GameTypes.Quality.LOW)
	Settings.set_limit_fps_60(true)
	var fresh: Node = SETTINGS_SCRIPT.new() as Node
	fresh.set(&"path", TEST_PATH)
	fresh.call(&"load_settings")
	assert_float(fresh.get(&"music_volume") as float).is_equal_approx(0.35, 0.0001)
	assert_float(fresh.get(&"sfx_volume") as float).is_equal_approx(0.6, 0.0001)
	assert_bool(fresh.get(&"vibration") as bool).is_false()
	assert_str(fresh.get(&"language") as String).is_equal("tr")
	assert_int(fresh.get(&"effect_quality") as int).is_equal(GameTypes.Quality.LOW)
	assert_bool(fresh.get(&"limit_fps_60") as bool).is_true()
	fresh.free()


## Kaydırıcı sürüklenirken (save = false) dosya yazılmaz, yalnızca uygulanır.
func test_dragging_applies_without_writing() -> void:
	Settings.set_music_volume(0.2, false)
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()
	assert_float(_bus_db(Settings.MUSIC_BUS)).is_equal_approx(linear_to_db(0.2), DB_TOLERANCE)


## Ses düzeyi yolun dB'si; 0'da yol susturulur, geri açılınca susturma kalkar.
func test_volume_drives_the_bus() -> void:
	for bus_name: StringName in [Settings.MUSIC_BUS, Settings.SFX_BUS]:
		var bus: int = AudioServer.get_bus_index(bus_name)
		assert_int(bus).is_greater_equal(0)
		_set_volume(bus_name, 0.5)
		assert_float(AudioServer.get_bus_volume_db(bus)).is_equal_approx(-6.02, DB_TOLERANCE)
		assert_bool(AudioServer.is_bus_mute(bus)).is_false()
		_set_volume(bus_name, 0.0)
		assert_bool(AudioServer.is_bus_mute(bus)).override_failure_message(
				"%s 0'da susmuyor" % bus_name).is_true()
		_set_volume(bus_name, 1.0)
		assert_bool(AudioServer.is_bus_mute(bus)).is_false()
		assert_float(AudioServer.get_bus_volume_db(bus)).is_equal_approx(0.0, DB_TOLERANCE)


## Müzik yolu susunca efekt yolu etkilenmez (ve tersi).
func test_buses_are_independent() -> void:
	Settings.set_sfx_volume(1.0)
	Settings.set_music_volume(0.0)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.SFX_BUS))).is_false()
	Settings.set_music_volume(1.0)
	Settings.set_sfx_volume(0.0)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.MUSIC_BUS))).is_false()


## Otomatik kalite ekransız kipte, kare yakalamada ve web'de kapalı (tarayıcı FPS tavanı zayıf
## GPU sanılmasın); telefonda ve masaüstünde açık.
func test_auto_quality_runs_only_where_frame_time_means_gpu_load() -> void:
	assert_bool(_allowed("Android", false, false)).is_true()
	assert_bool(_allowed("Windows", false, false)).is_true()
	assert_bool(_allowed("headless", false, false)).is_false()
	assert_bool(_allowed("Windows", true, false)).is_false()
	assert_bool(_allowed("Web", false, true)).is_false()


func test_fps_limit() -> void:
	Settings.set_limit_fps_60(true)
	assert_int(Engine.max_fps).is_equal(Settings.LIMITED_FPS)
	Settings.set_limit_fps_60(false)
	assert_int(Engine.max_fps).is_equal(0)


## Oyuncu ayarlar ekranından seçince seçim kalıcıdır; otomatik düşürme ona dokunmaz.
func test_player_choice_is_never_lowered() -> void:
	Settings.auto_quality = true
	Settings.set_effect_quality(GameTypes.Quality.HIGH)
	assert_bool(Settings.quality_chosen).is_true()
	assert_bool(Settings.can_lower_quality()).is_false()
	assert_bool(Settings.lower_quality_automatically()).is_false()
	assert_int(Settings.effect_quality).is_equal(GameTypes.Quality.HIGH)
	assert_bool(_fresh().get(&"quality_chosen") as bool).is_true()


## Seçilmemiş kalite bir kademe düşer, kaydedilir, duyurulur; seçim sayılmaz; en düşükte durur.
func test_unchosen_quality_steps_down_and_is_saved() -> void:
	Settings.auto_quality = true
	Settings.quality_chosen = false
	Settings.effect_quality = GameTypes.Quality.HIGH
	var announced: Array[bool] = []
	var count: Callable = func() -> void: announced.append(true)
	Events.settings_changed.connect(count)
	assert_bool(Settings.lower_quality_automatically()).is_true()
	Events.settings_changed.disconnect(count)
	assert_int(announced.size()).is_equal(1)
	assert_int(Settings.effect_quality).is_equal(GameTypes.Quality.MEDIUM)
	assert_bool(Settings.quality_chosen).is_false()
	var fresh: Node = _fresh()
	assert_int(fresh.get(&"effect_quality") as int).is_equal(GameTypes.Quality.MEDIUM)
	assert_bool(fresh.get(&"quality_chosen") as bool).is_false()
	assert_bool(Settings.lower_quality_automatically()).is_true()
	assert_bool(Settings.lower_quality_automatically()).is_false()
	assert_int(Settings.effect_quality).is_equal(GameTypes.Quality.LOW)


## Debug ölçümü ya da --quality= kapatınca düşürme yok.
func test_disabled_auto_quality_never_lowers() -> void:
	Settings.auto_quality = false
	Settings.quality_chosen = false
	Settings.effect_quality = GameTypes.Quality.HIGH
	assert_bool(Settings.lower_quality_automatically()).is_false()
	assert_int(Settings.effect_quality).is_equal(GameTypes.Quality.HIGH)


## M6-11 öncesi dosya (bayraksız): varsayılandan farklı kalite oyuncunun seçimi sayılır.
func test_legacy_file_counts_a_non_default_quality_as_chosen() -> void:
	for quality: GameTypes.Quality in [GameTypes.Quality.LOW, GameTypes.Quality.MEDIUM,
			GameTypes.Quality.HIGH]:
		var cfg := ConfigFile.new()
		cfg.set_value("video", "effect_quality", quality)
		assert_int(cfg.save(TEST_PATH)).is_equal(OK)
		assert_bool(_fresh().get(&"quality_chosen") as bool).is_equal(
				quality != Settings.DEFAULT_QUALITY)


## Ayarların ve uygulandıkları yerlerin anlık görüntüsü (testler sonra geri koyar).
static func snapshot() -> Dictionary[String, Variant]:
	var state: Dictionary[String, Variant] = {}
	for key: String in ["music_volume", "sfx_volume", "vibration", "language", "effect_quality",
			"quality_chosen", "auto_quality", "limit_fps_60", "path"]:
		state[key] = Settings.get(key)
	state["max_fps"] = Engine.max_fps
	state["locale"] = TranslationServer.get_locale()
	return state


static func restore(state: Dictionary[String, Variant]) -> void:
	for key: String in state:
		if key in Settings:
			Settings.set(key, state[key])
	Settings.apply()
	Engine.max_fps = state["max_fps"] as int
	TranslationServer.set_locale(state["locale"] as String)


## Dosyadan okuyan yeni bir Settings örneği (ağaca eklenmez, _ready çalışmaz).
func _fresh() -> Node:
	var fresh: Node = auto_free(SETTINGS_SCRIPT.new()) as Node
	fresh.set(&"path", TEST_PATH)
	fresh.call(&"load_settings")
	return fresh


func _set_volume(bus_name: StringName, value: float) -> void:
	if bus_name == Settings.MUSIC_BUS:
		Settings.set_music_volume(value)
	else:
		Settings.set_sfx_volume(value)


func _bus_db(bus_name: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))


## Settings autoload'unun statik kararı (örnek üzerinden statik çağrı uyarı verir).
func _allowed(display_server: String, is_movie: bool, is_web: bool) -> bool:
	return bool(SETTINGS_SCRIPT.call(&"auto_quality_allowed", display_server, is_movie, is_web))
