extends RefCounted
## Ortak UI kabulü (roadmap M5 "UI kabulü", architecture.md §5.3): menü, sonuç ve sonraki ekranların
## testleri aynı ölçüleri ve eşikleri kullanır. Her işlev sorunları metin listesi olarak döndürür;
## test listenin boş olduğunu doğrular (hata mesajında öğe ve değer yazar).

## Ekran oranı matrisi (M6-02; genişlik / yükseklik). Telefon: 9:16, 9:18, 9:19,5, 9:20, 9:21.
## Katlanabilir: kapak ekranı 9:23 (Galaxy Z Fold 904 × 2316), iç ekran 5:6 (Fold 1812 × 2176) ve
## 6:5 (Pixel Fold 2208 × 1840). Tablet 3:4, yatay tablet ve web 4:3, masaüstü web 16:9. İlki
## (9:16) tek oranlı testlerin oranıdır.
const ASPECTS: Array[float] = [9.0 / 16.0, 9.0 / 18.0, 9.0 / 19.5, 9.0 / 20.0, 9.0 / 21.0,
		9.0 / 23.0, 5.0 / 6.0, 6.0 / 5.0, 3.0 / 4.0, 4.0 / 3.0, 16.0 / 9.0]
## 48 dp'nin tuval pikseli (taban genişlik 1080, stretch "expand": telefonda tuval genişliği
## ekran genişliğidir). 360 dp genişliğindeki telefonda 1 dp = 1080 / 360 = 3 px → 48 dp = 144 px.
## Redmi (≈ 393 dp) 132 px ister; 360 dp yaygın küçük telefonların genişliği.
const MIN_TOUCH_PX: float = 144.0
## Komşu düğmeler arası 8 dp = 24 px (aynı hesap).
const MIN_GAP_PX: float = 24.0
## WCAG: normal metin 4,5; kapalı düğme yazısı (etkileşimsiz arayüz öğesi) 3.
const MIN_CONTRAST: float = 4.5
const MIN_DISABLED_CONTRAST: float = 3.0
## En küçük yazı: 12 sp = 36 px (360 dp genişliğinde 1 sp = 3 px; Material'ın en küçük gövde
## yazısı 12 sp).
const MIN_FONT_PX: int = 36
const LOCALES: Array[String] = ["en", "tr"]
## Güvenli alan (M6-01): ekran testleri kötü bir telefonda ölçer. Üstte 150 px çentik (≈ 50 dp;
## Redmi 94, 1440 px genişlikli büyük kamera delikleri tuvalde ≈ 110–130; SafeArea.DESIGN_MARGINS
## üstte 60'ı aşar, içerik kayar) ve 150 px yuvarlak köşe (≈ 50 dp; Redmi 102 = 37 dp). Dikey
## telefonda yan ve alt kesik neredeyse yok: oralarda pay tasarım payına eşit (40 px; ölçü öğelerin
## bu payı bıraktığını sınar). Godot köşe yarıçapını bildirmez: köşe bölgesi tasarımla boş kalır.
const WORST_INSETS: Vector4 = Vector4(40.0, 150.0, 40.0, 40.0)
const CORNER_RADIUS_PX: float = 150.0


## Oranı verilen ekranın tuval boyutu (stretch "expand", taban 1080 × 1920).
static func canvas_size(aspect: float) -> Vector2i:
	var base: Vector2 = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	var size: Vector2 = Vector2(base.x, base.x / aspect)
	if aspect > base.x / base.y:
		size = Vector2(base.y * aspect, base.y)
	return Vector2i(size.round())


## Ekranı kötü telefonun güvenli alanına alır (Main'in cihazda yaptığı gibi: tasarım payını aşan
## kısım kadar) ve öğelerin içinde kalması gereken güvenli dikdörtgeni döndürür.
static func apply_worst_safe_area(screen: Control) -> void:
	SafeArea.fit(screen, SafeArea.content_insets(WORST_INSETS))


## Kötü telefonun güvenli dikdörtgeni (tuvalden payları çıkarılmış).
static func worst_safe_rect(control: Control) -> Rect2:
	var view: Vector2 = control.get_viewport_rect().size
	return Rect2(WORST_INSETS.x, WORST_INSETS.y, view.x - WORST_INSETS.x - WORST_INSETS.z,
			view.y - WORST_INSETS.y - WORST_INSETS.w)


## Yuvarlak köşenin kestiği bölgeye giren sabit öğeler (her köşede yarıçap CORNER_RADIUS_PX'lik
## çeyrek dairenin dışı, köşe karesinin içi; öğenin ekrandaki kısmının köşeye en yakın noktası
## ölçülür). Kaydırılan listeler ve içerikleri sayılmaz: oyuncu onları köşeden kaydırarak çıkarır.
static func corner_problems(items: Array[Control]) -> Array[String]:
	var problems: Array[String] = []
	for item: Control in items:
		var view: Vector2 = item.get_viewport_rect().size
		var rect: Rect2 = item.get_global_rect().intersection(Rect2(Vector2.ZERO, view))
		if _scrolls(item) or not rect.has_area():
			continue
		var r: float = CORNER_RADIUS_PX
		var corners: Array[Vector2] = [Vector2(r, r), Vector2(view.x - r, r),
				Vector2(r, view.y - r), Vector2(view.x - r, view.y - r)]
		for center: Vector2 in corners:
			var left: bool = center.x < view.x / 2.0
			var top: bool = center.y < view.y / 2.0
			var nearest: Vector2 = Vector2(rect.position.x if left else rect.end.x,
					rect.position.y if top else rect.end.y)
			var outside_x: bool = nearest.x < center.x if left else nearest.x > center.x
			var outside_y: bool = nearest.y < center.y if top else nearest.y > center.y
			if outside_x and outside_y and nearest.distance_to(center) > r:
				problems.append("%s köşede %s (merkeze %.0f px > %.0f)" % [
					item.name, nearest, nearest.distance_to(center), r])
	return problems


