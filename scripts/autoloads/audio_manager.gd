extends Node
## Ses yöneticisi: efekt havuzu, müzik çalma ve geçişleri (architecture.md §8.3).
##
## Olayları Events'ten dinler. Engine.time_scale değiştiğinde müziğin pitch_scale
## değerini aynı orana çeker (ritim senkronu, ADR-008).
##
## Müzik (M2-20, ADR-040): turun parçasını (MusicTrack) çalar; M2-07'nin kodla üretilen
## metronomunun yerini aldı. Conductor her fizik adımında sync_beat_clock() ile vuruş saatini
## (turun başından beri geçen oyun zamanı) ve parçayı bildirir. Parça ilk vuruşla başladığı için
## turun 0. vuruşu parçanın 0. saniyesidir; duyulan konum MusicTrack.position_at(vuruş saati)
## olacak şekilde hizalanır. Döngü OGG'nin kendisindedir (loop_offset = loop_start) ve tam ölçü
## olduğu için döngüde vuruş kaymaz.
## Duyulan konum = çalma konumu + son karıştırmadan beri geçen süre − çıkış gecikmesi.
## Tur başlayınca çalar, oyuncu ölünce durur. Dirilişte (M4-07) saat yeniden açılır; parça,
## Run'ın ölümde durdurduğu vuruş saatinden, yani kaldığı yerden yeniden konumlanır.
##
## Duraklatma (M5-06): oyun ağacı duraklayınca parça durur (efektler ağaçla birlikte bekler).
## Devamda saat kaldığı yerden sürer; ilk sync_beat_clock parçayı vuruş saatine yeniden konumlar
## (dirilişteki gibi). Devamdan sonraki ilk kayma ölçümü debug günlüğüne yazılır.
##
## Efektler (M3-15, ADR-061): olay → ses eşlemesi SfxBank'te (data/audio/sfx_bank.tres).
## Havuz sabit sayıda çalardır (SfxBank.voices), oyun açılırken kurulur; tur sırasında düğüm
## oluşturulmaz. Boş çalar yoksa bitmesine en az kalan kesilir. Çalarlar SFX yolundadır.
## Final (M4-13): Büyük Depolama Birimi'nde final sesi aynı karedeki sektör sesini susturur.
## Efektler gerçek zamanda çalar: Engine.time_scale'i izlemez (yavaş çekimde ses yavaşlamaz;
## kural yalnızca müziğin vuruş senkronu için, .clauderules §5).
##
## Gerilim (M3-16, ADR-062): çöküş duvarı yaklaştıkça (Events.wall_proximity_changed) Music
## yolundaki alçak geçiren süzgeç kapanır (müzik boğuklaşır) ve döngülü gerilim sesi yükselir;
## değerler TensionMix'te (data/audio/tension_mix.tres). Ses, yakınlığa _process'te kısa bir zaman
## sabitiyle yetişir (yalnızca ses). Yakınlık 0'ken süzgeç kapalı, gerilim sesi durmuş olur
## (işlemci harcanmaz). Tur başında ve ölümde hemen sıfırlanır; ölümden sonraki yakınlık yok
## sayılır.
##
## Menü müziği (M5-10, ADR-096): menüde ve mağazada menü parçası (Liman; tur kataloğunda değil)
## kendi çalarında, Music yolunda çalar; menüye dönünce MENU_FADE_IN_SEC'de açılır. Sonuç ekranı
## sessizdir. Tur başlayınca boşluk ve çakışma olmasın diye geçiş tur parçasının ilk çaldığı anda
## başlar (o ana dek menü parçası sürer): CROSSFADE_SEC boyunca menü parçası kosinüsle söner, tur
## parçası sinüsle açılır; genliklerin kareleri toplamı (toplam güç) hep 1'dir (eşit güçlü geçiş).
## Menü müziği yoksa (yeniden dene, ilk açılış turu) tur parçası doğrudan tam düzeyde başlar.
## Geçişler gerçek zamanla ilerler (Engine.time_scale'den bağımsız), ama bir karede en çok
## MAX_FADE_STEP_SEC kadar: Redmi'de tur başındaki ≈ 400 ms'lik takılmadan sonraki ilk karede geçiş
## bitmiş oluyordu (yumuşak geçiş yerine ani kesme). Takılmada menü parçası sürer, geçiş sonra akar.
## Arayüz sesleri (UI_TAP, PURCHASE) ayrı, duraklatmada da çalan çalarlardadır: duraklatma
## ekranındaki dokunuş ağaç durunca bekleyip devamda çalmasın.
##
## Ölçüm karıştırma tamponu kadar titrer (Android'de onlarca ms). Bu yüzden kayma son karelerin
## ortalamasıyla ölçülür ve sınır aşılırsa ölçüde en fazla bir kez yeniden konumlanır. Her karede
## seek (durdur + çal) yapmak Android'de ses iş parçacığını çökertti (M2-07). Gerçek kayma örneği:
## tur başındaki takılmadan sonra fizik kaçırdığı adımları art arda çalıştırır, oyun saati ileri
## atlar; ses geride kalır (PC'de −121 ms ölçüldü) ve bir ölçü sonra yeniden konumlanır.

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
## Ortalama kayma bu sınırı aşarsa parça yeniden konumlanır (S-03, ilk değer).
const DRIFT_LIMIT: float = 0.04
## Kayma ortalaması için kare sayısı (60 Hz'de 0,25 sn).
const DRIFT_WINDOW: int = 15
## Çalmaya başladıktan ya da yeniden konumlandıktan sonra ölçülmeyen süre (konum otursun).
const SETTLE_TIME: float = 0.5
const BEATS_PER_BAR: int = 4
## Debug günlüğünde senkron raporu aralığı (ölçü).
const REPORT_EVERY_BARS: int = 8
const SFX_BANK: SfxBank = preload("res://data/audio/sfx_bank.tres")
const TENSION_MIX: TensionMix = preload("res://data/audio/tension_mix.tres")
## Duyulan yakınlık hedefe bu kadar yaklaşınca ona eşitlenir (0'a inebilsin).
const TENSION_SNAP: float = 0.001
const USEC_PER_SEC: float = 1000000.0
const MENU_TRACK: MusicTrack = preload("res://data/music/harbor.tres")
## Menü → tur geçişi (sn, gerçek zaman). Kısa tutulur: tur parçasının ilk vuruşu sinüsle açılır.
const CROSSFADE_SEC: float = 0.25
## Menüye dönünce menü parçasının açılma süresi (sn).
const MENU_FADE_IN_SEC: float = 1.5
## Menüden çıkılıp tur başlamadığında (ör. sonuç ekranı) menü parçasının sönme süresi (sn).
const MENU_FADE_OUT_SEC: float = 0.5
## Sessiz sayılan genlik (-80 dB): volume_db'ye -inf yazılmasın.
const SILENT_AMP: float = 0.0001
## Geçişin bir karede ilerleyebileceği en uzun süre (sn): takılmada bile ≥ 8 adım.
const MAX_FADE_STEP_SEC: float = 1.0 / 30.0
## Menü parçasının çaldığı durumlar.
const MENU_MUSIC_STATES: Array[GameTypes.AppState] = [
	GameTypes.AppState.MENU, GameTypes.AppState.SHOP,
]
## Duraklatmada da çalan arayüz sesleri ve çalar sayıları.
const UI_SFX: Array[GameTypes.Sfx] = [GameTypes.Sfx.UI_TAP, GameTypes.Sfx.PURCHASE]
const UI_VOICES: int = 2

