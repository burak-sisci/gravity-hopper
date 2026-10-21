extends GdUnitTestSuite
## Kayıt sistemi (M4-01, architecture.md §11): yazıp okuma, yedekten açılış, yarıda kalan geçici
## dosya, şifreleme, şemaya uydurma ve sürüm geçişi. Her test kendi geçici klasöründe çalışır;
## gerçek kayda dokunulmaz.

const TEST_DIR: String = "user://test_save"

var _saved_dir: String
var _saved_encrypted: bool


func before_test() -> void:
	_saved_dir = SaveManager.save_dir
	_saved_encrypted = SaveManager.encrypted
	SaveManager.save_dir = TEST_DIR
	SaveManager.encrypted = false
	_clear()


func after_test() -> void:
	_clear()
	SaveManager.save_dir = _saved_dir
	SaveManager.encrypted = _saved_encrypted


func test_save_and_load_round_trip_in_both_formats() -> void:
	for encrypted: bool in [false, true]:
		SaveManager.encrypted = encrypted
		var data: Dictionary[String, Variant] = SaveManager.default_data()
		data["glimmers"] = 1234
		data["best_height_m"] = 987
		(data["upgrades"] as Dictionary)["magnet"] = 3
		(data["trails"] as Dictionary)["owned"] = ["trail_default", "trail_aurora"]
		assert_bool(SaveManager.save_game(data)).is_true()
		var loaded: Dictionary[String, Variant] = SaveManager.load_game()
		assert_int(SaveManager.last_source).is_equal(SaveManager.Source.MAIN)
		assert_bool(loaded == data).override_failure_message(
				"şifreli=%s: %s" % [encrypted, loaded]).is_true()
		# JSON sayıları tam sayıya dönüyor.
		assert_int(typeof(loaded["glimmers"])).is_equal(TYPE_INT)
		_clear()


func test_missing_save_gives_a_fresh_one() -> void:
	var loaded: Dictionary[String, Variant] = SaveManager.load_game()
	assert_int(SaveManager.last_source).is_equal(SaveManager.Source.NEW)
	assert_bool(loaded == SaveManager.default_data()).is_true()


func test_corrupt_main_falls_back_to_backup() -> void:
	var first: Dictionary[String, Variant] = SaveManager.default_data()
	first["glimmers"] = 10
	SaveManager.save_game(first)
	var second: Dictionary[String, Variant] = SaveManager.default_data()
	second["glimmers"] = 20
	SaveManager.save_game(second)
	# İkinci yazmada ilk kayıt yedeğe geçti.
	_write_text(SaveManager.main_path(), "{\"glimmers\": 2")
	var loaded: Dictionary[String, Variant] = SaveManager.load_game()
	assert_int(SaveManager.last_source).is_equal(SaveManager.Source.BACKUP)
	assert_int(loaded["glimmers"]).is_equal(10)
	# Bozuk ana kayıt bir sonraki yazmada yedeği ezmez.
	var third: Dictionary[String, Variant] = SaveManager.default_data()
	third["glimmers"] = 30
	SaveManager.save_game(third)
	assert_int(SaveManager.load_game()["glimmers"]).is_equal(30)
	_write_text(SaveManager.main_path(), "")
	assert_int(SaveManager.load_game()["glimmers"]).is_equal(10)


func test_both_corrupt_gives_a_fresh_save() -> void:
	SaveManager.encrypted = true
	_write_text(SaveManager.main_path(), "bozuk")
	_write_text(SaveManager.backup_path(), "{]")
	var loaded: Dictionary[String, Variant] = SaveManager.load_game()
	assert_int(SaveManager.last_source).is_equal(SaveManager.Source.NEW)
	assert_bool(loaded == SaveManager.default_data()).is_true()


