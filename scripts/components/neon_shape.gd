class_name NeonShape
extends Node2D
## Parlayan neon şekil (architecture.md §9): parlama + saydam dolgu + parlak kenar çizgisi.
## Küçük, sivri köşeli şekiller (diken, Glimmer, oyuncu) arkalarında bir ışık lekesi taşır;
## çizgi kopyası sivri köşelerde ve kapanma noktasında yay izi bırakıyor (M0-09). Geniş açılı
## şekiller (blok) kenar çizgisinin parlama kopyalarını kullanır. Parlama efekt kalitesine göre
## değişir (Neon.quality); düğümler oluşturulurken bir kez kurulur.
## Parlama düğümleri yalnızca seçilen tür için, şekil ağaca ilk girerken kurulur (M3-10): havuzdaki
## her tehlikede kullanılmayan parlama düğümü tur başını yavaşlatıyordu.
## Sabit renkli şekiller (tehlike, Glimmer, oyuncu) rengi tone ile NeonStyle'dan alır (M3-05).

## Parlama türü.
enum Glow {
	BLOB, ## Arkada dairesel ışık lekesi
	LINE, ## Kenar çizgisinin parlama kopyaları
}

## Şeklin köşeleri (yerel koordinat).
@export var polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		polygon = value
		_update_polygon()
## Şeklin rengi (tone CUSTOM iken).
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		_update_look()
## Renk kaynağı: CUSTOM değilse renk NeonStyle'daki sabit renktir (tehlike, Glimmer, oyuncu).
@export var tone: GameTypes.NeonTone = GameTypes.NeonTone.CUSTOM:
	set(value):
		tone = value
		_update_look()
## Dolgunun saydamlığı.
@export_range(0.0, 1.0, 0.01) var fill_alpha: float = Neon.STYLE.fill_alpha:
	set(value):
		fill_alpha = value
		_update_look()
## Kenar çizgisinin kalınlığı.
@export_range(1.0, 40.0, 0.5, "suffix:px") var line_width: float = Neon.STYLE.line_width:
	set(value):
		line_width = value
		_update_look()
## Parlama türü.
@export var glow: Glow = Glow.BLOB:
	set(value):
		glow = value
		apply_quality()
## Kenar çizgisinin köşeleri sivri mi (diken, blok); kapalıysa yuvarlak.
@export var sharp: bool = false:
	set(value):
		sharp = value
		_update_look()

var _blob: Sprite2D
var _halos: Array[Line2D] = []
var _fill: Polygon2D
var _outline: Line2D


func _init() -> void:
	add_to_group(Neon.GROUP)
	# Çizim sırası: parlama → dolgu → kenar çizgisi (parlama sonradan dolgunun altına girer).
	_fill = Polygon2D.new()
	add_child(_fill)
	_outline = Neon.make_line(true)
	add_child(_outline)
	_update_polygon()
	_update_look()


func _enter_tree() -> void:
	apply_quality()


## Parlamayı geçerli kaliteye göre gösterir ya da gizler (Neon.set_quality çağırır).
func apply_quality() -> void:
	if _outline == null or not is_inside_tree():
		return
	_make_glow()
	if _blob != null:
		_blob.visible = glow == Glow.BLOB and Neon.STYLE.shows_blob(Neon.quality)
	Neon.apply_halos(_halos, shown_color(), glow == Glow.LINE)


## Şeklin görünen rengi: tone'a göre sabit renk ya da color.
func shown_color() -> Color:
	return Neon.STYLE.tone_color(tone, color)


func _update_polygon() -> void:
	if _outline == null:
		return
	_fill.polygon = polygon
	_outline.points = polygon
	for halo: Line2D in _halos:
		halo.points = polygon
	if polygon.is_empty() or _blob == null:
		return
	var bounds: Rect2 = Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		bounds = bounds.expand(point)
	var padding: Vector2 = Vector2(Neon.STYLE.blob_padding, Neon.STYLE.blob_padding)
	_blob.position = bounds.get_center()
	_blob.scale = (bounds.size * Neon.STYLE.blob_scale + padding) / Neon.BLOB_TEXTURE_SIZE


func _update_look() -> void:
	if _outline == null:
		return
	var shown: Color = shown_color()
	if _blob != null:
		_blob.modulate = Color(shown, Neon.STYLE.blob_intensity)
	_fill.color = Color(shown, fill_alpha)
	_outline.width = line_width
	_outline.default_color = shown
	_outline.joint_mode = Line2D.LINE_JOINT_SHARP if sharp else Line2D.LINE_JOINT_ROUND
	_outline.sharp_limit = Neon.STYLE.sharp_limit
	apply_quality()


## Seçilen parlama türünün düğümlerini ilk gerektiğinde kurar: ışık lekesi ya da çizgi kopyaları.
func _make_glow() -> void:
	if glow == Glow.BLOB and _blob == null:
		_blob = Sprite2D.new()
		_blob.texture = Neon.blob_texture()
		_blob.material = Neon.additive_material()
		_blob.modulate = Color(shown_color(), Neon.STYLE.blob_intensity)
		_add_below_fill(_blob)
	elif glow == Glow.LINE and _halos.is_empty():
		for i: int in Neon.STYLE.max_layer_count():
			var halo: Line2D = Neon.make_halo(true)
			_add_below_fill(halo)
			_halos.append(halo)
	else:
		return
	_update_polygon()


func _add_below_fill(node: CanvasItem) -> void:
	add_child(node)
	move_child(node, _fill.get_index())