## Olay → ses eşlemesi (testler değiştirebilir). Çalar sayısı açılışta bundan kurulur.
var sfx_bank: SfxBank = SFX_BANK
## Gerilim karışımı (testler değiştirebilir).
var tension_mix: TensionMix = TENSION_MIX
## Menü parçası (testler değiştirebilir).
var menu_track: MusicTrack = MENU_TRACK

var _music: AudioStreamPlayer
## Çalan parça (tur başında sıfırlanır; ilk sync_beat_clock kurar).
var _track: MusicTrack = null
## Tur sürüyor mu (run_started → player_died).
var _clock_active: bool = false
## Parça çalmaya başlatıldı mı. play()'den hemen sonra `playing` hâlâ false olabildiği için
## kendi bayrağımız tutulur; yoksa her karede yeniden play() çağrılır.
var _clock_playing: bool = false
var _last_beat_time: float = 0.0
## Son çalma ya da yeniden konumlamanın oyun zamanı; bekleme ve ölçü sınırı buna göre.
var _placed_at: float = 0.0
var _drift_samples: PackedFloat32Array = PackedFloat32Array()
## Son ölçülen ortalama kayma (rapor için).
var _last_drift: float = 0.0
var _resyncs: int = 0
var _max_drift: float = 0.0
var _reported_bar: int = 0
## Devamdan sonraki ilk kayma ölçümü bekleniyor (debug günlüğü).
var _resume_pending: bool = false
var _voices: Array[AudioStreamPlayer] = []
## Her çaların sesinin biteceği gerçek zaman (sn). play()'den hemen sonra `playing` hâlâ false
## olabildiği için doluluk buradan okunur; yoksa aynı karedeki iki efekt aynı çalara düşerdi.
var _voice_ends: PackedFloat64Array = PackedFloat64Array()
var _last_sfx: SfxSound = null
var _sfx_counts: Dictionary[GameTypes.Sfx, int] = {}
## Kombo çarpanı: büyüdüğü kıl payında kombo eşiği sesi çalar.
var _multiplier: int = 1
var _tension: AudioStreamPlayer
## Gerilim sesi çalıyor mu (play()'den hemen sonra `playing` hâlâ false olabilir).
var _tension_on: bool = false
## Gerilim sesi çalarken ulaşılan en büyük yakınlık (debug günlüğü).
var _tension_peak: float = 0.0
var _music_bus: int = -1
## Music yolundaki alçak geçiren süzgeç ve sırası (yol düzeninde yoksa null).
var _lowpass: AudioEffectLowPassFilter = null
var _lowpass_index: int = -1
## Duvarın bildirilen yakınlığı ve sesin ona yetişen değeri.
var _wall_proximity: float = 0.0
var _heard_proximity: float = 0.0
var _menu: AudioStreamPlayer
## Menü parçası çalıyor mu (play()'den hemen sonra `playing` hâlâ false olabilir).
var _menu_on: bool = false
## Süren geçişler (from, to, last, elapsed, length; boşsa geçiş yok) ve o anki genlikler (0–1).
var _menu_fade: Dictionary[StringName, float] = {}
var _run_fade: Dictionary[StringName, float] = {}
var _menu_amp: float = 0.0
var _run_amp: float = 1.0
## Tur başladı, menü parçası çalıyor: tur parçası ilk çaldığında geçiş başlar.
var _crossfade_pending: bool = false
var _ui_voices: Array[AudioStreamPlayer] = []
var _ui_next: int = 0


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	add_child(_music)
	for i: int in sfx_bank.voices:
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
	_voice_ends.resize(_voices.size())
	_tension = AudioStreamPlayer.new()
	_tension.bus = SFX_BUS
	add_child(_tension)
	_menu = AudioStreamPlayer.new()
	_menu.bus = MUSIC_BUS
	add_child(_menu)
	for i: int in UI_VOICES:
		var ui_voice := AudioStreamPlayer.new()
		ui_voice.bus = SFX_BUS
		ui_voice.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(ui_voice)
		_ui_voices.append(ui_voice)
	_find_lowpass()
	Events.run_started.connect(_on_run_started)
	Events.player_died.connect(_on_player_died)
	Events.player_revived.connect(_on_player_revived)
	Events.pause_changed.connect(_on_pause_changed)
	Events.player_flipped.connect(play_sfx.bind(GameTypes.Sfx.FLIP))
	Events.player_landed.connect(play_sfx.bind(GameTypes.Sfx.LAND))
	Events.glimmer_collected.connect(_on_glimmer_collected)
	Events.near_miss.connect(_on_near_miss)
	Events.combo_ended.connect(_on_combo_ended)
	Events.shield_changed.connect(_on_shield_changed)
	Events.sector_entered.connect(_on_sector_entered)
	Events.record_broken.connect(play_sfx.bind(GameTypes.Sfx.RECORD))
	Events.great_storage_reached.connect(_on_great_storage_reached)
	Events.wall_proximity_changed.connect(_on_wall_proximity_changed)
	Events.app_state_changed.connect(_on_app_state_changed)
	Events.item_purchased.connect(func(_cost: int) -> void: play_sfx(GameTypes.Sfx.PURCHASE))


