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
## Rekor çizgisi (M3-14): RecordLine, record_height yüksekliğinde (Main kalıcı rekoru verir)
## parlar; oyuncu yaklaştıkça güçlenir, varınca söner. Rekor yoksa ya da tur rekorun üstünden
## başladıysa çizgi yoktur.
## Yükseltmeler (M4-04, ADR-066): Main tur başında yükü (RunLoadout) verir; tur boyunca
## değişmez. Mıknatıs varsa Run her adımda oyuncunun yerini ChunkSpawner üstünden Glimmer'lara
## iletir (Magnet); menzile giren Glimmer oyuncuya akar. Harita değişmez. Yükteki kozmetik iz
## (M4-08) tur başında oyuncunun izine verilir.
## Kalkan yükseltmesi (M4-05): yükte varsa oyuncu tura kalkanla başlar; yenilenme mesafesi
## varsa kırılan kalkan, kırıldığı yerden o kadar tırmanılınca yeniden takılır.
## Başlangıç Sıçraması (M4-06): yükte varsa tur, oyuncunun normal tırmanışının üstüne ek bir yolla
## başlar. Ek yol tam vuruş sayısına yuvarlanır ve yumuşak (smoothstep) bir eğriyle verilir;
## bitince oyuncu vuruş ızgarasında tam k vuruş öndedir, engeller yine yarım vuruşta geçilir.
## Sıçramada oyuncu dokunulmazdır ve geçtiği Glimmer'lar toplanır. Harita değişmez.
## İkinci Şans (M4-07): ölü oyuncunun turunda saat (Conductor) durur. GameManager dirilişi
## duyurunca (Events.player_revived) oyuncu kaldığı yerde canlanır: yakındaki tehlikeler
## temizlenir, çöküş duvarı geri itilir, revive_grace boyunca dokunulmazdır. Saat ölümde durduğu
## için oyuncu vuruş ızgarasındaki yerindedir; müzik kaldığı yerden sürer (AudioManager).
## Büyük Depolama Birimi (M4-13): finale sektörüne (Taşma) girilen adımda final anı oynar:
## sector_entered'dan hemen sonra Events.great_storage_reached yayılır, oyuncunun yerinde bütün
## paletlerin renkleriyle bir patlama çıkar ve kamera hafifçe sarsılır. Sınır turda bir kez geçilir;
## tur Taşma'dan başlarsa final oynamaz.
## Döngüsel palet (M4-13): sektörün palet döngüsü varsa palet, sektörün başından her
## palette_cycle_length'te sıradakine renk dalgasıyla geçer (yalnızca görsel; hız, zorluk ve
## sektör değişmez).

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
## Rekor yüksekliği (m; Main, Progression'ın kalıcı rekorunu verir). 0 ise rekor çizgisi yok.
@export var record_height: int = 0

