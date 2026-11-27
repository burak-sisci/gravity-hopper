extends GdUnitTestSuite
## Android dışa aktarım ayarı ölçüm için geçici değişir (M6-04: emülatöre x86_64; M6-03/M6-10:
## command_line/extra_args) ve elle geri alınır. Geri alınmazsa yayına girmesin: depodaki her
## Android ön ayarı (yayın ön ayarı da, M8-01) yalnızca ARM mimarileri içerir ve başlatma
## argümanı taşımaz. Ön ayarların sırası önemsizdir.

const PRESETS_PATH: String = "res://export_presets.cfg"

var _presets: ConfigFile


func before() -> void:
	_presets = ConfigFile.new()
	assert_int(_presets.load(PRESETS_PATH)).is_equal(OK)


func test_there_is_an_android_preset() -> void:
	assert_array(_android_options()).is_not_empty()


func test_only_arm_architectures_ship() -> void:
	# Gerçek Android telefonlar ARM; x86 yalnızca emülatör içindir (M6-04) ve ≈ 30 MB ekler.
	for options: String in _android_options():
		assert_bool(bool(_presets.get_value(options, "architectures/arm64-v8a", false))) \
				.override_failure_message(options + ": arm64-v8a kapalı").is_true()
		assert_bool(bool(_presets.get_value(options, "architectures/armeabi-v7a", false))) \
				.override_failure_message(options + ": armeabi-v7a kapalı").is_true()
		assert_bool(bool(_presets.get_value(options, "architectures/x86", false))) \
				.override_failure_message(options + ": x86 açık").is_false()
		assert_bool(bool(_presets.get_value(options, "architectures/x86_64", false))) \
				.override_failure_message(options + ": x86_64 açık").is_false()


func test_no_measurement_launch_arguments() -> void:
	# --invincible, --perf gibi debug argümanları yalnızca ölçüm yapısına girer.
	for options: String in _android_options():
		assert_str(str(_presets.get_value(options, "command_line/extra_args", ""))) \
				.override_failure_message(options + ": başlatma argümanı var").is_empty()


## Android ön ayarlarının seçenek bölümleri ("preset.N.options").
func _android_options() -> Array[String]:
	var found: Array[String] = []
	for section: String in _presets.get_sections():
		if section.count(".") == 1 and str(_presets.get_value(section, "platform", "")) == "Android":
			found.append(section + ".options")
	return found
