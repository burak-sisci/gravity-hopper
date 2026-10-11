extends Node
## Kök sahne (architecture.md §5.1). Sahnedeki işi yapar: turu World kabına kurar ve kaldırır.
## Kararı GameManager verir (tohum, durum, sonuç); Main uygular ve GameManager'a haber verir.
## Debug build'de debug katmanını Debug kabına yükler; yayın sürümünde yüklenmez (ADR-023).

const DEBUG_LAYER_PATH: String = "res://scenes/debug/debug_layer.tscn"
const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
## M1 geçici akışı: ölümden bu kadar sonra tur kendiliğinden yeniden başlar.
## M5'te sonuç ekranı ve "Tekrar" düğmesi (Events.retry_requested) bunun yerini alır.
const AUTO_RESTART_DELAY: float = 0.35
## Oyun açılınca ilk tur S1'den başlar. Sektör seçimi (M5) ve debug 5 tuşu
## Events.start_requested ile başka bir sektörden başlatır.
const START_SECTOR: int = 1

var _run: Run
## Yeniden başlama (ölüm, Tekrar) son seçilen sektörden olur (kontrol noktası).
var _start_sector: int = START_SECTOR

@onready var _world: Node2D = %World
@onready var _debug: CanvasLayer = %Debug


func _ready() -> void:
	if OS.is_debug_build() and ResourceLoader.exists(DEBUG_LAYER_PATH):
		_debug.add_child((load(DEBUG_LAYER_PATH) as PackedScene).instantiate())
	Events.run_ended.connect(_on_run_ended)
	Events.retry_requested.connect(_start_run)
	Events.start_requested.connect(_on_start_requested)
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
	_world.add_child(_run)
	# Run, katalog dışı sektörü sınırlar; duyurulan sektör gerçek başlangıçtır.
	_start_sector = _run.start_sector
	GameManager.begin_run(run_seed, _start_sector)


func _on_start_requested(sector: int) -> void:
	_start_sector = sector
	_start_run()


func _on_run_ended(_result: RunResult) -> void:
	await get_tree().create_timer(AUTO_RESTART_DELAY).timeout
	_start_run()