## Gerilim karışımı duvarın yakınlığına yumuşakça yetişir (yalnızca ses).
func _process(delta: float) -> void:
	_update_fades()
	if _heard_proximity == _wall_proximity:
		return
	var smoothing: float = tension_mix.smoothing
	var step: float = 1.0 if smoothing <= 0.0 else 1.0 - exp(-delta / smoothing)
	_heard_proximity = lerpf(_heard_proximity, _wall_proximity, step)
	if absf(_heard_proximity - _wall_proximity) < TENSION_SNAP:
		_heard_proximity = _wall_proximity
	_apply_tension()


## Conductor her fizik adımında çağırır: turun parçasını vuruş saatine hizalar.
func sync_beat_clock(beat_time: float, track: MusicTrack) -> void:
	if not _clock_active or track == null or track.stream == null:
		return
	_music.pitch_scale = Engine.time_scale
	if track != _track:
		_set_track(track)
	var bar: float = BEATS_PER_BAR * track.beat_length()
	if not _clock_playing or beat_time < _last_beat_time:
		_place(beat_time)
	elif beat_time - _placed_at >= SETTLE_TIME:
		_measure_drift(beat_time, bar)
	_last_beat_time = beat_time
	_report(beat_time, bar)


## Olayın sesini havuzdaki boş bir çalarla çalar; boş yoksa bitmesine en az kalanı keser.
func play_sfx(event: GameTypes.Sfx) -> void:
	var sound: SfxSound = sfx_bank.sound_for(event) if sfx_bank != null else null
	if sound == null or sound.stream == null or _voices.is_empty():
		return
	_sfx_counts[event] = _sfx_counts.get(event, 0) + 1
	_last_sfx = sound
	if event in UI_SFX:
		var ui_voice: AudioStreamPlayer = _ui_voices[_ui_next]
		_ui_next = (_ui_next + 1) % _ui_voices.size()
		ui_voice.stream = sound.stream
		ui_voice.volume_db = sound.volume_db
		ui_voice.pitch_scale = 1.0 + randf_range(-sound.pitch_jitter, sound.pitch_jitter)
		ui_voice.play()
		return
	var now: float = Time.get_ticks_usec() / USEC_PER_SEC
	var index: int = _free_voice(now)
	var voice: AudioStreamPlayer = _voices[index]
	voice.stream = sound.stream
	voice.volume_db = sound.volume_db
	# Kozmetik rastgelelik: oynanışı etkilemez, turun RNG'si kullanılmaz (.clauderules §5).
	voice.pitch_scale = 1.0 + randf_range(-sound.pitch_jitter, sound.pitch_jitter)
	voice.play()
	_voice_ends[index] = now + sound.duration(voice.pitch_scale)


