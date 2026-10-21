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

## Neon bileşenin renk kaynağı (M3-05): sektörden bağımsız sabit renkler NeonStyle'da durur.
enum NeonTone {
	CUSTOM, ## Bileşenin kendi rengi (color)
	HAZARD, ## Tehlike kırmızısı
	GLIMMER, ## Glimmer yeşili
	PLAYER, ## Oyuncu beyazı
	RECORD, ## Rekor sarısı (M3-18: HUD'un rekor satırı)
}

## Ses efekti olayları (M3-15, architecture.md §8.8). Sıra tools/sfx_prep.py'deki SOUNDS ile aynı.
enum Sfx {
	FLIP, ## Çevirme (her dokunuş)
	LAND, ## Duvara tutunma
	GLIMMER, ## Glimmer toplama
	NEAR_MISS, ## Kıl payı
	COMBO_UP, ## Kombo eşiği: çarpan ×2 ya da ×3'e çıktı
	SHIELD_BREAK, ## Kalkan kırıldı
	DEATH, ## Ölüm
	SECTOR, ## Yeni sektöre geçiş
	RECORD, ## Oturum rekoru kırıldı (rekor çizgisine varıldı)
}

## Kozmetik izin nasıl açıldığı (M4-08, GDD §11). Yedi günlük seri başarımı M7-03'te eklenir.
enum TrailUnlock {
	FREE, ## Baştan açık (varsayılan iz)
	PURCHASE, ## Glimmer ile satın alınır (TrailDef.cost)
	GREAT_STORAGE, ## Başarım: Büyük Depolama Birimi'ne ulaş (M4-13)
	NEAR_MISSES, ## Başarım: toplam kıl payı sayısı TrailDef.goal'a ulaşır
}
