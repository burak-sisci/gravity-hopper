class_name ChunkLibrary
extends Resource
## Oyunda kullanılan desen parçalarının listesi (architecture.md §8.2). Yeni parça hem
## scenes/levels/chunks/ altına hem buraya eklenir; test, klasördeki her parçanın burada
## olduğunu denetler. Yayın sürümünde klasör taranamadığı için liste elle tutulur.

## Desen parçası sahneleri (kökleri ChunkInfo).
@export var chunks: Array[PackedScene] = []
