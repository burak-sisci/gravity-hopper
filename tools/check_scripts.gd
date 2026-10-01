extends SceneTree
## Projedeki tüm .gd dosyalarını autoload'lar yüklüyken derler.
##
## tools/check.ps1 tarafından çalıştırılır. override.cfg ile uyarılar hataya
## çekildiği için uyarılar da burada hata olarak görünür.
## Not: --check-only autoload adlarını tanımadığından bu yol kullanılır.

const SKIP_DIRS: Array[String] = ["res://.godot", "res://addons"]

var _failures: int = 0
var _checked: int = 0


func _process(_delta: float) -> bool:
	_scan("res://")
	print("KONTROL: %d betik, %d hatalı" % [_checked, _failures])
	quit(1 if _failures > 0 else 0)
	return false


func _scan(dir_path: String) -> void:
	if dir_path.trim_suffix("/") in SKIP_DIRS:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan(dir_path.path_join(sub))
	for file: String in dir.get_files():
		if file.get_extension() == "gd":
			_check(dir_path.path_join(file))


func _check(path: String) -> void:
	# Çalışan betik kendini yeniden derlerse bayt kodu bozulur. Kendisi atlanır; denetim
	# modunda (uyarılar hata) başarıyla başlamış olması zaten temiz derlendiğini gösterir.
	if path == (get_script() as Script).resource_path:
		return
	_checked += 1
	# CACHE_MODE_IGNORE betiği önbellekten almadan yeniden derler. reload() kullanılmaz:
	# çalışan autoload'lar için reddedilir.
	var script: GDScript = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	if script == null or not script.can_instantiate():
		_failures += 1
		print("HATA %s" % path)
	else:
		print("OK   %s" % path)
