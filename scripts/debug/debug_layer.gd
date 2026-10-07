extends Control
## Debug katmanı (M1-02, architecture.md §13). Main bunu yalnızca debug build'de yükler.
## Oyun dünyasını tanımaz; dünyaya ait istekler Events sinyalleriyle iletilir (M1-11, M1-12).
## Yalnızca geliştirici görür; bu yüzden metinler tr() ile değil doğrudan yazılır.

## godot-debug-menu görünüm sayısı (eklentinin Style enum'u): gizli → kısa → ayrıntılı.
const MENU_STYLE_COUNT: int = 3
const DEBUG_MENU_PATH: String = "res://addons/debug_menu/debug_menu.tscn"
## Telefonda okunabilsin diye eklentinin katmanı büyütülür.
const DEBUG_MENU_SCALE: float = 2.0
## Ekran oranı denemesi (yalnızca PC, architecture.md §3): dikey pencere boyutları.
const ASPECT_WINDOWS: Array[Vector2i] = [
	Vector2i(450, 800), Vector2i(450, 1000), Vector2i(600, 800),
]
const ASPECT_NAMES: Array[String] = ["16:9", "20:9", "4:3"]

## Debug tuşları: tuş kodu → işlev. Sonraki görevler buraya ekler (architecture.md §13 tablosu).
var _key_actions: Dictionary[int, Callable] = {}
var _debug_menu: CanvasLayer
var _aspect_index: int = 0


func _ready() -> void:
	_key_actions[KEY_7] = _cycle_fps
	_key_actions[KEY_KP_7] = _cycle_fps
	_key_actions[KEY_6] = _cycle_aspect
	_key_actions[KEY_KP_6] = _cycle_aspect
	_debug_menu = (load(DEBUG_MENU_PATH) as PackedScene).instantiate() as CanvasLayer
	add_child(_debug_menu)
	get_viewport().size_changed.connect(_place_debug_menu)
	_place_debug_menu()
	_connect_event_log()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var action: Callable = _key_actions.get(key.keycode, Callable())
	if action.is_valid():
		get_viewport().set_input_as_handled()
		action.call()


## Telefondaki debug düğmesi. Şimdilik FPS'yi değiştirir; M1-11'de debug panelini açar.
func _on_debug_button_pressed() -> void:
	_cycle_fps()


## Pencereyi sıradaki ekran oranına getirir. Telefonda pencere boyutu değişmez, tuş etkisizdir.
func _cycle_aspect() -> void:
	if OS.has_feature("mobile"):
		return
	_aspect_index = (_aspect_index + 1) % ASPECT_WINDOWS.size()
	get_window().size = ASPECT_WINDOWS[_aspect_index]
	print("ASPECT %s pencere=%s" % [ASPECT_NAMES[_aspect_index], ASPECT_WINDOWS[_aspect_index]])


func _cycle_fps() -> void:
	var style: int = _debug_menu.get(&"style")
	_debug_menu.set(&"style", (style + 1) % MENU_STYLE_COUNT)


## Olay günlüğü: önemli Events sinyalleri "EVENT ..." satırı olarak yazılır. Telefondaki
## denemeler günlükten (adb logcat) doğrulanır. Yeni olaylar ilgili görevde eklenir.
func _connect_event_log() -> void:
	Events.player_flipped.connect(_log_event.bind("player_flipped"))
	Events.player_died.connect(func(cause: GameTypes.DeathCause) -> void:
		_log_event("player_died cause=%s" % GameTypes.DeathCause.keys()[cause]))
	Events.run_started.connect(func(run_seed: int, start_sector: int) -> void:
		_log_event("run_started seed=%d sector=%d" % [run_seed, start_sector]))
	Events.run_ended.connect(func(result: RunResult) -> void:
		_log_event("run_ended height=%d cause=%s" % [
			result.height_m, GameTypes.DeathCause.keys()[result.cause],
		]))


func _log_event(event_name: String) -> void:
	print("EVENT %s t=%d" % [event_name, Time.get_ticks_msec()])


## Menü sağ üste yaslıdır; büyütülünce ekrandan taşmasın diye sola kaydırılır.
func _place_debug_menu() -> void:
	var width: float = get_viewport_rect().size.x
	_debug_menu.scale = Vector2(DEBUG_MENU_SCALE, DEBUG_MENU_SCALE)
	_debug_menu.offset = Vector2(-width * (DEBUG_MENU_SCALE - 1.0), 0.0)
