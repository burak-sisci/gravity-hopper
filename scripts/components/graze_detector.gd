class_name GrazeDetector
extends Area2D
## Kıl payı algılayıcısı (M2-14, architecture.md §8.5). Çarpışma kutusundan her yanda biraz büyük
## bir alandır. Bir tehlike bu alana girip çarpışma kutusuna hiç değmeden çıkarsa yukarı grazed
## yayar. Değen tehlikeyi sahibi mark_hit() ile işaretler; o tehlike kıl payı sayılmaz.
## Tehlikeyi tanımaz, onunla konuşmaz; tehlikeler pasiftir.

signal grazed

## İçerideki tehlikeler: değer = çarpışma kutusuna değdi mi.
var _inside: Dictionary[Area2D, bool] = {}

@onready var _shape: CollisionShape2D = $Shape


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


## Alanı, çarpışma kutusu artı her yanda margin olacak şekilde boyutlar.
func set_size(hurt_size: Vector2, margin: float) -> void:
	var rect: RectangleShape2D = _shape.shape as RectangleShape2D
	var size: Vector2 = hurt_size + Vector2(margin, margin) * 2.0
	if rect.size != size:
		rect.size = size


## Bu tehlike çarpışma kutusuna değdi; çıkınca kıl payı sayılmaz.
func mark_hit(area: Area2D) -> void:
	_inside[area] = true


func _on_area_entered(area: Area2D) -> void:
	if not _inside.has(area):
		_inside[area] = false


func _on_area_exited(area: Area2D) -> void:
	if not _inside.has(area):
		return
	var touched: bool = _inside[area]
	_inside.erase(area)
	if not touched:
		grazed.emit()
