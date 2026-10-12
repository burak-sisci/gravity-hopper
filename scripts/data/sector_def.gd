class_name SectorDef
extends Resource
## Bir sektörün tanımı (GDD §12, architecture.md §10). Dosyalar data/sectors/sector_NN.tres;
## sıralı liste SectorCatalog'da. Hız sektörün içinde sabittir, zorluk desenlerle artar (GDD §13).

## Adın çeviri anahtarı (localization/translations.csv, TR ve EN).
@export var name_key: StringName = &""
## Tempo. Engeller bu vuruşlara ve yarım vuruşlara oturur.
@export_range(60.0, 200.0, 1.0, "suffix:BPM") var bpm: float = 100.0
## Tırmanış hızı.
@export_range(4.0, 30.0, 0.5, "suffix:m/sn") var climb_speed: float = 12.0
## Sektörün boyu. Katalogdaki son sektör bitmez (S4–S5 M4-07'de gelir).
@export_range(50.0, 5000.0, 10.0, "suffix:m") var length: float = 750.0
## Çöküş duvarının oyuncuya göre sürünme hızı (GDD §14: S1 0,3 → S5 0,8 m/sn).
@export_range(0.0, 3.0, 0.025, "suffix:m/sn") var wall_creep: float = 0.3
## Görülebilecek tehlike türleri (spike, gap, block, laser). Parçalarla denetimi M2-11'de başlar.
@export var allowed_hazards: Array[StringName] = [&"spike"]
## Sektör içi zorluk eğrisinin başı ve sonu (desen parçası zorluğu 1–10, M2-10).
@export_range(1, 10) var min_difficulty: int = 1
@export_range(1, 10) var max_difficulty: int = 3
## Geçici çevre rengi; kesin palet M3-11'de. Kırmızı ve yeşil kullanılmaz (GDD §12).
@export var ambient_color: Color = Color(0.3, 0.85, 0.95)


## Bu sektörde bir vuruşun dünyadaki boyu (px).
func beat_px() -> float:
	return ChunkInfo.beat_px(climb_speed, bpm)


## Tırmanış hızı (px/sn).
func climb_px() -> float:
	return TuningConfig.to_px(climb_speed)
