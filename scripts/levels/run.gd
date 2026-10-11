class_name Run
extends Node2D
## Oyun dünyası (architecture.md §5.2). Kendi çocuklarını aşağı çağrıyla yönetir; dışarıya
## yalnızca Events ile seslenir. Kamera oyuncuyu izler; koridor ve desen parçaları kameraya
## göre yenilenir. Tam metre değiştikçe Events.height_changed yayar.
## process_physics_priority = 1: Run oyuncudan sonra çalışır, kamera bu adımın konumunu izler.
## Ritim saati (Conductor) de burada, oyuncuyla aynı adımda ilerletilir (§8.3).

@export var tuning: TuningConfig
## Turun tohumu; Main, GameManager'dan alıp verir. 0 ise (sahne tek başına çalıştırılınca)
## yeni bir tohum üretilir.
@export var run_seed: int = 0

var rng: RunRng

var _start_y: float = 0.0
var _height_m: int = 0

@onready var _conductor: Conductor = %Conductor
@onready var _corridor: Corridor = %Corridor
@onready var _chunks: ChunkSpawner = %ChunkSpawner
@onready var _camera: GameCamera = %GameCamera
@onready var _player: Player = %Player


func _ready() -> void:
	if tuning == null:
		push_error("Run: tuning atanmamış")
		return
	rng = RunRng.new(run_seed if run_seed != 0 else RunRng.make_seed())
	_player.tuning = tuning
	_start_y = _player.position.y
	_camera.follow(_player.position.y, TuningConfig.to_px(tuning.lookahead))
	_corridor.build(_camera.view_top() - Corridor.SEGMENT_HEIGHT)
	_chunks.bpm = _conductor.bpm
	_chunks.setup(rng, tuning, _player.position.y)
	_update_view()
	_camera.reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_conductor.advance(delta)
	_update_view()
	var meters: int = floori((_start_y - _player.position.y) / TuningConfig.PX_PER_M)
	if meters != _height_m:
		_height_m = meters
		Events.height_changed.emit(meters)


## Değerler her adımda TuningConfig'ten okunur; canlı ayar paneli (M1-11) anında etki eder.
func _update_view() -> void:
	_camera.follow(_player.position.y, TuningConfig.to_px(tuning.lookahead))
	var half_width: float = TuningConfig.to_px(tuning.corridor_width) * 0.5
	_corridor.update_view(_camera.view_bottom(), half_width)
	_chunks.update_view(_camera.view_top(), _camera.view_bottom(), half_width)
