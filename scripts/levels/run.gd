class_name Run
extends Node2D
## Oyun dünyası (architecture.md §5.2). Kendi çocuklarını aşağı çağrıyla yönetir; dışarıya
## yalnızca Events ile seslenir. Kamera oyuncuyu izler; koridor ve desen parçaları kameraya
## göre yenilenir. Tam metre değiştikçe Events.height_changed yayar.
## process_physics_priority = 1: Run oyuncudan sonra çalışır, kamera bu adımın konumunu izler.
## Ritim saati (Conductor) de burada, oyuncuyla aynı adımda ilerletilir (§8.3).
##
## Sektörler (M2-08): tur start_sector'ün başladığı yükseklikten başlar. Oyuncu sektör sınırını
## geçtiği adımda hız yeni sektörünkine geçer (hız basamağı) ve Events.sector_entered yayılır.
##
## Müzik (M2-20, ADR-040): tur, tohumundan seçilen parçayı çalar; tempo o parçanınkidir ve tur
## boyunca değişmez. Vuruş ızgarası turun başından kesintisiz sürer; ChunkSpawner yeni sektörün
## ilk parçasını müziğin vuruşuna hizalar.
##
## Çöküş duvarı (M2-15): PressureSystem mesafeyi tutar; Glimmer ve kıl payı iter. Duvar oyuncuya
## varınca Run oyuncuyu öldürür (player_died(WALL)). Görsel CollapseWall oyuncunun mesafe × 50 px
## altına konur; yakınlık (0 ekranın altında – 1 oyuncuda) Events.wall_proximity_changed ile
## yayılır.

## Duvar yakınlığı bundan az değişince yeniden yayılmaz (HUD vinyeti için yeterli çözünürlük).
const PROXIMITY_STEP: float = 0.01

@export var tuning: TuningConfig
@export var sectors: SectorCatalog
@export var music: MusicCatalog
## Turun tohumu; Main, GameManager'dan alıp verir. 0 ise (sahne tek başına çalıştırılınca)
## yeni bir tohum üretilir.
@export var run_seed: int = 0
## Turun başladığı sektör (kontrol noktası; Main verir). Katalog dışındaysa sınırlanır.
@export var start_sector: int = 1

var rng: RunRng
## Turun müzik parçası (katalog boşsa null; tempo o zaman Conductor.bpm'in varsayılanı).
var track: MusicTrack = null
## Oyuncunun bulunduğu sektör.
var sector: int = 1
## Turun istatistikleri (Glimmer, kombo; §8.6).
var stats: RunStats = RunStats.new()

var _start_y: float = 0.0
## Başlangıç sektörünün başladığı yükseklik (m); HUD yüksekliği buradan sayar.
var _start_height: float = 0.0
## Oyuncunun sıradaki sektöre geçeceği dünya y'si (son sektörde -INF).
var _next_boundary_y: float = -INF
var _height_m: int = 0
## Son yayılan duvar yakınlığı (küçük değişimler yayılmaz).
var _proximity: float = -1.0
## Kıl payı kombosu (M2-14): zincir uzunluğu ve son kıl payının oyun zamanı.
var _combo: int = 0
var _last_graze_time: float = 0.0

@onready var _conductor: Conductor = %Conductor
@onready var _corridor: Corridor = %Corridor
@onready var _chunks: ChunkSpawner = %ChunkSpawner
@onready var _camera: GameCamera = %GameCamera
@onready var _player: Player = %Player
@onready var _pressure: PressureSystem = %PressureSystem
@onready var _collapse_wall: Node2D = %CollapseWall


