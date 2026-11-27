extends Node
## Kök sahne (architecture.md §5.1). Sahnedeki işi yapar: turu World kabına kurar ve kaldırır.
## Kararı GameManager verir (tohum, durum, sonuç); Main uygular ve GameManager'a haber verir.
## Debug build'de debug katmanını Debug kabına yükler; yayın sürümünde yüklenmez (ADR-023).
## Efekt kalitesini ayardan neon bileşenlerine aktarır (Neon autoload kullanmaz, §9). Tur sürerken
## karelerin gerçek süresini AutoQuality'ye verir; cihaz 60 FPS'i uzun süre tutamazsa ve oyuncu
## kaliteyi seçmediyse Settings kaliteyi bir kademe düşürür (M6-11).
## Desen parçası havuzları (ChunkPools) turlar arasında burada korunur; her tura verilir (M3-10).
## Her tura Progression'ın kalıcı rekoru verilir; Run rekor çizgisini oraya koyar (M3-14, M4-02).
## Yükseltmelerin etkileri tur başında tek bir yük olarak Run'a ve GameManager'a verilir (M4-04).
## Tur, Progression'da seçilen kontrol noktasından başlar (M4-09).
## Durum makinesi (M5-01): açılışta GameManager.launch_state()'e göre menü ya da tur; menü
## durumunda tur kaldırılır, Events.play_requested ile seçili kontrol noktasından tur kurulur.
## Sonuç ekranı (M5-03) durum RESULTS iken açıktır; tur kendiliğinden yeniden başlamaz, Tekrar
## (Events.retry_requested) yeni turu kurar. Ölü tur ekranın arkasında donmuş kalır.
## Mağaza (M5-04) durum SHOP iken açıktır; menüdeki gibi tur kaldırılır.
## Duraklatma ekranı (M5-06) durum PAUSED iken açıktır; tur ekranın arkasında donmuş bekler.

const DEBUG_LAYER_PATH: String = "res://scenes/debug/debug_layer.tscn"
const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")

var _run: Run
## Yeni turların başladığı sektör: açılışta seçili kontrol noktası (Progression.start_sector);
## seçim değişince sonraki turdan geçerli. Debug 5 tuşu ve --start= Events.start_requested ile
## kilide bakmadan başka bir sektörden hemen başlatır. Ölüm ve Tekrar'dan sonra da aynı sektör.
var _start_sector: int
var _auto_quality: AutoQuality = AutoQuality.new()
## Önceki karenin gerçek zamanı (µs; Engine.time_scale'den bağımsız).
var _last_frame_usec: int = 0

@onready var _world: Node2D = %World
@onready var _chunk_pools: ChunkPools = %ChunkPools
@onready var _debug: CanvasLayer = %Debug
@onready var _hud: Hud = %Hud
@onready var _menu: MainMenu = %MainMenu
@onready var _results: ResultsScreen = %ResultsScreen
@onready var _shop: ShopScreen = %ShopScreen
@onready var _pause: PauseScreen = %PauseScreen
@onready var _ui: CanvasLayer = %UI


func _ready() -> void:
	if OS.is_debug_build() and ResourceLoader.exists(DEBUG_LAYER_PATH):
		_debug.add_child((load(DEBUG_LAYER_PATH) as PackedScene).instantiate())
	_apply_quality()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	Events.settings_changed.connect(_apply_quality)
	Events.retry_requested.connect(_start_run)
	Events.start_requested.connect(_on_start_requested)
	Events.start_sector_selected.connect(_on_start_sector_selected)
	Events.play_requested.connect(_start_run)
	Events.app_state_changed.connect(_on_app_state_changed)
	_start_sector = Progression.start_sector
	if GameManager.launch_state() == GameTypes.AppState.MENU:
		GameManager.change_state(GameTypes.AppState.MENU)
	else:
		_start_run()


