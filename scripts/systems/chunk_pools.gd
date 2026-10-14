class_name ChunkPools
extends Node2D
## Turlar arasında korunan desen parçası havuzları (architecture.md §8.7, M3-10, ADR-054).
## Main'de durur; her turun ChunkSpawner'ı havuzları buradan ödünç alır, tur bitince etkin
## parçaları geri verir. Böylece yeniden başlamada yüzlerce düğüm yeniden kurulmaz (Redmi'de
## ≈ 150 ms sürüyordu). Parçalar dünya koordinatındadır (Run ve bu düğüm orijinde).
## Çizim sırası z_index ile korunur: koridorun (-2) üstünde, çöküş duvarı ve oyuncunun (0) altında.

var _pools: Dictionary[PackedScene, ObjectPool] = {}


## Sahnenin havuzu; ilk istenişte kurulur (kopyaları ChunkSpawner ayırır).
func pool_for(scene: PackedScene) -> ObjectPool:
	if not _pools.has(scene):
		_pools[scene] = ObjectPool.new(scene, self)
	return _pools[scene]
