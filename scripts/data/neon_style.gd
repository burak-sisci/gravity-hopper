class_name NeonStyle
extends Resource
## Neon görünüşünün değerleri (architecture.md §9, ADR-020). Dosya data/visual/neon_style.tres;
## NeonLine ve NeonShape bunu Neon.STYLE üzerinden okur. Başlangıç değerleri M0-09 ölçümünden.
## Parlama katmanı: x = genişlik (px), y = yoğunluk (0–1). Katmanlar dıştan içe sıralanır.

## Yüksek kalitede çizgi parlama katmanları.
@export var high_layers: Array[Vector2] = [Vector2(64.0, 0.35), Vector2(26.0, 0.7)]
## Orta kalitede çizgi parlama katmanları.
@export var medium_layers: Array[Vector2] = [Vector2(40.0, 0.55)]
## Düşük kalitede çizgi parlama katmanları (boşsa parlama yok).
@export var low_layers: Array[Vector2] = []
## Işık lekesinin göründüğü en düşük kalite.
@export var blob_min_quality: GameTypes.Quality = GameTypes.Quality.MEDIUM
## Işık lekesinin şeklin sınır kutusuna göre büyüklüğü.
@export_range(1.0, 5.0, 0.1) var blob_scale: float = 2.6
## Işık lekesine eklenen sabit pay.
@export_range(0.0, 200.0, 1.0, "suffix:px") var blob_padding: float = 40.0
## Işık lekesinin yoğunluğu.
@export_range(0.0, 1.0, 0.05) var blob_intensity: float = 0.65
## Çekirdek çizginin kalınlığı.
@export_range(1.0, 20.0, 0.5, "suffix:px") var line_width: float = 6.0
## Kapalı şekillerin dolgu saydamlığı.
@export_range(0.0, 1.0, 0.01) var fill_alpha: float = 0.18

@export_group("Sabit renkler")
## Tehlike kırmızısı: her sektörde aynı; hiçbir çevre rengi kırmızı olamaz (GDD §12).
@export var hazard_color: Color = Color(1.0, 0.22, 0.32)
## Glimmer yeşili: her sektörde aynı; hiçbir çevre rengi yeşil olamaz.
@export var glimmer_color: Color = Color(0.35, 1.0, 0.5)
## Oyuncu çekirdeğinin beyazı.
@export var player_color: Color = Color(1.0, 1.0, 1.0)


## Verilen kalitedeki çizgi parlama katmanları.
func layers_for(quality: GameTypes.Quality) -> Array[Vector2]:
	match quality:
		GameTypes.Quality.HIGH:
			return high_layers
		GameTypes.Quality.MEDIUM:
			return medium_layers
	return low_layers


## Herhangi bir kalitedeki en çok katman sayısı: bileşenler bu kadar kopyayı baştan kurar.
func max_layer_count() -> int:
	return maxi(high_layers.size(), maxi(medium_layers.size(), low_layers.size()))


## Verilen kalitede ışık lekesi görünür mü.
func shows_blob(quality: GameTypes.Quality) -> bool:
	return quality >= blob_min_quality
