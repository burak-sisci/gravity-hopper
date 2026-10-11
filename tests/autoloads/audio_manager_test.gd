extends GdUnitTestSuite
## Metronom döngüsü (M2-07, architecture.md §8.3): bir ölçü, ilk vuruşta tık, döngü sonundan
## sonra sessiz pay (Android'deki çökmenin önlemi).

## Statik fonksiyon autoload örneğinden değil, betiğin kendisinden çağrılır.
const AudioManagerScript := preload("res://scripts/autoloads/audio_manager.gd")


func test_metronome_is_one_bar_with_tail() -> void:
	var stream: AudioStreamWAV = AudioManagerScript.make_metronome(100.0)
	# 100 BPM: vuruş 0,6 sn = 26460 örnek; ölçü 4 vuruş.
	assert_int(stream.loop_end).is_equal(4 * 26460)
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	var tail: int = AudioManagerScript.LOOP_TAIL_SAMPLES
	assert_int(stream.data.size()).is_equal((stream.loop_end + tail) * 2)
	assert_float(stream.get_length()).is_greater(2.4)


func test_metronome_clicks_on_beats_and_tail_is_silent() -> void:
	var stream: AudioStreamWAV = AudioManagerScript.make_metronome(120.0)
	# 120 BPM: vuruş 22050 örnek; yarısında tık çoktan sönmüş olmalı.
	var beat: int = 22050
	var half_beat: int = 11025
	for i: int in 4:
		# Tık sinüsü 0'dan başlar; ilk birkaç örnekte ses yükselir.
		assert_int(absi(stream.data.decode_s16((i * beat + 5) * 2))).is_greater(1000)
		assert_int(stream.data.decode_s16((i * beat + half_beat) * 2)).is_equal(0)
	for i: int in AudioManagerScript.LOOP_TAIL_SAMPLES:
		assert_int(stream.data.decode_s16((stream.loop_end + i) * 2)).is_equal(0)
