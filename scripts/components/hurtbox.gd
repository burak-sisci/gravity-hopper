class_name Hurtbox
extends Area2D
## Oyuncunun çarpışma kutusu (architecture.md §7.3). Tehlike katmanındaki bir alana değince
## yukarıya `hit(alan)` yayar; alan, kıl payı algılayıcısı o tehlikeyi saymasın diye (M2-14).
## Tehlikenin ne olduğunu bilmez, onunla konuşmaz; tehlikeler pasiftir.
## Boyutu sahibinin gövdesinden küçüktür (TuningConfig.hurtbox_scale); sahibi set_size() ile atar.

signal hit(area: Area2D)

@onready var _shape: CollisionShape2D = $Shape


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func set_size(size: Vector2) -> void:
	var rect: RectangleShape2D = _shape.shape as RectangleShape2D
	if rect.size != size:
		rect.size = size


func _on_area_entered(area: Area2D) -> void:
	hit.emit(area)
