class_name Run
extends Node2D
## Oyun dünyası (architecture.md §5.2). Kendi çocuklarını aşağı çağrıyla yönetir; dışarıya
## yalnızca Events ile seslenir. Kamera oyuncuyu izler; koridor ve desen parçaları kameraya
## göre yenilenir. Tam metre değiştikçe Events.height_changed yayar.
## process_physics_priority = 1: Run oyuncudan sonra çalışır, kamera bu adımın konumunu izler.
## Ritim saati (Conductor) de burada, oyuncuyla aynı adımda ilerletilir (§8.3).
##
## Sektörler (M2-08): tur start_sector'ün başladığı yükseklikten başlar. Oyuncu sektör sınırını
## geçtiği adımda hız ve tempo yeni sektörünkine geçer (hız basamağı) ve Events.sector_entered
## yayılır. Yeni vuruş ızgarası tam sınırdan başlar; oyuncunun sınırı aştığı pay hesaba katılır.

@export var tuning: TuningConfig
@export var sectors: SectorCatalog
## Turun tohumu; Main, GameManager'dan alıp verir. 0 ise (sahne tek başına çalıştırılınca)
## yeni bir tohum üretilir.
@export var run_seed: int = 0
## Turun başladığı sektör (kontrol noktası; Main verir). Katalog dışındaysa sınırlanır.
@export var start_sector: int = 1

var rng: RunRng
## Oyuncunun bulunduğu sektör.
var sector: int = 1

var _start_y: float = 0.0
## Başlangıç sektörünün başladığı yükseklik (m); HUD yüksekliği buradan sayar.
var _start_height: float = 0.0
## Oyuncunun sıradaki sektöre geçeceği dünya y'si (son sektörde -INF).
var _next_boundary_y: float = -INF
var _height_m: int = 0

@onready var _conductor: Conductor = %Conductor
@onready var _corridor: Corridor = %Corridor
@onready var _chunks: ChunkSpawner = %ChunkSpawner
@onready var _camera: GameCamera = %GameCamera
@onready var _player: Player = %Player


func _ready() -> void:
	if tuning == null or sectors == null or sectors.count() == 0:
		push_error("Run: tuning ya da sectors atanmamış")
		return
	rng = RunRng.new(run_seed if run_seed != 0 else RunRng.make_seed())
	start_sector = clampi(start_sector, 1, sectors.count())
	sector = start_sector
	_start_y = _player.position.y
	_start_height = sectors.start_height(start_sector)
	var def: SectorDef = sectors.def_at(sector)
	_player.tuning = tuning
	_player.climb_speed = def.climb_speed
	_conductor.set_tempo(def.bpm, 0.0)
	_next_boundary_y = _boundary_y(sector)
	_camera.follow(_player.position.y, TuningConfig.to_px(tuning.lookahead))
	_corridor.build(_camera.view_top() - Corridor.SEGMENT_HEIGHT)
	_corridor.set_tint(def.ambient_color, true)
	_chunks.setup(rng, tuning, sectors, start_sector, _start_y)
	_update_view()
	_camera.reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_conductor.advance(delta)
	if _player.position.y <= _next_boundary_y:
		_enter_sector(sector + 1)
	_update_view()
	var meters: int = floori(_start_height + (_start_y - _player.position.y) / TuningConfig.PX_PER_M)
	if meters != _height_m:
		_height_m = meters
		Events.height_changed.emit(meters)


## Hız basamağı: yeni sektörün hızı ve temposu. Oyuncu bu adımda sınırı biraz aşmıştır; yeni
## ızgaranın başlangıç anı, bu payın yeni hızla alınacağı süre kadar geriye çekilir. Böylece yeni
## sektördeki engeller de tam vuruş anlarında geçer.
func _enter_sector(next: int) -> void:
	var def: SectorDef = sectors.def_at(next)
	var overshoot: float = _next_boundary_y - _player.position.y
	sector = next
	_player.climb_speed = def.climb_speed
	_conductor.set_tempo(def.bpm, _conductor.run_time - overshoot / def.climb_px())
	_next_boundary_y = _boundary_y(next)
	_corridor.set_tint(def.ambient_color)
	Events.sector_entered.emit(next)


## Sektörün bittiği dünya y'si (son sektörde -INF).
func _boundary_y(index: int) -> float:
	return _start_y - TuningConfig.to_px(sectors.end_height(index) - _start_height)


## Değerler her adımda TuningConfig'ten okunur; canlı ayar paneli (M1-11) anında etki eder.
func _update_view() -> void:
	_camera.follow(_player.position.y, TuningConfig.to_px(tuning.lookahead))
	var half_width: float = TuningConfig.to_px(tuning.corridor_width) * 0.5
	_corridor.update_view(_camera.view_bottom(), half_width)
	_chunks.update_view(_camera.view_top(), _camera.view_bottom(), half_width)
