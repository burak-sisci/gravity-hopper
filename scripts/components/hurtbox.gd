class_name Hurtbox
extends Area2D
## Oyuncunun çarpışma kutusu (architecture.md §7.3). Tehlike katmanındaki bir alana değince
## yukarıya `hit` yayar. Tehlikenin ne olduğunu bilmez, onunla konuşmaz; tehlikeler pasiftir.
## Boyutu sahibinin gövdesinden küçüktür (TuningConfig.hurtbox_scale); sahibi set_size() ile atar.

signal hit

@onready var _shape: CollisionShape2D = $Shape


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func set_size(size: Vector2) -> void:
	var rect: RectangleShape2D = _shape.shape as RectangleShape2D
	if rect.size != size:
		rect.size = size


func _on_area_entered(_area: Area2D) -> void:
	hit.emit()
