class_name ChunkSpawner
extends Node2D
## Desen parçası yerleştirici (architecture.md §8.2, M2-04). Görünür alanın üstünde iki ekranlık
## alanı parçalarla dolu tutar; tamamen ekranın altına inen parça havuzuna döner. Parçalar art
## arda, boşluksuz dizilir: her parçanın alt kenarı bir öncekinin üst kenarıdır (vuruş ızgarası).
##
## Sektörler (M2-08): her sektör kendi vuruş boyuyla dizilir ve ızgarası sektörün başladığı
## yükseklikten başlar. Sektörün sonuna sığmayan kalan boş bırakılır; parça sınırı aşmaz.
## Yeni sektör, tam vuruşa yuvarlanmış bir "nefes alma" boşluğuyla başlar (M2-09).
##
## Zorluk eğrisi (M2-10): hedef zorluk, sektör içindeki ilerlemeyle SectorDef.min_difficulty'den
## max_difficulty'ye çıkar. Her parçanın ağırlığı zorluğunun hedefe yakınlığıyla çan eğrisi gibi
## azalır (genişlik TuningConfig.difficulty_spread). Son no_repeat_count parça yeniden seçilmez.
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

## Yerleştirme günlüğü: sırayla her parçanın adı, alt kenarı, zorluğu ve o andaki hedef zorluk
## (testler, belirlenimcilik, zorluk ölçümü).
var placed_names: Array[StringName] = []
var placed_bottoms: Array[float] = []
var placed_difficulties: Array[int] = []
var placed_targets: Array[float] = []

var _rng: RunRng
var _tuning: TuningConfig
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
	_tuning = tuning
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


## Etkin parçalardaki duvar boşlukları: (duvar -1/+1, üst y, alt y). Run koridora bildirir.
func active_gaps() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for chunk: ChunkInfo in _active:
		for gap: WallGap in chunk.gaps():
			var span: Vector2 = chunk.gap_range(gap)
			result.append(Vector3(gap.side(), span.x, span.y))
	return result


## Sıradaki parçanın yerleşeceği sektör (testler).
func placement_sector() -> int:
	return _sector


## Sıradaki parçanın yerinde hedef zorluk: sektör içindeki ilerlemeyle min → max (son sektör,
## boyunu aşınca en zor değerde kalır).
func target_difficulty() -> float:
	var def: SectorDef = _sectors.def_at(_sector)
	var sector_start: float = _start_y \
			- TuningConfig.to_px(_sectors.start_height(_sector) - _base_height)
	var climbed: float = sector_start - _next_bottom
	var progress: float = clampf(climbed / TuningConfig.to_px(def.length), 0.0, 1.0)
	return lerpf(def.min_difficulty, def.max_difficulty, progress)


## Havuzlar tükenip tur sırasında örnek oluşturuldu mu? (testler)
func pools_grown() -> int:
	var total: int = 0
	for pool: ObjectPool in _pools:
		total += pool.grown
	return total


## Son no_repeat_count parçayı çıkarır; hiçbiri kalmıyorsa (sektör sonu) kural esner.
func _without_recent(fitting: Array[int]) -> Array[int]:
	var first: int = maxi(0, placed_names.size() - _tuning.no_repeat_count)
	var recent: Array[StringName] = placed_names.slice(first)
	var result: Array[int] = []
	for i: int in fitting:
		if not recent.has(_ids[i]):
			result.append(i)
	return result if not result.is_empty() else fitting


## Sektörün bittiği dünya y'si; son sektör bitmez (-INF).
func _end_y(sector: int) -> float:
	return _start_y - TuningConfig.to_px(_sectors.end_height(sector) - _base_height)


func _place_next() -> bool:
	var end_y: float = _end_y(_sector)
	if _next_bottom <= end_y + EDGE_EPSILON:
		# Sınıra varıldı: sonraki sektörün ızgarası tam sınırdan başlar; ilk parça nefes alma
		# boşluğundan sonra, tam vuruşta.
		_sector += 1
		var next: SectorDef = _sectors.def_at(_sector)
		var next_beat: float = next.beat_px()
		var breath: float = next.climb_px() * _tuning.sector_breath
		_next_bottom = end_y - ceilf(breath / next_beat - EDGE_EPSILON) * next_beat
		return true
	var beat: float = _sectors.def_at(_sector).beat_px()
	var room: float = _next_bottom - end_y
	var allowed: bool = false
	var fitting: Array[int] = []
	for i: int in _pools.size():
		var info: ChunkInfo = _pools[i].peek() as ChunkInfo
		if not info.allows_sector(_sector):
			continue
		allowed = true
		if info.height_px(beat) <= room + EDGE_EPSILON:
			fitting.append(i)
	if not allowed:
		push_error("ChunkSpawner: sektör %d için parça yok" % _sector)
		return false
	if fitting.is_empty():
		# Sektörün sonuna hiçbir parça sığmıyor: kalan boş kalır.
		_next_bottom = end_y
		return true
	var candidates: Array[int] = _without_recent(fitting)
	var target: float = target_difficulty()
	var weights: Array[float] = []
	for i: int in candidates:
		var difficulty: int = (_pools[i].peek() as ChunkInfo).difficulty
		var gap: float = (difficulty - target) / _tuning.difficulty_spread
		weights.append(exp(-0.5 * gap * gap))
	var index: int = candidates[_rng.weighted_index(weights)]
	var chunk: ChunkInfo = _pools[index].acquire() as ChunkInfo
	chunk.position = Vector2(0.0, _next_bottom)
	chunk.layout(beat, _half_width)
	chunk.reset_physics_interpolation()
	_active.append(chunk)
	_active_pools.append(_pools[index])
	placed_names.append(_ids[index])
	placed_bottoms.append(_next_bottom)
	placed_difficulties.append(chunk.difficulty)
	placed_targets.append(target)
	_next_bottom = chunk.top_y()
	Events.chunk_placed.emit(_ids[index], chunk.difficulty, _sector)
	return true
