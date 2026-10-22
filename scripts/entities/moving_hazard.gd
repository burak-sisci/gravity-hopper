class_name MovingHazard
extends Area2D
## Vuruşla hareket eden tehlikelerin ortak kökü (M4-10, GDD §6): dönen şekil (Rotor) ve hareketli
## blok (MovingBlock). Hareket eden kısım tek bir dışbükey çokgendir: çarpışması (Shape) ve
## görüntüsü (Visual) aynı dönüşümü aynı adımda alır. Doğrulayıcı aynı dönüşümü pose_at ile
## hesaplar; yalnızca dışa açık değerlere baktığı için ağaçta olmayan parçada da çalışır.
##
## Ritim: her vuruşta bir adım. Adım vuruşun son move_beats kadarında yumuşakça atılır ve tam
## vuruşta biter (vuruşa oturur); vuruşun kalanında şekil durur.
##
## Pasiftir: oyuncuyu tanımaz. Vuruşu Run → ChunkSpawner → ChunkInfo zinciriyle aşağıdan alır
## (set_beat); koridor ölçeğini ChunkInfo.layout verir (x_scale).

## Adımın vuruş içinde sürdüğü kısım (vuruş); adım tam vuruşta biter.
@export_range(0.25, 1.0, 0.25) var move_beats: float = 0.5
## Ritmin vuruş ızgarasına göre kayması (0 = adım vuruşta biter, 0,5 = yarım vuruşta).
@export_range(0.0, 0.5, 0.5) var phase: float = 0.0

## Koridor genişliğinin tasarıma oranı (ChunkInfo.layout verir); yatay hareket bununla ölçeklenir.
var x_scale: float = 1.0

@onready var _shape: CollisionPolygon2D = $Shape
@onready var _visual: NeonShape = $Visual


func _ready() -> void:
	var outline: PackedVector2Array = rest_polygon()
	_shape.polygon = outline
	_visual.polygon = outline
	set_beat(0.0)


## Hareket eden şeklin duruş hâli (öğenin kendi uzayında, dışbükey).
func rest_polygon() -> PackedVector2Array:
	return PackedVector2Array()


## Hareket eden kısmın verilen vuruştaki dönüşümü (öğenin kendi uzayında).
func pose_at(_beat: float, _scale_x: float) -> Transform2D:
	return Transform2D.IDENTITY


## Hareketin taradığı alanın kutusu (öğenin kendi uzayında): parça sınırı ve Glimmer yakınlığı.
func swept_rect(_scale_x: float) -> Rect2:
	return Rect2()


## Çarpışma çokgeni verilen vuruşta (öğenin kendi uzayında; doğrulayıcı ve testler).
func polygon_at(beat: float, scale_x: float) -> PackedVector2Array:
	return pose_at(beat, scale_x) * rest_polygon()


## Tamamlanan adım sayısı: tam vuruşta tamsayı, adım sırasında yumuşak kesirli (0 → 1 → 2 …).
func steps_at(beat: float) -> float:
	var shifted: float = beat - phase
	var whole: float = floorf(shifted)
	var t: float = clampf((shifted - whole - (1.0 - move_beats)) / move_beats, 0.0, 1.0)
	return whole + smoothstep(0.0, 1.0, t)


## Run'dan gelen vuruş konumuna göre şekli yerine koyar: çarpışma ve görüntü aynı adımda.
func set_beat(beat: float) -> void:
	var pose: Transform2D = pose_at(beat, x_scale)
	_shape.transform = pose
	_visual.transform = pose