## Son çalınan efekt (testler ve debug).
func last_sfx() -> SfxSound:
	return _last_sfx


## Olayın sesinin oyun açıldığından beri kaç kez çaldığı (testler ve debug).
func sfx_count(event: GameTypes.Sfx) -> int:
	return _sfx_counts.get(event, 0)


## Eşit güçlü geçişin genliği: `from`'dan `to`'ya, ilerleme 0–1. Açılış sinüs, sönüş kosinüs
## çeyreğidir; aynı anda biri açılıp öbürü sönerken genliklerin kareleri toplamı sabittir.
func fade_amp(from: float, to: float, progress: float) -> float:
	if progress >= 1.0:
		return to
	var angle: float = maxf(progress, 0.0) * PI * 0.5
	if to >= from:
		return from + (to - from) * sin(angle)
	return to + (from - to) * cos(angle)


## Menü parçasının çaları (testler ve debug).
func menu_player() -> AudioStreamPlayer:
	return _menu


## Menü (x) ve tur (y) parçasının o anki geçiş genliği (0–1; testler ve debug). Menü parçası
## çalmıyorsa x 0'dır.
func music_amps() -> Vector2:
	return Vector2(_menu_amp if _menu_on else 0.0, _run_amp)


## Bir geçiş sürüyor ya da bekliyor mu (testler).
func fading() -> bool:
	return _crossfade_pending or not _menu_fade.is_empty() or not _run_fade.is_empty()


