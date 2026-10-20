extends GdUnitTestSuite
## Müzik kataloğu (M2-20, ADR-040; M3-21, ADR-065): üç özgün parça, her biri ilk vuruşla
## başlıyor ve tam ölçülük döngüyle bitiyor (vuruş ızgarası döngüde kaymaz), atıf bilgisi tam,
## lisans kurala uygun ve her parçanın bestesi (kaynak betiği) depoda.
## Seçim yalnızca tohumdan gelir ve bütün parçalar seçilebilir.

const MUSIC: MusicCatalog = preload("res://data/music/music_catalog.tres")
const BEATS_PER_BAR: int = 4
## Ses dosyası süresinin tam vuruş katından en çok sapması (sn).
const TIME_TOLERANCE: float = 0.002
## .clauderules §7: ses için yalnızca CC0 ve CC-BY; "Original" projenin kendi bestesi (ADR-065).
const ALLOWED_LICENSES: Array[String] = ["Original", "CC0 1.0", "CC-BY 4.0", "CC-BY 3.0"]
## Özgün parçaların bestesi: tools/music/tracks/<id>.py (çalgı kayıtları CC0, CREDITS.md).
const SCORE_DIR: String = "tools/music/tracks/"


func test_catalog_has_the_chosen_tracks() -> void:
	var ids: Array[String] = []
	for track: MusicTrack in MUSIC.tracks:
		ids.append(String(track.id))
	assert_array(ids).contains_exactly_in_any_order(["caravan", "pagoda", "castle"])
	assert_array(MUSIC.tempos()).is_equal([90.0, 100.0, 120.0])
	assert_float(MUSIC.max_bpm()).is_equal(120.0)


func test_every_track_keeps_the_beat_grid() -> void:
	for track: MusicTrack in MUSIC.tracks:
		var label: String = String(track.id)
		assert_object(track.stream).override_failure_message(label).is_instanceof(
				AudioStreamOggVorbis)
		assert_float(track.bpm).override_failure_message(label).is_between(70.0, 130.0)
		var beat: float = track.beat_length()
		var length_beats: float = track.length() / beat
		var loop_beats: float = (track.length() - track.loop_start) / beat
		assert_float(absf(length_beats - roundf(length_beats)) * beat).override_failure_message(
				"%s: süre tam vuruş değil (%.3f vuruş)" % [label, length_beats]).is_less(
				TIME_TOLERANCE)
		assert_float(track.loop_start / beat).override_failure_message(label).is_equal_approx(
				roundf(track.loop_start / beat), 0.0001)
		assert_int(roundi(loop_beats) % BEATS_PER_BAR).override_failure_message(
				"%s: döngü tam ölçü değil (%.2f vuruş)" % [label, loop_beats]).is_equal(0)
		assert_float(track.volume_db).override_failure_message(label).is_between(-12.0, 0.0)


func test_every_track_is_credited() -> void:
	for track: MusicTrack in MUSIC.tracks:
		var label: String = String(track.id)
		assert_str(track.title).override_failure_message(label).is_not_empty()
		assert_str(track.author).override_failure_message(label).is_not_empty()
		assert_array(ALLOWED_LICENSES).override_failure_message(label).contains([track.license])
		assert_str(track.source_url).override_failure_message(label).is_equal(
				SCORE_DIR + label + ".py")
		assert_bool(FileAccess.file_exists("res://" + track.source_url)).override_failure_message(
				label).is_true()


func test_pick_follows_the_seed_and_reaches_every_track() -> void:
	assert_object(MUSIC.pick(12345)).is_same(MUSIC.pick(12345))
	var seen: Dictionary[StringName, int] = {}
	for run_seed: int in range(1, 301):
		var track: MusicTrack = MUSIC.pick(run_seed)
		seen[track.id] = seen.get(track.id, 0) + 1
	assert_int(seen.size()).is_equal(MUSIC.count())
	# 300 tohumda her parça kabaca üçte bir (en az 30 kez).
	for id: StringName in seen:
		assert_int(seen[id]).override_failure_message(String(id)).is_greater(30)
	assert_object(MusicCatalog.new().pick(1)).is_null()


func test_position_wraps_inside_the_loop() -> void:
	var track: MusicTrack = MusicTrack.new()
	track.stream = MUSIC.tracks[0].stream
	track.loop_start = 10.0
	var end: float = track.length()
	assert_float(track.position_at(0.0)).is_equal(0.0)
	assert_float(track.position_at(end - 1.0)).is_equal_approx(end - 1.0, 0.000001)
	# Sondan 2 sn sonra döngü başından 2 sn sonrası; iki döngü sonra yine aynı yer.
	assert_float(track.position_at(end + 2.0)).is_equal_approx(12.0, 0.000001)
	var loop: float = end - 10.0
	assert_float(track.position_at(end + 2.0 + 2.0 * loop)).is_equal_approx(12.0, 0.0001)
