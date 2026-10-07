class_name GameCamera
extends Camera2D
## Oyun kamerası: sabit ileri görüş kuralı (architecture.md §3). Hedefin üstünde her cihazda
## aynı mesafe görünür; uzun ekranlardaki fazla dikey alan hedefin altına gider. Yatayda
## koridorun ortası (x = 0) ekranın ortasıdır. Run her fizik adımında follow() çağırır.


## Kamerayı, hedefin üstünde lookahead_px kadar alan görünecek şekilde konumlar.
func follow(target_y: float, lookahead_px: float) -> void:
	var view_height: float = get_viewport_rect().size.y
	position = Vector2(0.0, target_y - lookahead_px + view_height * 0.5)


## Görünür alanın üst kenarı (dünya koordinatı).
func view_top() -> float:
	return position.y - get_viewport_rect().size.y * 0.5


## Görünür alanın alt kenarı (dünya koordinatı).
func view_bottom() -> float:
	return position.y + get_viewport_rect().size.y * 0.5
