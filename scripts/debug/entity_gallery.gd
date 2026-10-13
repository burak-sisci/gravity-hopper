extends Node2D
## Varlık galerisi (M3-05): oyunun tehlike ve toplanabilir sahneleri (diken, blok, lazer,
## Glimmer) ve oyuncu (M3-06) S1 renkleriyle yan yana, vuruşla canlı. Yalnızca debug amaçlıdır,
## oyuncu görmez; görsel işleri rastgele parça beklemeden incelemek ve ekran görüntüsü almak
## içindir.
## PC'de: <godot> --path . res://scenes/debug/entity_gallery.tscn
## Telefonda argüman verilemez: sahne geçici olarak ana sahne yapılıp yüklenir, sonra geri alınır.

const SECTOR: SectorDef = preload("res://data/sectors/sector_01.tres")
const SPIKE_SCENE: PackedScene = preload("res://scenes/entities/spike.tscn")
const BLOCK_SCENE: PackedScene = preload("res://scenes/entities/block.tscn")
const LASER_SCENE: PackedScene = preload("res://scenes/entities/laser.tscn")
const GLIMMER_SCENE: PackedScene = preload("res://scenes/entities/glimmer.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/player.tscn")

## Galeri tasarım alanı (proje görüntü alanı 1080 × 1920; uzun ekranda aşağı uzar).
const VIEW_WIDTH: float = 1080.0
const VIEW_HEIGHT: float = 2400.0
## Duvarların ekrandaki x'i (oyundaki dar koridor gibi).
const WALL_INSET: float = 90.0
## Galerinin vuruş hızı (S1 tempo aralığında).
const BPM: float = 128.0
const SECONDS_PER_MINUTE: float = 60.0
const SPIKE_ROW_Y: float = 380.0
const SPIKE_STEP_Y: float = 160.0
const BLOCK_ROW_Y: float = 760.0
const LASER_ROW_Y: float = 1100.0
const LASER_STEP_Y: float = 200.0
const GLIMMER_ROW_Y: float = 1560.0
const GLIMMER_STEP_X: float = 150.0
const GLIMMER_COUNT: int = 3
## Oyuncu sol duvarda (çekirdeğin duvardan uzaklığı oyundaki gibi).
const PLAYER_POSITION: Vector2 = Vector2(120.0, 1760.0)

var _beat: float = 0.0
var _lasers: Array[Laser] = []
var _blocks: Array[Block] = []
var _glimmers: Array[Glimmer] = []


func _ready() -> void:
	Neon.set_quality(Settings.effect_quality, get_tree())
	var palette: SectorPalette = SECTOR.palette
	var background: ColorRect = ColorRect.new()
	background.color = palette.background
	background.size = Vector2(VIEW_WIDTH, VIEW_HEIGHT)
	add_child(background)
	var right: float = VIEW_WIDTH - WALL_INSET
	for x: float in [WALL_INSET, right]:
		var wall: NeonLine = NeonLine.new()
		wall.points = PackedVector2Array([Vector2(x, 0.0), Vector2(x, VIEW_HEIGHT)])
		wall.color = palette.ambient
		add_child(wall)
	for i: int in 2:
		var y: float = SPIKE_ROW_Y + i * SPIKE_STEP_Y
		_add_item(SPIKE_SCENE, Vector2(WALL_INSET, y), false)
		_add_item(SPIKE_SCENE, Vector2(right, y), true)
	_blocks.append(_add_item(BLOCK_SCENE, Vector2(VIEW_WIDTH * 0.5, BLOCK_ROW_Y), false) as Block)
	var left_laser: Laser = _add_item(LASER_SCENE, Vector2(WALL_INSET, LASER_ROW_Y), false) as Laser
	var right_laser: Laser = _add_item(
			LASER_SCENE, Vector2(right, LASER_ROW_Y + LASER_STEP_Y), true) as Laser
	right_laser.on_phase = 0.5
	_lasers.append_array([left_laser, right_laser])
	for i: int in GLIMMER_COUNT:
		var x: float = VIEW_WIDTH * 0.5 + (i - (GLIMMER_COUNT - 1) * 0.5) * GLIMMER_STEP_X
		_glimmers.append(_add_item(GLIMMER_SCENE, Vector2(x, GLIMMER_ROW_Y), false) as Glimmer)
	# Oyuncu yalnızca görüntü için: işlemesi kapalı, tırmanmaz.
	var player: Node2D = PLAYER_SCENE.instantiate() as Node2D
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = PLAYER_POSITION
	add_child(player)


func _physics_process(delta: float) -> void:
	_beat += delta * BPM / SECONDS_PER_MINUTE
	for laser: Laser in _lasers:
		laser.set_beat(_beat)
	for block: Block in _blocks:
		block.set_beat(_beat)
	for glimmer: Glimmer in _glimmers:
		glimmer.set_beat(_beat)


## Sahneyi verilen yere koyar; sağ duvardakiler koridora bakacak şekilde aynalanır.
func _add_item(scene: PackedScene, at: Vector2, mirrored: bool) -> Node2D:
	var item: Node2D = scene.instantiate() as Node2D
	item.position = at
	if mirrored:
		item.scale.x = -1.0
	add_child(item)
	return item