## Süren geçişleri hemen bitirir (testler).
func finish_fades() -> void:
	_update_fades(INF)


## Arayüz seslerinin çalarları (testler).
func ui_voices() -> Array[AudioStreamPlayer]:
	return _ui_voices


## Efekt havuzundaki çalarlar (testler).
func sfx_voices() -> Array[AudioStreamPlayer]:
	return _voices


## Çalan parça (testler ve debug).
func current_track() -> MusicTrack:
	return _track


## Müziğin çalma hızı; Engine.time_scale'i izler (testler ve debug).
func music_pitch() -> float:
	return _music.pitch_scale


## Music yolundaki alçak geçiren süzgeç (testler ve debug).
func music_lowpass() -> AudioEffectLowPassFilter:
	return _lowpass


## Süzgeç açık mı (testler ve debug).
func music_lowpass_enabled() -> bool:
	return _lowpass != null and AudioServer.is_bus_effect_enabled(_music_bus, _lowpass_index)


## Gerilim sesinin çaları (testler ve debug).
func tension_player() -> AudioStreamPlayer:
	return _tension


## Gerilim sesi çalıyor mu (testler ve debug).
func tension_playing() -> bool:
	return _tension_on


## Müzik vuruş saatine bağlı çalıyor mu (testler).
func music_playing() -> bool:
	return _clock_playing


## Parçanın son konumlandığı vuruş saati (testler: devamda yeniden kilitlenme).
func music_placed_at() -> float:
	return _placed_at


## Sesin duvar yakınlığına yetişmiş değeri (testler ve debug).
func heard_proximity() -> float:
	return _heard_proximity


## Boş çalar; hepsi doluysa sesinin bitmesine en az kalan.
func _free_voice(now: float) -> int:
	var best: int = 0
	for i: int in _voices.size():
		if _voice_ends[i] <= now:
			return i
		if _voice_ends[i] < _voice_ends[best]:
			best = i
	return best


## Music yolundaki alçak geçiren süzgeci bulur (sırası yol düzenine bağlı kalmasın).
func _find_lowpass() -> void:
	_music_bus = AudioServer.get_bus_index(MUSIC_BUS)
	if _music_bus < 0:
		return
	for i: int in AudioServer.get_bus_effect_count(_music_bus):
		var effect: AudioEffectLowPassFilter = AudioServer.get_bus_effect(_music_bus, i) \
				as AudioEffectLowPassFilter
		if effect != null:
			_lowpass = effect
			_lowpass_index = i
			return


## Duyulan yakınlığı süzgece ve gerilim sesine uygular.
func _apply_tension() -> void:
	var active: bool = _heard_proximity > 0.0
	if _lowpass != null:
		_lowpass.cutoff_hz = tension_mix.cutoff_at(_heard_proximity)
		AudioServer.set_bus_effect_enabled(_music_bus, _lowpass_index, active)
	if not active or tension_mix.stream == null:
		if _tension_on and OS.is_debug_build():
			print("AUDIO tension off peak=%.2f cutoff=%d Hz volume=%.1f dB" % [
				_tension_peak, roundi(tension_mix.cutoff_at(_tension_peak)),
				tension_mix.volume_at(_tension_peak),
			])
		_tension.stop()
		_tension_on = false
		return
	_tension.volume_db = tension_mix.volume_at(_heard_proximity)
	_tension.pitch_scale = tension_mix.pitch_at(_heard_proximity)
	_tension_peak = maxf(_tension_peak, _heard_proximity)
	if not _tension_on:
		_tension.stream = tension_mix.stream
		_tension.play()
		_tension_on = true
		_tension_peak = _heard_proximity
		if OS.is_debug_build():
			print("AUDIO tension on")


