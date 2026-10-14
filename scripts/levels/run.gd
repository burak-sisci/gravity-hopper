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
##
## Renkler (M3-02): sektörün paleti (SectorPalette) duvarlara ve arka plana (ekranın temizleme
## rengi) uygulanır; tur başında anında, sektör geçişinde renk dalgasıyla (yalnızca görsel).
## Renk dalgası (M3-08, ADR-051): yeni palet ekranın altından üstüne NeonStyle.wave_time'da
## yayılır; arka plan, duvarlar ve iz dalganın önüne göre boyanır. Afiş dalga ona varınca
## gelir (HUD aynı süreyi NeonStyle'dan okur).
## Arka plan veri ağı (M3-07): Background kameranın y'siyle paralaks kayar, vuruşta nabız atar.
## Hız hissi (M3-13): sektörün tırmanış hızıyla hız çizgileri yoğunlaşır ve iz uzar (yalnızca
## görsel); tur başında hemen, sektör geçişinde yavaşça.
## Oyun hissi (M3-10): ölümde dünya death_freeze boyunca donar, ardından kamera sarsılır; kalkan
## kırılınca da hafifçe sarsılır (yalnızca yatay, görüş kuralı bozulmaz). Parça havuzları
## turlar arasında Main'in ChunkPools'unda korunur (ADR-054).
## Parçacıklar (M3-11): Effects iniş kıvılcımını, Glimmer patlamasını ve donmanın sonunda ölüm
## patlamasını çıkarır (çekirdek o anda gizlenir).
## Kıl payı yavaş çekimi (M3-12): zincirin ilk halkasında ve çarpanın büyüdüğü halkada
## SlowMotion Engine.time_scale'i kısa süre düşürür (müzik de yavaşlar). Ölümde ve tur yarıda
## bitince ölçek hemen geri verilir.
## Rekor çizgisi (M3-14): RecordLine, record_height yüksekliğinde (Main oturum rekorunu verir)
## parlar; oyuncu yaklaştıkça güçlenir, varınca söner. Rekor yoksa ya da tur rekorun üstünden
## başladıysa çizgi yoktur.

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
## Rekor yüksekliği (m; Main, GameManager'ın oturum rekorunu verir). 0 ise rekor çizgisi yok.
@export var record_height: int = 0

var rng: RunRng
## Turun müzik parçası (katalog boşsa null; tempo o zaman Conductor.bpm'in varsayılanı).
var track: MusicTrack = null
## Oyuncunun bulunduğu sektör.
var sector: int = 1
## Turun istatistikleri (Glimmer, kombo; §8.6).
var stats: RunStats = RunStats.new()
## Turlar arasında korunan parça havuzları (Main atar, M3-10). Atanmamışsa (testler) ChunkSpawner
## havuzları kendi altında kurar.
var chunk_pools: ChunkPools = null

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
## Gösterilen palet (dalga sırasında dalganın üstündeki eski palet).
var _ambient: Color = Color.WHITE
var _accent: Color = Color.WHITE
var _background_color: Color = Color.BLACK
## Renk dalgasının getirdiği palet (dalga yokken null) ve dalganın başından beri geçen süre.
var _wave_palette: SectorPalette = null
var _wave_elapsed: float = 0.0
## Ölüm görüldü mü ve donmanın kalan süresi (M3-10).
var _death_seen: bool = false
var _freeze_left: float = 0.0
var _slow_motion: SlowMotion = SlowMotion.new()

