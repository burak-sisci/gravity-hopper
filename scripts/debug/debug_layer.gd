extends Control
## Debug katmanı (M1-02, architecture.md §13). Main bunu yalnızca debug build'de yükler.
## Oyun dünyasını tanımaz; dünyaya ait istekler Events sinyalleriyle iletilir.
## Yalnızca geliştirici görür; bu yüzden metinler tr() ile değil doğrudan yazılır.

## godot-debug-menu görünüm sayısı (eklentinin Style enum'u): gizli → kısa → ayrıntılı.
const MENU_STYLE_COUNT: int = 3
const DEBUG_MENU_PATH: String = "res://addons/debug_menu/debug_menu.tscn"
## Telefonda okunabilsin diye eklentinin katmanı büyütülür.
const DEBUG_MENU_SCALE: float = 2.0
## Başlatma argümanı (`-- --invincible`): uzun denemelerde ölümsüzlük baştan açık olur.
const INVINCIBLE_ARG: String = "--invincible"
## Başlatma argümanı (`-- --start-sector=2`): ilk tur o sektörden başlar (kare yakalama, M2-11).
const START_SECTOR_ARG: String = "--start-sector="
## Başlatma argümanı (`-- --quality=low`): efekt kalitesi bu oturum için (kaydedilmez; M3-07).
const QUALITY_ARG: String = "--quality="
## Başlatma argümanı (`-- --record=40`): rekor baştan bu yükseklikte, ilk turda rekor
## çizgisi görünür (kare yakalama, M3-14).
const RECORD_ARG: String = "--record="
## Başlatma argümanı (`-- --perf=6`): oyunun içinde performans ölçümü, evre süresi sn (M3-19,
## PerfProbe). `-- --auto-tap=0.5` ölçüm sırasında bu aralıkla dokunuş gönderir.
const PERF_ARG: String = "--perf="
const AUTO_TAP_ARG: String = "--auto-tap="
## Başlatma argümanı (`-- --upgrade=magnet:5`, tekrarlanabilir): yükseltme seviyesi baştan bu
## (kare yakalama, M4-04). Kalıcıdır: bir sonraki kayıt anında (debug) kayda yazılır.
const UPGRADE_ARG: String = "--upgrade="
## Kalite argümanının değerleri ve düğme yazıları, GameTypes.Quality sırasıyla.
const QUALITY_ARGS: Array[String] = ["low", "medium", "high"]
const QUALITY_LABELS: Array[String] = ["Kalite D", "Kalite O", "Kalite Y"]
## Ekran oranı denemesi (yalnızca PC, architecture.md §3): dikey pencere boyutları.
const ASPECT_WINDOWS: Array[Vector2i] = [
	Vector2i(450, 800), Vector2i(450, 1000), Vector2i(600, 800),
]
const ASPECT_NAMES: Array[String] = ["16:9", "20:9", "4:3"]
## Yavaş çekim tuşunun zaman ölçeği. Müzik gelince AudioManager pitch_scale'i buna uydurur.
const SLOW_MOTION_SCALE: float = 0.3

## Debug tuşları: tuş kodu → işlev (architecture.md §13 tablosu).
var _key_actions: Dictionary[int, Callable] = {}
var _debug_menu: CanvasLayer
var _aspect_index: int = 0
var _invincible: bool = false
## Oyuncunun bulunduğu sektör (run_started ve sector_entered'dan izlenir).
var _sector: int = 1

@onready var _tuning_panel: Control = %TuningPanel
@onready var _progress_panel: ProgressPanel = %ProgressPanel
@onready var _invincible_button: Button = %InvincibleButton
@onready var _collisions_button: Button = %CollisionsButton
@onready var _slow_button: Button = %SlowButton
@onready var _quality_button: Button = %QualityButton


