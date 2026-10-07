extends Node2D
## Sahne aracı deneme düzeneği (M0-11). Bilerek bozuk başvurular içerir; normal denetime girmez.
## Beklenen: `scene_tool.gd -- check --dir res://tools/fixtures` tam 7 hata bulur ve 1 ile çıkar.
## Tuzaklar (hata SAYILMAMALI): mod işlemi, biçimlendirme, yorum ve metin içindeki yollar,
## has_node(), başka bir düğüm üzerinde get_node().

@export var target: Node2D

var mod_result: int = 7 % 3
var formatted: String = "%d adet" % 5
var note: String = "get_node(\"Ghost\") ve $Ghost burada yalnızca metin"
var found: Node = null
var missing: Node = null
var parent_node: Node = null
var sibling: Node = null

@onready var label: Label = %Label # doğru
@onready var label_typo: Label = %Labell # HATA 1: yazım hatası
@onready var child: Node2D = $Container/Child # doğru
@onready var child_typo: Node2D = $Contaner/Child # HATA 2: yazım hatası


func run_checks() -> void:
	# $Ghost bu bir yorum
	found = get_node_or_null("Container") # doğru
	missing = get_node("Missing") # HATA 3
	parent_node = get_parent() # HATA 4: kural ihlali
	sibling = $"../Sibling" # HATA 5: kural ihlali
	if has_node("Nope"):
		found = label.get_node("Ghost")


func _on_container_visibility_changed() -> void:
	pass
# HATA 6: sahnedeki ikinci bağlantının metodu yok. HATA 7: @export target yolu yanlış.
