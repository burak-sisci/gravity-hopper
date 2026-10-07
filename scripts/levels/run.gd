extends Node2D
## Oyun dünyası (architecture.md §5.2). Kendi çocuklarını aşağı çağrıyla yönetir; dışarıya
## yalnızca Events ile seslenir. Kamera oyuncuyu izler, koridor kameraya göre yenilenir.
## process_physics_priority = 1: Run oyuncudan sonra çalışır, kamera bu adımın konumunu izler.

@export var tuning: TuningConfig

@onready var _corridor: Corridor = %Corridor
@onready var _camera: GameCamera = %GameCamera
@onready var _player: Player = %Player


func _ready() -> void:
	if tuning == null:
		push_error("Run: tuning atanmamış")
		return
	_player.tuning = tuning
	_camera.follow(_player.position.y, TuningConfig.to_px(tuning.lookahead))
	_corridor.build(_camera.view_top() - Corridor.SEGMENT_HEIGHT)
	_update_view()
	_camera.reset_physics_interpolation()


func _physics_process(_delta: float) -> void:
	_update_view()


## Değerler her adımda TuningConfig'ten okunur; canlı ayar paneli (M1-11) anında etki eder.
func _update_view() -> void:
	_camera.follow(_player.position.y, TuningConfig.to_px(tuning.lookahead))
	_corridor.update_view(_camera.view_bottom(), TuningConfig.to_px(tuning.corridor_width) * 0.5)
