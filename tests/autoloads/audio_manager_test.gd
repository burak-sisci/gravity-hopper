extends GdUnitTestSuite
## Müzik çalma (M2-20, architecture.md §8.3): tur başlayınca vuruş saatinin bildirdiği parça
## çalara konur ve döngüsü loop_start'tan kurulur; oyuncu ölünce durur, yeni turda yeniden kurulur;
## dirilişte kaldığı yerden sürer (M4-07).

const MUSIC: MusicCatalog = preload("res://data/music/music_catalog.tres")


func after_test() -> void:
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	Engine.time_scale = 1.0


func test_run_plays_the_reported_track_with_its_loop() -> void:
	var track: MusicTrack = _track(&"castle")
	Events.run_started.emit(1, 1)
	AudioManager.sync_beat_clock(0.0, track)
	assert_object(AudioManager.current_track()).is_same(track)
	var ogg: AudioStreamOggVorbis = track.stream as AudioStreamOggVorbis
	assert_bool(ogg.loop).is_true()
	assert_float(ogg.loop_offset).is_equal(track.loop_start)


func test_new_run_sets_the_track_again_and_death_silences() -> void:
	Events.run_started.emit(1, 1)
	AudioManager.sync_beat_clock(0.0, _track(&"pagoda"))
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	# Ölümden sonra bildirilen saat yok sayılır.
	AudioManager.sync_beat_clock(1.0, _track(&"caravan"))
	assert_str(String(AudioManager.current_track().id)).is_equal("pagoda")
	Events.run_started.emit(2, 1)
	assert_object(AudioManager.current_track()).is_null()
	AudioManager.sync_beat_clock(0.0, _track(&"caravan"))
	assert_str(String(AudioManager.current_track().id)).is_equal("caravan")


## Dirilişte (M4-07) müzik aynı parçayla, vuruş saatinden yeniden çalar; ölümde susar.
func test_revive_resumes_the_music_from_the_beat_clock() -> void:
	var track: MusicTrack = _track(&"castle")
	Events.run_started.emit(1, 1)
	AudioManager.sync_beat_clock(0.0, track)
	assert_bool(AudioManager.music_playing()).is_true()
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	assert_bool(AudioManager.music_playing()).is_false()
	AudioManager.sync_beat_clock(2.0, track)
	assert_bool(AudioManager.music_playing()).is_false()
	Events.player_revived.emit()
	AudioManager.sync_beat_clock(2.0, track)
	assert_bool(AudioManager.music_playing()).is_true()
	assert_object(AudioManager.current_track()).is_same(track)


## Yavaş çekimde müzik aynı oranda yavaşlar (M3-12, ADR-008).
func test_music_pitch_follows_time_scale() -> void:
	var track: MusicTrack = _track(&"castle")
	Events.run_started.emit(1, 1)
	AudioManager.sync_beat_clock(0.0, track)
	assert_float(AudioManager.music_pitch()).is_equal(1.0)
	Engine.time_scale = 0.5
	AudioManager.sync_beat_clock(0.1, track)
	assert_float(AudioManager.music_pitch()).is_equal(0.5)
	Engine.time_scale = 1.0
	AudioManager.sync_beat_clock(0.2, track)
	assert_float(AudioManager.music_pitch()).is_equal(1.0)


func _track(id: StringName) -> MusicTrack:
	for track: MusicTrack in MUSIC.tracks:
		if track.id == id:
			return track
	return null
