extends Node
## Kayıt dosyalarını okur ve yazar: şifreleme, atomik yazma, yedek, sürüm geçişi
## (architecture.md §11).
##
## Yalnızca kalıcılıktan sorumludur, oyun kuralı bilmez: ne kaydedileceğine Progression karar verir.
## Yayın yapısında şifreli `savegame.dat`, debug yapısında incelenebilir düz `savegame_debug.json`.
## Şifre uygulamanın içinde durduğu için bu güvenlik değil caydırıcılıktır (§11.3).

## Kayıt hangi dosyadan açıldı.
enum Source { MAIN, BACKUP, NEW }

const SAVE_NAME: String = "savegame"
const DEBUG_SAVE_NAME: String = "savegame_debug"
const ENCRYPTED_EXTENSION: String = ".dat"
const PLAIN_EXTENSION: String = ".json"
const BACKUP_EXTENSION: String = ".bak"
const TEMP_EXTENSION: String = ".tmp"
const SCHEMA_VERSION: int = 1
## Caydırıcı şifre (§11.3). Değişirse eski kayıtlar açılamaz.
const PASSWORD: String = "gravity-hopper/core/v1"
## Godot'nun şifreli dosyalarının ilk dört baytı. Başka bir şeyle başlayan dosya hiç açılmaz
## (motor bozuk dosyada hata yazdırır).
const ENCRYPTED_MAGIC: String = "GDEC"
## gdUnit komut aracıyla çalışan testler (tools/check.ps1) gerçek kayda dokunmaz: kayıt bu
## klasöre gider ve her test oturumu boş kayıtla başlar.
const TEST_RUNNER_SCRIPT: String = "GdUnitCmdTool.gd"
const TEST_SAVE_DIR: String = "user://test_runs"

## Kayıt klasörü. Testler geçici bir klasör verir.
var save_dir: String = "user://"
## Açıksa şifreli `.dat`, kapalıysa düz JSON (debug yapısı, incelenebilir).
var encrypted: bool = not OS.is_debug_build()
## Son yüklemede kaydın geldiği yer.
var last_source: Source = Source.NEW


func _init() -> void:
	if not OS.is_debug_build():
		return
	for arg: String in OS.get_cmdline_args():
		if arg.ends_with(TEST_RUNNER_SCRIPT):
			save_dir = TEST_SAVE_DIR
			delete_save()
			return


## Şema 1'in boş kaydı (§11.2). Her yüklemede eksik ya da bozuk alanlar buradan tamamlanır.
func default_data() -> Dictionary[String, Variant]:
	return {
		"version": SCHEMA_VERSION,
		"glimmers": 0,
		"best_height_m": 0,
		"highest_sector": 1,
		"great_storage_reached": false,
		"upgrades": {
			"magnet": 0, "shield": 0, "head_start": 0, "glimmer_boost": 0, "second_chance": 0,
		},
		"trails": {"owned": ["trail_default"], "equipped": "trail_default"},
		"stats": {"runs": 0, "total_height_m": 0, "near_misses": 0, "glimmers_earned": 0},
		"daily": {"last_date": "", "best_height_m": 0},
		"ftue_done": false,
	}


## Değeri şablonun biçimine uydurur: şablonda olmayan anahtarlar düşer, eksik ya da türü
## uymayan alanlar şablondan gelir. JSON sayıları ondalık okunduğu için tam sayıya çevrilir.
func conform(value: Variant, template: Variant) -> Variant:
	var numeric: bool = value is int or (value is float and is_finite(value))
	match typeof(template):
		TYPE_DICTIONARY:
			var source: Dictionary = value if value is Dictionary else {}
			var out: Dictionary = {}
			var shape: Dictionary = template
			for key: Variant in shape:
				out[key] = conform(source.get(key, shape[key]), shape[key])
			return out
		TYPE_ARRAY:
			return _conform_array(value, template)
		TYPE_INT:
			return int(value) if numeric else template
		TYPE_FLOAT:
			return float(value) if numeric else template
		_:
			return value if typeof(value) == typeof(template) else template


## Kaydı `from_version`'dan `to_version`'a adım adım yükseltir. `steps`: anahtar eski sürüm,
## değer bir sonraki sürümün kaydını döndüren işlev. Eksik adım varsa kayıt olduğu gibi kalır.
func migrate(
		data: Dictionary, from_version: int, to_version: int,
		steps: Dictionary[int, Callable]) -> Dictionary:
	var out: Dictionary = data
	for version: int in range(from_version, to_version):
		if not steps.has(version):
			push_warning("Kayıt sürüm %d → %d geçişi yok" % [version, version + 1])
			return out
		out = steps[version].call(out)
	return out


