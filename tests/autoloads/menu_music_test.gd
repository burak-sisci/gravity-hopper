extends GdUnitTestSuite
## Menü müziği ve arayüz sesleri (M5-10, GDD §19, architecture.md §8.3): menüde ve mağazada menü
## parçası çalar, menüden çıkınca söner. Tur başlarken boşluk ve çakışma yok: menü parçası tur
## parçası gerçekten çalana dek tam düzeyde sürer; sonra eşit güçlü geçişle (toplam güç sabit)
## yer değiştirirler. Menü müziği yoksa tur parçası tam düzeyde başlar. Düğmeler dokunuş, satın
## almalar satın alma sesi çalar; arayüz sesleri duraklatmada da çalan çalarlardadır.
## Ses düzeyleri (menü parçası ±1 LU, ≤ -1 dBTP; efekt katmanları) tools/audio_check.py'de.

const MUSIC: MusicCatalog = preload("res://data/music/music_catalog.tres")
## Geçişte toplam gücün 0 dB'den en büyük sapması (dB). Eşit güçlü eğride kuramsal sapma 0'dır;
## doğrusal geçişte ortada -3 dB çukur (boşluk), tur parçası doğrudan tam açılırsa +3 dB tümsek
## (çakışma) olur. ±0,5 dB bu ikisini ayırır ve kayan nokta payını karşılar.
const MAX_POWER_DEVIATION_DB: float = 0.5
## Eğrinin örneklendiği adım sayısı.
const CURVE_STEPS: int = 1000
## Geçişin gerçek zamanlı ölçümünde en az bu kadar örnek alınır.
const MIN_FADE_SAMPLES: int = 3
## Geçiş en geç bu sürede biter (sn; CROSSFADE_SEC 0,25).
const FADE_TIMEOUT_SEC: float = 2.0
## Örnekler arası gerçek bekleme (ms). Geçiş gerçek zamanla ilerler, ekransız kareler ise çok hızlı
## akar: beklenmezse gdUnit'in oyun zamanıyla saydığı süre sınırı geçiş bitmeden dolar.
const SAMPLE_MSEC: int = 10
## Redmi'de tur başında ölçülen takılma (ms): geçiş başladıktan sonra kare gelmedi.
const HITCH_MSEC: int = 400
## Bir örnekte tur parçası genliğinin en büyük sıçraması. Kare başına 1/30 sn sınırıyla sinüs
## eğrisinde en büyük adım ≈ 0,21; sınır olmasa takılmadan sonra 0 → 1 (ani kesme).
const MAX_AMP_JUMP: float = 0.25


func after_test() -> void:
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	Events.app_state_changed.emit(GameTypes.AppState.BOOT)
	AudioManager.finish_fades()
	GameManager.reset()


## Eşit güç: biri sönerken öbürü açılırken genliklerin kareleri toplamı her an 1 (0 dB).
func test_crossfade_curve_keeps_total_power() -> void:
	var worst: float = 0.0
	for step: int in CURVE_STEPS + 1:
		var progress: float = float(step) / CURVE_STEPS
		var out: float = AudioManager.fade_amp(1.0, 0.0, progress)
		var into: float = AudioManager.fade_amp(0.0, 1.0, progress)
		worst = maxf(worst, absf(_power_db(Vector2(out, into))))
	assert_float(worst).is_less_equal(MAX_POWER_DEVIATION_DB)
	assert_float(AudioManager.fade_amp(1.0, 0.0, 1.0)).is_equal(0.0)
	assert_float(AudioManager.fade_amp(0.0, 1.0, 1.0)).is_equal(1.0)


## Menüde menü parçası sessizden açılır; mağazaya geçişte yeniden başlamadan sürer; sonuç ekranı
## gibi öbür durumlarda söner ve durur.
func test_menu_and_shop_play_the_menu_track() -> void:
	assert_bool(GameManager.change_state(GameTypes.AppState.MENU)).is_true()
	var player: AudioStreamPlayer = AudioManager.menu_player()
	assert_object(player.stream).is_same(AudioManager.MENU_TRACK.stream)
	assert_bool(player.playing).is_true()
	assert_bool(AudioManager.fading()).is_true()
	AudioManager.finish_fades()
	assert_float(AudioManager.music_amps().x).is_equal(1.0)
	assert_float(player.volume_db).is_equal_approx(AudioManager.MENU_TRACK.volume_db, 0.01)
	assert_bool(GameManager.change_state(GameTypes.AppState.SHOP)).is_true()
	assert_bool(AudioManager.fading()).is_false()
	assert_float(AudioManager.music_amps().x).is_equal(1.0)
	Events.app_state_changed.emit(GameTypes.AppState.RESULTS)
	assert_bool(AudioManager.fading()).is_true()
	AudioManager.finish_fades()
	assert_float(AudioManager.music_amps().x).is_equal(0.0)
	assert_bool(player.playing).is_false()


