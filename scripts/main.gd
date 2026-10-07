extends Node
## Kök sahne (architecture.md §5.1). Sahnedeki işi yapar: turu World kabına kurar ve kaldırır.
## Kararı GameManager verir (tohum, durum, sonuç); Main uygular ve GameManager'a haber verir.
## Debug build'de debug katmanını Debug kabına yükler; yayın sürümünde yüklenmez (ADR-023).

const DEBUG_LAYER_PATH: String = "res://scenes/debug/debug_layer.tscn"
const RUN_SCENE: PackedScene = preload("res://scenes/levels/run.tscn")
## M1 geçici akışı: ölümden bu kadar sonra tur kendiliğinden yeniden başlar.
## M5'te sonuç ekranı ve "Tekrar" düğmesi (Events.retry_requested) bunun yerini alır.
const AUTO_RESTART_DELAY: float = 0.35
## M1'de sektör seçimi yok; her tur S1'den başlar.
const START_SECTOR: int = 1

var _run: Run

@onready var _world: Node2D = %World
@onready var _debug: CanvasLayer = %Debug


func _ready() -> void:
	if OS.is_debug_build() and ResourceLoader.exists(DEBUG_LAYER_PATH):
		_debug.add_child((load(DEBUG_LAYER_PATH) as PackedScene).instantiate())
	Events.run_ended.connect(_on_run_ended)
	Events.retry_requested.connect(_start_run)
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
	_world.add_child(_run)
	GameManager.begin_run(run_seed, START_SECTOR)


func _on_run_ended(_result: RunResult) -> void:
	await get_tree().create_timer(AUTO_RESTART_DELAY).timeout
	_start_run()