## Gerilimi hemen sıfırlar (tur başı, ölüm).
func _reset_tension() -> void:
	_wall_proximity = 0.0
	_heard_proximity = 0.0
	_apply_tension()


## Parçayı çalara koyar; döngü dosyanın loop_start anından başlar.
func _set_track(track: MusicTrack) -> void:
	_track = track
	_music.stop()
	var ogg: AudioStreamOggVorbis = track.stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
		ogg.loop_offset = track.loop_start
	_music.stream = track.stream
	_apply_run_volume()
	_clock_playing = false
	if OS.is_debug_build():
		print("AUDIO music=%s bpm=%s loop_start=%.2f length=%.2f" % [
			track.id, String.num(track.bpm), track.loop_start, track.length(),
		])


## Parçayı, duyulan konumu vuruş saatine denk gelecek yerden çalar.
func _place(beat_time: float) -> void:
	var latency: float = AudioServer.get_output_latency() * Engine.time_scale
	_music.play(_track.position_at(beat_time + latency))
	_clock_playing = true
	if _crossfade_pending:
		# Tur parçası şimdi başlıyor: menü parçası tam bu anda sönmeye başlar (boşluk yok).
		_crossfade_pending = false
		_start_fade(_menu_fade, _menu_amp, 0.0, CROSSFADE_SEC)
		_start_fade(_run_fade, 0.0, 1.0, CROSSFADE_SEC)
		if OS.is_debug_build():
			print("AUDIO crossfade start menu_amp=%.2f" % _menu_amp)
	_placed_at = beat_time
	_drift_samples.clear()


## Kaymayı pencere ortalamasıyla ölçer; sınır aşılırsa (ölçüde en fazla bir kez) yeniden konumlar.
func _measure_drift(beat_time: float, bar: float) -> void:
	var latency: float = AudioServer.get_output_latency() * Engine.time_scale
	var heard: float = _music.get_playback_position() \
			+ AudioServer.get_time_since_last_mix() * Engine.time_scale - latency
	var drift: float = heard - _track.position_at(beat_time)
	# Döngü dikişinin iki yanındaki ölçüm bir döngü boyu farklı görünür.
	var loop_length: float = _track.length() - _track.loop_start
	if loop_length > 0.0:
		drift = wrapf(drift, -loop_length * 0.5, loop_length * 0.5)
	_drift_samples.append(drift)
	if _drift_samples.size() < DRIFT_WINDOW:
		return
	var average: float = 0.0
	for sample: float in _drift_samples:
		average += sample
	average /= _drift_samples.size()
	_drift_samples.clear()
	_last_drift = average
	if _resume_pending:
		_resume_pending = false
		if OS.is_debug_build():
			print("AUDIO resume drift=%d ms" % roundi(average * 1000.0))
	_max_drift = maxf(_max_drift, absf(average))
	# Turun ilk düzeltmesi hemen (başlangıç takılması), sonrakiler ölçüde en fazla bir kez.
	if absf(average) > DRIFT_LIMIT and (_resyncs == 0 or beat_time - _placed_at >= bar):
		_resyncs += 1
		if OS.is_debug_build():
			print("AUDIO resync drift=%d ms" % roundi(average * 1000.0))
		_place(beat_time)


func _on_run_started(_run_seed: int, _start_sector: int) -> void:
	_clock_active = true
	_clock_playing = false
	_track = null
	_last_beat_time = 0.0
	_resyncs = 0
	_max_drift = 0.0
	_reported_bar = 0
	_multiplier = 1
	_music.stop()
	_reset_tension()
	_run_fade.clear()
	_crossfade_pending = _menu_on
	_run_amp = 0.0 if _crossfade_pending else 1.0
	if OS.is_debug_build():
		print("AUDIO output_latency=%d ms mix_rate=%d" % [
			roundi(AudioServer.get_output_latency() * 1000.0), roundi(AudioServer.get_mix_rate()),
		])


