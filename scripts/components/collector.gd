class_name Collector
extends Area2D
## Oyuncunun toplama alanı (M2-13). Yalnızca collector katmanında durur; Glimmer'lar bu alanı
## algılayıp kendilerini toplar. Toplama alanı gövdeden büyüktür (affedici toplama); yarıçapı
## sahibi TuningConfig.pickup_radius'tan atar. Mıknatıs (M4) ayrı bir alan olacak.

@onready var _shape: CollisionShape2D = $Shape


func set_radius(radius: float) -> void:
	var circle: CircleShape2D = _shape.shape as CircleShape2D
	if not is_equal_approx(circle.radius, radius):
		circle.radius = radius
