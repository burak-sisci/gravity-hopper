class_name GameTypes
extends RefCounted
## Oyun genelinde paylaşılan türler (enum'lar).
##
## Birden fazla sistemin kullandığı türler burada durur; örneğin ölüm nedenini
## hem Player hem PressureSystem yayar.

## Turun neden bittiği.
enum DeathCause {
	HAZARD, ## Bir tehlikeye çarptı
	FELL, ## Duvar boşluğundan koridorun dışına düştü
	WALL, ## Çöküş duvarına yakalandı
}

## Efekt kalitesi seviyesi (Ayarlar).
enum Quality {
	LOW, ## Parlama kapalı ya da sahte, az parçacık
	MEDIUM, ## Ara seviye
	HIGH, ## Tüm efektler açık
}
