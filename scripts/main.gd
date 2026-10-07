extends Node
## Kök sahne (architecture.md §5.1). Debug build'de debug katmanını Debug kabına yükler;
## yayın sürümünde debug katmanı hiç yüklenmez (ADR-023).

const DEBUG_LAYER_PATH: String = "res://scenes/debug/debug_layer.tscn"

@onready var _debug: CanvasLayer = %Debug


func _ready() -> void:
	if OS.is_debug_build() and ResourceLoader.exists(DEBUG_LAYER_PATH):
		_debug.add_child((load(DEBUG_LAYER_PATH) as PackedScene).instantiate())