func _on_player_died(_cause: GameTypes.DeathCause) -> void:
	_clock_active = false
	_clock_playing = false
	_music.stop()
	_run_fade.clear()
	_run_amp = 1.0
	if _crossfade_pending:
		_crossfade_pending = false
		_start_fade(_menu_fade, _menu_amp, 0.0, MENU_FADE_OUT_SEC)
	_reset_tension()
	play_sfx(GameTypes.Sfx.DEATH)


## Diriliş: saat yeniden açılır; ilk sync_beat_clock parçayı vuruş saatine konumlar.
func _on_player_revived() -> void:
	_clock_active = true
	_clock_playing = false


## Menü ve mağazada menü parçası açılır (çalıyorsa sürer); tur dışındaki öbür durumlarda söner.
## Tur başlarken söndürmez: geçişi tur parçasının ilk çaldığı an başlatır (_place).
func _on_app_state_changed(state: GameTypes.AppState) -> void:
	if state in MENU_MUSIC_STATES:
		if not _menu_on:
			_menu.stream = menu_track.stream
			var ogg: AudioStreamOggVorbis = menu_track.stream as AudioStreamOggVorbis
			if ogg != null:
				ogg.loop = true
				ogg.loop_offset = menu_track.loop_start
			_menu_amp = 0.0
			_apply_menu_volume()
			_menu.play()
			_menu_on = true
			if OS.is_debug_build():
				print("AUDIO menu music start")
		_crossfade_pending = false
		if _menu_amp < 1.0 or not _menu_fade.is_empty():
			_start_fade(_menu_fade, _menu_amp, 1.0, MENU_FADE_IN_SEC * (1.0 - _menu_amp))
	elif state != GameTypes.AppState.RUNNING and _menu_on and not _crossfade_pending:
		_start_fade(_menu_fade, _menu_amp, 0.0, MENU_FADE_OUT_SEC)


func _start_fade(fade: Dictionary[StringName, float], from: float, to: float,
		seconds: float) -> void:
	fade[&"from"] = from
	fade[&"to"] = to
	fade[&"last"] = Time.get_ticks_usec() / USEC_PER_SEC
	fade[&"elapsed"] = 0.0
	fade[&"length"] = seconds


## Süren geçişleri gerçek zamanla ilerletir; `now` verilirse o ana göre (INF: bitir).
func _update_fades(now: float = -1.0) -> void:
	if now < 0.0:
		now = Time.get_ticks_usec() / USEC_PER_SEC
	if not _menu_fade.is_empty():
		_menu_amp = _fade_step(_menu_fade, now)
		_apply_menu_volume()
		if _menu_fade.is_empty() and _menu_amp <= SILENT_AMP:
			_menu.stop()
			_menu_on = false
	if not _run_fade.is_empty():
		_run_amp = _fade_step(_run_fade, now)
		_apply_run_volume()
		if OS.is_debug_build() and _music_bus >= 0:
			# Telefonda ölçü: geçiş boyunca Music yolunun tepe düzeyi (boşluk ya da çakışma).
			print("AUDIO xfade menu=%.3f run=%.3f bus_peak=%.1f dB" % [_menu_amp, _run_amp,
					AudioServer.get_bus_peak_volume_left_db(_music_bus, 0)])


## Geçişin `now`'daki genliği; geçiş bittiyse sözlüğü boşaltır.
func _fade_step(fade: Dictionary[StringName, float], now: float) -> float:
	var length: float = fade[&"length"]
	if is_inf(now):
		fade[&"elapsed"] = length
	else:
		fade[&"elapsed"] += clampf(now - fade[&"last"], 0.0, MAX_FADE_STEP_SEC)
		fade[&"last"] = now
	var progress: float = 1.0 if length <= 0.0 else fade[&"elapsed"] / length
	var amp: float = fade_amp(fade[&"from"], fade[&"to"], progress)
	if progress >= 1.0:
		fade.clear()
	return amp


