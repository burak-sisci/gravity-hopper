extends Node
## Kök sahne (architecture.md §5.1). Sahnedeki işi yapar: turu World kabına kurar ve kaldırır.
## Kararı GameManager verir (tohum, durum, sonuç); Main uygular ve GameManager'a haber verir.
## Debug build'de debug katmanını Debug kabına yükler; yayın sürümünde yüklenmez (ADR-023).
## Efekt kalitesini ayardan neon bileşenlerine aktarır (Neon autoload kullanmaz, §9).
## Desen parçası havuzları (ChunkPools) turlar arasında burada korunur; her tura verilir (M3-10).
## Her tura Progression'ın kalıcı rekoru verilir; Run rekor çizgisini oraya koyar (M3-14, M4-02).
## Yükseltmelerin etkileri tur başında tek bir yük olarak Run'a ve GameManager'a verilir (M4-04).
## Tur, Progression'da seçilen kontrol noktasından başlar (M4-09).

const DEBUG_LAYER_PATH: String = "res://scenes/debug/debug_layer.tscn"
const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
## M1 geçici akışı: ölümden bu kadar sonra tur kendiliğinden yeniden başlar.
## M5'te sonuç ekranı ve "Tekrar" düğmesi (Events.retry_requested) bunun yerini alır.
const AUTO_RESTART_DELAY: float = 0.35

var _run: Run
## Yeni turların başladığı sektör: açılışta seçili kontrol noktası (Progression.start_sector);
## seçim değişince sonraki turdan geçerli. Debug 5 tuşu ve --start= Events.start_requested ile
## kilide bakmadan başka bir sektörden hemen başlatır. Ölüm ve Tekrar'dan sonra da aynı sektör.
var _start_sector: int

@onready var _world: Node2D = %World
@onready var _chunk_pools: ChunkPools = %ChunkPools
@onready var _debug: CanvasLayer = %Debug


func _ready() -> void:
	if OS.is_debug_build() and ResourceLoader.exists(DEBUG_LAYER_PATH):
		_debug.add_child((load(DEBUG_LAYER_PATH) as PackedScene).instantiate())
	_apply_quality()
	Events.settings_changed.connect(_apply_quality)
	Events.run_ended.connect(_on_run_ended)
	Events.retry_requested.connect(_start_run)
	Events.start_requested.connect(_on_start_requested)
	Events.start_sector_selected.connect(_on_start_sector_selected)
	_start_sector = Progression.start_sector
	_start_run()


## Varsa eski turu kaldırır, yeni tohumla yeni bir tur kurar ve GameManager'a bildirir.
## Turlar arasında düğüm oluşturmak serbesttir; tur sırasında yasaktır (.clauderules §6).
func _start_run() -> void:
	if _run != null:
		_world.remove_child(_run)
		_run.queue_free()
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


func _on_run_ended(_result: RunResult) -> void:
	await get_tree().create_timer(AUTO_RESTART_DELAY).timeout
	_start_run()
