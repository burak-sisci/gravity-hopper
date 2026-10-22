class_name Block
extends Area2D
## Veri bloğu (M3-05, GDD §6): köşeli kırmızı neon kutu, içinde sönük veri satırları. Görüntüsü
## vuruşla hafifçe süzülür; çarpışma kutusu yerinde kalır (yalnızca görsel, ADR-035).
##
## Pasiftir: oyuncuyu tanımaz. Vuruşu Run → ChunkSpawner → ChunkInfo zinciriyle aşağıdan alır
## (set_beat). Satırlar çarpışma kutusunun boyundan kurulur.

@onready var _shape: CollisionShape2D = $Shape
@onready var _visual: NeonShape = $Visual


func _ready() -> void:
	add_data_rows(_visual, (_shape.shape as RectangleShape2D).size)


## Bloğun boyuna göre veri satırlarını görüntüye ekler (hareketli blok da kullanır, M4-10).
static func add_data_rows(visual: Node2D, size: Vector2) -> void:
	var style: NeonStyle = Neon.STYLE
	var left: float = size.x * (style.block_row_inset - 0.5)
	var inner_width: float = size.x * (1.0 - 2.0 * style.block_row_inset)
	for row: Vector2 in style.block_rows:
		var line: Line2D = Neon.make_line(false)
		line.width = style.block_row_width
		line.default_color = Color(style.hazard_color, style.block_row_alpha)
		var y: float = row.x * size.y
		line.points = PackedVector2Array([Vector2(left, y), Vector2(left + inner_width * row.y, y)])
		visual.add_child(line)


## Vuruş konumuna (tempo ızgarasının başından beri geçen vuruş) göre görüntüyü süzdürür.
func set_beat(beat: float) -> void:
	var style: NeonStyle = Neon.STYLE
	_visual.position.y = sin(beat * TAU / style.block_hover_beats) * style.block_hover_px