func _ready() -> void:
	if tuning == null or sectors == null or sectors.count() == 0 or music == null:
		push_error("Run: tuning, sectors ya da music atanmamış")
		return
	rng = RunRng.new(run_seed if run_seed != 0 else RunRng.make_seed())
	track = music.pick(rng.run_seed)
	start_sector = clampi(start_sector, 1, sectors.count())
	sector = start_sector
	_start_y = _player.position.y
	_start_height = sectors.start_height(start_sector)
	var def: SectorDef = sectors.def_at(sector)
	_player.tuning = tuning
	_player.climb_speed = def.climb_speed
	_conductor.track = track
	if track != null:
		_conductor.set_tempo(track.bpm, 0.0)
	_next_boundary_y = _boundary_y(sector)
	_camera.follow(_player.position.y, TuningConfig.to_px(tuning.lookahead))
	_corridor.build(_camera.view_top() - Corridor.SEGMENT_HEIGHT)
	_corridor.set_tint(def.ambient_color, true)
	_chunks.setup(rng, tuning, sectors, start_sector, _start_y, _conductor.bpm)
	_chunks.glimmer_collected.connect(_on_glimmer_collected)
	_player.near_missed.connect(_on_near_missed)
	_pressure.setup(tuning.wall_start_distance, tuning.wall_max_distance, def.wall_creep)
	_pressure.wall_reached.connect(_player.die.bind(GameTypes.DeathCause.WALL))
	_player.shield_broken.connect(_on_shield_broken)
	_update_view()
	_camera.reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_conductor.advance(delta)
	if _player.is_alive():
		_pressure.advance(delta)
	if _player.position.y <= _next_boundary_y:
		_enter_sector(sector + 1)
	_update_view()
	# Lazerler vuruşla yanıp söner (M2-12); yeni yerleşen parçalar da aynı adımda güncellenir.
	_chunks.set_beat(_conductor.beat_time() / _conductor.beat_length())
	_update_wall()
	if _combo > 0 and _conductor.run_time - _last_graze_time > tuning.combo_window:
		_combo = 0
		stats.multiplier = 1
		Events.combo_ended.emit()
	var meters: int = floori(_start_height + (_start_y - _player.position.y) / TuningConfig.PX_PER_M)
	if meters != _height_m:
		_height_m = meters
		Events.height_changed.emit(meters)


## Hız basamağı. Oyuncu bu adımda sınırı eski hızla biraz aşmıştır; konumu, sınırı geçtiği andan
## beri yeni hızla tırmanmış gibi düzeltilir (en çok 1–2 px). Böylece oyuncu her an
## ChunkSpawner'ın hesapladığı yerdedir ve yeni sektörün engelleri de tam vuruş anlarında geçer.
func _enter_sector(next: int) -> void:
	var def: SectorDef = sectors.def_at(next)
	var past: float = (_next_boundary_y - _player.position.y) / sectors.def_at(sector).climb_px()
	_player.position.y = _next_boundary_y - past * def.climb_px()
	sector = next
	_player.climb_speed = def.climb_speed
	_pressure.creep = def.wall_creep
	_next_boundary_y = _boundary_y(next)
	_corridor.set_tint(def.ambient_color)
	Events.sector_entered.emit(next)


## Kıl payı: pencere içindeyse kombo uzar, değilse yeni zincir başlar. Glimmer çarpanı
## kombo uzunluğuna göre ×1 / ×2 / ×3 (GDD §15).
func _on_near_missed() -> void:
	var now: float = _conductor.run_time
	_combo = _combo + 1 if _combo > 0 and now - _last_graze_time <= tuning.combo_window else 1
	_last_graze_time = now
	stats.near_misses += 1
	_pressure.push(tuning.near_miss_push)
	if _combo >= tuning.combo_x3_at:
		stats.multiplier = 3
	elif _combo >= tuning.combo_x2_at:
		stats.multiplier = 2
	else:
		stats.multiplier = 1
	Events.near_miss.emit(_combo)


## Duvar görselini oyuncunun altına koyar ve yakınlığı yayar (ekranın altında 0, oyuncuda 1).
func _update_wall() -> void:
	var gap_px: float = TuningConfig.to_px(_pressure.distance_m)
	_collapse_wall.position = Vector2(0.0, _player.position.y + gap_px)
	var below_px: float = maxf(_camera.view_bottom() - _player.position.y, 1.0)
	var proximity: float = clampf(1.0 - gap_px / below_px, 0.0, 1.0)
	if absf(proximity - _proximity) >= PROXIMITY_STEP or (proximity == 0.0 and _proximity != 0.0):
		_proximity = proximity
		Events.wall_proximity_changed.emit(proximity)


## Kalkanla darbe almak çöküş duvarını yaklaştırır (GDD §7, §14).
func _on_shield_broken() -> void:
	_pressure.pull(tuning.shield_pull)


func _on_glimmer_collected(value: int) -> void:
	Events.glimmer_collected.emit(stats.add_glimmer(value))
	_pressure.push(tuning.glimmer_push)


## Sektörün bittiği dünya y'si (son sektörde -INF).
func _boundary_y(index: int) -> float:
	return _start_y - TuningConfig.to_px(sectors.end_height(index) - _start_height)


## Değerler her adımda TuningConfig'ten okunur; canlı ayar paneli (M1-11) anında etki eder.
func _update_view() -> void:
	_camera.follow(_player.position.y, TuningConfig.to_px(tuning.lookahead))
	var half_width: float = TuningConfig.to_px(tuning.corridor_width) * 0.5
	_chunks.update_view(_camera.view_top(), _camera.view_bottom(), half_width)
	# Parçaların duvar boşlukları koridora bildirilir; koridor o aralıklarda duvarsız kalır.
	_corridor.set_gaps(_chunks.active_gaps())
	_corridor.update_view(_camera.view_bottom(), half_width)
