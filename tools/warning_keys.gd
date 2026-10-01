extends SceneTree
## Seviyesi "Warn" olan tüm GDScript uyarı ayarlarını yazdırır.
##
## tools/check.ps1 bu listeden geçici bir override.cfg üretir ve uyarıları hataya çeker.


func _init() -> void:
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if key.begins_with("debug/gdscript/warnings/") and prop["hint_string"] == "Ignore,Warn,Error":
			if ProjectSettings.get_setting(key) == 1:
				print("WARNKEY " + key)
	quit()