## Turun yükseltme yükü (Main, Progression'dan verir). Boş yük yükseltmesiz turdur.
var loadout: RunLoadout = RunLoadout.new()

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
## Mıknatıs yükseltmesi (yükte yoksa null).
var _magnet: Magnet = null
## Kırılan kalkan bekleniyor mu ve oyuncu hangi y'ye varınca yeniden takılır (M4-05).
var _shield_due: bool = false
var _shield_due_y: float = 0.0
## Başlangıç Sıçraması (M4-06): sürüyor mu, ek yol (px), süre (sn) ve verilmiş oran (0–1).
var _dashing: bool = false
var _dash_px: float = 0.0
var _dash_time: float = 0.0
var _dash_progress: float = 0.0
## Döngüsel palet: gösterilen adım ve oyuncunun sıradaki palete geçeceği dünya y'si (döngü
## yoksa -INF).
var _palette_step: int = 0
var _next_palette_y: float = -INF

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
	_start_palette_cycle(def, _start_y)
	_camera.follow(_player.position.y, TuningConfig.to_px(tuning.lookahead))
	_background.reset_scroll(_camera.position.y)
	_player.set_trail(loadout.trail)
	_show_speed(def.climb_speed, true)
	_corridor.build(_camera.view_top() - Corridor.SEGMENT_HEIGHT)
	_show_palette(def.palette, true)
	_place_record()
	_chunks.shared_pools = chunk_pools
	_chunks.setup(rng, tuning, sectors, start_sector, _start_y, _conductor.bpm)
	_chunks.glimmer_collected.connect(_on_glimmer_collected)
	if loadout.magnet_m > 0.0:
		_magnet = Magnet.new(tuning, loadout.magnet_m)
	_player.near_missed.connect(_on_near_missed)
	_pressure.setup(tuning.wall_start_distance, tuning.wall_max_distance, def.wall_creep)
	_pressure.wall_reached.connect(_player.die.bind(GameTypes.DeathCause.WALL))
	_player.shield_broken.connect(_on_shield_broken)
	if loadout.start_shield:
		_player.give_shield()
	if loadout.head_start_m > 0.0:
		_start_dash(def)
	_player.landed.connect(_effects.landing_spark)
	_record_line.passed.connect(Events.record_broken.emit)
	Events.player_revived.connect(_on_player_revived)
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
	# Ölü oyuncunun turunda saat durur: diriliş vuruş ızgarasında kaldığı yerden sürer (M4-07).
	if _player.is_alive():
		_conductor.advance(delta)
		_advance_dash()
		_pressure.advance(delta)
	if _player.position.y <= _next_boundary_y:
		_enter_sector(sector + 1)
	if _player.position.y <= _next_palette_y:
		_next_cycle_palette()
	_update_view()
	if _magnet != null and _player.is_alive():
		_chunks.attract(_player.global_position, _magnet, delta)
	_regen_shield()
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
	_effects.track_finale(_player.global_position)
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
	_start_palette_cycle(def, _next_boundary_y)
	_next_boundary_y = _boundary_y(next)
	_show_palette(def.palette, false)
	_show_speed(def.climb_speed, false)
	Events.sector_entered.emit(next)
	if def.finale:
		_play_finale()


## Büyük Depolama Birimi'ne varış: bütün paletlerin renkleriyle patlama, hafif sarsıntı ve duyuru
## (HUD afişi, AudioManager sesi, Progression başarım izi).
func _play_finale() -> void:
	var colors: Array[Color] = []
	for palette: SectorPalette in sectors.palettes():
		colors.append(palette.ambient)
	_effects.finale_burst(_player.global_position, colors)
	_camera.add_trauma(tuning.finale_trauma)
	Events.great_storage_reached.emit()


## Sektörün palet döngüsünü başından kurar (döngü yoksa kapalı). sector_start_y: sektörün başladığı
## dünya y'si.
func _start_palette_cycle(def: SectorDef, sector_start_y: float) -> void:
	_palette_step = 0
	_next_palette_y = -INF
	if def.cycles_palette():
		_next_palette_y = sector_start_y - TuningConfig.to_px(def.palette_cycle_length)


## Döngünün sıradaki paleti renk dalgasıyla gelir.
func _next_cycle_palette() -> void:
	var def: SectorDef = sectors.def_at(sector)
	_palette_step += 1
	_next_palette_y -= TuningConfig.to_px(def.palette_cycle_length)
	_show_palette(def.palette_at(_palette_step), false)


## Döngüsel palette gösterilen adım (testler).
func palette_step() -> int:
	return _palette_step


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
	if loadout.shield_regen_m > 0.0:
		_shield_due = true
		_shield_due_y = _player.position.y - TuningConfig.to_px(loadout.shield_regen_m)


