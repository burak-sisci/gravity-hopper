extends GdUnitTestSuite
## Oyunun fontu (M3-17, S-06): proje fontu Exo 2 kalın; Türkçe harfler ve oyunun işaretleri var.

## Oyuncunun göreceği Türkçe harfler ve HUD'un kullandığı işaretler (×2, "S2 · VERİ AKIŞI", %).
const NEEDED: String = "ÇĞİÖŞÜçğıöşü×·!?%0123456789"
const BOLD: int = 700


func test_project_font_is_exo2_bold() -> void:
	var font: FontVariation = _project_font()
	assert_object(font).is_not_null()
	assert_str(font.base_font.get_font_name()).is_equal("Exo 2")
	# Ağırlık ekseni sayı etiketiyle yazılmalı; "wght" metin anahtarı Godot'da etkisiz kalıyor.
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	assert_int(int(font.variation_opentype.get(tag, 0))).is_equal(BOLD)


func test_font_has_turkish_glyphs() -> void:
	var font: FontVariation = _project_font()
	for i: int in NEEDED.length():
		assert_bool(font.has_char(NEEDED.unicode_at(i))).override_failure_message(
				"Fontta eksik harf: %s" % NEEDED[i]).is_true()


func _project_font() -> FontVariation:
	var path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	return load(path) as FontVariation