@onready var _background: Background = %Background
@onready var _conductor: Conductor = %Conductor
@onready var _corridor: Corridor = %Corridor
@onready var _chunks: ChunkSpawner = %ChunkSpawner
@onready var _camera: GameCamera = %GameCamera
@onready var _player: Player = %Player
@onready var _pressure: PressureSystem = %PressureSystem
@onready var _collapse_wall: CollapseWall = %CollapseWall
@onready var _effects: Effects = %Effects
@onready var _record_line: RecordLine = %RecordLine


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
	_camera.tuning = tuning
	_player.climb_speed = def.climb_speed
	_conductor.track = track
	if track != null:
		_conductor.set_tempo(track.bpm, 0.0)
	_next_boundary_y = _boundary_y(sector)
	_camera.follow(_player.position.y, TuningConfig.to_px(tuning.lookahead))
	_background.reset_scroll(_camera.position.y)
	_show_speed(def.climb_speed, true)
	_corridor.build(_camera.view_top() - Corridor.SEGMENT_HEIGHT)
	_show_palette(def.palette, true)
	_place_record()
	_chunks.shared_pools = chunk_pools
	_chunks.setup(rng, tuning, sectors, start_sector, _start_y, _conductor.bpm)
	_chunks.glimmer_collected.connect(_on_glimmer_collected)
	_player.near_missed.connect(_on_near_missed)
	_pressure.setup(tuning.wall_start_distance, tuning.wall_max_distance, def.wall_creep)
	_pressure.wall_reached.connect(_player.die.bind(GameTypes.DeathCause.WALL))
	_player.shield_broken.connect(_on_shield_broken)
	_player.landed.connect(_effects.landing_spark)
	_update_view()
	_update_wall()
	# Tur ilk karesinden yerinde (M3-10'da bulundu): ara değerleme bütün dünyada sıfırlanır
	# (çocuklara yayılır); yoksa duvarlar ve çöküş duvarı ilk karelerde varsayılan konumlarından
	# kayarak gelirdi. Ara değerlemeli kamera kendini ancak ilk fizik adımında uygular; yeni tur
	# bir karede (yeniden başlama zamanlayıcısı) kurulunca o karede dünya kamerasız çiziliyordu.
	reset_physics_interpolation()
	_camera.force_update_scroll()


## Tur yavaş çekimin ortasında biterse (yeniden başlama) zaman ölçeği geri verilir.
func _exit_tree() -> void:
	_slow_motion.stop()


func _physics_process(delta: float) -> void:
	_slow_motion.advance(1.0 / Engine.physics_ticks_per_second)
	if _frozen(delta):
		return
	_conductor.advance(delta)
	if _player.is_alive():
		_pressure.advance(delta)
	if _player.position.y <= _next_boundary_y:
		_enter_sector(sector + 1)
	_update_view()
	_advance_wave(delta)
	# Lazerler vuruşla yanıp söner (M2-12); yeni yerleşen parçalar da aynı adımda güncellenir.
	# Duvarlar, arka plan ağı ve çöküş duvarının glitch'i vuruşta nabız atar (M3-03, M3-07,
	# M3-09; yalnızca görsel).
	var beat: float = _conductor.beat_time() / _conductor.beat_length()
	_chunks.set_beat(beat)
	_corridor.set_beat(beat)
	_background.set_beat(beat)
	_collapse_wall.set_beat(beat)
	_record_line.track(_player.position.y, beat)
	_background.set_scroll(_camera.position.y)
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
	_show_palette(def.palette, false)
	_show_speed(def.climb_speed, false)
	Events.sector_entered.emit(next)


## Kıl payı: pencere içindeyse kombo uzar, değilse yeni zincir başlar. Glimmer çarpanı
## kombo uzunluğuna göre ×1 / ×2 / ×3 (GDD §15). Yavaş çekim zincirin ilk halkasında ve
## çarpanın büyüdüğü halkada.
func _on_near_missed() -> void:
	var now: float = _conductor.run_time
	var previous: int = stats.multiplier
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
	if _combo == 1 or stats.multiplier > previous:
		_slow_motion.start(tuning.slow_motion_scale, tuning.slow_motion_time,
				tuning.slow_motion_return)
	Events.near_miss.emit(_combo, stats.multiplier)


## Duvar görselini oyuncunun altına koyar ve yakınlığı yayar (ekranın altında 0, oyuncuda 1).
func _update_wall() -> void:
	var gap_px: float = TuningConfig.to_px(_pressure.distance_m)
	_collapse_wall.position = Vector2(0.0, _player.position.y + gap_px)
	var below_px: float = maxf(_camera.view_bottom() - _player.position.y, 1.0)
	var proximity: float = clampf(1.0 - gap_px / below_px, 0.0, 1.0)
	if absf(proximity - _proximity) >= PROXIMITY_STEP or (proximity == 0.0 and _proximity != 0.0):
		_proximity = proximity
		Events.wall_proximity_changed.emit(proximity)


## Kalkanla darbe almak çöküş duvarını yaklaştırır (GDD §7, §14) ve kamerayı sarsar.
func _on_shield_broken() -> void:
	_pressure.pull(tuning.shield_pull)
	_camera.add_trauma(tuning.shield_trauma)


