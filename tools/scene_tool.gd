extends SceneTree
## Sahne aracı (M0-11, architecture.md §13.1): oyunu çalıştırmadan sahneleri okur ve denetler.
##
## Kullanım (proje kökünde):
##   <godot> --headless --path . --script res://tools/scene_tool.gd -- tree res://scenes/main.tscn
##   <godot> --headless --path . --script res://tools/scene_tool.gd -- check [--dir res://klasör]
## tree : düğüm ağacı (ad, tür, %benzersiz ad, betik, örneklenen sahne, gruplar, bağlantılar).
## check: betiklerdeki $Yol, %Ad ve get_node("...") başvurularını, sahnelerdeki sinyal
##        bağlantılarını ve @export düğüm yollarını sahnelere karşı denetler. get_parent() ve
##        ".." içeren yollar kural ihlalidir (.clauderules §3). Hata varsa çıkış kodu 1.
## Sahneler ağaca eklenmeden örneklenir: yalnızca _init çalışır, _ready çalışmaz. Başvurular
## Godot'nun kendi get_node_or_null() çözümlemesiyle denenir; %Ad sahiplik kuralı aynen geçerlidir.

const DEFAULT_DIR: String = "res://"
## Varsayılan taramada atlanır: motor önbelleği, dış eklentiler, araçlar (deneme düzenekleri
## dahil) ve testler.
const SKIP_DIRS: Array[String] = ["res://.godot", "res://addons", "res://tools", "res://tests"]
const NODE_PATH_FUNCS: Array[String] = ["get_node", "get_node_or_null"]
## Bu sözcüklerden sonra gelen % işareti mod işlemi değil, benzersiz ad başlangıcıdır.
const KEYWORDS: Array[String] = [
	"return", "and", "or", "not", "in", "if", "elif", "else", "while", "await", "match", "when",
]
const SUGGEST_MIN_SIMILARITY: float = 0.5
const EXIT_USAGE: int = 2

var _errors: int = 0
var _ref_count: int = 0
var _connection_count: int = 0
var _attached_scripts: Dictionary[String, bool] = {}
var _ref_cache: Dictionary[String, Array] = {}
var _reported_rules: Dictionary[String, bool] = {}


func _initialize() -> void:
	quit(_run(OS.get_cmdline_user_args()))


func _run(args: PackedStringArray) -> int:
	if args.size() >= 2 and args[0] == "tree":
		return _tree(args[1])
	if args.size() >= 1 and args[0] == "check":
		var dir: String = DEFAULT_DIR
		var dir_index: int = args.find("--dir")
		if dir_index >= 0 and dir_index + 1 < args.size():
			dir = args[dir_index + 1]
		return _check(dir)
	print("Kullanım: -- tree <res://sahne.tscn> | -- check [--dir res://klasör]")
	return EXIT_USAGE


# --- tree ---------------------------------------------------------------------------

func _tree(scene_path: String) -> int:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		print("HATA %s yüklenemedi" % scene_path)
		return 1
	var scene_root: Node = packed.instantiate()
	print(scene_path)
	_print_node(scene_root, scene_root, "", true, true)
	var lines: PackedStringArray = _connection_lines(scene_root, scene_root)
	if not lines.is_empty():
		print("Bağlantılar:")
		for line: String in lines:
			print("  " + line)
	scene_root.free()
	return 0


func _print_node(node: Node, scene_root: Node, prefix: String,
		is_last: bool, is_root: bool) -> void:
	if is_root:
		print(_describe(node, scene_root))
	else:
		print(prefix + ("└── " if is_last else "├── ") + _describe(node, scene_root))
	var child_prefix: String = "" if is_root else prefix + ("    " if is_last else "│   ")
	var children: Array[Node] = node.get_children()
	for i: int in children.size():
		_print_node(children[i], scene_root, child_prefix, i == children.size() - 1, false)