## Menüden tura: tur parçası çalana dek menü parçası tam düzeyde (boşluk yok); sonra gerçek
## zamanda her karede ölçülen toplam güç 0 dB'de kalır (çakışma da boşluk da yok) ve genlik
## çalara gerçekten yazılır; telefondaki tur başı takılmasından (HITCH_MSEC) sonra da geçiş
## adım adım akar (ani kesme yok); geçiş bitince menü parçası durmuş, tur parçası kendi düzeyinde.
func test_run_start_crossfades_without_gap_or_clash() -> void:
	var track: MusicTrack = MUSIC.tracks[0]
	assert_bool(GameManager.change_state(GameTypes.AppState.MENU)).is_true()
	AudioManager.finish_fades()
	assert_bool(GameManager.change_state(GameTypes.AppState.RUNNING)).is_true()
	Events.run_started.emit(1, 1)
	await get_tree().process_frame
	assert_float(AudioManager.music_amps().x).is_equal(1.0)
	assert_bool(AudioManager.menu_player().playing).is_true()
	AudioManager.sync_beat_clock(0.0, track)
	OS.delay_msec(HITCH_MSEC)
	var started: int = Time.get_ticks_msec()
	var samples: int = 0
	var worst_power: float = 0.0
	var worst_jump: float = 0.0
	var last_run: float = AudioManager.music_amps().y
	var worst_written: float = 0.0
	while AudioManager.fading() and Time.get_ticks_msec() - started < FADE_TIMEOUT_SEC * 1000.0:
		OS.delay_msec(SAMPLE_MSEC)
		await get_tree().process_frame
		var amps: Vector2 = AudioManager.music_amps()
		samples += 1
		worst_jump = maxf(worst_jump, absf(amps.y - last_run))
		last_run = amps.y
		var power: float = _power_db(amps)
		if absf(power) > absf(worst_power):
			worst_power = power
		if amps.x > 0.0:
			var written: float = db_to_linear(AudioManager.menu_player().volume_db
					- AudioManager.MENU_TRACK.volume_db)
			worst_written = maxf(worst_written, absf(written - amps.x))
	assert_bool(AudioManager.fading()).override_failure_message("geçiş bitmedi").is_false()
	assert_int(samples).is_greater_equal(MIN_FADE_SAMPLES)
	assert_float(absf(worst_power)).override_failure_message("toplam güç %.2f dB (%d örnek)" % [
		worst_power, samples]).is_less_equal(MAX_POWER_DEVIATION_DB)
	assert_float(worst_written).is_less_equal(0.001)
	assert_float(worst_jump).override_failure_message("takılmadan sonra ani kesme: %.2f" % [
		worst_jump]).is_less_equal(MAX_AMP_JUMP)
	assert_bool(AudioManager.menu_player().playing).is_false()
	assert_float(AudioManager.music_amps().y).is_equal(1.0)


## Menü müziği çalmıyorken (yeniden dene, ilk açılış turu) tur parçası tam düzeyde başlar.
func test_run_without_menu_music_starts_at_full_level() -> void:
	Events.run_started.emit(1, 1)
	AudioManager.sync_beat_clock(0.0, MUSIC.tracks[0])
	assert_bool(AudioManager.fading()).is_false()
	assert_vector(AudioManager.music_amps()).is_equal(Vector2(0.0, 1.0))


## Tur parçası çalmadan oyuncu ölürse menü parçası asılı kalmaz: söner.
func test_death_before_the_run_track_fades_the_menu_out() -> void:
	assert_bool(GameManager.change_state(GameTypes.AppState.MENU)).is_true()
	AudioManager.finish_fades()
	Events.run_started.emit(1, 1)
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_bool(AudioManager.fading()).is_true()
	AudioManager.finish_fades()
	assert_float(AudioManager.music_amps().x).is_equal(0.0)


## Neon düğme dokunuş sesi çalar (kapatılabilir); yükseltme ve iz satın alma, satın alma sesi.
## Arayüz sesleri duraklatmada da çalan ayrı çalarlarda çalar (efekt havuzu ağaçla bekler).
func test_buttons_and_purchases_play_ui_sounds() -> void:
	var button: NeonButton = auto_free(NeonButton.new()) as NeonButton
	add_child(button)
	var taps: int = AudioManager.sfx_count(GameTypes.Sfx.UI_TAP)
	button.pressed.emit()
	assert_int(AudioManager.sfx_count(GameTypes.Sfx.UI_TAP)).is_equal(taps + 1)
	button.click_sound = false
	button.pressed.emit()
	assert_int(AudioManager.sfx_count(GameTypes.Sfx.UI_TAP)).is_equal(taps + 1)
	var tap_stream: AudioStream = AudioManager.sfx_bank.sound_for(GameTypes.Sfx.UI_TAP).stream
	assert_bool(AudioManager.ui_voices().any(func(voice: AudioStreamPlayer) -> bool:
		return voice.stream == tap_stream)).is_true()
	for voice: AudioStreamPlayer in AudioManager.ui_voices():
		assert_int(voice.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	for voice: AudioStreamPlayer in AudioManager.sfx_voices():
		assert_bool(voice.stream == tap_stream).is_false()
	Progression.reset()
	var purchases: int = AudioManager.sfx_count(GameTypes.Sfx.PURCHASE)
	var upgrade: StringName = Progression.UPGRADES.ids()[0]
	Progression.glimmers = Progression.upgrade_cost(upgrade)
	assert_bool(Progression.buy_upgrade(upgrade)).is_true()
	assert_int(AudioManager.sfx_count(GameTypes.Sfx.PURCHASE)).is_equal(purchases + 1)
	Progression.reset()


func _power_db(amps: Vector2) -> float:
	return 10.0 * log(maxf(amps.length_squared(), 1e-12)) / log(10.0)
