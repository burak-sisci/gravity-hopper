class_name Rotor
extends MovingHazard
## Dönen şekil (M4-10, GDD §6): koridorda, merkezi çevresinde dönen iki ucu sivri çubuk. Her
## vuruşta turn_degrees döner; dönüş vuruşun ikinci yarısında (move_beats 0,5) olur ve tam vuruşta
## biter, ilk yarısında çubuk durur.
##
## Görünüş: tehlike kırmızısı neon çubuk (sivri köşeli), ortasında beyaza çekilmiş çekirdek
## çizgisi (Visual/Core); çekirdek görüntüyle birlikte döner.

## Çubuğun kalınlığı; uçlar 90° sivri (uç boyu kalınlığın yarısı).
const THICKNESS: float = 40.0

## Çubuğun uçtan uca boyu (px; koridor 900 px). Taradığı dairenin yarıçapı bu boyun yarısıdır.
@export_range(100.0, 900.0, 50.0, "suffix:px") var length: float = 300.0
## Her vuruştaki dönüş.
@export_range(45.0, 180.0, 45.0, "suffix:°") var turn_degrees: float = 90.0
## Ekranda saat yönünde mi döner.
@export var clockwise: bool = true
## 0. vuruştaki açı (0 = yatay).
@export_range(0.0, 135.0, 45.0, "suffix:°") var start_degrees: float = 0.0

@onready var _core: Line2D = $Visual/Core


func _ready() -> void:
	super()
	var style: NeonStyle = Neon.STYLE
	var reach: float = length * 0.5 - THICKNESS * 0.5
	_core.points = PackedVector2Array([Vector2(-reach, 0.0), Vector2(reach, 0.0)])
	_core.width = THICKNESS * style.rotor_core_ratio
	_core.default_color = _visual.shown_color().lerp(Color.WHITE, style.rotor_core_whiten)


## Duruş hâli: yatay, iki ucu 90° sivri altıgen çubuk.
func rest_polygon() -> PackedVector2Array:
	var half_length: float = length * 0.5
	var half_thickness: float = THICKNESS * 0.5
	var shoulder: float = half_length - half_thickness
	return PackedVector2Array([
		Vector2(-half_length, 0.0), Vector2(-shoulder, -half_thickness),
		Vector2(shoulder, -half_thickness), Vector2(half_length, 0.0),
		Vector2(shoulder, half_thickness), Vector2(-shoulder, half_thickness),
	])


func pose_at(beat: float, _scale_x: float) -> Transform2D:
	return Transform2D(angle_at(beat), Vector2.ZERO)


## Verilen vuruştaki açı (radyan; ekranda saat yönü artı, 0 – 2π).
func angle_at(beat: float) -> float:
	var spin: float = 1.0 if clockwise else -1.0
	return deg_to_rad(fposmod(start_degrees + spin * turn_degrees * steps_at(beat), 360.0))


## Taradığı daire, uçların yarıçapıyla (dönüş ekseni ölçeklenmez).
func swept_rect(_scale_x: float) -> Rect2:
	var radius: float = length * 0.5
	return Rect2(-radius, -radius, 2.0 * radius, 2.0 * radius)