func _on_glimmer_collected(value: int, at: Vector2) -> void:
	Events.glimmer_collected.emit(stats.add_glimmer(value))
	_pressure.push(tuning.glimmer_push)
	_effects.glimmer_burst(at)


## Ölümde kısa donma (M3-10, GDD §19): ölümün görüldüğü adımdan death_freeze boyunca dünya
## ilerlemez (vuruş, lazer, dalga, duvar, iz); bitince kamera sarsılır. Ara değerlenen arka plan
## titremesin diye son değerleri yeniden verilir. Ölü oyuncunun turunda oynanış yoktur; donma
## yeniden başlama süresinin içindedir. Donma bitince çekirdek patlar (_shatter). Dünya bu adım
## donuksa true.
func _frozen(delta: float) -> bool:
	if not _death_seen:
		if _player.is_alive():
			return false
		_death_seen = true
		_slow_motion.stop()
		_background.stop_speed()
		_freeze_left = tuning.death_freeze
		if _freeze_left <= 0.0:
			_shatter()
			return false
		_player.set_held(true)
	if _freeze_left <= 0.0:
		return false
	_freeze_left -= delta
	_background.set_scroll(_camera.position.y)
	_advance_wave(0.0)
	if _freeze_left <= 0.0:
		_player.set_held(false)
		_shatter()
	return true


## Ölüm donmasının sonu (M3-11): çekirdek gizlenir, yerinde ölüm patlaması çıkar, kamera sarsılır.
func _shatter() -> void:
	_player.hide_core()
	_effects.death_burst(_player.global_position)
	_camera.add_trauma(tuning.death_trauma)


## Hız hissi: hız çizgileri ve izin boyu sektörün tırmanış hızından (M3-13).
func _show_speed(climb_speed: float, instant: bool) -> void:
	var style: NeonStyle = Neon.STYLE
	_background.set_speed(climb_speed, instant)
	_player.set_trail_stretch(style.trail_stretch(style.speed_feel(climb_speed)))


## Rekor çizgisini rekorun dünya y'sine koyar (HUD yüksekliğiyle aynı hesap). Tur rekorun
## üstünden başladıysa çizgi yoktur.
func _place_record() -> void:
	if float(record_height) <= _start_height:
		return
	var y: float = _start_y - TuningConfig.to_px(record_height - _start_height)
	_record_line.place(y, TuningConfig.to_px(tuning.corridor_width) * 0.5)


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


## Sektörün paletini gösterir: anında ya da renk dalgasıyla.
func _show_palette(palette: SectorPalette, instant: bool) -> void:
	if palette == null:
		return
	if _wave_palette != null:
		_finish_wave()
	if instant:
		_apply_colors(palette.ambient, palette.accent, palette.background)
		return
	_wave_palette = palette
	_wave_elapsed = 0.0
	# Ekranın temizleme rengi hemen yenisi; eskisi dalganın üstünü örter (Background).
	_background.start_wave(_background_color, palette.ambient, palette.accent)
	RenderingServer.set_default_clear_color(palette.background)
	_advance_wave(0.0)


## Dalganın önünü ilerletir (ekranda alttan üste; dünyada kameranın görünür alanına göre).
func _advance_wave(delta: float) -> void:
	if _wave_palette == null:
		return
	var style: NeonStyle = Neon.STYLE
	_wave_elapsed += delta
	var progress: float = style.wave_progress(_wave_elapsed)
	if progress >= 1.0:
		_finish_wave()
		return
	var front_y: float = style.wave_front(progress, _camera.view_top(), _camera.view_bottom())
	_background.set_wave(progress)
	_corridor.set_wave(front_y, _wave_palette.ambient, _wave_palette.accent)
	var weight: float = style.wave_weight(_player.position.y, front_y)
	_player.set_ambient(_ambient.lerp(_wave_palette.ambient, weight))


func _finish_wave() -> void:
	var palette: SectorPalette = _wave_palette
	_wave_palette = null
	_background.end_wave()
	_apply_colors(palette.ambient, palette.accent, palette.background)


func _apply_colors(ambient: Color, accent: Color, background: Color) -> void:
	_ambient = ambient
	_accent = accent
	_background_color = background
	_corridor.set_colors(ambient, accent)
	_background.set_colors(ambient, accent)
	_player.set_ambient(ambient)
	_effects.set_ambient(ambient)
	RenderingServer.set_default_clear_color(background)
