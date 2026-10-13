class_name SectorCatalog
extends Resource
## Sektörlerin sıralı listesi (architecture.md §10). Sektör numaraları 1'den başlar; her sektör
## bir öncekinin bittiği yükseklikte başlar. Son sektör sonsuza uzanır.

@export var sectors: Array[SectorDef] = []


func count() -> int:
	return sectors.size()


## Sektör tanımı (numara 1'den başlar; katalog dışı numaralar en yakın uca sınırlanır).
func def_at(index: int) -> SectorDef:
	return sectors[clampi(index, 1, sectors.size()) - 1]


## Sektörün başladığı yükseklik (m): öncekilerin boyları toplamı.
func start_height(index: int) -> float:
	var height: float = 0.0
	for i: int in range(1, clampi(index, 1, sectors.size())):
		height += sectors[i - 1].length
	return height


## Sektörün bittiği yükseklik (m); son sektör bitmez (INF).
func end_height(index: int) -> float:
	if index >= sectors.size():
		return INF
	return start_height(index) + def_at(index).length


## Bir yüksekliğin bulunduğu sektör.
func sector_at(height_m: float) -> int:
	for index: int in range(1, sectors.size()):
		if height_m < end_height(index):
			return index
	return sectors.size()


## Verilen tempoda bütün sektörler içinde en kısa vuruş boyu (px); havuzlar en kötü duruma göre
## kurulur.
func min_beat_px(bpm: float) -> float:
	var result: float = INF
	for def: SectorDef in sectors:
		result = minf(result, def.beat_px(bpm))
	return result