## Arayüz ekranlarını cihazın güvenli alanına (çentik, kamera deliği) alır; zeminleri tam ekran
## kalır (M6-01, SafeArea). Pencere boyutu değişince yeniden hesaplanır.
func _apply_safe_area() -> void:
	var insets: Vector4 = SafeArea.device_insets(get_viewport())
	var shift: Vector4 = SafeArea.content_insets(insets)
	for screen: Node in _ui.get_children():
		if screen is Control:
			SafeArea.fit(screen as Control, shift)
	if OS.is_debug_build():
		print("SAFE insets=%s shift=%s safe_area=%s window=%s canvas=%s" % [insets, shift,
				DisplayServer.get_display_safe_area(), DisplayServer.window_get_size(),
				get_viewport().get_visible_rect().size])


## Varsa eski turu kaldırır, yeni tohumla yeni bir tur kurar ve GameManager'a bildirir.
## Turlar arasında düğüm oluşturmak serbesttir; tur sırasında yasaktır (.clauderules §6).
func _start_run() -> void:
	_remove_run()
	var run_seed: int = GameManager.new_run_seed()
	_run = RUN_SCENE.instantiate() as Run
	_run.run_seed = run_seed
	_run.start_sector = _start_sector
	_run.record_height = Progression.best_height_m
	var loadout: RunLoadout = Progression.loadout()
	_run.loadout = loadout
	_run.chunk_pools = _chunk_pools
	# İlk açılış turu (M5-07): ilk parça tanıtım parçası, ekranda "dokun" eli.
	var first_run: bool = not Progression.ftue_done
	_run.ftue = first_run
	_world.add_child(_run)
	# Run, katalog dışı sektörü sınırlar; duyurulan sektör gerçek başlangıçtır.
	_start_sector = _run.start_sector
	GameManager.begin_run(run_seed, _start_sector, loadout)
	if first_run:
		_hud.show_tap_hint()


## Görsel kalite kararı: yalnızca tur sürerken sayılır (menü, duraklatma ve sonuç ekranı hariç).
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	_track_frame((now - _last_frame_usec) / 1_000_000.0)
	_last_frame_usec = now


## Karenin gerçek süresini (sn) otomatik kalite kuralına verir.
func _track_frame(frame_sec: float) -> void:
	if GameManager.state != GameTypes.AppState.RUNNING or not Settings.can_lower_quality():
		return
	if _auto_quality.add_frame(frame_sec):
		if OS.is_debug_build():
			print("QUALITY auto window_ms=%.1f" % _auto_quality.last_window_ms)
		Settings.lower_quality_automatically()


func _apply_quality() -> void:
	Neon.set_quality(Settings.effect_quality, get_tree())


func _on_start_requested(sector: int) -> void:
	_start_sector = sector
	_start_run()


## Süren tur bozulmaz; seçim sonraki turdan geçerli.
func _on_start_sector_selected(sector: int) -> void:
	_start_sector = sector


## Menüde ve mağazada tur kalmaz: dünya boşalır, ekran açılır, HUD gizlenir (M5-02, M5-04).
## Sonuç durumunda sonuç ekranı açılır (M5-03); her ekran kendi durumu dışında kapalıdır.
func _on_app_state_changed(state: GameTypes.AppState) -> void:
	var in_menu: bool = state == GameTypes.AppState.MENU
	var in_shop: bool = state == GameTypes.AppState.SHOP
	_hud.visible = not (in_menu or in_shop)
	if in_menu or in_shop:
		_remove_run()
	_show(_results, state == GameTypes.AppState.RESULTS, _results.open)
	_show(_menu, in_menu, _menu.open)
	_show(_shop, in_shop, _shop.open)
	_show(_pause, state == GameTypes.AppState.PAUSED, _pause.open)


func _show(screen: Control, shown: bool, opener: Callable) -> void:
	if shown:
		opener.call()
	else:
		screen.visible = false


func _remove_run() -> void:
	if _run == null:
		return
	_world.remove_child(_run)
	_run.queue_free()
	_run = null
