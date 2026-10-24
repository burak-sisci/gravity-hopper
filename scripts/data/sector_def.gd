class_name SectorDef
extends Resource
## Bir sektörün tanımı (GDD §12, architecture.md §10). Dosyalar data/sectors/sector_NN.tres;
## sıralı liste SectorCatalog'da. Hız sektörün içinde sabittir, zorluk desenlerle artar (GDD §13).
## Tempo sektörde değil, turun müzik parçasındadır (MusicTrack, ADR-040).

## Adın çeviri anahtarı (localization/translations.csv, TR ve EN).
@export var name_key: StringName = &""
## Tırmanış hızı.
@export_range(4.0, 30.0, 0.5, "suffix:m/sn") var climb_speed: float = 12.0
## Sektörün boyu. Katalogdaki son sektör (Taşma) bitmez; boyu yalnızca zorluk eğrisinin uzunluğudur.
@export_range(50.0, 5000.0, 10.0, "suffix:m") var length: float = 750.0
## Çöküş duvarının oyuncuya göre sürünme hızı (GDD §14: S1 0,3 → S5 0,8 m/sn).
@export_range(0.0, 3.0, 0.025, "suffix:m/sn") var wall_creep: float = 0.3
## Görülebilecek tehlike türleri (spike, gap, block, laser, rotor, moving_block). Parçalarla
## denetimi M2-11'de başlar.
@export var allowed_hazards: Array[StringName] = [&"spike"]
## Sektör içi zorluk eğrisinin başı ve sonu (desen parçası zorluğu 1–10, M2-10).
@export_range(1, 10) var min_difficulty: int = 1
@export_range(1, 10) var max_difficulty: int = 3
## Sektörün renkleri (çevre, vurgu, arka plan; M3-02). Kesin tonlar M3-17'de.
@export var palette: SectorPalette
## Döngüsel palet (M4-13, Taşma): boş değilse sektörün başından her palette_cycle_length'te palet
## sıradakine renk dalgasıyla geçer: palette → palette_cycle[0] → … → son → yeniden palette.
@export var palette_cycle: Array[SectorPalette] = []
@export_range(50.0, 5000.0, 10.0, "suffix:m") var palette_cycle_length: float = 500.0
## Bu sektöre varış Büyük Depolama Birimi'dir (M4-13): Run final anını oynatır.
@export var finale: bool = false


## Döngünün step'inci paleti (0 = palette); döngü yoksa her zaman palette.
func palette_at(step: int) -> SectorPalette:
	if palette_cycle.is_empty():
		return palette
	var index: int = posmod(step, palette_cycle.size() + 1)
	return palette if index == 0 else palette_cycle[index - 1]


## Paleti döngüyle değişiyor mu.
func cycles_palette() -> bool:
	return not palette_cycle.is_empty()


## Bu sektörde, verilen tempoda bir vuruşun dünyadaki boyu (px).
func beat_px(bpm: float) -> float:
	return ChunkInfo.beat_px(climb_speed, bpm)


## Tırmanış hızı (px/sn).
func climb_px() -> float:
	return TuningConfig.to_px(climb_speed)