func _describe(node: Node, scene_root: Node) -> String:
	var text: String = ("%" if node.is_unique_name_in_owner() else "") + String(node.name)
	var script: Script = node.get_script() as Script
	var type_name: String = node.get_class()
	if script != null and not String(script.get_global_name()).is_empty():
		type_name += ":" + String(script.get_global_name())
	text += " (%s)" % type_name
	if script != null:
		text += "  betik=" + script.resource_path
	if node != scene_root and not node.scene_file_path.is_empty():
		text += "  [sahne: %s]" % node.scene_file_path
	var groups: PackedStringArray = PackedStringArray()
	for group: StringName in node.get_groups():
		if not String(group).begins_with("_"):
			groups.append(String(group))
	if not groups.is_empty():
		text += "  {%s}" % ", ".join(groups)
	return text


## Sahneden gelen (kalıcı) sinyal bağlantıları: "Kaynak.sinyal → Hedef.metot()".
func _connection_lines(node: Node, scene_root: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for info: Dictionary in node.get_signal_list():
		var signal_name: StringName = info["name"]
		for connection: Dictionary in node.get_signal_connection_list(signal_name):
			var flags: int = connection["flags"]
			if (flags & CONNECT_PERSIST) == 0:
				continue
			var callable: Callable = connection["callable"]
			var target: Node = callable.get_object() as Node
			var target_name: String = "?"
			if target != null:
				target_name = _state_path_label(scene_root.get_path_to(target), scene_root)
			lines.append("%s.%s → %s.%s()" % [
				scene_root.get_path_to(node), signal_name, target_name, callable.get_method(),
			])
	for child: Node in node.get_children():
		lines.append_array(_connection_lines(child, scene_root))
	return lines


# --- check --------------------------------------------------------------------------

func _check(dir: String) -> int:
	var scenes: Array[String] = []
	var scripts: Array[String] = []
	_collect(dir, scenes, scripts)
	for scene_path: String in scenes:
		_check_scene(scene_path)

	# Hiçbir sahneye bağlı olmayan betikler: kural ihlalleri yine hata, yollar ise denetlenemez.
	var unchecked: int = 0
	for script_path: String in scripts:
		if _attached_scripts.has(script_path):
			continue
		for ref: Dictionary in _refs_of(script_path):
			if not _is_rule_violation(script_path, ref):
				unchecked += 1

	print("SAHNE: %d sahne, %d başvuru, %d bağlantı, %d hata" % [
		scenes.size(), _ref_count, _connection_count, _errors,
	])
	if unchecked > 0:
		print("NOT  %d düğüm başvurusu hiçbir sahneye bağlı olmayan betiklerde; denetlenmedi" % unchecked)
	return 1 if _errors > 0 else 0


func _collect(dir_path: String, scenes: Array[String], scripts: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		var sub_path: String = dir_path.path_join(sub)
		if not sub_path in SKIP_DIRS:
			_collect(sub_path, scenes, scripts)
	for file: String in dir.get_files():
		var file_path: String = dir_path.path_join(file)
		match file.get_extension():
			"tscn", "scn":
				scenes.append(file_path)
			"gd":
				scripts.append(file_path)


func _check_scene(scene_path: String) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		_report(scene_path, "sahne yüklenemedi")
		return
	var scene_root: Node = packed.instantiate()
	if scene_root == null:
		_report(scene_path, "sahne örneklenemedi")
		return
	_check_scripts_in(scene_path, scene_root, scene_root)
	_check_connections(scene_path, packed.get_state(), scene_root)
	_check_exported_paths(scene_path, packed.get_state(), scene_root)
	scene_root.free()


## Bu sahne dosyasına ait düğümlerin betiklerini denetler. Örneklenen alt sahnelerin
## düğümleri, o alt sahne dosyası denetlenirken ele alınır (aynı hata iki kez yazılmasın).
func _check_scripts_in(scene_path: String, node: Node, scene_root: Node) -> void:
	var own: bool = node == scene_root \
			or (node.owner == scene_root and node.scene_file_path.is_empty())
	if own:
		var script: Script = node.get_script() as Script
		while script != null and script.resource_path.begins_with("res://") \
				and not script.resource_path.begins_with("res://addons"):
			_attached_scripts[script.resource_path] = true
			for ref: Dictionary in _refs_of(script.resource_path):
				_check_ref(scene_path, node, scene_root, script.resource_path, ref)
			script = script.get_base_script()
	for child: Node in node.get_children():
		_check_scripts_in(scene_path, child, scene_root)


func _check_ref(scene_path: String, node: Node, scene_root: Node,
		script_path: String, ref: Dictionary) -> void:
	if _is_rule_violation(script_path, ref):
		return
	var where: String = _node_label(node, scene_root)
	var path: String = ref["path"]
	if path.begins_with("/"):
		return # Mutlak yol: ağaç dışında denetlenemez.
	_ref_count += 1
	if node.get_node_or_null(NodePath(path)) != null:
		return
	var line: int = ref["line"]
	_report(scene_path, "%s: %s:%d \"%s\" bulunamadı%s" % [
		where, script_path, line, path, _suggest_node(node, path),
	])


## get_parent() çağrısı ya da ".." içeren yol kural ihlalidir. Betik birden çok sahnede
## kullanılsa da her ihlal bir kez raporlanır.
func _is_rule_violation(script_path: String, ref: Dictionary) -> bool:
	var kind: String = ref["kind"]
	var path: String = ref["path"]
	var message: String = ""
	if kind == "parent":
		message = "get_parent() kullanılmaz; ebeveyne sinyalle haber verilir"
	elif ".." in path.split("/"):
		message = "\"%s\": yukarı çıkan yol kullanılmaz; %%Ad ya da @export kullanılır" % path
	if message.is_empty():
		return false
	var key: String = "%s:%d:%s" % [script_path, ref["line"], path]
	if not _reported_rules.has(key):
		_reported_rules[key] = true
		_errors += 1
		print("KURAL %s:%d %s (.clauderules §3)" % [script_path, ref["line"], message])
	return true


func _check_connections(scene_path: String, state: SceneState, scene_root: Node) -> void:
	for i: int in state.get_connection_count():
		_connection_count += 1
		var signal_name: StringName = state.get_connection_signal(i)
		var method: StringName = state.get_connection_method(i)
		var source: Node = scene_root.get_node_or_null(state.get_connection_source(i))
		var target: Node = scene_root.get_node_or_null(state.get_connection_target(i))
		var label: String = "bağlantı %s.%s → %s.%s()" % [
			_state_path_label(state.get_connection_source(i), scene_root), signal_name,
			_state_path_label(state.get_connection_target(i), scene_root), method,
		]
		if source == null:
			_report(scene_path, label + ": kaynak düğüm yok")
		elif not source.has_signal(signal_name):
			_report(scene_path, label + ": kaynakta bu sinyal yok")
		if target == null:
			_report(scene_path, label + ": hedef düğüm yok")
		elif not target.has_method(method):
			var names: PackedStringArray = PackedStringArray()
			for info: Dictionary in target.get_method_list():
				names.append(String(info["name"]))
			_report(scene_path, label + ": hedefte bu metot yok" + _suggest(String(method), names))


## Sahnede kayıtlı NodePath özellikleri (@export düğüm başvuruları) çözülüyor mu?
func _check_exported_paths(scene_path: String, state: SceneState, scene_root: Node) -> void:
	for i: int in state.get_node_count():
		var node: Node = scene_root.get_node_or_null(state.get_node_path(i))
		if node == null:
			continue
		for p: int in state.get_node_property_count(i):
			var value: Variant = state.get_node_property_value(i, p)
			var paths: Array[NodePath] = []
			if value is NodePath:
				paths.append(value as NodePath)
			elif value is Array:
				for item: Variant in value as Array:
					if item is NodePath:
						paths.append(item as NodePath)
			for node_path: NodePath in paths:
				if node_path.is_empty():
					continue
				_ref_count += 1
				if node.get_node_or_null(node_path) == null:
					_report(scene_path, "%s: \"%s\" özelliğindeki yol \"%s\" çözülemedi" % [
						_node_label(node, scene_root), state.get_node_property_name(i, p), node_path,
					])


func _refs_of(script_path: String) -> Array:
	if not _ref_cache.has(script_path):
		_ref_cache[script_path] = find_node_refs(FileAccess.get_file_as_string(script_path))
	return _ref_cache[script_path]


func _node_label(node: Node, scene_root: Node) -> String:
	if node == scene_root:
		return String(scene_root.name)
	return String(scene_root.name) + "/" + String(scene_root.get_path_to(node))


## SceneState yolunu okunur hale getirir: "." → kök düğümün adı.
func _state_path_label(path: NodePath, scene_root: Node) -> String:
	var text: String = String(path).trim_prefix("./")
	return String(scene_root.name) if text == "." or text.is_empty() else text


func _report(scene_path: String, message: String) -> void:
	_errors += 1
	print("HATA %s → %s" % [scene_path, message])


## Bulunamayan yol için en benzer düğüm adını önerir.
func _suggest_node(node: Node, path: String) -> String:
	var candidates: PackedStringArray = PackedStringArray()
	if path.begins_with("%"):
		var scope: Node = node.owner if node.owner != null else node
		_collect_unique(scope, node, candidates)
	else:
		_collect_relative(node, node, candidates)
	return _suggest(path, candidates)


func _collect_unique(scope: Node, origin: Node, out: PackedStringArray) -> void:
	for child: Node in scope.get_children():
		if child.is_unique_name_in_owner() and (child.owner == origin or child.owner == origin.owner):
			out.append("%" + String(child.name))
		_collect_unique(child, origin, out)


func _collect_relative(base: Node, node: Node, out: PackedStringArray) -> void:
	for child: Node in node.get_children():
		out.append(String(base.get_path_to(child)))
		_collect_relative(base, child, out)


func _suggest(wrong: String, candidates: PackedStringArray) -> String:
	var best: String = ""
	var best_score: float = SUGGEST_MIN_SIMILARITY
	for candidate: String in candidates:
		var score: float = wrong.similarity(candidate)
		if score > best_score:
			best_score = score
			best = candidate
	return "" if best.is_empty() else ". Bunu mu demek istediniz: \"%s\"?" % best


# --- betik tarayıcı -----------------------------------------------------------------

## Betik kaynağındaki düğüm başvurularını bulur. Her öge: { "path": String, "line": int,
## "kind": "ref" | "parent" }. Yorumlar ve metin sabitleri atlanır; "a % b" mod işlemi
## benzersiz ad sayılmaz. Yalnızca kendi üzerinde çağrılan get_node("...") sayılır
## (başka.get_node(...) denetlenemez), has_node() sayılmaz.
static func find_node_refs(source: String) -> Array[Dictionary]:
	var refs: Array[Dictionary] = []
	var n: int = source.length()
	var i: int = 0
	var line: int = 1
	var prev_kind: String = "" # "ident", "operand", "punct"
	var prev_text: String = ""
	var pending: String = "" # get_node için: "name" → "(" bekleniyor, "open" → metin bekleniyor
	while i < n:
		var c: String = source[i]
		if c == "\n":
			line += 1
			i += 1
		elif c == " " or c == "\t" or c == "\r" or c == "\\":
			i += 1
		elif c == "#":
			while i < n and source[i] != "\n":
				i += 1
		elif c == "\"" or c == "'":
			var literal: Dictionary = _read_string(source, i)
			if pending == "open":
				refs.append({ "path": literal["value"], "line": line, "kind": "ref" })
			pending = ""
			line += int(literal["newlines"])
			i = literal["end"]
			prev_kind = "operand"
			prev_text = "\""
		elif c == "$":
			i += 1
			var path: String = ""
			if i < n and (source[i] == "\"" or source[i] == "'"):
				var quoted: Dictionary = _read_string(source, i)
				path = quoted["value"]
				line += int(quoted["newlines"])
				i = quoted["end"]
			else:
				var start: int = i
				i = _skip_unquoted_path(source, i)
				path = source.substr(start, i - start)
			refs.append({ "path": path, "line": line, "kind": "ref" })
			pending = ""
			prev_kind = "operand"
			prev_text = "$"
		elif c == "%" and i + 1 < n and _is_ident_start(source[i + 1]) \
				and prev_kind != "operand" and not (prev_kind == "ident" and not prev_text in KEYWORDS):
			var end: int = _skip_ident(source, i + 1)
			refs.append({ "path": source.substr(i, end - i), "line": line, "kind": "ref" })
			i = end
			pending = ""
			prev_kind = "operand"
			prev_text = "%"
		elif _is_ident_start(c):
			var end: int = _skip_ident(source, i)
			var ident: String = source.substr(i, end - i)
			var on_self: bool = prev_text != "."
			pending = "name" if ident in NODE_PATH_FUNCS and on_self else ""
			if ident == "get_parent" and on_self:
				refs.append({ "path": "", "line": line, "kind": "parent" })
			i = end
			prev_kind = "ident"
			prev_text = ident
		elif c >= "0" and c <= "9":
			# Ondalık nokta yalnızca ardından rakam geliyorsa sayıya dahildir (1.5 ama x[0].y değil).
			while i < n and (_is_ident_char(source[i])
					or (source[i] == "." and i + 1 < n and _is_digit(source[i + 1]))):
				i += 1
			pending = ""
			prev_kind = "operand"
			prev_text = "0"
		else:
			if c == "(" and pending == "name":
				pending = "open"
			elif not (c == "^" and pending == "open"):
				pending = ""
			prev_kind = "operand" if c in [")", "]", "}"] else "punct"
			prev_text = c
			i += 1
	return refs


## Metin sabitini okur (tek/çift tırnak, üçlü tırnak, kaçış karakterleri, r"" ham metin).
static func _read_string(source: String, start: int) -> Dictionary:
	var n: int = source.length()
	var quote: String = source[start]
	var triple: bool = source.substr(start, 3) == quote.repeat(3)
	var raw: bool = start > 0 and source[start - 1] == "r"
	var i: int = start + (3 if triple else 1)
	var value: String = ""
	var newlines: int = 0
	while i < n:
		var c: String = source[i]
		if c == "\\" and not raw and i + 1 < n:
			if source[i + 1] == "\n":
				newlines += 1
			value += source[i + 1]
			i += 2
			continue
		if triple and source.substr(i, 3) == quote.repeat(3):
			i += 3
			break
		if not triple and c == quote:
			i += 1
			break
		if c == "\n":
			newlines += 1
		value += c
		i += 1
	return { "value": value, "end": i, "newlines": newlines }


## $Ad/Çocuk, $%Ad ve $../Ad biçimindeki tırnaksız yolun sonunu bulur (".metot" dahil değil).
static func _skip_unquoted_path(source: String, start: int) -> int:
	var n: int = source.length()
	var i: int = start
	while i < n:
		if source.substr(i, 2) == "..":
			i += 2
		elif source[i] == "%" and i + 1 < n and _is_ident_start(source[i + 1]):
			i = _skip_ident(source, i + 1)
		elif _is_ident_start(source[i]):
			i = _skip_ident(source, i)
		else:
			break
		if i < n and source[i] == "/":
			i += 1
		else:
			break
	return i


static func _skip_ident(source: String, start: int) -> int:
	var i: int = start
	while i < source.length() and _is_ident_char(source[i]):
		i += 1
	return i


static func _is_ident_start(c: String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


static func _is_ident_char(c: String) -> bool:
	return _is_ident_start(c) or _is_digit(c)


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"