## Başlangıç Sıçraması (M4-06). Ek yol tam vuruş sayısıdır (k vuruşluk tırmanış): sıçramadan
## sonra oyuncunun yeri, turun başından t + k vuruş tırmanmış gibidir; ızgara kaymaz. Sıçrama
## başlangıç sektöründe biter (toplam yol = ek yol × çarpan / (çarpan − 1)); sığmazsa kısalır.
func _start_dash(def: SectorDef) -> void:
	var speedup: float = tuning.head_start_speedup
	var beat_px: float = def.climb_px() * _conductor.beat_length()
	var beats: int = roundi(TuningConfig.to_px(loadout.head_start_m) / beat_px)
	var room_px: float = _player.position.y - _next_boundary_y
	if is_finite(room_px):
		beats = mini(beats, floori(room_px * (speedup - 1.0) / speedup / beat_px) - 1)
	if beats <= 0:
		return
	_dashing = true
	_dash_px = beats * beat_px
	_dash_time = beats * _conductor.beat_length() / (speedup - 1.0)
	_dash_progress = 0.0
	_player.set_dashing(true)
	_background.set_speed(Neon.STYLE.speed_feel_max_speed, false)


## Sıçramanın bu adımdaki payı: oyuncuyu ek yolun eğrisine göre yukarı taşır, geçtiği Glimmer'ları
## toplatır. Süre turun saatinden (run_time) okunur; bitişte ek yolun tamamı verilmiştir.
## Başlangıç ilk adımda duyurulur: run_started'dan (Main, Run ağaca girince) sonra.
func _advance_dash() -> void:
	if not _dashing:
		return
	if _dash_progress == 0.0:
		Events.head_start_changed.emit(true)
	var t: float = minf(_conductor.run_time / _dash_time, 1.0)
	var progress: float = smoothstep(0.0, 1.0, t)
	_player.position.y -= (progress - _dash_progress) * _dash_px
	_dash_progress = progress
	_chunks.collect_passed(_player.position.y)
	if t >= 1.0:
		_dashing = false
		_player.set_dashing(false, tuning.head_start_grace)
		_background.set_speed(sectors.def_at(sector).climb_speed, false)
		Events.head_start_changed.emit(false)


## Sıçrama sürüyor mu (testler).
func is_dashing() -> bool:
	return _dashing


## İkinci Şans (M4-07): ölü oyuncu kaldığı yerde canlanır. Donma sürüyorsa biter; önündeki
## (sektörün hızıyla revive_clear_time sürede tırmanılacak yol) ve hemen altındaki tehlikeler
## temizlenir; çöküş duvarı geri itilir; kombo biter, hız çizgileri yeniden akar.
func _on_player_revived() -> void:
	if _player.is_alive():
		return
	_death_seen = false
	_freeze_left = 0.0
	_player.set_held(false)
	_player.revive(tuning.revive_grace)
	var y: float = _player.position.y
	var ahead_px: float = sectors.def_at(sector).climb_px() * tuning.revive_clear_time
	_chunks.clear_hazards(y - ahead_px, y + TuningConfig.to_px(tuning.revive_clear_behind))
	_pressure.revive(tuning.revive_wall_distance)
	_background.resume_speed()
	if _combo > 0:
		_combo = 0
		stats.multiplier = 1
		Events.combo_ended.emit()
	_update_wall()


## Kalkan yükseltmesi (M4-05): kırılan kalkan, yenilenme mesafesi tırmanılınca geri gelir.
func _regen_shield() -> void:
	if _shield_due and _player.is_alive() and _player.position.y <= _shield_due_y:
		_shield_due = false
		_player.give_shield()


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
		_apply_colors(palette)
		return
	_wave_palette = palette
	_wave_elapsed = 0.0
	# Ekranın temizleme rengi hemen yenisi; eskisi dalganın üstünü örter (Background).
	_background.start_wave(_background_color, palette.ambient, palette.accent, palette.glitch)
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
	_apply_colors(palette)


func _apply_colors(palette: SectorPalette) -> void:
	_ambient = palette.ambient
	_accent = palette.accent
	_background_color = palette.background
	_corridor.set_colors(_ambient, _accent)
	_background.set_colors(_ambient, _accent, palette.glitch)
	_player.set_ambient(_ambient)
	_effects.set_ambient(_ambient)
	RenderingServer.set_default_clear_color(_background_color)