func test_half_written_temp_does_not_hurt_the_save() -> void:
	var data: Dictionary[String, Variant] = SaveManager.default_data()
	data["glimmers"] = 77
	SaveManager.save_game(data)
	# Yazma yarıda kesildi: geçici dosya yarım kaldı, ana kayıt eski.
	_write_text(SaveManager.temp_path(), "{\"glimmers\": 99")
	assert_int(SaveManager.load_game()["glimmers"]).is_equal(77)
	assert_int(SaveManager.last_source).is_equal(SaveManager.Source.MAIN)
	data["glimmers"] = 88
	assert_bool(SaveManager.save_game(data)).is_true()
	assert_int(SaveManager.load_game()["glimmers"]).is_equal(88)
	assert_bool(FileAccess.file_exists(SaveManager.temp_path())).is_false()


func test_encrypted_save_is_not_plain_text() -> void:
	SaveManager.encrypted = true
	var data: Dictionary[String, Variant] = SaveManager.default_data()
	data["glimmers"] = 4321
	SaveManager.save_game(data)
	assert_str(SaveManager.main_path()).ends_with(".dat")
	var raw: String = FileAccess.get_file_as_bytes(SaveManager.main_path()).get_string_from_ascii()
	assert_str(raw).not_contains("glimmers")
	assert_str(raw).not_contains("4321")
	# Debug yapısının düz kaydı incelenebilir.
	SaveManager.encrypted = false
	SaveManager.save_game(data)
	assert_str(SaveManager.main_path()).ends_with(".json")
	assert_str(FileAccess.get_file_as_string(SaveManager.main_path())).contains("\"glimmers\": 4321")


func test_load_conforms_to_the_schema() -> void:
	# Eksik alanlar varsayılandan gelir, türü yanlış olanlar düzeltilir, bilinmeyenler düşer.
	_write_text(SaveManager.main_path(), JSON.stringify({
		"version": 1,
		"glimmers": "çok",
		"best_height_m": 512.0,
		"upgrades": {"magnet": 2, "laser_eyes": 5},
		"trails": {"owned": ["trail_default", 7, "trail_aurora"]},
		"unknown": true,
	}))
	var loaded: Dictionary[String, Variant] = SaveManager.load_game()
	assert_int(loaded["glimmers"]).is_equal(0)
	assert_int(loaded["best_height_m"]).is_equal(512)
	assert_int(typeof(loaded["best_height_m"])).is_equal(TYPE_INT)
	var upgrades: Dictionary = loaded["upgrades"]
	assert_int(upgrades["magnet"]).is_equal(2)
	assert_int(upgrades["shield"]).is_equal(0)
	assert_bool(upgrades.has("laser_eyes")).is_false()
	var trails: Dictionary = loaded["trails"]
	assert_array(trails["owned"]).is_equal(["trail_default", "trail_aurora"])
	assert_str(trails["equipped"]).is_equal("trail_default")
	assert_bool(loaded.has("unknown")).is_false()
	assert_bool(loaded.has("stats")).is_true()
	assert_int(loaded["version"]).is_equal(SaveManager.SCHEMA_VERSION)


func test_migration_runs_step_by_step() -> void:
	var steps: Dictionary[int, Callable] = {1: _v1_to_v2, 2: _v2_to_v3}
	var migrated: Dictionary = SaveManager.migrate({"version": 1, "shards": 5}, 1, 3, steps)
	assert_int(migrated["version"]).is_equal(3)
	assert_int(migrated["glimmers"]).is_equal(11)
	assert_bool(migrated.has("shards")).is_false()
	# Güncel sürümde adım çalışmaz.
	assert_bool(SaveManager.migrate({"version": 3}, 3, 3, steps) == {"version": 3}).is_true()


## Örnek geçiş: alanın adı ve anlamı değişiyor.
func _v1_to_v2(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	out["coins"] = int(out["shards"]) * 2
	out.erase("shards")
	out["version"] = 2
	return out


func _v2_to_v3(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	out["glimmers"] = int(out["coins"]) + 1
	out["version"] = 3
	return out


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _clear() -> void:
	for encrypted: bool in [false, true]:
		SaveManager.encrypted = encrypted
		SaveManager.delete_save()
	SaveManager.encrypted = false
