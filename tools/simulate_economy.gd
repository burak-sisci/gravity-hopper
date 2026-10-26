extends SceneTree
## Ekonomi benzetimi aracı (M4-14, architecture.md §13.1): her profilden oyuncular oynatır;
## "kaç turda, kaç günde ne alınır?" tablosunu basar (architecture.md'ye olduğu gibi konur).
## Kullanım:
##   <godot> --headless --path . --script res://tools/simulate_economy.gd [-- --players=200
##   --seeds=48 --glimmer-value=N --sector-bonus=N]
## Son ikisi "ya şöyle olsaydı" denemesidir: ayar yalnızca bellekte değişir.
## Rapor betiği ilk karede yolundan yüklenir: benzetim oyundaki ChunkSpawner'ı kullanır, o da
## Events autoload'una bağlıdır; autoload'lar bu betik derlenirken henüz yoktur
## (tools/check_scripts.gd ile aynı yol).

const REPORT_PATH: String = "res://tools/economy_report.gd"

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var report: RefCounted = (load(REPORT_PATH) as GDScript).new() as RefCounted
	quit(report.call("run", root, OS.get_cmdline_user_args()) as int)
	return true
