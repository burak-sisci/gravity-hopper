extends Node2D
## Oyun dünyası (architecture.md §5.2). Kendi çocuklarını aşağı çağrıyla yönetir; dışarıya
## yalnızca Events ile seslenir. M1-03: koridor ve kamera, tırmanış noktası sabit hızla yukarı
## çıkar. M1-04'te bu noktanın yerini oyuncu alır.

@export var tuning: TuningConfig

var _climb_y: float = 0.0

@onready var _corridor: Corridor = %Corridor
@onready var _camera: GameCamera = %GameCamera


func _ready() -> void:
	if tuning == null:
		push_error("Run: tuning atanmamış")
		return
	_camera.follow(_climb_y, TuningConfig.to_px(tuning.lookahead))
	_corridor.build(_camera.view_top() - Corridor.SEGMENT_HEIGHT)
	_update_view()
	_camera.reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_climb_y -= TuningConfig.to_px(tuning.climb_speed) * delta
	_update_view()


## Değerler her adımda TuningConfig'ten okunur; canlı ayar paneli (M1-11) anında etki eder.
func _update_view() -> void:
	_camera.follow(_climb_y, TuningConfig.to_px(tuning.lookahead))
	_corridor.update_view(_camera.view_bottom(), TuningConfig.to_px(tuning.corridor_width) * 0.5)
