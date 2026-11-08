extends SceneTree
## Glimmer yerleştirme aracı (M4-16, architecture.md §8.2). Kütüphanedeki her parçanın
## Glimmer'larını silip yeniden yerleştirir: adaylar beş şeritte (x = −400, −200, 0, 200, 400)
## ve her yarım vuruştadır. ChunkValidator'ın Glimmer kurallarını (adil yolda toplanır, riskli
## yolda, tehlike çizimine binmez) her izinli sektör ve tempoda geçen adaylar kalır. Dizi: önce
## tek bir adil yolda en çoğu birlikte toplanabilen adaylar (ChunkValidator.pickup_path), sonra
## öbürleri; her grupta tehlikeye dikeyde en yakın olan önce, her yarım vuruşta en çok bir tane,
## hedef sayıya kadar.
## Hedef = vuruş sayısı × min(1, taban + adım × (zorluk − 1)): zor parçalar (üst sektörler) daha
## yoğun (GDD §9.1). Araç yeniden çalıştırılabilir; sonuç hep aynıdır.
## Kullanım:
##   <godot> --headless --path . --script res://tools/place_glimmers.gd
##       [-- --base=0.5 --step=0.08 --dry <parça.tscn> ...]
## --dry: dosyalara yazmaz, yalnızca sayıları basar. Ardından tools/validate_chunks.gd ve
## ekonomi benzetimi (tools/simulate_economy.gd) çalıştırılır.

const LIBRARY_PATH: String = "res://data/chunks/chunk_library.tres"
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SECTORS_PATH: String = "res://data/sectors/sector_catalog.tres"
const MUSIC_PATH: String = "res://data/music/music_catalog.tres"
const GLIMMER_PATH: String = "res://scenes/entities/glimmer.tscn"
const GLIMMER_RESOURCE_ID: String = "9_glimmer"
## Aday şeritleri (tasarım px) ve adlardaki kısaltmaları.
const LANES: Array[float] = [-400.0, -200.0, 0.0, 200.0, 400.0]
const LANE_TAGS: Array[String] = ["LL", "L", "M", "R", "RR"]
const DEFAULT_BASE: float = 0.5
const DEFAULT_STEP: float = 0.08

var _base: float = DEFAULT_BASE
var _step: float = DEFAULT_STEP
var _dry: bool = false
## Son parçada seçilenlerden tek bir adil yolda birlikte toplananların sayısı.
var _on_path: int = 0


func _initialize() -> void:
	var paths: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--base="):
			_base = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--step="):
			_step = arg.get_slice("=", 1).to_float()
		elif arg == "--dry":
			_dry = true
		else:
			paths.append(arg)
	if paths.is_empty():
		for scene: PackedScene in (load(LIBRARY_PATH) as ChunkLibrary).chunks:
			paths.append(scene.resource_path)
	var validator: ChunkValidator = ChunkValidator.new(load(TUNING_PATH) as TuningConfig,
			ChunkValidator.player_body_size(), load(SECTORS_PATH) as SectorCatalog,
			load(MUSIC_PATH) as MusicCatalog)
	var glimmer_scene: PackedScene = load(GLIMMER_PATH) as PackedScene
	var total: int = 0
	var short: int = 0
	var on_path: int = 0
	for path: String in paths:
		var chunk: ChunkInfo = (load(path) as PackedScene).instantiate() as ChunkInfo
		var chosen: Array[Vector2] = _place(chunk, validator, glimmer_scene)
		var target: int = _target(chunk)
		total += chosen.size()
		if chosen.size() < target:
			short += 1
		print("%-28s zorluk %d, %2d vuruş: %2d / %2d Glimmer, tek yolda %2d" % [
			path.get_file(), chunk.difficulty, chunk.length_beats, chosen.size(), target, _on_path,
		])
		on_path += _on_path
		chunk.free()
		if not _dry:
			_write(path, chosen)
	print("GLIMMER: %d parça, %d Glimmer (%d'i tek yolda birlikte), hedefin altında %d parça%s" % [
		paths.size(), total, on_path, short, " (yazılmadı)" if _dry else "",
	])
	quit()


func _target(chunk: ChunkInfo) -> int:
	var per_beat: float = minf(1.0, _base + _step * (chunk.difficulty - 1))
	return roundi(chunk.length_beats * per_beat)


