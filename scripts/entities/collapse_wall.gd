class_name CollapseWall
extends Node2D
## Çöküş duvarının görseli (M3-09; GDD §14, architecture.md §8.4, §9). Run her fizik adımında
## kenarını oyuncunun mesafe × 50 px altına koyar ve müziğin vuruşunu verir. Yerel y = 0
## öldürme çizgisidir, aşağısı duvarın içi. Yalnızca görseldir; yakalama PressureSystem'de.
## Kenar sütun sütun kırıktır; sütun yükseklikleri ve yana kayan dilimler vuruş başına
## collapse_steps_per_beat kez yeniden hesaplanır (adım başına bir kez, burada; shader'a dizi
## olarak yazılır). Kırık kenar hiç öldürme çizgisinin altına inmez (duvar olduğundan uzak
## görünmez). Kenar vuruşta parlar.
## Orta ve yüksek kalitede kenarı bir glitch bandı çizer (shader; yalnızca kenarın çevresindeki
## bant, tam ekran değil: M3-07 ölçümü): kırık kenar, kayan dilimler, kenarın üstünde dağılan
## veri kırıntıları, içte bozuk bloklar; yüksekte kenarda renk kayması. Düşük kalitede shader
## yok: aynı kırık kenarın çizgisi ve düz dolgu. Dolgu opaktır: altında kalan her şey silinmiş
## görünür. Ekran boyu değişince bant ve dolgu yeniden kurulur. Control yok: dokunuşları yutmaz.

## Dolgunun ve bandın ekranın kenarlarından taşma payı (kamera ara değerlemesi, sarsıntı).
const VIEW_MARGIN: float = 200.0
## Glitch adımı bu sayıda sarılır; shader'daki özet küçük sayılarla kararlı kalır.
const STEP_WRAP: int = 1024
## Shader'daki sütun ve dilim dizilerinin boyu (collapse_glitch.gdshader ile aynı olmalı).
## Daha geniş ekranda fazla sütunlar sonuncunun yüksekliğini alır.
const MAX_COLUMNS: int = 96
const MAX_ROWS: int = 32

## Şu anki glitch adımı (vuruş × adım/vuruş, sarılmış).
var _step: int = -1
var _half_width: float = 0.0
var _first_column: int = 0
var _column_count: int = 0
var _first_row: int = 0
var _tops: PackedFloat32Array = PackedFloat32Array()
var _shifts: PackedFloat32Array = PackedFloat32Array()

@onready var _body: Polygon2D = %Body
@onready var _top: Node2D = %Top
@onready var _edge: NeonLine = %Edge
@onready var _glitch: Polygon2D = %Glitch
@onready var _material: ShaderMaterial = _glitch.material as ShaderMaterial


func _enter_tree() -> void:
	add_to_group(Neon.GROUP)


func _ready() -> void:
	var style: NeonStyle = Neon.STYLE
	_tops.resize(MAX_COLUMNS)
	_shifts.resize(MAX_ROWS)
	_body.color = style.collapse_body_color
	_first_row = floori(-style.collapse_rise / style.collapse_slice)
	var params: Dictionary[StringName, Variant] = {
		&"edge_color": style.hazard_color, &"body_color": style.collapse_body_color,
		&"rise": style.collapse_rise, &"depth": style.collapse_depth,
		&"column_px": style.collapse_column, &"slice_px": style.collapse_slice,
		&"block_px": style.collapse_block, &"dust_density": style.collapse_dust_density,
		&"edge_px": style.collapse_edge_width, &"glow_px": style.collapse_glow,
		&"glow_alpha": style.collapse_glow_alpha, &"pulse_gain": style.collapse_pulse_gain,
		&"first_row": float(_first_row),
	}
	for key: StringName in params:
		_material.set_shader_parameter(key, params[key])
	_top.draw.connect(_draw_top)
	get_viewport().size_changed.connect(_fit)
	_fit()
	set_beat(0.0)
	apply_quality()


## Müziğin vuruşu (tempo ızgarasının başından, kesirli). Yalnızca görsel.
func set_beat(beat: float) -> void:
	var style: NeonStyle = Neon.STYLE
	var pulse: float = style.beat_pulse(beat)
	_material.set_shader_parameter(&"pulse", pulse)
	var shade: float = 1.0 + style.collapse_pulse_gain * pulse
	_edge.modulate = Color(shade, shade, shade)
	var next: int = posmod(floori(beat * style.collapse_steps_per_beat), STEP_WRAP)
	if next != _step:
		_step = next
		_roll()


