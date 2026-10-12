class_name WallGap
extends Node2D
## Duvar boşluğu (M2-11, architecture.md §8.2). Desen parçasının bir öğesidir: konumu boşluğun alt
## ucudur (x = ±450, hangi duvar), boyu yarım vuruşun katıdır ve vuruş boyuyla ölçeklenir.
## Koridor bu aralıkta duvarsız kalır; tutunduğu duvar biten oyuncu koridordan düşer.
## Pasiftir: oyuncuyu tanımaz; Run, etkin boşlukları koridora bildirir.

## Boşluğun tasarımdaki boyu (px; 100 = 1 vuruş, 50'nin katı).
@export_range(50.0, 1600.0, 50.0, "suffix:px") var length: float = 100.0


## Boşluğun duvarı: -1 sol, +1 sağ (tasarımdaki x'in işareti).
func side() -> float:
	return signf(position.x)
