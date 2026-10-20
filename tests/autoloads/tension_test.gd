extends GdUnitTestSuite
## Gerilim (M3-16, architecture.md §8.8): çöküş duvarı yaklaştıkça müzik boğuklaşır (Music
## yolundaki alçak geçiren süzgeç) ve döngülü gerilim sesi yükselir. Ses yakınlığa yumuşakça
## yetişir; duvar ekranda değilken süzgeç kapalı ve ses durmuş olur; tur başı ve ölüm hemen
## sıfırlar, ölümden sonraki yakınlık yok sayılır.

## Yumuşak geçişin oturması için beklenen kare (0,15 sn'lik zaman sabitinin 10 katı).
const SETTLE_FRAMES: int = 90
const HZ_TOLERANCE: float = 0.01
const DB_TOLERANCE: float = 0.01

var _mix: TensionMix = AudioManager.TENSION_MIX


func before_test() -> void:
	Events.run_started.emit(1, 1)


func after_test() -> void:
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)


func test_mix_is_open_far_and_muffled_near() -> void:
	assert_float(_mix.cutoff_at(0.0)).is_equal_approx(_mix.open_hz, HZ_TOLERANCE)
	assert_float(_mix.cutoff_at(1.0)).is_equal_approx(_mix.closed_hz, HZ_TOLERANCE)
	assert_float(_mix.volume_at(0.0)).is_equal(TensionMix.SILENT_DB)
	assert_float(_mix.volume_at(1.0)).is_equal_approx(_mix.volume_db, DB_TOLERANCE)
	var cutoff: float = _mix.cutoff_at(0.0)
	var volume: float = _mix.volume_at(0.0)
	var pitch: float = _mix.pitch_at(0.0)
	for i: int in range(1, 11):
		var proximity: float = i / 10.0
		assert_float(_mix.cutoff_at(proximity)).is_less(cutoff)
		assert_float(_mix.volume_at(proximity)).is_greater(volume)
		assert_float(_mix.pitch_at(proximity)).is_greater(pitch)
		cutoff = _mix.cutoff_at(proximity)
		volume = _mix.volume_at(proximity)
		pitch = _mix.pitch_at(proximity)


func test_tension_sound_loops_and_is_credited() -> void:
	var ogg: AudioStreamOggVorbis = _mix.stream as AudioStreamOggVorbis
	assert_object(ogg).is_not_null()
	assert_bool(ogg.loop).is_true()
	assert_str(ogg.resource_path).is_equal("res://assets/audio/sfx/tension.ogg")
	for field: String in [_mix.title, _mix.author, _mix.license, _mix.source_url]:
		assert_str(field).is_not_empty()


func test_filter_and_sound_follow_the_wall() -> void:
	assert_object(AudioManager.music_lowpass()).is_not_null()
	assert_bool(AudioManager.music_lowpass_enabled()).is_false()
	assert_bool(AudioManager.tension_playing()).is_false()
	Events.wall_proximity_changed.emit(0.5)
	await _frames(SETTLE_FRAMES)
	assert_float(AudioManager.heard_proximity()).is_equal(0.5)
	assert_bool(AudioManager.music_lowpass_enabled()).is_true()
	var half: float = AudioManager.music_lowpass().cutoff_hz
	assert_float(half).is_equal_approx(_mix.cutoff_at(0.5), HZ_TOLERANCE)
	assert_bool(AudioManager.tension_playing()).is_true()
	var player: AudioStreamPlayer = AudioManager.tension_player()
	assert_str(String(player.bus)).is_equal(String(AudioManager.SFX_BUS))
	var quiet: float = player.volume_db
	var low: float = player.pitch_scale
	Events.wall_proximity_changed.emit(0.9)
	await _frames(SETTLE_FRAMES)
	assert_float(AudioManager.music_lowpass().cutoff_hz).is_less(half)
	assert_float(player.volume_db).is_greater(quiet)
	assert_float(player.pitch_scale).is_greater(low)
	# Duvar ekrandan çıkınca süzgeç kapanır, ses durur (işlemci harcanmaz).
	Events.wall_proximity_changed.emit(0.0)
	await _frames(SETTLE_FRAMES)
	assert_float(AudioManager.heard_proximity()).is_equal(0.0)
	assert_bool(AudioManager.music_lowpass_enabled()).is_false()
	assert_bool(AudioManager.tension_playing()).is_false()


## Duvar birden yaklaşınca (kalkan kırılması) ses sıçramaz, kısa sürede yetişir.
func test_mix_catches_up_smoothly() -> void:
	Events.wall_proximity_changed.emit(1.0)
	await _frames(1)
	var heard: float = AudioManager.heard_proximity()
	assert_float(heard).is_greater(0.0)
	assert_float(heard).is_less(0.5)
	assert_float(AudioManager.music_lowpass().cutoff_hz).is_greater(_mix.closed_hz)
	await _frames(SETTLE_FRAMES)
	assert_float(AudioManager.heard_proximity()).is_equal(1.0)
	assert_float(AudioManager.music_lowpass().cutoff_hz).is_equal_approx(
			_mix.closed_hz, HZ_TOLERANCE)


func test_death_and_run_start_reset_at_once() -> void:
	Events.wall_proximity_changed.emit(0.8)
	await _frames(SETTLE_FRAMES)
	assert_bool(AudioManager.tension_playing()).is_true()
	# Ölüm sesinin altında gerilim kalmaz; müzik boğuk kalmaz.
	Events.player_died.emit(GameTypes.DeathCause.WALL)
	assert_bool(AudioManager.tension_playing()).is_false()
	assert_bool(AudioManager.music_lowpass_enabled()).is_false()
	# Ölümden sonra (kamera sarsılırken) bildirilen yakınlık gerilimi açmaz.
	Events.wall_proximity_changed.emit(0.9)
	await _frames(SETTLE_FRAMES)
	assert_float(AudioManager.heard_proximity()).is_equal(0.0)
	assert_bool(AudioManager.tension_playing()).is_false()
	Events.run_started.emit(2, 1)
	Events.wall_proximity_changed.emit(0.6)
	await _frames(SETTLE_FRAMES)
	assert_bool(AudioManager.tension_playing()).is_true()
	# Tur yarıda yeniden başlarsa da sıfırlanır.
	Events.run_started.emit(3, 1)
	assert_float(AudioManager.heard_proximity()).is_equal(0.0)
	assert_bool(AudioManager.tension_playing()).is_false()
	assert_bool(AudioManager.music_lowpass_enabled()).is_false()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
