extends GdUnitTestSuite
## Ses efektleri (M3-15, architecture.md §8.8): her olayın atıflı bir sesi var; Events'teki olay
## doğru sesi çalar; aynı karedeki efektler ayrı çalarlarda çalar; havuz dolunca bitmesine en az
## kalan kesilir ve düğüm sayısı değişmez; efektler Engine.time_scale'i izlemez. Final sesi
## (M4-13) aynı karedeki sektör sesinin yerini alır.
##
## Çalarların doluluğunu ölçmek için testler sesleri uzun, birbirinden ayırt edilir sessiz
## WAV'lardan kurulu bir bankayla değiştirir (önceki testlerin kısa sesleri bunlardan önce biter).

const SFX_DIR: String = "res://assets/audio/sfx/"
## Test seslerinin süresi: ilk ses en kısası, her sonraki biraz daha uzun (sn).
const TEST_LENGTH: float = 20.0
## Havuz testinin sesleri önceki testlerinkinden sonra biter; kesilecek olan hep kendi sesleri olur.
const POOL_LENGTH: float = 100.0
const TEST_STEP: float = 1.0
const TEST_MIX_RATE: int = 1000

var _bank: SfxBank
var _streams: Dictionary[GameTypes.Sfx, AudioStream] = {}


func before_test() -> void:
	_bank = _make_bank(TEST_LENGTH)
	AudioManager.sfx_bank = _bank


func after_test() -> void:
	AudioManager.sfx_bank = AudioManager.SFX_BANK
	Engine.time_scale = 1.0
	for voice: AudioStreamPlayer in AudioManager.sfx_voices():
		voice.stop()
	# Final olayı Progression'a da gider (başarım izi); kayıt temiz kalsın.
	Progression.reset()


func test_every_event_has_a_credited_sound() -> void:
	var bank: SfxBank = AudioManager.SFX_BANK
	for event: int in GameTypes.Sfx.values():
		var sound: SfxSound = bank.sound_for(event as GameTypes.Sfx)
		var label: String = GameTypes.Sfx.keys()[event]
		assert_object(sound).override_failure_message("Sesi yok: %s" % label).is_not_null()
		assert_object(sound.stream as AudioStreamOggVorbis).is_not_null()
		assert_str(sound.stream.resource_path).starts_with(SFX_DIR)
		# Efekt döngüsüz; döngülü olsaydı çalar hiç boşalmazdı.
		assert_bool((sound.stream as AudioStreamOggVorbis).loop).is_false()
		assert_float(sound.volume_db).is_between(-24.0, 6.0)
		for field: String in [sound.title, sound.author, sound.license, sound.source_url]:
			assert_str(field).override_failure_message("Atıf eksik: %s" % label).is_not_empty()


func test_events_play_their_sound() -> void:
	Events.run_started.emit(1, 1)
	var cases: Array[Array] = [
		[GameTypes.Sfx.FLIP, Events.player_flipped.emit],
		[GameTypes.Sfx.LAND, Events.player_landed.emit],
		[GameTypes.Sfx.GLIMMER, Events.glimmer_collected.emit.bind(1)],
		[GameTypes.Sfx.NEAR_MISS, Events.near_miss.emit.bind(1, 1)],
		[GameTypes.Sfx.SHIELD_BREAK, Events.shield_changed.emit.bind(false)],
		[GameTypes.Sfx.SECTOR, Events.sector_entered.emit.bind(2)],
		[GameTypes.Sfx.RECORD, Events.record_broken.emit],
		[GameTypes.Sfx.FINALE, Events.great_storage_reached.emit],
		[GameTypes.Sfx.DEATH, Events.player_died.emit.bind(GameTypes.DeathCause.HAZARD)],
	]
	for case: Array in cases:
		var event: GameTypes.Sfx = case[0]
		var count: int = AudioManager.sfx_count(event)
		(case[1] as Callable).call()
		assert_int(AudioManager.sfx_count(event)).is_equal(count + 1)
		assert_int(AudioManager.last_sfx().event).is_equal(event)
		assert_object(_voice_with(_streams[event])).is_not_null()


func test_shield_gain_is_silent() -> void:
	var count: int = AudioManager.sfx_count(GameTypes.Sfx.SHIELD_BREAK)
	Events.shield_changed.emit(true)
	assert_int(AudioManager.sfx_count(GameTypes.Sfx.SHIELD_BREAK)).is_equal(count)


## Büyük Depolama Birimi: sektör sesi aynı karede başlar, final sesi onu susturup yerini alır.
func test_finale_replaces_the_sector_sound() -> void:
	Events.run_started.emit(1, 5)
	Events.sector_entered.emit(6)
	assert_object(_voice_with(_streams[GameTypes.Sfx.SECTOR])).is_not_null()
	Events.great_storage_reached.emit()
	assert_object(_voice_with(_streams[GameTypes.Sfx.SECTOR])).is_null()
	assert_object(_voice_with(_streams[GameTypes.Sfx.FINALE])).is_not_null()
	assert_int(AudioManager.last_sfx().event).is_equal(GameTypes.Sfx.FINALE)


