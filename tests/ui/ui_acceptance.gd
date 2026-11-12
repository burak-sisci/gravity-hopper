extends RefCounted
## Ortak UI kabulü (roadmap M5 "UI kabulü", architecture.md §5.3): menü, sonuç ve sonraki ekranların
## testleri aynı ölçüleri ve eşikleri kullanır. Her işlev sorunları metin listesi olarak döndürür;
## test listenin boş olduğunu doğrular (hata mesajında öğe ve değer yazar).

## En-boy oranları (genişlik / yükseklik): 9:16, 9:19,5, 9:21, 3:4 (tablet), 4:3 (yatay tablet).
const ASPECTS: Array[float] = [9.0 / 16.0, 9.0 / 19.5, 9.0 / 21.0, 3.0 / 4.0, 4.0 / 3.0]
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


## Oranı verilen ekranın tuval boyutu (stretch "expand", taban 1080 × 1920).
static func canvas_size(aspect: float) -> Vector2i:
	var base: Vector2 = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	var size: Vector2 = Vector2(base.x, base.x / aspect)
	if aspect > base.x / base.y:
		size = Vector2(base.y * aspect, base.y)
	return Vector2i(size.round())


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


## Font metnin her harfini içerir.
static func glyph_problems(font: Font, text: String) -> Array[String]:
	var problems: Array[String] = []
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code != 32 and not font.has_char(code):
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


## İki dikdörtgen arasındaki en kısa boşluk (çakışıyorsa 0).
static func _touchable(item: Control) -> bool:
	return item is Button or item is Slider


static func _gap(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy: float = maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()