## Seçilen Glimmer konumları (tasarım px), aşağıdan yukarı.
func _place(chunk: ChunkInfo, validator: ChunkValidator,
		glimmer_scene: PackedScene) -> Array[Vector2]:
	var hazard_ys: Array[float] = []
	for item: Node2D in chunk.items():
		if item is Glimmer:
			chunk.remove_child(item)
			item.free()
		else:
			hazard_ys.append(item.position.y)
	var candidates: Array[Glimmer] = []
	for row: int in range(1, chunk.length_beats * 2):
		for lane: int in LANES.size():
			var glimmer: Glimmer = glimmer_scene.instantiate() as Glimmer
			glimmer.name = "Candidate%d_%d" % [row, lane]
			glimmer.position = Vector2(LANES[lane], -row * ChunkInfo.Y_STEP_PX)
			chunk.add_child(glimmer)
			candidates.append(glimmer)
	var errors: PackedStringArray = validator.chunk_errors(chunk)
	var fit: Array[Vector2] = []
	for glimmer: Glimmer in candidates:
		var rejected: bool = false
		for message: String in errors:
			if message.contains(String(glimmer.name) + " "):
				rejected = true
				break
		if rejected:
			chunk.remove_child(glimmer)
			glimmer.free()
		else:
			fit.append(glimmer.position)
	# Önce dizi: en yavaş izinli sektörde ve orta tempoda, adil yollardan en çok uygun adayı
	# toplayan yolun topladıkları. Sonra (hedefe varılmadıysa) öbür yollardaki adaylar.
	var tempos: Array[float] = validator.tempos()
	tempos.sort()
	var path: Array[Vector2] = []
	var middle_bpm: float = tempos[floori(tempos.size() / 2.0)]
	for glimmer: Glimmer in validator.pickup_path(chunk, chunk.min_sector, middle_bpm):
		path.append(glimmer.position)
	var risk: Callable = func(at: Vector2) -> float:
		var nearest: float = INF
		for y: float in hazard_ys:
			nearest = minf(nearest, absf(at.y - y))
		return nearest
	# Tehlikeye dikeyde en yakın olan önce; eşitlikte orta şeride yakın olan, sonra aşağıdaki.
	var riskier: Callable = func(a: Vector2, b: Vector2) -> bool:
		var ra: float = risk.call(a)
		var rb: float = risk.call(b)
		if ra != rb:
			return ra < rb
		if absf(a.x) != absf(b.x):
			return absf(a.x) < absf(b.x)
		if a.y != b.y:
			return a.y > b.y
		return a.x < b.x
	path.sort_custom(riskier)
	fit.sort_custom(riskier)
	var chosen: Array[Vector2] = []
	var used_rows: Dictionary[float, bool] = {}
	var target: int = _target(chunk)
	for at: Vector2 in path + fit:
		if chosen.size() >= target:
			break
		if used_rows.has(at.y):
			continue
		used_rows[at.y] = true
		chosen.append(at)
	_on_path = 0
	for at: Vector2 in chosen:
		if path.has(at):
			_on_path += 1
	chosen.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
	return chosen


## Parça dosyasındaki Glimmer düğümlerini seçilenlerle değiştirir (metin olarak; başka düğüme
## ve biçime dokunmaz).
func _write(path: String, chosen: Array[Vector2]) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var id: String = _glimmer_id(text)
	if id.is_empty():
		id = GLIMMER_RESOURCE_ID
		var line: String = '[ext_resource type="PackedScene" path="%s" id="%s"]' % [GLIMMER_PATH, id]
		var last: int = text.rfind("[ext_resource ")
		var at: int = text.find("\n", last) + 1
		text = text.substr(0, at) + line + "\n" + text.substr(at)
	var marker: String = 'instance=ExtResource("%s")]' % id
	var blocks: PackedStringArray = text.strip_edges(false, true).split("\n\n")
	var kept: PackedStringArray = PackedStringArray()
	for block: String in blocks:
		if not (block.begins_with("[node ") and block.get_slice("\n", 0).ends_with(marker)):
			kept.append(block)
	for at: Vector2 in chosen:
		var beat: String = String.num(-at.y / ChunkInfo.BEAT_GRID_PX, 1).replace(".", "_")
		var lane: String = LANE_TAGS[LANES.find(at.x)]
		kept.append('[node name="Glimmer%s%s" parent="." %s\nposition = Vector2(%d, %d)' % [
			lane, beat.trim_suffix("_0"), marker, roundi(at.x), roundi(at.y),
		])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n\n".join(kept) + "\n")


func _glimmer_id(text: String) -> String:
	for line: String in text.split("\n"):
		if line.begins_with("[ext_resource ") and line.contains('path="%s"' % GLIMMER_PATH):
			return line.get_slice('id="', 1).get_slice('"', 0)
	return ""