func _apply_menu_volume() -> void:
	_menu.volume_db = menu_track.volume_db + linear_to_db(maxf(_menu_amp, SILENT_AMP))


func _apply_run_volume() -> void:
	if _track != null:
		_music.volume_db = _track.volume_db + linear_to_db(maxf(_run_amp, SILENT_AMP))


## Duraklayınca parça durur; devamda ilk sync_beat_clock vuruş saatine yeniden konumlar.
func _on_pause_changed(paused: bool) -> void:
	if not _clock_active:
		return
	if paused:
		_music.stop()
		_clock_playing = false
		if OS.is_debug_build():
			# Telefonda ölçü: duraklamadan biraz sonra müzik yolu gerçekten sessiz mi.
			get_tree().create_timer(SETTLE_TIME, true).timeout.connect(_log_paused_peak)
	else:
		_resume_pending = true


func _log_paused_peak() -> void:
	print("AUDIO paused music peak=%.1f dB" % AudioServer.get_bus_peak_volume_left_db(
			_music_bus, 0))


## Yalnızca tur sürerken: ölümden sonra kamera sarsılırken bildirilen yakınlık gerilimi açmasın.
func _on_wall_proximity_changed(ratio: float) -> void:
	if _clock_active:
		_wall_proximity = clampf(ratio, 0.0, 1.0)


func _on_glimmer_collected(_value: int) -> void:
	play_sfx(GameTypes.Sfx.GLIMMER)


## Her kıl payında kıl payı sesi; çarpan büyüdüyse üstüne kombo eşiği sesi.
func _on_near_miss(_combo: int, multiplier: int) -> void:
	play_sfx(GameTypes.Sfx.NEAR_MISS)
	if multiplier > _multiplier:
		play_sfx(GameTypes.Sfx.COMBO_UP)
	_multiplier = multiplier


func _on_combo_ended() -> void:
	_multiplier = 1


## Kalkan yalnızca tükenince kapanır (Shield.consume): kapanış kırılmadır.
func _on_shield_changed(active: bool) -> void:
	if not active:
		play_sfx(GameTypes.Sfx.SHIELD_BREAK)


func _on_sector_entered(_index: int) -> void:
	play_sfx(GameTypes.Sfx.SECTOR)


## Final sesi, aynı karede başlayan sektör sesinin yerini alır (iki büyük an üst üste binmesin).
func _on_great_storage_reached() -> void:
	_stop_sfx(GameTypes.Sfx.SECTOR)
	play_sfx(GameTypes.Sfx.FINALE)


## Olayın sesini çalan çalarları susturur ve boşaltır.
func _stop_sfx(event: GameTypes.Sfx) -> void:
	var sound: SfxSound = sfx_bank.sound_for(event) if sfx_bank != null else null
	if sound == null:
		return
	for i: int in _voices.size():
		if _voices[i].stream == sound.stream:
			_voices[i].stop()
			_voices[i].stream = null
			_voice_ends[i] = 0.0


## Debug build'de birkaç ölçüde bir senkron raporu (S-03 ölçümü).
func _report(beat_time: float, bar: float) -> void:
	if not OS.is_debug_build():
		return
	var bar_index: int = floori(beat_time / bar)
	if bar_index < _reported_bar + REPORT_EVERY_BARS:
		return
	_reported_bar = bar_index
	print(("AUDIO sync bar=%d drift=%d ms max_drift=%d ms resyncs=%d latency=%d ms "
			+ "tension=%.2f lowpass=%s cutoff=%d Hz") % [
		bar_index, roundi(_last_drift * 1000.0), roundi(_max_drift * 1000.0), _resyncs,
		roundi(AudioServer.get_output_latency() * 1000.0), _heard_proximity,
		music_lowpass_enabled(), roundi(_lowpass.cutoff_hz) if _lowpass != null else 0,
	])
	_max_drift = 0.0
