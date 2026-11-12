class_name SettingsScreen
extends Control
## Ayarlar (M5-05, GDD §20, architecture.md §5.3): müzik ve efekt düzeyi, titreşim, dil, efekt
## kalitesi, 60 FPS sınırı ve Hakkında (Events.about_requested; AboutScreen üstte açılır, M5-09).
## Değişiklik hemen uygulanır ve yazılır (Settings servisi, .clauderules §3); kaydırıcı
## sürüklenirken yalnızca uygulanır, bırakınca yazılır. Menünün üstünde açılır:
## Events.settings_requested ile kendini açar, geri düğmesi ve durum değişimi kapatır. Dünyaya
## erişmez. Duraklatmadan da açılır (M5-06): oyun ağacı duraklıyken çalışır (process_mode ALWAYS).

## Seçili ve seçili olmayan seçeneğin vurgusu (mağaza sekmeleriyle aynı).
const ACTIVE: Color = ShopScreen.TAB_ACTIVE
const IDLE: Color = ShopScreen.TAB_IDLE

@onready var _back: NeonButton = %BackButton
@onready var _music: NeonSlider = %MusicSlider
@onready var _sfx: NeonSlider = %SfxSlider
@onready var _vibration: NeonButton = %VibrationButton
@onready var _fps: NeonButton = %FpsButton
@onready var _about: NeonButton = %AboutButton
@onready var _languages: Dictionary[String, NeonButton] = {
	"tr": %TurkishButton, "en": %EnglishButton,
}
@onready var _qualities: Dictionary[GameTypes.Quality, NeonButton] = {
	GameTypes.Quality.LOW: %LowButton,
	GameTypes.Quality.MEDIUM: %MediumButton,
	GameTypes.Quality.HIGH: %HighButton,
}


func _ready() -> void:
	_back.pressed.connect(close)
	_music.value_changed.connect(func(value: float) -> void:
		Settings.set_music_volume(value, false))
	_music.drag_ended.connect(func(_changed: bool) -> void: Settings.save_settings())
	_sfx.value_changed.connect(func(value: float) -> void: Settings.set_sfx_volume(value, false))
	_sfx.drag_ended.connect(func(_changed: bool) -> void: Settings.save_settings())
	_vibration.pressed.connect(func() -> void: Settings.set_vibration(not Settings.vibration))
	_fps.pressed.connect(func() -> void: Settings.set_limit_fps_60(not Settings.limit_fps_60))
	for code: String in _languages:
		_languages[code].pressed.connect(Settings.set_language.bind(code))
	for quality: GameTypes.Quality in _qualities:
		_qualities[quality].pressed.connect(Settings.set_effect_quality.bind(quality))
	_about.pressed.connect(Events.about_requested.emit)
	Events.settings_requested.connect(open)
	Events.settings_changed.connect(refresh)
	Events.app_state_changed.connect(func(_state: GameTypes.AppState) -> void: close())
	refresh()


## Ekranı açar ve değerleri yeniden okur.
func open() -> void:
	visible = true
	refresh()


func close() -> void:
	visible = false


## Denetimleri Settings'teki değerlere getirir (kaydırıcı sinyal yaymadan).
func refresh() -> void:
	_music.set_value_no_signal(Settings.music_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_set_toggle(_vibration, Settings.vibration)
	_set_toggle(_fps, Settings.limit_fps_60)
	var locale: String = TranslationServer.get_locale().left(2)
	for code: String in _languages:
		_languages[code].accent = ACTIVE if code == locale else IDLE
	for quality: GameTypes.Quality in _qualities:
		_qualities[quality].accent = ACTIVE if quality == Settings.effect_quality else IDLE


func _set_toggle(button: NeonButton, on: bool) -> void:
	button.text = "SETTINGS_ON" if on else "SETTINGS_OFF"
	button.accent = ACTIVE if on else IDLE
