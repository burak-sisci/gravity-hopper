class_name NeonLine
extends Node2D
## Parlayan neon çizgi (architecture.md §9): toplamsal parlama kopyaları + parlak çekirdek çizgi.
## Duvarlar ve iz için. Kopya sayısı efekt kalitesine göre değişir (Neon.quality); kopyalar
## oluşturulurken bir kez kurulur, kalite değişince yalnızca görünürlükleri değişir.
## Sabit renkli çizgiler (lazer) rengi tone ile NeonStyle'dan alır (M3-06).

## Çizginin noktaları (yerel koordinat).
@export var points: PackedVector2Array = PackedVector2Array():
	set(value):
		points = value
		_update_points()
## Çizginin rengi (tone CUSTOM iken).
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		_update_look()
## Renk kaynağı: CUSTOM değilse renk NeonStyle'daki sabit renktir (ör. tehlike kırmızısı).
@export var tone: GameTypes.NeonTone = GameTypes.NeonTone.CUSTOM:
	set(value):
		tone = value
		_update_look()
## Parlamanın rengi; tamamen saydamsa çizginin rengi kullanılır.
@export var glow_color: Color = Color.TRANSPARENT:
	set(value):
		glow_color = value
		apply_quality()
## Çekirdek çizginin kalınlığı.
@export_range(1.0, 40.0, 0.5, "suffix:px") var width: float = Neon.STYLE.line_width:
	set(value):
		width = value
		_update_look()
## Son nokta ilkine bağlanır mı.
@export var closed: bool = false:
	set(value):
		closed = value
		_update_points()
## Kalınlık eğrisi (ör. izin sivrilen ucu); parlamaya da uygulanır.
@export var width_curve: Curve:
	set(value):
		width_curve = value
		_update_look()
## Çekirdek çizginin renk geçişi (ör. izin sönen ucu); parlamaya uygulanmaz.
@export var gradient: Gradient:
	set(value):
		gradient = value
		_update_look()
## Kapalıysa parlama kopyaları hiç görünmez (ör. ışık lekesi taşıyan bir şeklin kenarı).
@export var glow_enabled: bool = true:
	set(value):
		glow_enabled = value
		apply_quality()

var _halos: Array[Line2D] = []
var _core: Line2D


func _init() -> void:
	add_to_group(Neon.GROUP)
	for i: int in Neon.STYLE.max_layer_count():
		var halo: Line2D = Neon.make_halo(closed)
		add_child(halo)
		_halos.append(halo)
	_core = Neon.make_line(closed)
	add_child(_core)
	_update_points()
	_update_look()


func _enter_tree() -> void:
	apply_quality()


## Parlama kopyalarını geçerli kaliteye göre gösterir ya da gizler (Neon.set_quality çağırır).
func apply_quality() -> void:
	if _core == null:
		return
	var glow: Color = shown_color() if glow_color.a <= 0.0 else glow_color
	Neon.apply_halos(_halos, glow, glow_enabled)


## Çizginin görünen rengi: tone'a göre sabit renk ya da color.
func shown_color() -> Color:
	return Neon.STYLE.tone_color(tone, color)


func _update_points() -> void:
	if _core == null:
		return
	_core.points = points
	_core.closed = closed
	for halo: Line2D in _halos:
		halo.points = points
		halo.closed = closed


func _update_look() -> void:
	if _core == null:
		return
	_core.width = width
	_core.default_color = shown_color()
	_core.width_curve = width_curve
	_core.gradient = gradient
	for halo: Line2D in _halos:
		halo.width_curve = width_curve
	apply_quality()
