extends GdUnitTestSuite
## Sektör ilerleyişi (M2-08, architecture.md §8.2–8.3): hız basamağı, Events.sector_entered ve
## her sektörde dikenlerin müziğin yarım vuruş anında geçmesi. Tempo turun parçasından gelir ve
## sektör geçişinde değişmez (M2-20). Gerçek sektörlerin hızı, kısa boylarla (150 m) denenir;
## tur S1'den son sektöre tırmanır ve orada LAST_SECTOR_TIME daha oynanır.

const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
const SECTORS: SectorCatalog = preload("res://data/sectors/sector_catalog.tres")
const MUSIC: MusicCatalog = preload("res://data/music/music_catalog.tres")
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SHORT_LENGTH: float = 150.0
const DT: float = 1.0 / 60.0
## Son sektöre girildikten sonra oynanan süre (sn): nefes alma (2,5 sn) + birkaç parça.
const LAST_SECTOR_TIME: float = 10.0

var _entered: Array[int] = []


func before_test() -> void:
	_entered.clear()
	Events.sector_entered.connect(_on_sector_entered)


func after_test() -> void:
	Events.sector_entered.disconnect(_on_sector_entered)
	Events.debug_invincibility_changed.emit(false)


func test_spikes_stay_on_music_beat_at_fastest_tempo() -> void:
	await _check_sectors_on_beat(&"castle")


func test_spikes_stay_on_music_beat_at_slowest_tempo() -> void:
	await _check_sectors_on_beat(&"pagoda")


## Tur tek parçayla (verilen id) S1'den son sektöre tırmanır: her sektörde adım sabit, tempo tur
## boyunca parçanınki ve her diken, turun başından sayılan müzik ızgarasında yarım vuruş anında
## geçer.
func _check_sectors_on_beat(track_id: StringName) -> void:
	var run: Run = _start(1, track_id)
	var player: Node2D = run.get_node("%Player") as Node2D
	var conductor: Conductor = run.get_node("%Conductor") as Conductor
	var spawner: ChunkSpawner = run.get_node("%ChunkSpawner") as ChunkSpawner
	var speeds: Dictionary[int, float] = {}
	var last: int = SECTORS.count()
	var passes: Dictionary[int, int] = {}
	for sector: int in range(1, last + 1):
		passes[sector] = 0
	var entered_at: Dictionary[int, float] = {1: 0.0}
	var corridor: Corridor = run.get_node("%Corridor") as Corridor
	# Tur başında palet anında gelir (M3-02).
	assert_bool(corridor.ambient().is_equal_approx(_palette(1).ambient)).is_true()
	var ambient_on_entry: Color = Color.BLACK
	var background: Background = run.get_node("%Background") as Background
	# Renk dalgası (M3-08): girişte başlıyor mu, kaç adım sürüyor, ortasında duvarlar.
	var wave_on_entry: bool = false
	var clear_on_entry: Color = Color.BLACK
	var wave_steps: int = 0
	var mid_wave: Array[Vector4] = []
	var half_wave: int = roundi(Neon.STYLE.wave_time * 30.0)
	# await physics_frame adım işlenmeden döner; ölçüm ilk tam adımdan sonra başlar.
	await _frames(2)
	var previous_y: float = player.position.y
	var previous_sector: int = run.sector
	for frame: int in ceili((_last_sector_entry() + LAST_SECTOR_TIME) / DT):
		await get_tree().physics_frame
		var step: float = previous_y - player.position.y
		if run.sector != previous_sector:
			# Sınır karesi: Run, oyuncunun sınırı eski hızla aştığı payı yeni hıza göre düzeltir.
			entered_at[run.sector] = conductor.run_time
			if run.sector == 2:
				ambient_on_entry = corridor.ambient()
				wave_on_entry = background.is_wave_active()
				clear_on_entry = RenderingServer.get_default_clear_color()
		elif not speeds.has(run.sector):
			speeds[run.sector] = step
		else:
			# Adım tam sabit (Player, kaymanın dikey payını geri alır; M2-10).
			assert_float(step).is_equal_approx(speeds[run.sector], 0.002)
		if run.sector == 2 and run.sector == previous_sector and background.is_wave_active():
			wave_steps += 1
			if wave_steps == half_wave:
				mid_wave = corridor.segment_colors(-1.0)
		previous_sector = run.sector
		var half_beat: float = conductor.beat_length() * 0.5
		for chunk: ChunkInfo in spawner.active_chunks():
			for item: Node2D in chunk.items():
				var y: float = chunk.position.y + item.position.y
				if previous_y > y and player.position.y <= y:
					passes[run.sector] += 1
					var t: float = conductor.beat_time()
					# Nefes alma (M2-09): yeni sektörün ilk 2,5 sn'sinde diken geçmez.
					if run.sector > 1:
						var since: float = conductor.run_time - entered_at[run.sector]
						assert_float(since).override_failure_message(
								"S%d'ye girdikten %.2f sn sonra diken" % [run.sector, since]
						).is_greater_equal(2.5)
					var off: float = absf(t - roundf(t / half_beat) * half_beat)
					assert_float(off).override_failure_message(
							"S%d: %s yarım vuruştan %.4f sn uzak" % [run.sector, item.name, off]
					).is_less_equal(DT + 0.0001)
		previous_y = player.position.y
	assert_array(_entered).is_equal(range(2, last + 1))
	for sector: int in range(1, last + 1):
		assert_float(speeds.get(sector, 0.0)).override_failure_message(
				"S%d adım hızı" % sector).is_equal_approx(
				SECTORS.def_at(sector).climb_px() * DT, 0.001)
		assert_int(passes[sector]).override_failure_message(
				"S%d'de diken geçişi yok" % sector).is_greater(0)
	# Tempo tur boyunca parçanın temposu; ızgara sektör geçişinde yeniden başlamaz.
	assert_str(String(run.track.id)).is_equal(String(track_id))
	assert_float(conductor.bpm).is_equal(run.track.bpm)
	assert_float(conductor.beat_time()).is_equal_approx(conductor.run_time, 0.000001)
	# Renkler paletten (M3-02): S2'ye girişte dalga yeni başlıyor (duvarlar hâlâ S1 renginde,
	# ekranın temizleme rengi S2'ninki; eskisini dalganın üstü örter). Dalga wave_time sürer;
	# ortasında üstteki duvarlar eski, alttakiler yeni renkte. Son sektöre çok önce girildi,
	# dalga bitti: duvarlar ve arka plan son sektörün paletinde.
	assert_float(_channel_gap(ambient_on_entry, _palette(1).ambient)).is_less(0.05)
	assert_float(_channel_gap(ambient_on_entry, _palette(2).ambient)).is_greater(0.1)
	assert_bool(wave_on_entry).is_true()
	assert_bool(clear_on_entry.is_equal_approx(_palette(2).background)).is_true()
	assert_int(wave_steps).is_between(half_wave * 2 - 2, half_wave * 2 + 1)
	var top: Vector4 = mid_wave[0]
	var bottom: Vector4 = mid_wave[mid_wave.size() - 1]
	assert_bool(Color(top.y, top.z, top.w).is_equal_approx(_palette(1).ambient)).is_true()
	assert_bool(Color(bottom.y, bottom.z, bottom.w).is_equal_approx(_palette(2).ambient)).is_true()
	assert_bool(background.is_wave_active()).is_false()
	assert_bool(corridor.ambient().is_equal_approx(_palette(last).ambient)).is_true()
	var clear: Color = RenderingServer.get_default_clear_color()
	assert_bool(clear.is_equal_approx(_palette(last).background)).is_true()


