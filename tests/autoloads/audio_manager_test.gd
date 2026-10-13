extends GdUnitTestSuite
## Müzik çalma (M2-20, architecture.md §8.3): tur başlayınca vuruş saatinin bildirdiği parça
## çalara konur ve döngüsü loop_start'tan kurulur; oyuncu ölünce durur, yeni turda yeniden kurulur.

const MUSIC: MusicCatalog = preload("res://data/music/music_catalog.tres")


func after_test() -> void:
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)


func test_run_plays_the_reported_track_with_its_loop() -> void:
	var track: MusicTrack = _track(&"epic_departure")
	Events.run_started.emit(1, 1)
	AudioManager.sync_beat_clock(0.0, track)
	assert_object(AudioManager.current_track()).is_same(track)
	var ogg: AudioStreamOggVorbis = track.stream as AudioStreamOggVorbis
	assert_bool(ogg.loop).is_true()
	assert_float(ogg.loop_offset).is_equal(track.loop_start)


func test_new_run_sets_the_track_again_and_death_silences() -> void:
	Events.run_started.emit(1, 1)
	AudioManager.sync_beat_clock(0.0, _track(&"treasure_hunter"))
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)
	# Ölümden sonra bildirilen saat yok sayılır.
	AudioManager.sync_beat_clock(1.0, _track(&"mountain_peak"))
	assert_str(String(AudioManager.current_track().id)).is_equal("treasure_hunter")
	Events.run_started.emit(2, 1)
	assert_object(AudioManager.current_track()).is_null()
	AudioManager.sync_beat_clock(0.0, _track(&"mountain_peak"))
	assert_str(String(AudioManager.current_track().id)).is_equal("mountain_peak")


func _track(id: StringName) -> MusicTrack:
	for track: MusicTrack in MUSIC.tracks:
		if track.id == id:
			return track
	return null
