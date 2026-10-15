class_name SectorPalette
extends Resource
## Bir sektörün renkleri (GDD §12, architecture.md §9). Dosyalar data/sectors/palette_NN.tres;
## SectorDef.palette ile bağlanır. Tehlike kırmızısı, Glimmer yeşili ve oyuncu beyazı sektörden
## bağımsızdır (NeonStyle). Çevre ve vurgu rengi kırmızı ya da yeşil olamaz (GDD §12, test).
## Kesin renkler M3-17'de seçildi (kullanıcı kararı, ADR-059); varsayılanlar S1'inkiler.

## Çevre: koridor duvarları, arka plan ağı, iz parlaması.
@export var ambient: Color = Color(0.0, 0.85, 1.0)
## Vurgu: sektör afişi, vuruş nabzı, renk dalgasının cephesi.
@export var accent: Color = Color(0.75, 0.97, 1.0)
## Arka plan: neonun parlayabilmesi için koyu.
@export var background: Color = Color(0.02, 0.04, 0.1)
