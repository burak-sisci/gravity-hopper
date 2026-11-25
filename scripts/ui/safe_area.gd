class_name SafeArea
extends RefCounted
## Güvenli alan (M6-01, architecture.md §5.3): çentik ve kamera deliği gibi ekranın kesilen
## kısımları. Cihazın bildirdiği güvenli alan tuval pikseline çevrilir; ekranlar o kadar içeri
## alınır. `FULL_BLEED_GROUP`'taki zemin ve karartmalar yine bütün ekranı kaplar. Yuvarlak köşeleri
## Godot bildirmez: ekranlar köşe bölgesini tasarımla boş bırakır (UI kabulü ölçer).
## Kenar payları Vector4(sol, üst, sağ, alt) olarak taşınır.

## Ekranın kenarına dek uzanan (güvenli alanla içeri alınmayan) düğümlerin grubu.
const FULL_BLEED_GROUP: StringName = &"full_bleed"
## Yatayda ortalanmış sütunların grubu (anchor 0,5, sahnede ±yarım genişlik): tasarım
## genişliğinde kalır; güvenli alanla daralan ekrana sığmazsa yanlarda DESIGN_MARGINS kadar pay
## bırakacak kadar daralır (ölçek küçülmez, içindeki dokunma hedefleri ≥ 48 dp kalır; M6-01).
const COLUMN_GROUP: StringName = &"safe_column"
## Sütunun sahnedeki tasarım genişliği: ilk sığdırmada okunur, sonraki sığdırmalar onu ezmez.
const _DESIGN_WIDTH_META: StringName = &"safe_area_design_width"
## Ekranların kenarlarda zaten bıraktığı pay (tuval px; sol, üst, sağ, alt): güvenli alanın bu
## kadarı içeriği kaydırmaz, yalnızca aşan kısmı kaydırır (Redmi'de çentik 94 px → içerik 34 px
## iner). Ölçüldü (M6-01): en yakın öğeler üstte 60 px (geri ve duraklat düğmeleri, başlıklar),
## yanlarda 40, altta 258. Doğruluğu UI kabulü en kötü profille ölçer.
const DESIGN_MARGINS: Vector4 = Vector4(40.0, 60.0, 40.0, 40.0)

## Yalnızca debug sürümünde: true iken cihazın bildirdiği güvenli alan yerine `simulated_insets`
## kullanılır (testler ve `-- --safe-area=` argümanı; çentiksiz cihazda kötü telefonu dener).
static var simulate: bool = false
## Taklit edilen güvenli alan payları (tuval px; sol, üst, sağ, alt).
static var simulated_insets: Vector4 = Vector4.ZERO


## Cihazın güvenli alanının pencere kenarlarına uzaklığı, tuval pikselinde. Güvenli alan
## bilinmiyorsa (ekransız) ya da pencere onun içindeyse (masaüstü) sıfır.
static func device_insets(viewport: Viewport) -> Vector4:
	if simulate and OS.is_debug_build():
		return simulated_insets
	return insets_for(Rect2(DisplayServer.get_display_safe_area()),
			Rect2(DisplayServer.window_get_position(), DisplayServer.window_get_size()),
			viewport.get_visible_rect().size)


## Ekran pikselindeki güvenli alan ve pencereden tuval pikselinde kenar payları (saf hesap).
static func insets_for(safe: Rect2, window: Rect2, canvas: Vector2) -> Vector4:
	if not safe.has_area() or not window.has_area():
		return Vector4.ZERO
	var inner: Rect2 = window.intersection(safe)
	if not inner.has_area():
		return Vector4.ZERO
	var scale: Vector2 = canvas / window.size
	return Vector4((inner.position.x - window.position.x) * scale.x,
			(inner.position.y - window.position.y) * scale.y,
			(window.end.x - inner.end.x) * scale.x,
			(window.end.y - inner.end.y) * scale.y)


## Güvenli alan paylarından içeriğin kayacağı paylar: tasarım payını aşan kısım.
static func content_insets(insets: Vector4) -> Vector4:
	return Vector4(maxf(0.0, insets.x - DESIGN_MARGINS.x), maxf(0.0, insets.y - DESIGN_MARGINS.y),
			maxf(0.0, insets.z - DESIGN_MARGINS.z), maxf(0.0, insets.w - DESIGN_MARGINS.w))


## Tam ekran (anchor'ları 0–1) bir ekranı kenar paylarıyla içeri alır; içindeki
## `FULL_BLEED_GROUP` düğümleri dışarı uzatılarak yine bütün ekranı kaplar, `COLUMN_GROUP`
## sütunları yeni genişliğe sığdırılır. Sıfır payla taban genişlikte ekran olduğu gibi kalır.
static func fit(screen: Control, insets: Vector4) -> void:
	screen.offset_left = insets.x
	screen.offset_top = insets.y
	screen.offset_right = -insets.z
	screen.offset_bottom = -insets.w
	var room: float = screen.size.x - DESIGN_MARGINS.x - DESIGN_MARGINS.z
	for node: Node in screen.find_children("*", "Control", true, false):
		if node.is_in_group(FULL_BLEED_GROUP):
			var bleed: Control = node as Control
			bleed.offset_left = -insets.x
			bleed.offset_top = -insets.y
			bleed.offset_right = insets.z
			bleed.offset_bottom = insets.w
		elif node.is_in_group(COLUMN_GROUP):
			fit_column(node as Control, room)


## Ortalanmış sütunu tasarım genişliğiyle `room` genişliğinin küçüğüne getirir (saf yerleşim).
static func fit_column(column: Control, room: float) -> void:
	if not column.has_meta(_DESIGN_WIDTH_META):
		column.set_meta(_DESIGN_WIDTH_META, column.offset_right - column.offset_left)
	var design: float = column.get_meta(_DESIGN_WIDTH_META)
	var half: float = minf(design, room) * 0.5
	column.offset_left = -half
	column.offset_right = half
