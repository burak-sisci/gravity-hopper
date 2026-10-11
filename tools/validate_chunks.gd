extends SceneTree
## Desen parçası doğrulama aracı (M2-05, architecture.md §8.2). Kütüphanedeki her parçayı
## izinli her sektör hızında ChunkValidator ile dener; kamera kuralını ve sektör kapsamını denetler.
## tools/check.ps1 çalıştırır. Kullanım:
##   <godot> --headless --path . --script res://tools/validate_chunks.gd [-- <parça.tscn> ...]
## Sahne yolu verilirse kütüphane yerine yalnızca onlar denenir (yeni parça tasarlarken).
## Çıkış kodu 0 = bütün parçalar adil.

const LIBRARY_PATH: String = "res://data/chunks/chunk_library.tres"
const TUNING_PATH: String = "res://data/tuning/default_tuning.tres"
const SECTORS_PATH: String = "res://data/sectors/sector_catalog.tres"


func _initialize() -> void:
	var scenes: Array[PackedScene] = []
	for path: String in OS.get_cmdline_user_args():
		scenes.append(load(path) as PackedScene)
	var from_library: bool = scenes.is_empty()
	if from_library:
		scenes = (load(LIBRARY_PATH) as ChunkLibrary).chunks
	var tuning: TuningConfig = load(TUNING_PATH) as TuningConfig
	var sectors: SectorCatalog = load(SECTORS_PATH) as SectorCatalog
	var validator: ChunkValidator = ChunkValidator.new(
			tuning, ChunkValidator.player_body_size(), sectors)
	var errors: int = 0
	var trials: int = 0
	var chunks: Array[ChunkInfo] = []
	for scene: PackedScene in scenes:
		var chunk: ChunkInfo = scene.instantiate() as ChunkInfo
		if chunk == null:
			print("PARÇA HATA %s: kök ChunkInfo değil" % scene.resource_path)
			errors += 1
			continue
		chunks.append(chunk)
		trials += maxi(0, mini(chunk.max_sector, sectors.count()) - chunk.min_sector + 1)
		for message: String in validator.chunk_errors(chunk):
			print("PARÇA HATA %s: %s" % [scene.resource_path.get_file(), message])
			errors += 1
	var global_errors: PackedStringArray = validator.view_errors()
	if from_library:
		global_errors.append_array(validator.coverage_errors(chunks))
	for message: String in global_errors:
		print("PARÇA HATA %s" % message)
		errors += 1
	for chunk: ChunkInfo in chunks:
		chunk.free()
	print("PARÇALAR: %d parça, %d sektör denemesi, %d hata" % [chunks.size(), trials, errors])
	quit(1 if errors > 0 else 0)