func _ready() -> void:
	_bind_key(KEY_1, KEY_KP_1, _toggle_tuning_panel)
	# Tuşlar düğmenin basılı durumunu değiştirir; düğmenin toggled sinyali işi yapar.
	_bind_key(KEY_2, KEY_KP_2, func() -> void: _invincible_button.button_pressed = not _invincible)
	_bind_key(KEY_3, KEY_KP_3, func() -> void:
		_collisions_button.button_pressed = not get_tree().debug_collisions_hint)
	_bind_key(KEY_4, KEY_KP_4, func() -> void:
		_slow_button.button_pressed = is_equal_approx(Engine.time_scale, 1.0))
	_bind_key(KEY_5, KEY_KP_5, _on_next_sector_pressed)
	_bind_key(KEY_8, KEY_KP_8, _on_shield_pressed)
	_bind_key(KEY_6, KEY_KP_6, _cycle_aspect)
	_bind_key(KEY_7, KEY_KP_7, _cycle_fps)
	_bind_key(KEY_0, KEY_KP_0, _toggle_progress_panel)
	_bind_key(KEY_9, KEY_KP_9, _cycle_quality)
	_key_actions[KEY_R] = _on_restart_pressed
	_debug_menu = (load(DEBUG_MENU_PATH) as PackedScene).instantiate() as CanvasLayer
	add_child(_debug_menu)
	get_viewport().size_changed.connect(_place_debug_menu)
	_place_debug_menu()
	_connect_event_log()
	var perf_sec: float = 0.0
	var tap_interval: float = 0.0
	for arg: String in OS.get_cmdline_user_args():
		if arg == INVINCIBLE_ARG:
			_invincible_button.button_pressed = true
		elif arg.begins_with(START_SECTOR_ARG):
			# Main, start_requested'i bu karenin sonunda dinlemeye başlar; istek bir sonraki karede.
			Events.start_requested.emit.call_deferred(int(arg.trim_prefix(START_SECTOR_ARG)))
		elif arg.begins_with(QUALITY_ARG):
			# Main kaliteyi debug katmanını yükledikten hemen sonra uygular; duyuru gerekmez.
			var quality: int = QUALITY_ARGS.find(arg.trim_prefix(QUALITY_ARG))
			if quality >= 0:
				Settings.effect_quality = quality as GameTypes.Quality
		elif arg.begins_with(RECORD_ARG):
			# Main ilk turu debug katmanını yükledikten hemen sonra kurar ve rekoru o an okur.
			# Kalıcı rekordur: tur sonunda (debug) kayda da yazılır.
			Progression.best_height_m = int(arg.trim_prefix(RECORD_ARG))
		elif arg.begins_with(UPGRADE_ARG):
			# Main ilk turun yükünü debug katmanını yükledikten hemen sonra alır.
			var parts: PackedStringArray = arg.trim_prefix(UPGRADE_ARG).split(":")
			if parts.size() == 2:
				Progression.set_upgrade_level(StringName(parts[0]), int(parts[1]))
		elif arg.begins_with(PERF_ARG):
			perf_sec = float(arg.trim_prefix(PERF_ARG))
		elif arg.begins_with(AUTO_TAP_ARG):
			tap_interval = float(arg.trim_prefix(AUTO_TAP_ARG))
	if perf_sec > 0.0:
		var probe: PerfProbe = PerfProbe.new()
		probe.phase_sec = perf_sec
		probe.tap_interval = tap_interval
		add_child(probe)
	_show_quality()
	# Yeni turdaki oyuncu ölümsüzlük durumunu bilmez; her tur başında yeniden duyurulur.
	Events.run_started.connect(func(_run_seed: int, start_sector: int) -> void:
		_sector = start_sector
		if _invincible:
			Events.debug_invincibility_changed.emit(true))
	Events.sector_entered.connect(func(index: int) -> void: _sector = index)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var action: Callable = _key_actions.get(key.keycode, Callable())
	if action.is_valid():
		get_viewport().set_input_as_handled()
		action.call()


## Telefondaki debug düğmesi ayar panelini açıp kapatır.
func _on_debug_button_pressed() -> void:
	_toggle_tuning_panel()


## Ayar panelindeki "İlerleme" düğmesi: İlerleme sayfası ayar panelinin yerini alır (M4-03).
func _on_progress_pressed() -> void:
	_tuning_panel.visible = false
	_progress_panel.visible = true


## Tuşlar da düğmenin basılı durumunu değiştirir; böylece düğme ve tuş hep aynı durumu gösterir.
func _on_invincible_toggled(enabled: bool) -> void:
	_invincible = enabled
	Events.debug_invincibility_changed.emit(enabled)
	print("DEBUG ölümsüzlük %s" % ("açık" if enabled else "kapalı"))


