class_name BurstStyle
extends Resource
## Bir parçacık patlamasının görünüşü (M3-11, architecture.md §9): Effects her patlama türü için
## bir CPUParticles2D halkası kurar ve değerleri buradan alır. NeonStyle üç tane taşır: iniş
## kıvılcımı, Glimmer patlaması, ölüm patlaması. Aralıklar Vector2: x en az, y en çok.

## Yüksek kalitede bir patlamadaki parçacık sayısı (orta ve düşükte NeonStyle'daki oranla azalır).
@export_range(1, 128) var amount: int = 12
## Parçacığın ömrü.
@export_range(0.05, 3.0, 0.05, "suffix:sn") var lifetime: float = 0.4
## Çıkış hızı aralığı.
@export var speed: Vector2 = Vector2(200.0, 500.0)
## Çıkış yönünün iki yana yayılma açısı (180 = her yöne).
@export_range(0.0, 180.0, 1.0, "suffix:°") var spread: float = 180.0
## Hızın saniyede azalması (parçacık havada yavaşlar).
@export_range(0.0, 10000.0, 10.0, "suffix:px/sn²") var damping: float = 800.0
## Parçacığın boyu (ışık lekesi dokusunun kenarına oranla) aralığı; ömür boyunca küçülür.
@export var size: Vector2 = Vector2(0.08, 0.16)
## Hareket yönünde uzama: 1 yuvarlak nokta, büyüdükçe çizgi gibi kıvılcım.
@export_range(1.0, 8.0, 0.1) var stretch: float = 1.0
## Renk kaynağı: CUSTOM ise sektörün çevre rengi (Effects.set_ambient), değilse sabit renk.
@export var tone: GameTypes.NeonTone = GameTypes.NeonTone.CUSTOM
## Parçacığın başta beyaza çekilme oranı (sıcak çekirdek), ömrünün ortasında kendi rengine iner.
@export_range(0.0, 1.0, 0.05) var whiten: float = 0.5