## Kaydı yükler: ana dosya → bozuksa yedek → ikisi de yoksa boş kayıt. Sonuç her zaman şemaya
## uyar (eksik alanlar tamamlanmış, eski sürümü yükseltilmiş). Kaynak `last_source`'ta.
func load_game() -> Dictionary[String, Variant]:
	var raw: Variant = _read(main_path())
	last_source = Source.MAIN
	if raw == null:
		raw = _read(backup_path())
		last_source = Source.BACKUP
	if raw == null:
		last_source = Source.NEW
		_log("loaded source=NEW")
		return default_data()
	var data: Dictionary = raw
	var stored: Variant = data.get("version")
	var version: int = int(stored) if stored is float or stored is int else SCHEMA_VERSION
	if version < SCHEMA_VERSION:
		data = migrate(data, version, SCHEMA_VERSION, _migration_steps())
	elif version > SCHEMA_VERSION:
		push_warning("Kayıt daha yeni bir sürümden (%d); bilinen alanlar okunuyor" % version)
	var out: Dictionary[String, Variant] = {}
	out.assign(conform(data, default_data()))
	out["version"] = SCHEMA_VERSION
	_log("loaded source=%s" % Source.keys()[last_source])
	return out


## Kaydı atomik yazar: önce geçici dosyaya, geri okuyup doğrular; sonra sağlam eski kayıt
## yedeğe, geçici dosya ana kayda geçer. Yarıda kesilen yazma eski kaydı bozmaz.
func save_game(data: Dictionary[String, Variant]) -> bool:
	var text: String = JSON.stringify(data, "" if encrypted else "\t")
	var temp: String = temp_path()
	if not _write(temp, text) or _read_text(temp) != text:
		push_warning("Kayıt yazılamadı: %s" % temp)
		DirAccess.remove_absolute(temp)
		return false
	var main: String = main_path()
	if FileAccess.file_exists(main):
		# Yalnızca sağlam kayıt yedeğe geçer; bozuk ana kayıt iyi yedeği ezmesin.
		if _read(main) != null:
			_replace(main, backup_path())
		else:
			DirAccess.remove_absolute(main)
	if DirAccess.rename_absolute(temp, main) != OK:
		push_warning("Kayıt yerine konamadı: %s" % main)
		return false
	_log("saved bytes=%d" % text.length())
	return true


## Kayıt dosyalarını siler (debug: kaydı sıfırla; testler).
func delete_save() -> void:
	for path: String in [main_path(), backup_path(), temp_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func main_path() -> String:
	return _base_path() + (ENCRYPTED_EXTENSION if encrypted else PLAIN_EXTENSION)


func backup_path() -> String:
	return _base_path() + BACKUP_EXTENSION


func temp_path() -> String:
	return _base_path() + TEMP_EXTENSION


func _base_path() -> String:
	return save_dir.path_join(SAVE_NAME if encrypted else DEBUG_SAVE_NAME)


## Dosyayı okuyup JSON sözlüğüne çevirir; yoksa, açılamıyorsa ya da bozuksa null.
func _read(path: String) -> Variant:
	var text: String = _read_text(path)
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	return json.data


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess
	if encrypted:
		var head: PackedByteArray = FileAccess.get_file_as_bytes(path).slice(
				0, ENCRYPTED_MAGIC.length())
		if head.get_string_from_ascii() != ENCRYPTED_MAGIC:
			return ""
		file = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, PASSWORD)
	else:
		file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _write(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var file: FileAccess
	if encrypted:
		file = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, PASSWORD)
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var ok: bool = file.store_string(text)
	file.close()
	return ok


## Dizi değil ise şablonun kopyası; dizi ise şablonun ilk öğesiyle aynı türde olan öğeleri.
func _conform_array(value: Variant, template: Array) -> Array:
	if not value is Array:
		return template.duplicate(true)
	var items: Array = value
	if template.is_empty():
		return items.duplicate(true)
	var kind: int = typeof(template[0])
	return items.filter(func(item: Variant) -> bool: return typeof(item) == kind)


## `from`'u `to`'nun yerine koyar (varsa `to` önce silinir).
func _replace(from: String, to: String) -> void:
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	DirAccess.rename_absolute(from, to)


## Sürüm geçişleri: anahtar eski sürüm, değer kaydı bir sonraki sürüme çeviren işlev
## (ör. `{1: _migrate_v1_to_v2}`). Alan eklemek sürüm gerektirmez (eksik alan varsayılanla
## tamamlanır); sürüm yalnızca bir alanın anlamı ya da yapısı değişince artar.
func _migration_steps() -> Dictionary[int, Callable]:
	return {}


func _log(line: String) -> void:
	if OS.is_debug_build():
		print("SAVE ", line)
