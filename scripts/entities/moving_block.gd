class_name MovingBlock
extends MovingHazard
## Hareketli blok (M4-10, GDD §6): duvardan duvara ritimle gidip gelen veri bloğu. Her vuruşta
## öbür uca gider ve tam vuruşta varır (sahnede move_beats 1: hiç durmaz, uçta yavaşlar). Konumu
## yolun ortasıdır; uçlar ±travel (tasarımda; koridor genişliğiyle ölçeklenir). Varsayılan yolda
## blok iki duvara da değer.
##
## Görünüş: veri bloğu (Block) gibi kırmızı neon kutu ve veri satırları; altında yolunu gösteren
## soluk bir şerit (Lane, yerinde durur).

## Bloğun boyu.
@export var size: Vector2 = Vector2(200.0, 100.0)
## Yolun yarısı (tasarımda): blok ortadan ±travel'a gider. 350'de 200 px'lik blok duvara değer.
@export_range(50.0, 400.0, 50.0, "suffix:px") var travel: float = 350.0
## 0. vuruşta sol uçta mı (değilse sağda).
@export var starts_left: bool = true

## Şeridin son kurulduğu koridor ölçeği (değişince yeniden kurulur).
var _lane_scale: float = 0.0

@onready var _lane: Polygon2D = $Lane


func _ready() -> void:
	super()
	Block.add_data_rows(_visual, size)
	_lane.color = Color(Neon.STYLE.hazard_color, Neon.STYLE.mover_lane_alpha)


func rest_polygon() -> PackedVector2Array:
	var half: Vector2 = size * 0.5
	return PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])


func pose_at(beat: float, scale_x: float) -> Transform2D:
	return Transform2D(0.0, Vector2(offset_at(beat) * scale_x, 0.0))


## Verilen vuruşta merkezin yolun ortasından uzaklığı (tasarımda; sol eksi).
func offset_at(beat: float) -> float:
	var steps: float = steps_at(beat)
	var whole: float = floorf(steps)
	var start: float = -1.0 if starts_left else 1.0
	var from: float = start if posmod(int(whole), 2) == 0 else -start
	return travel * from * (1.0 - 2.0 * (steps - whole))


func swept_rect(scale_x: float) -> Rect2:
	var reach: float = travel * scale_x + size.x * 0.5
	return Rect2(-reach, -size.y * 0.5, 2.0 * reach, size.y)


func set_beat(beat: float) -> void:
	super(beat)
	if not is_equal_approx(_lane_scale, x_scale):
		_lane_scale = x_scale
		var lane: Rect2 = swept_rect(x_scale)
		_lane.polygon = PackedVector2Array([
			lane.position, Vector2(lane.end.x, lane.position.y), lane.end,
			Vector2(lane.position.x, lane.end.y),
		])