## Kalite (Neon.GROUP): orta ve üstünde glitch bandı, yüksekte renk kayması; düşükte kırık kenar
## çizgisi ve düz dolgu.
func apply_quality() -> void:
	if not is_node_ready():
		return
	var style: NeonStyle = Neon.STYLE
	var glitch: bool = Neon.quality >= style.collapse_glitch_min_quality
	_glitch.visible = glitch
	_top.visible = not glitch
	_edge.visible = not glitch
	var split: bool = Neon.quality >= style.collapse_split_min_quality
	_material.set_shader_parameter(&"split_px", style.collapse_split if split else 0.0)
	_build_edge()


## Şu anki glitch adımı (test ve tezgâh için).
func glitch_step() -> int:
	return _step


## Kırık kenarın noktaları (yerel; düşük kalitenin çizgisi, glitch bandıyla aynı sütunlar):
## sütun başına bir basamak, y 0 ile -collapse_jag arası; ekranı taşma payıyla kaplar.
func edge_points() -> PackedVector2Array:
	var column: float = Neon.STYLE.collapse_column
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in _column_count:
		var x: float = (_first_column + i) * column
		var top: float = _tops[mini(i, MAX_COLUMNS - 1)]
		points.append(Vector2(x, top))
		points.append(Vector2(x + column, top))
	return points


## Sütun yüksekliklerinin ve dilim kaymalarının kopyası (test için).
func column_tops() -> PackedFloat32Array:
	return _tops.duplicate()


func slice_shifts() -> PackedFloat32Array:
	return _shifts.duplicate()


func _fit() -> void:
	var style: NeonStyle = Neon.STYLE
	var view: Vector2 = get_viewport_rect().size
	_half_width = view.x * 0.5
	var left: float = -_half_width - VIEW_MARGIN
	var right: float = _half_width + VIEW_MARGIN
	_first_column = floori(left / style.collapse_column)
	_column_count = ceili(right / style.collapse_column) - _first_column
	_material.set_shader_parameter(&"first_column", float(_first_column))
	_body.polygon = _rect(left, 0.0, right, view.y + VIEW_MARGIN)
	_glitch.polygon = _rect(left, -style.collapse_rise, right, style.collapse_depth)
	if _step >= 0:
		_roll()


## Bu adımın kırık kenarı ve dilim kaymaları (kozmetik özet; turun RNG'sine dokunmaz).
func _roll() -> void:
	var style: NeonStyle = Neon.STYLE
	for i: int in MAX_COLUMNS:
		var index: int = _first_column + mini(i, _column_count - 1)
		_tops[i] = -style.collapse_jag * _hash01(index, _step, 0)
	for i: int in MAX_ROWS:
		var row: int = _first_row + i
		var shift: float = 0.0
		if _hash01(row, _step, 1) < style.collapse_slice_chance:
			shift = (_hash01(row, _step, 2) * 2.0 - 1.0) * style.collapse_slice_shift
		_shifts[i] = shift
	_material.set_shader_parameter(&"glitch_step", float(_step))
	_material.set_shader_parameter(&"tops", _tops)
	_material.set_shader_parameter(&"shifts", _shifts)
	_build_edge()


## Düşük kalitenin kırık kenarı (glitch bandı görünüyorsa gerek yok).
func _build_edge() -> void:
	if not is_node_ready() or not _edge.visible:
		return
	_edge.points = edge_points()
	_top.queue_redraw()


## Kırık kenarın altı, öldürme çizgisine kadar dolgu renginde (sütun başına bir dikdörtgen).
func _draw_top() -> void:
	var points: PackedVector2Array = edge_points()
	var color: Color = Neon.STYLE.collapse_body_color
	for i: int in range(0, points.size(), 2):
		var top: Vector2 = points[i]
		_top.draw_rect(Rect2(top.x, top.y, points[i + 1].x - top.x, -top.y), color)


static func _rect(left: float, top: float, right: float, bottom: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom),
	])


## 0–1 arası tamsayı özeti (aynı girdiye her cihazda aynı sonuç).
static func _hash01(a: int, b: int, c: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0
