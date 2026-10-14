extends GdUnitTestSuite
## Sahne aracının katman kuralı (M3-14, .clauderules §3): dünya betiği ve sahnesi UI'ya, UI dünyaya
## başvuramaz. Sınıf adları tam sözcük, yollar önekle eşleşir; yorumlar sayılmaz. (Denendi:
## run.gd'ye HUD sahnesinin yolu, hud.gd'ye Run tipi, player.tscn'ye HUD sahnesi eklenince check
## üçünü de yakaladı.)

const SceneTool := preload("res://tools/scene_tool.gd")
const UI_CLASSES: Array[String] = ["TapHint"]
const UI_PATHS: Array[String] = ["res://scripts/ui/", "res://scenes/ui/", "/root/"]


func test_finds_ui_paths_classes_and_root_paths() -> void:
	var source: String = "\n".join(PackedStringArray([
		"var hud: PackedScene = preload(\"res://scenes/ui/hud.tscn\")",
		"func _ready() -> void:",
		"\tvar hint: TapHint = TapHint.new()",
		"\tget_node(^\"/root/Main/UI/HUD\").hide()",
	]))
	var refs: Array[Dictionary] = SceneTool.find_layer_refs(source, UI_CLASSES, UI_PATHS)
	assert_array(refs.map(func(ref: Dictionary) -> String: return ref["text"])).is_equal([
		"res://scenes/ui/hud.tscn", "TapHint", "TapHint", "/root/Main/UI/HUD",
	])
	assert_array(refs.map(func(ref: Dictionary) -> int: return ref["line"])).is_equal([1, 3, 3, 4])


func test_ignores_comments_and_similar_names() -> void:
	var source: String = "\n".join(PackedStringArray([
		"## HUD bunu res://scenes/ui/hud.tscn'den okur; TapHint de öyle.",
		"var tap_hint_style: TapHintStyle  # TapHint",
		"var text: String = \"# TapHint res://scenes/ui/\"",
		"var path: String = \"res://scenes/uikit/x.tscn\"",
	]))
	assert_array(SceneTool.find_layer_refs(source, UI_CLASSES, UI_PATHS)).is_empty()


func test_finds_ui_resources_in_world_scenes() -> void:
	var source: String = "\n".join(PackedStringArray([
		"[gd_scene format=3]",
		"",
		"[ext_resource type=\"PackedScene\" path=\"res://scenes/ui/hud.tscn\" id=\"1_hud\"]",
		"[ext_resource type=\"Script\" path=\"res://scripts/entities/player.gd\" id=\"2_player\"]",
	]))
	var refs: Array[Dictionary] = SceneTool.find_scene_layer_refs(source, UI_PATHS)
	assert_int(refs.size()).is_equal(1)
	assert_str(refs[0]["text"]).is_equal("res://scenes/ui/hud.tscn")
	assert_int(refs[0]["line"]).is_equal(3)
