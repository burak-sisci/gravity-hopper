class_name Neon
extends RefCounted
## Neon bileşenlerinin (NeonLine, NeonShape) ortak durumu (architecture.md §9, ADR-020):
## efekt kalitesi, görünüş değerleri, paylaşılan dokular ve toplamsal malzeme.
## Autoload kullanmaz: ekransız araç betikleri bu sınıfı adıyla derler (§15, M1-04 dersi).
## Kaliteyi Main, Settings'ten okuyup set_quality ile yazar.

## Ağaçtaki her neon bileşenin grubu.
const GROUP: StringName = &"neon"
const STYLE: NeonStyle = preload("res://data/visual/neon_style.tres")
## Işık lekesi dokusunun kenarı (px).
const BLOB_TEXTURE_SIZE: int = 128
## Parlama dokusunun boyu (px): çizginin enine sönümü.
const HALO_TEXTURE_SIZE: Vector2i = Vector2i(4, 64)

## Geçerli efekt kalitesi. Ağaca giren bileşen kendini buna göre ayarlar.
static var quality: GameTypes.Quality = GameTypes.Quality.HIGH
static var _halo_texture: GradientTexture2D
static var _blob_texture: GradientTexture2D
static var _additive: CanvasItemMaterial


## Kaliteyi değiştirir ve ağaçtaki her neon bileşene uygular. Düğüm oluşturmaz: katmanlar
## baştan kuruludur, yalnızca görünürlükleri ve kalınlıkları değişir (.clauderules §6).
static func set_quality(value: GameTypes.Quality, tree: SceneTree) -> void:
	quality = value
	tree.call_group(GROUP, &"apply_quality")


## Parlak çekirdek çizgi.
static func make_line(closed: bool) -> Line2D:
	var line: Line2D = Line2D.new()
	line.closed = closed
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	return line


## Parlama kopyası: enine sönen dokulu, toplamsal karışımlı geniş çizgi.
static func make_halo(closed: bool) -> Line2D:
	var halo: Line2D = make_line(closed)
	halo.texture = halo_texture()
	halo.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	halo.material = additive_material()
	return halo


## Parlama kopyalarını geçerli kaliteye göre ayarlar; fazla kopyalar gizlenir.
static func apply_halos(halos: Array[Line2D], color: Color, enabled: bool) -> void:
	var layers: Array[Vector2] = STYLE.layers_for(quality)
	for i: int in halos.size():
		var halo: Line2D = halos[i]
		halo.visible = enabled and i < layers.size()
		if halo.visible:
			halo.width = layers[i].x
			halo.default_color = Color(color, layers[i].y)


## Toplamsal karışım: parlama yalnızca altındakini aydınlatır.
static func additive_material() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


## Çizginin enine yumuşak sönen doku: ortada tam, kenarlarda sıfır.
static func halo_texture() -> GradientTexture2D:
	if _halo_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.38, 0.5, 0.62, 0.8, 1.0])
		gradient.colors = PackedColorArray([
			Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.35), Color(1, 1, 1, 1.0),
			Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.0),
		])
		_halo_texture = GradientTexture2D.new()
		_halo_texture.gradient = gradient
		_halo_texture.width = HALO_TEXTURE_SIZE.x
		_halo_texture.height = HALO_TEXTURE_SIZE.y
		_halo_texture.fill_from = Vector2(0.0, 0.0)
		_halo_texture.fill_to = Vector2(0.0, 1.0)
	return _halo_texture


## Merkezde tam, kenara doğru sönen dairesel ışık lekesi dokusu.
static func blob_texture() -> GradientTexture2D:
	if _blob_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 1.0])
		gradient.colors = PackedColorArray([
			Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0),
		])
		_blob_texture = GradientTexture2D.new()
		_blob_texture.gradient = gradient
		_blob_texture.width = BLOB_TEXTURE_SIZE
		_blob_texture.height = BLOB_TEXTURE_SIZE
		_blob_texture.fill = GradientTexture2D.FILL_RADIAL
		_blob_texture.fill_from = Vector2(0.5, 0.5)
		_blob_texture.fill_to = Vector2(1.0, 0.5)
	return _blob_texture