func test_start_sector_sets_height_and_speed() -> void:
	var heights: Array[int] = []
	var on_height: Callable = func(meters: int) -> void: heights.append(meters)
	Events.height_changed.connect(on_height)
	var run: Run = _start(2)
	var player: Node2D = run.get_node("%Player") as Node2D
	await _frames(1)
	var y0: float = player.position.y
	await _frames(60)
	Events.height_changed.disconnect(on_height)
	assert_int(run.sector).is_equal(2)
	# 1 sn'de S2 hızıyla 14 m; yükseklik S2'nin başından (150 m) sayılır.
	assert_float(y0 - player.position.y).is_equal_approx(SECTORS.def_at(2).climb_px(), 0.01)
	assert_int(heights[0]).is_equal(int(SHORT_LENGTH))
	assert_int(heights[heights.size() - 1]).is_equal(int(SHORT_LENGTH) + 14)


## Turu kısa sektörlerle kurar; track_id verilirse tur yalnızca o parçayı çalabilir.
func _start(sector: int, track_id: StringName = &"") -> Run:
	var run: Run = auto_free(RUN_SCENE.instantiate()) as Run
	if track_id != &"":
		var only: MusicCatalog = MusicCatalog.new()
		for track: MusicTrack in MUSIC.tracks:
			if track.id == track_id:
				only.tracks.append(track)
		run.music = only
	run.tuning = ResourceLoader.load(
			TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TuningConfig
	var sectors: SectorCatalog = SectorCatalog.new()
	for i: int in SECTORS.count():
		var def: SectorDef = SECTORS.def_at(i + 1).duplicate() as SectorDef
		def.length = SHORT_LENGTH
		sectors.sectors.append(def)
	run.sectors = sectors
	run.run_seed = 31
	run.start_sector = sector
	add_child(run)
	Events.debug_invincibility_changed.emit(true)
	return run


## S1'den başlayan turun son sektöre girdiği an (sn).
func _last_sector_entry() -> float:
	var result: float = 0.0
	for sector: int in range(1, SECTORS.count()):
		result += SHORT_LENGTH / SECTORS.def_at(sector).climb_speed
	return result


## İki renk arasındaki en büyük kanal farkı.
func _channel_gap(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _palette(sector: int) -> SectorPalette:
	return SECTORS.def_at(sector).palette


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _on_sector_entered(index: int) -> void:
	_entered.append(index)
