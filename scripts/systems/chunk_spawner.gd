class_name ChunkSpawner
extends Node2D
## Desen parçası yerleştirici (architecture.md §8.2, M2-04). Görünür alanın üstünde iki ekranlık
## alanı parçalarla dolu tutar; tamamen ekranın altına inen parça havuzuna döner. Parçalar art
## arda, boşluksuz dizilir: her parçanın alt kenarı bir öncekinin üst kenarıdır (vuruş ızgarası).
##
## Sektörler (M2-08): her sektör kendi vuruş boyuyla dizilir ve ızgarası sektörün başladığı
## yükseklikten başlar. Sektörün sonuna sığmayan kalan boş bırakılır; parça sınırı aşmaz.
##
## Belirlenimcilik: sıradaki parçayı yalnızca RunRng ve sektör seçer; ekran boyu yalnızca
## parçanın ne zaman yerleştiğini değiştirir, hangisi olduğunu değil. Bu yüzden Run.rng'yi
## yalnızca bu düğüm çeker. Havuzlar en uzun ekrana göre kurulur; tükenmeleri seçimi değiştirmez.
## Her yerleştirmede Events.chunk_placed yayar (debug olay günlüğü, zorluk ölçümü).

## Görünür alanın üstünde dolu tutulan alan (ekran boyu cinsinden).
const AHEAD_SCREENS: float = 2.0
## Parçanın üst kenarı görünür alanın bu kadar altına inince havuza döner.
const RELEASE_MARGIN: float = 100.0
## Sınır karşılaştırmalarında kayan nokta payı (px).
const EDGE_EPSILON: float = 0.01

## Seçilebilecek parçalar.
@export var library: ChunkLibrary

## Yerleştirme günlüğü: sırayla her parçanın adı ve alt kenarı (testler, belirlenimcilik).
var placed_names: Array[StringName] = []
var placed_bottoms: Array[float] = []

var _rng: RunRng
var _sectors: SectorCatalog
## Sıradaki parçanın yerleşeceği sektör (oyuncunun sektöründen önde gider).
var _sector: int = 1
## Başlangıç sektörünün başladığı yükseklik (m) ve dünyadaki y'si.
var _base_height: float = 0.0
var _start_y: float = 0.0
var _pools: Array[ObjectPool] = []
var _ids: Array[StringName] = []
var _active: Array[ChunkInfo] = []
var _active_pools: Array[ObjectPool] = []
var _next_bottom: float = 0.0
var _half_width: float = 0.0


## Havuzları kurar ve ilk parçanın yerini belirler. İlk parça, start_y'nin üstünde
## run_start_gap'e en yakın tam vuruş katında başlar (ızgara turun başından hizalı).
func setup(rng: RunRng, tuning: TuningConfig, sectors: SectorCatalog, start_sector: int,
		start_y: float) -> void:
	_rng = rng
	_sectors = sectors
	_sector = start_sector
	_base_height = sectors.start_height(start_sector)
	_start_y = start_y
	# Kopya sayısı en kısa vuruşa (en sık parçaya) göre: alan / parça boyu + 1.
	var min_beat: float = sectors.min_beat_px()
	var span: float = Corridor.MAX_VIEW_HEIGHT * (1.0 + AHEAD_SCREENS) + RELEASE_MARGIN
	for scene: PackedScene in library.chunks:
		var pool: ObjectPool = ObjectPool.new(scene, self)
		var info: ChunkInfo = pool.peek() as ChunkInfo
		pool.reserve(ceili(span / info.height_px(min_beat)) + 1)
		_pools.append(pool)
		_ids.append(StringName(scene.resource_path.get_file().get_basename()))
	var beat: float = sectors.def_at(start_sector).beat_px()
	_next_bottom = start_y - ceilf(TuningConfig.to_px(tuning.run_start_gap) / beat) * beat


## Ekranın altında kalan parçaları havuza döndürür, sonra görünür alana göre parça ekler
## (önce iade: havuzdaki kopya sayısı en kötü durumu karşılar).
func update_view(view_top: float, view_bottom: float, half_width: float) -> void:
	if not is_equal_approx(half_width, _half_width):
		_half_width = half_width
		for chunk: ChunkInfo in _active:
			chunk.layout(chunk.laid_out_beat_px, half_width)
	while not _active.is_empty() and _active[0].top_y() > view_bottom + RELEASE_MARGIN:
		var pool: ObjectPool = _active_pools.pop_front()
		var chunk: ChunkInfo = _active.pop_front()
		pool.release(chunk)
	var fill_top: float = view_top - (view_bottom - view_top) * AHEAD_SCREENS
	while _next_bottom > fill_top:
		if not _place_next():
			break


## Etkin parçalar, alttan üste.
func active_chunks() -> Array[ChunkInfo]:
	return _active.duplicate()


## Sıradaki parçanın yerleşeceği sektör (testler).
func placement_sector() -> int:
	return _sector


## Havuzlar tükenip tur sırasında örnek oluşturuldu mu? (testler)
func pools_grown() -> int:
	var total: int = 0
	for pool: ObjectPool in _pools:
		total += pool.grown
	return total


## Sektörün bittiği dünya y'si; son sektör bitmez (-INF).
func _end_y(sector: int) -> float:
	return _start_y - TuningConfig.to_px(_sectors.end_height(sector) - _base_height)


func _place_next() -> bool:
	var end_y: float = _end_y(_sector)
	if _next_bottom <= end_y + EDGE_EPSILON:
		# Sınıra varıldı: sonraki sektörün ızgarası tam sınırdan başlar.
		_next_bottom = end_y
		_sector += 1
		return true
	var beat: float = _sectors.def_at(_sector).beat_px()
	var room: float = _next_bottom - end_y
	var allowed: bool = false
	var candidates: Array[int] = []
	var weights: Array[float] = []
	for i: int in _pools.size():
		var info: ChunkInfo = _pools[i].peek() as ChunkInfo
		if not info.allows_sector(_sector):
			continue
		allowed = true
		if info.height_px(beat) <= room + EDGE_EPSILON:
			candidates.append(i)
			# Eşit ağırlık; sektör içi zorluk eğrisi M2-10'da.
			weights.append(1.0)
	if not allowed:
		push_error("ChunkSpawner: sektör %d için parça yok" % _sector)
		return false
	if candidates.is_empty():
		# Sektörün sonuna hiçbir parça sığmıyor: kalan boş kalır.
		_next_bottom = end_y
		return true
	var index: int = candidates[_rng.weighted_index(weights)]
	var chunk: ChunkInfo = _pools[index].acquire() as ChunkInfo
	chunk.position = Vector2(0.0, _next_bottom)
	chunk.layout(beat, _half_width)
	chunk.reset_physics_interpolation()
	_active.append(chunk)
	_active_pools.append(_pools[index])
	placed_names.append(_ids[index])
	placed_bottoms.append(_next_bottom)
	_next_bottom = chunk.top_y()
	Events.chunk_placed.emit(_ids[index], chunk.difficulty)
	return true
