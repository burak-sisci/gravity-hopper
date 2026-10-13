class_name SectorPalette
extends Resource
## Bir sektörün renkleri (GDD §12, architecture.md §9). Dosyalar data/sectors/palette_NN.tres;
## SectorDef.palette ile bağlanır. Tehlike kırmızısı, Glimmer yeşili ve oyuncu beyazı sektörden
## bağımsızdır (NeonStyle). Çevre ve vurgu rengi kırmızı ya da yeşil olamaz (GDD §12, test).
## M3-02 tonları geçicidir; kesin renkler M3-17'de seçilir.

## Çevre: koridor duvarları, arka plan ağı, iz parlaması.
@export var ambient: Color = Color(0.3, 0.85, 0.95)
## Vurgu: sektör afişi, vuruş nabzı, rekor çizgisi.
@export var accent: Color = Color(0.8, 0.97, 1.0)
## Arka plan: neonun parlayabilmesi için koyu.
@export var background: Color = Color(0.039, 0.055, 0.122)
