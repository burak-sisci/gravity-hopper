extends Node
## Kök sahne (architecture.md §5.1). Sahnedeki işi yapar: turu World kabına kurar ve kaldırır.
## Kararı GameManager verir (tohum, durum, sonuç); Main uygular ve GameManager'a haber verir.
## Debug build'de debug katmanını Debug kabına yükler; yayın sürümünde yüklenmez (ADR-023).
## Efekt kalitesini ayardan neon bileşenlerine aktarır (Neon autoload kullanmaz, §9).
## Desen parçası havuzları (ChunkPools) turlar arasında burada korunur; her tura verilir (M3-10).
## Her tura Progression'ın kalıcı rekoru verilir; Run rekor çizgisini oraya koyar (M3-14, M4-02).
## Yükseltmelerin etkileri tur başında tek bir yük olarak Run'a ve GameManager'a verilir (M4-04).
## Tur, Progression'da seçilen kontrol noktasından başlar (M4-09).
## Durum makinesi (M5-01): açılışta GameManager.launch_state()'e göre menü ya da tur; menü
## durumunda tur kaldırılır, Events.play_requested ile seçili kontrol noktasından tur kurulur.
## Sonuç ekranı (M5-03) durum RESULTS iken açıktır; tur kendiliğinden yeniden başlamaz, Tekrar
## (Events.retry_requested) yeni turu kurar. Ölü tur ekranın arkasında donmuş kalır.

const DEBUG_LAYER_PATH: String = "res://scenes/debug/debug_layer.tscn"
const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")

var _run: Run
## Yeni turların başladığı sektör: açılışta seçili kontrol noktası (Progression.start_sector);
## seçim değişince sonraki turdan geçerli. Debug 5 tuşu ve --start= Events.start_requested ile
## kilide bakmadan başka bir sektörden hemen başlatır. Ölüm ve Tekrar'dan sonra da aynı sektör.
var _start_sector: int

@onready var _world: Node2D = %World
@onready var _chunk_pools: ChunkPools = %ChunkPools
@onready var _debug: CanvasLayer = %Debug
@onready var _hud: Control = %Hud
@onready var _menu: MainMenu = %MainMenu
@onready var _results: ResultsScreen = %ResultsScreen


func _ready() -> void:
	if OS.is_debug_build() and ResourceLoader.exists(DEBUG_LAYER_PATH):
		_debug.add_child((load(DEBUG_LAYER_PATH) as PackedScene).instantiate())
	_apply_quality()
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
	_world.add_child(_run)
	# Run, katalog dışı sektörü sınırlar; duyurulan sektör gerçek başlangıçtır.
	_start_sector = _run.start_sector
	GameManager.begin_run(run_seed, _start_sector, loadout)


func _apply_quality() -> void:
	Neon.set_quality(Settings.effect_quality, get_tree())


func _on_start_requested(sector: int) -> void:
	_start_sector = sector
	_start_run()


## Süren tur bozulmaz; seçim sonraki turdan geçerli.
func _on_start_sector_selected(sector: int) -> void:
	_start_sector = sector


## Menüde tur kalmaz: dünya boşalır, menü açılır, HUD gizlenir (M5-02). Sonuç durumunda sonuç
## ekranı açılır (M5-03); başka durumda kapanır.
func _on_app_state_changed(state: GameTypes.AppState) -> void:
	var in_menu: bool = state == GameTypes.AppState.MENU
	_hud.visible = not in_menu
	if state == GameTypes.AppState.RESULTS:
		_results.open()
	else:
		_results.visible = false
	if in_menu:
		_remove_run()
		_menu.open()
	else:
		_menu.visible = false


func _remove_run() -> void:
	if _run == null:
		return
	_world.remove_child(_run)
	_run.queue_free()
	_run = null