## Görünür yaprak öğeler: düğmeler, kaydırıcılar ve yazılar (kaplar ve zemin değil).
static func leaves(root: Control) -> Array[Control]:
	var found: Array[Control] = []
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.is_visible_in_tree() and (control is Button or control is Label
				or control is Slider):
			found.append(control)
	return found


## Öğeler ekranın içinde ve çakışmıyor; dokunulan öğeler (düğme, kaydırıcı) ≥ 48 dp ve aralarında
## ≥ 8 dp.
static func layout_problems(items: Array[Control], screen: Rect2) -> Array[String]:
	var problems: Array[String] = []
	for item: Control in items:
		var rect: Rect2 = item.get_global_rect()
		if not screen.encloses(rect):
			problems.append("%s ekran dışı %s" % [item.name, rect])
		for other: Control in items:
			if other != item and rect.intersection(other.get_global_rect()).get_area() > 0.0:
				problems.append("%s ~ %s çakışıyor" % [item.name, other.name])
		if not _touchable(item):
			continue
		if minf(rect.size.x, rect.size.y) < MIN_TOUCH_PX:
			problems.append("%s %s < %.0f px" % [item.name, rect.size, MIN_TOUCH_PX])
		for other: Control in items:
			if other != item and _touchable(other):
				var gap: float = _gap(rect, other.get_global_rect())
				if gap < MIN_GAP_PX:
					problems.append("%s ~ %s arası %.0f px" % [item.name, other.name, gap])
	problems.append_array(corner_problems(items))
	return problems


## Düğme yazısı gerçek fontla tasarlanan genişliğe sığar (sığmayan yazı düğmeyi büyütür, ölçüyü
## gizlerdi; bu yüzden custom_minimum_size'a göre) ve düğme tasarlanan boyunda kalır.
static func button_fit_problems(button: Button) -> Array[String]:
	var problems: Array[String] = []
	var text: String = button.text
	if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		text = button.tr(button.text)
	var font: Font = button.get_theme_font(&"font")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			button.get_theme_font_size(&"font_size")).x
	var room: float = button.custom_minimum_size.x - 2.0 * NeonButton.BORDER_PX * 4.0
	if width > room:
		problems.append("'%s' %.0f px > %.0f" % [text, width, room])
	if button.size != button.custom_minimum_size:
		problems.append("%s büyüdü: %s" % [button.name, button.size])
	problems.append_array(glyph_problems(font, text))
	return problems


## Tek satırlık yazı, gerçek fontla ölçülen genişliğiyle verilen genişliğe sığar.
static func label_fit_problems(label: Label, room: float) -> Array[String]:
	var problems: Array[String] = []
	var width: float = label.get_minimum_size().x
	if width > room:
		problems.append("'%s' %.0f px > %.0f" % [label.text, width, room])
	problems.append_array(glyph_problems(label_font(label), label.text))
	return problems


## Yazılar ve düğme yazıları en az MIN_FONT_PX boyunda (kaydırıcının yazısı yok).
static func font_size_problems(items: Array[Control]) -> Array[String]:
	var problems: Array[String] = []
	for item: Control in items:
		if item is Slider:
			continue
		var size: int = item.get_theme_font_size(&"font_size")
		var label: Label = item as Label
		if label != null and label.label_settings != null:
			size = label.label_settings.font_size
		if size < MIN_FONT_PX:
			problems.append("%s %d px < %d" % [item.name, size, MIN_FONT_PX])
	return problems


## Font metnin her harfini içerir (boşluk ve satır sonu gibi denetim karakterleri çizilmez).
static func glyph_problems(font: Font, text: String) -> Array[String]:
	var problems: Array[String] = []
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code > 32 and not font.has_char(code):
			problems.append("fontta yok: '%s'" % text[index])
	return problems


## Yazının gösterildiği font (LabelSettings'te yoksa temadan).
static func label_font(label: Label) -> Font:
	if label.label_settings != null and label.label_settings.font != null:
		return label.label_settings.font
	return label.get_theme_font(&"font")


## Neon düğme yazısının dolgu üstündeki kontrastı (dolgu zeminin üstünde): açık ≥ 4,5, kapalı ≥ 3.
static func button_contrast_problems(ground: Color) -> Array[String]:
	var problems: Array[String] = []
	var fill: Color = ground.blend(NeonButton.FILL)
	var normal: float = ColorMetrics.contrast_ratio(NeonButton.TEXT, fill)
	if normal < MIN_CONTRAST:
		problems.append("düğme %.2f" % normal)
	var off: float = ColorMetrics.contrast_ratio(NeonButton.TEXT_DISABLED, fill)
	if off < MIN_DISABLED_CONTRAST:
		problems.append("kapalı düğme %.2f" % off)
	return problems


## Yazının çekirdek renginin zemindeki kontrastı ≥ 4,5.
static func label_contrast_problems(label: Label, ground: Color) -> Array[String]:
	var ratio: float = ColorMetrics.contrast_ratio(label.label_settings.font_color, ground)
	if ratio < MIN_CONTRAST:
		return ["%s '%s' %.2f" % [label.name, label.text, ratio]]
	return []


## Öğe kaydırılan bir liste ya da onun içinde.
static func _scrolls(item: Node) -> bool:
	var node: Node = item
	while node != null:
		if node is ScrollContainer:
			return true
		node = node.get_parent()
	return false


## İki dikdörtgen arasındaki en kısa boşluk (çakışıyorsa 0).
static func _touchable(item: Control) -> bool:
	return item is Button or item is Slider


static func _gap(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy: float = maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()
