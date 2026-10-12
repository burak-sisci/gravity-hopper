class_name Laser
extends Area2D
## Lazer ışını (M2-12, GDD §6). Duvara bağlı yatay ışın: kökü duvarda, +x yönünde length kadar
## koridora uzanır (sağ duvarda scale.x = -1). Vuruşla yanıp söner: açık penceresi vuruşa
## ortalıdır (her vuruşun çeyrek öncesinden çeyrek sonrasına kadar). Engeller yarım vuruş
## ızgarasında durduğu için oyuncu ışını ya tamamen açıkken ya tamamen kapalıyken geçer.
## on_phase = 0,5 ile yarım vuruşta yanan ışın, tam vuruşta geçilirken kapalıdır (aldatıcı).
## Açıkken tehlikedir, kapalıyken sönük bir çizgi. İki duvardan birer ışın, ortada açıklık
## bırakan bir lazer kapısı olur.
##
## Pasiftir: oyuncuyu tanımaz. Vuruşu Run → ChunkSpawner → ChunkInfo zinciriyle aşağıdan alır
## (set_beat). Doğrulayıcı aynı kuralı is_on_at() ile hesaplar.

## Işının açık kaldığı süre (vuruş).
const ON_LENGTH: float = 0.5
const THICKNESS: float = 16.0
const OFF_ALPHA: float = 0.25

## Işının koridora uzanan boyu (px; koridor 900 px).
@export_range(50.0, 900.0, 50.0, "suffix:px") var length: float = 450.0
## Açık penceresinin ortası, vuruş içinde (0 = vuruşta yanar, 0,5 = yarım vuruşta).
@export_range(0.0, 0.5, 0.5) var on_phase: float = 0.0

var _on: bool = true

@onready var _shape: CollisionShape2D = $Shape
@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	# Her ışının kendi şekli olur (sahnedeki şekil kaynağı örnekler arasında paylaşılırdı).
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(length, THICKNESS)
	_shape.shape = rect
	_shape.position = Vector2(length * 0.5, 0.0)
	var box: Rect2 = beam_rect()
	_visual.polygon = PackedVector2Array([
		box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y),
	])
	_apply(true)


## Işının kendi uzayındaki kutusu (doğrulayıcı da kullanır; sahne ağaçta olmasa bile).
func beam_rect() -> Rect2:
	return Rect2(0.0, -THICKNESS * 0.5, length, THICKNESS)


## Verilen vuruş konumunda (tempo ızgarasının başından beri geçen vuruş) ışın açık mı?
func is_on_at(beat: float) -> bool:
	return fposmod(beat - on_phase + ON_LENGTH * 0.5, 1.0) < ON_LENGTH


## Run'dan gelen vuruş konumuna göre ışını yakar ya da söndürür.
func set_beat(beat: float) -> void:
	var on: bool = is_on_at(beat)
	if on != _on:
		_apply(on)


func is_on() -> bool:
	return _on


func _apply(on: bool) -> void:
	_on = on
	_shape.disabled = not on
	_visual.modulate.a = 1.0 if on else OFF_ALPHA