## Kombo eşiği sesi yalnızca çarpan büyüdüğü kıl payında; zincir bitince sayaç baştan.
func test_combo_sound_only_when_the_multiplier_grows() -> void:
	Events.run_started.emit(1, 1)
	var start: int = AudioManager.sfx_count(GameTypes.Sfx.COMBO_UP)
	Events.near_miss.emit(1, 1)
	assert_int(AudioManager.sfx_count(GameTypes.Sfx.COMBO_UP)).is_equal(start)
	Events.near_miss.emit(2, 2)
	assert_int(AudioManager.sfx_count(GameTypes.Sfx.COMBO_UP)).is_equal(start + 1)
	# Kıl payı ile kombo eşiği aynı karede ayrı çalarlarda.
	assert_object(_voice_with(_streams[GameTypes.Sfx.NEAR_MISS])).is_not_null()
	assert_object(_voice_with(_streams[GameTypes.Sfx.COMBO_UP])).is_not_null()
	Events.near_miss.emit(3, 2)
	assert_int(AudioManager.sfx_count(GameTypes.Sfx.COMBO_UP)).is_equal(start + 1)
	Events.near_miss.emit(4, 3)
	assert_int(AudioManager.sfx_count(GameTypes.Sfx.COMBO_UP)).is_equal(start + 2)
	Events.combo_ended.emit()
	Events.near_miss.emit(1, 1)
	Events.near_miss.emit(2, 2)
	assert_int(AudioManager.sfx_count(GameTypes.Sfx.COMBO_UP)).is_equal(start + 3)


## Aynı karede çalan efektler havuzun ayrı çalarlarına düşer; havuz dolunca bitmesine en az
## kalan kesilir, düğüm oluşmaz (.clauderules §6).
func test_full_pool_cuts_the_sound_ending_soonest() -> void:
	_bank = _make_bank(POOL_LENGTH)
	AudioManager.sfx_bank = _bank
	var voices: Array[AudioStreamPlayer] = AudioManager.sfx_voices()
	assert_int(voices.size()).is_equal(_bank.voices)
	var children: int = AudioManager.get_child_count()
	var events: Array = GameTypes.Sfx.values()
	assert_int(events.size()).is_greater(voices.size())
	# Havuz kadar efekt aynı karede: her biri kendi çalarında.
	for i: int in voices.size():
		AudioManager.play_sfx(events[i])
	var used: Dictionary[AudioStreamPlayer, bool] = {}
	for i: int in voices.size():
		var voice: AudioStreamPlayer = _voice_with(_streams[events[i]])
		assert_object(voice).is_not_null()
		used[voice] = true
	assert_int(used.size()).is_equal(voices.size())
	# Bir fazlası en kısa süren ilk sesin yerini alır, diğerleri sürer.
	var first: AudioStreamPlayer = _voice_with(_streams[events[0]])
	AudioManager.play_sfx(events[voices.size()])
	assert_object(first.stream).is_same(_streams[events[voices.size()]])
	for i: int in range(1, voices.size()):
		assert_object(_voice_with(_streams[events[i]])).is_not_null()
	assert_int(AudioManager.get_child_count()).is_equal(children)
	assert_int(AudioManager.sfx_voices().size()).is_equal(voices.size())


## Yavaş çekimde müzik yavaşlar ama efektler yavaşlamaz.
func test_effects_ignore_time_scale() -> void:
	Engine.time_scale = 0.5
	AudioManager.play_sfx(GameTypes.Sfx.NEAR_MISS)
	var voice: AudioStreamPlayer = _voice_with(_streams[GameTypes.Sfx.NEAR_MISS])
	assert_float(voice.pitch_scale).is_equal(1.0)


func _make_bank(length: float) -> SfxBank:
	var bank := SfxBank.new()
	bank.voices = AudioManager.sfx_voices().size()
	_streams.clear()
	for event: int in GameTypes.Sfx.values():
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_8_BITS
		wav.mix_rate = TEST_MIX_RATE
		var data := PackedByteArray()
		data.resize(roundi((length + event * TEST_STEP) * TEST_MIX_RATE))
		wav.data = data
		var sound := SfxSound.new()
		sound.event = event as GameTypes.Sfx
		sound.stream = wav
		bank.sounds.append(sound)
		_streams[event as GameTypes.Sfx] = wav
	return bank


func _voice_with(stream: AudioStream) -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in AudioManager.sfx_voices():
		if voice.stream == stream:
			return voice
	return null
