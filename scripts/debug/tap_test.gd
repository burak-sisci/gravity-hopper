extends Node2D
## M0-10 dokunma testi: her dokunuşta neon elmas sıradaki sektör rengine geçer ve kısaca büyür.
## Girdi kuralları oyuncununkiyle aynıdır (architecture.md §8.1): her parmağın basışı sayılır,
## dokunuştan türetilen sahte fare olayları yok sayılır (S-07). M1-02'de run.tscn ile değişir.

## Sektör çevre renkleri taslağı (S1 camgöbeği → S5 beyaz); kesin tonlar M3'te seçilecek.
const COLORS: Array[Color] = [
	Color(0.0, 0.9, 1.0),
	Color(0.62, 0.35, 1.0),
	Color(1.0, 0.72, 0.1),
	Color(1.0, 0.3, 0.85),
	Color(1.0, 1.0, 1.0),
]
## Elmasın ekrandaki yeri: yatayda orta, dikeyde bu oranda.
const HEIGHT_RATIO: float = 0.45
const POP_SCALE: float = 1.15
const POP_SEC: float = 0.15

var _color_index: int = 0
var _tap_count: int = 0
var _pop_tween: Tween


func _ready() -> void:
	get_viewport().size_changed.connect(_place)
	_place()
	modulate = COLORS[_color_index]


func _unhandled_input(event: InputEvent) -> void:
	if _is_tap(event):
		get_viewport().set_input_as_handled()
		_on_tapped()


func _on_tapped() -> void:
	_tap_count += 1
	_color_index = (_color_index + 1) % COLORS.size()
	modulate = COLORS[_color_index]
	_pop()
	if OS.is_debug_build():
		print("TAP %d" % _tap_count)


func _pop() -> void:
	if _pop_tween != null:
		_pop_tween.kill()
	scale = Vector2.ONE * POP_SCALE
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "scale", Vector2.ONE, POP_SEC) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _place() -> void:
	position = get_viewport_rect().size * Vector2(0.5, HEIGHT_RATIO)


static func _is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT \
				and mouse.device != InputEvent.DEVICE_ID_EMULATION
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return key.pressed and not key.echo and key.keycode == KEY_SPACE
	return false