## Çarpışma şekillerini gösterir. Var olan şekiller yeniden çizilsin diye ağaca çizim çağrısı
## yayılır; dünyaya tek tek erişilmez.
func _on_collisions_toggled(enabled: bool) -> void:
	get_tree().debug_collisions_hint = enabled
	get_tree().root.propagate_call(&"queue_redraw")
	print("DEBUG çarpışma kutuları %s" % ("açık" if enabled else "kapalı"))


func _on_slow_toggled(enabled: bool) -> void:
	Engine.time_scale = SLOW_MOTION_SCALE if enabled else 1.0
	print("DEBUG zaman ölçeği %.2f" % Engine.time_scale)


func _on_restart_pressed() -> void:
	Events.retry_requested.emit()


## Oyuncuya kalkan verir (M2-16; Kalkan yükseltmesi M4-05).
func _on_shield_pressed() -> void:
	Events.debug_shield_requested.emit()


## Sonraki sektörün başından yeni tur (kontrol noktası yolu; son sektörde aynı sektör).
func _on_next_sector_pressed() -> void:
	Events.start_requested.emit(_sector + 1)


## Üst sıradaki rakam tuşu ve sayısal tuş takımındaki karşılığı aynı işi yapar.
func _bind_key(key: Key, keypad_key: Key, action: Callable) -> void:
	_key_actions[key] = action
	_key_actions[keypad_key] = action


func _toggle_tuning_panel() -> void:
	_tuning_panel.visible = not _tuning_panel.visible
	if _tuning_panel.visible:
		_progress_panel.visible = false


func _toggle_progress_panel() -> void:
	_progress_panel.visible = not _progress_panel.visible
	if _progress_panel.visible:
		_tuning_panel.visible = false


## Pencereyi sıradaki ekran oranına getirir. Telefonda pencere boyutu değişmez, tuş etkisizdir.
func _cycle_aspect() -> void:
	if OS.has_feature("mobile"):
		return
	_aspect_index = (_aspect_index + 1) % ASPECT_WINDOWS.size()
	get_window().size = ASPECT_WINDOWS[_aspect_index]
	print("ASPECT %s pencere=%s" % [ASPECT_NAMES[_aspect_index], ASPECT_WINDOWS[_aspect_index]])


## Efekt kalitesi: yüksek → orta → düşük → yüksek. Yalnızca bu oturum için (kaydedilmez);
## Main ayar değişikliğini duyunca neon bileşenlerine ve arka plana uygular.
func _cycle_quality() -> void:
	var quality: int = posmod(Settings.effect_quality - 1, GameTypes.Quality.size())
	Settings.effect_quality = quality as GameTypes.Quality
	Events.settings_changed.emit()
	_show_quality()
	print("DEBUG kalite %s" % QUALITY_ARGS[quality])


func _show_quality() -> void:
	_quality_button.text = QUALITY_LABELS[Settings.effect_quality]


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
	Events.sector_entered.connect(func(index: int) -> void:
		_log_event("sector_entered index=%d" % index))
	Events.near_miss.connect(func(combo: int, multiplier: int) -> void:
		_log_event("near_miss combo=%d x%d" % [combo, multiplier]))
	Events.shield_changed.connect(func(active: bool) -> void:
		_log_event("shield_changed active=%s" % active))
	Events.combo_ended.connect(_log_event.bind("combo_ended"))
	Events.chunk_placed.connect(func(chunk_id: StringName, difficulty: int, sector: int) -> void:
		_log_event("chunk_placed id=%s difficulty=%d sector=%d" % [chunk_id, difficulty, sector]))
	Events.run_ended.connect(func(result: RunResult) -> void:
		_log_event("run_ended height=%d cause=%s earned=%d bonus=%d boost=%d record=%s" % [
			result.height_m, GameTypes.DeathCause.keys()[result.cause], result.earned,
			result.sector_bonus, result.boost_bonus, result.new_record,
		]))


func _log_event(event_name: String) -> void:
	print("EVENT %s t=%d" % [event_name, Time.get_ticks_msec()])


## Menü sağ üste yaslıdır; büyütülünce ekrandan taşmasın diye sola kaydırılır.
func _place_debug_menu() -> void:
	var width: float = get_viewport_rect().size.x
	_debug_menu.scale = Vector2(DEBUG_MENU_SCALE, DEBUG_MENU_SCALE)
	_debug_menu.offset = Vector2(-width * (DEBUG_MENU_SCALE - 1.0), 0.0)
