class_name ChunkLibrary
extends Resource
## Oyunda kullanılan desen parçalarının listesi (architecture.md §8.2). Yeni parça hem
## scenes/levels/chunks/ altına hem buraya eklenir; test, klasördeki her parçanın burada
## olduğunu denetler. Yayın sürümünde klasör taranamadığı için liste elle tutulur.

## Desen parçası sahneleri (kökleri ChunkInfo).
@export var chunks: Array[PackedScene] = []
## İlk açılış deneyiminin ilk parçası (M5-07, GDD §18): yalnızca FTUE turunun başında konur,
## rastgele seçime girmez. Doğrulama ve klasör denetimi onu da kapsar (all_chunks).
@export var intro: PackedScene


## Kütüphanedeki bütün parçalar: rastgele seçilenler ve tanıtım parçası.
func all_chunks() -> Array[PackedScene]:
	var result: Array[PackedScene] = chunks.duplicate()
	if intro != null:
		result.append(intro)
	return result
