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

## Kalkan halkasının rengi (kırmızı ve yeşilden uzak).
@export var shield_color: Color = Color(0.55, 0.9, 1.0)

@export_group("Oyuncu izi")
## İzin geriye uzandığı süre; boyu tırmanış hızıyla birlikte uzar (GDD §13).
@export_range(0.05, 1.0, 0.01, "suffix:sn") var trail_duration: float = 0.4
## İzin baştaki kalınlığı; kuyruğa doğru sıfıra iner.
@export_range(1.0, 60.0, 0.5, "suffix:px") var trail_width: float = 18.0

@export_group("Tehlikeler")
## Sivri köşeli kenar çizgisinde köşe sivriliğinin sınırı (Line2D.sharp_limit).
@export_range(1.0, 20.0, 0.5) var sharp_limit: float = 8.0
## Veri bloğunun vuruşla süzülme genliği (yalnızca görsel; çarpışma kutusu yerinde kalır).
@export_range(0.0, 20.0, 0.5, "suffix:px") var block_hover_px: float = 4.0
## Süzülmenin bir turu kaç vuruş sürer.
@export_range(0.5, 8.0, 0.5) var block_hover_beats: float = 2.0
## Bloğun içindeki veri satırları: x = dikey konum (bloğun boyuna oranla, merkezden),
## y = boy (iç genişliğe oranla). Satırlar sola yaslıdır.
@export var block_rows: Array[Vector2] = [
	Vector2(-0.25, 0.7), Vector2(0.0, 0.45), Vector2(0.25, 0.6),
]
## Veri satırlarının kenardan içeri payı (bloğun genişliğine oranla).
@export_range(0.0, 0.4, 0.01) var block_row_inset: float = 0.12
## Veri satırlarının kalınlığı.
@export_range(1.0, 20.0, 0.5, "suffix:px") var block_row_width: float = 4.0
## Veri satırlarının saydamlığı.
@export_range(0.0, 1.0, 0.05) var block_row_alpha: float = 0.55

@export_group("Lazer")
## Yanık ışının sivrilen ucunun çarpışma kutusunun ucundan taşan boyu (görüntü kutudan büyük
## kalır, oyuncunun aleyhine olmaz).
@export_range(0.0, 40.0, 1.0, "suffix:px") var laser_tip_px: float = 24.0
## Yanık ışının beyaza yakın çekirdeğinin kalınlığı (ışın kalınlığına oranla).
@export_range(0.0, 1.0, 0.05) var laser_core_ratio: float = 0.4
## Çekirdeğin tehlike kırmızısından beyaza çekilme oranı (yanık ışın sönükten parlak görünsün).
@export_range(0.0, 1.0, 0.05) var laser_core_whiten: float = 0.6
## Sönük ışının (ray) kalınlığı: ışının nereden geçeceğini gösterir.
@export_range(1.0, 20.0, 0.5, "suffix:px") var laser_off_width: float = 3.0
## Sönük ışının saydamlığı.
@export_range(0.0, 1.0, 0.05) var laser_off_alpha: float = 0.3
## Uyarı ışıması yanmadan bu kadar vuruş önce başlar; ray kalınlaşıp parlar.
@export_range(0.05, 0.5, 0.05) var laser_warn_beats: float = 0.25
## Uyarının sonunda rayın kalınlığı.
@export_range(1.0, 20.0, 0.5, "suffix:px") var laser_warn_width: float = 8.0
## Uyarının sonunda rayın saydamlığı.
@export_range(0.0, 1.0, 0.05) var laser_warn_alpha: float = 0.85

@export_group("Glimmer")
## Glimmer dairesinin köşe sayısı (yuvarlak görünsün diye).
@export_range(8, 48, 1) var glimmer_segments: int = 20
## Glimmer dolgusunun saydamlığı.
@export_range(0.0, 1.0, 0.05) var glimmer_fill_alpha: float = 0.5
## Glimmer'ın vuruşta büyüme oranı (parıltı); vuruş nabzıyla söner.
@export_range(0.0, 1.0, 0.05) var glimmer_pulse_scale: float = 0.25

@export_group("Duvarlar")
## Duvar dolgusunun saydamlığı; parçalar sırayla açık ve koyu, böylece kayma gözle görülür.
@export_range(0.0, 1.0, 0.01) var wall_fill_light: float = 0.16
## Koyu duvar parçasının dolgu saydamlığı.
@export_range(0.0, 1.0, 0.01) var wall_fill_dark: float = 0.09
## Duvar kenar çizgisinin çekirdeği çevre renginden beyaza bu oranda çekilir; parlaması çevre
## renginde kalır.
@export_range(0.0, 1.0, 0.05) var wall_core_whiten: float = 0.55

@export_group("Arka plan ağı")
## Ağın göründüğü en düşük kalite; altında arka plan düz renktir.
@export var grid_min_quality: GameTypes.Quality = GameTypes.Quality.MEDIUM
## Uzak katmanın göründüğü en düşük kalite.
@export var grid_far_min_quality: GameTypes.Quality = GameTypes.Quality.HIGH
## Yakın katmanın hücre boyu (çizgi aralığı); koridorun ortasından hizalanır.
@export_range(40.0, 800.0, 10.0, "suffix:px") var grid_near_cell: float = 300.0
## Yakın katmanın kamerayla kayma oranı (paralaks; 1 = dünyayla aynı hızda).
@export_range(0.0, 1.0, 0.01) var grid_near_parallax: float = 0.3
## Yakın katman çizgilerinin kalınlığı.
@export_range(0.5, 8.0, 0.5, "suffix:px") var grid_near_width: float = 2.5
## Yakın katman çizgilerinin saydamlığı.
@export_range(0.0, 1.0, 0.01) var grid_near_alpha: float = 0.1
## Yakın katmanın kesişimlerindeki düğüm noktalarının yarıçapı.
@export_range(0.0, 20.0, 0.5, "suffix:px") var grid_node_radius: float = 6.0
## Düğüm noktalarının saydamlığı.
@export_range(0.0, 1.0, 0.01) var grid_node_alpha: float = 0.3
## Uzak katmanın hücre boyu.
@export_range(20.0, 400.0, 10.0, "suffix:px") var grid_far_cell: float = 100.0
## Uzak katmanın kamerayla kayma oranı (yakından yavaş: derinlik hissi).
@export_range(0.0, 1.0, 0.01) var grid_far_parallax: float = 0.12
## Uzak katman çizgilerinin kalınlığı.
@export_range(0.5, 8.0, 0.5, "suffix:px") var grid_far_width: float = 1.5
## Uzak katman çizgilerinin saydamlığı.
@export_range(0.0, 1.0, 0.01) var grid_far_alpha: float = 0.06
## Nabız tepesinde ağın saydamlık artışı (1 = iki katı).
@export_range(0.0, 3.0, 0.05) var grid_pulse_alpha: float = 1.0
## Her vuruşta yanıp sönen düğümlerin oranı.
@export_range(0.0, 1.0, 0.01) var grid_flash_density: float = 0.12
## Yanıp sönen düğümün tepedeki saydamlığı (vurgu renginde).
@export_range(0.0, 1.0, 0.05) var grid_flash_alpha: float = 0.5

@export_group("Renk dalgası")
## Sektör geçişinde yeni paletin ekranın altından üstüne varma süresi (sn; M3-08).
@export_range(0.2, 4.0, 0.05, "suffix:sn") var wave_time: float = 1.2
## Duvarların ve izin eski renkten yenisine geçtiği bant: yarısı dalganın önünde, yarısı
## arkasında.
@export_range(1.0, 1200.0, 10.0, "suffix:px") var wave_blend: float = 400.0
## Dalganın önündeki parlak çizginin kalınlığı.
@export_range(0.5, 20.0, 0.5, "suffix:px") var wave_crest_width: float = 5.0
## Çizginin çevresindeki ışık bandının yüksekliği.
@export_range(0.0, 800.0, 10.0, "suffix:px") var wave_glow_height: float = 220.0
## Işık bandının tepedeki saydamlığı (yeni paletin çevre renginde).
@export_range(0.0, 1.0, 0.05) var wave_glow_alpha: float = 0.6
## Işık bandının göründüğü en düşük kalite; altında yalnızca çizgi.
@export var wave_glow_min_quality: GameTypes.Quality = GameTypes.Quality.MEDIUM

@export_group("Çöküş duvarı")
## Duvarın içinin rengi (opak: altında kalan her şey silinmiş görünür; M3-09). Kenarı tehlike
## kırmızısında.
@export var collapse_body_color: Color = Color(0.14, 0.015, 0.04)
## Glitch bandının (shader) göründüğü en düşük kalite; altında kırık kenar çizgisi ve düz dolgu.
@export var collapse_glitch_min_quality: GameTypes.Quality = GameTypes.Quality.MEDIUM
## Kenardaki renk kaymasının (RGB) göründüğü en düşük kalite.
@export var collapse_split_min_quality: GameTypes.Quality = GameTypes.Quality.HIGH
## Glitch deseninin vuruş başına kaç kez değiştiği.
@export_range(1, 8) var collapse_steps_per_beat: int = 4
## Glitch bandının kenarın üstünde kalan yüksekliği (ışık ve veri kırıntıları).
@export_range(0.0, 400.0, 5.0, "suffix:px") var collapse_rise: float = 70.0
## Glitch bandının kenarın altında kalan yüksekliği (bozuk bloklar, tarama çizgileri).
@export_range(0.0, 600.0, 5.0, "suffix:px") var collapse_depth: float = 100.0
## Kırık kenarın sütun genişliği.
@export_range(4.0, 200.0, 1.0, "suffix:px") var collapse_column: float = 36.0
## Kırık kenarın en büyük yüksekliği; kenar hep öldürme çizgisinde ya da üstünde.
@export_range(0.0, 120.0, 1.0, "suffix:px") var collapse_jag: float = 36.0
## Yana kayan dilimlerin yüksekliği.
@export_range(2.0, 80.0, 1.0, "suffix:px") var collapse_slice: float = 14.0
## Bir dilimin en büyük yana kayması.
@export_range(0.0, 200.0, 1.0, "suffix:px") var collapse_slice_shift: float = 40.0
## Bir dilimin bir adımda kayma olasılığı.
@export_range(0.0, 1.0, 0.01) var collapse_slice_chance: float = 0.2
## Veri kırıntılarının ve içteki bozuk blokların boyu.
@export_range(2.0, 60.0, 1.0, "suffix:px") var collapse_block: float = 12.0
## Kenarın hemen üstünde kırıntı sıklığı (yukarı doğru seyrelir).
@export_range(0.0, 1.0, 0.01) var collapse_dust_density: float = 0.12
## Kenar çizgisinin kalınlığı.
@export_range(1.0, 30.0, 0.5, "suffix:px") var collapse_edge_width: float = 6.0
## Kenarın üstündeki ışığın sönme uzunluğu.
@export_range(1.0, 120.0, 1.0, "suffix:px") var collapse_glow: float = 24.0
## Kenarın üstündeki ışığın en yüksek saydamlığı.
@export_range(0.0, 1.0, 0.05) var collapse_glow_alpha: float = 0.5
## Renk kaymasında kopyaların kenardan uzaklığı.
@export_range(0.0, 20.0, 0.5, "suffix:px") var collapse_split: float = 5.0
## Vuruşta kenarın ve ışığın parlaklık artışı (0 = nabız yok).
@export_range(0.0, 2.0, 0.05) var collapse_pulse_gain: float = 0.6

@export_group("Vuruş nabzı")
## Nabzın vuruştan sonra sönme süresi (vuruşun kesri). Sesi kapalı oynayan ritmi bundan görür.
@export_range(0.05, 1.0, 0.05) var beat_pulse_length: float = 0.35
## Nabzın tepesinde renklerin vurgu rengine ne kadar çekildiği (0 = nabız yok).
@export_range(0.0, 1.0, 0.05) var beat_pulse_gain: float = 0.7
## Nabzın tepesindeki ek parlaklık çarpanı.
@export_range(1.0, 3.0, 0.05) var beat_pulse_boost: float = 1.4


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


## Renk kaynağının rengi: CUSTOM ise bileşenin kendi rengi, değilse sabit renk.
func tone_color(tone: GameTypes.NeonTone, custom: Color) -> Color:
	match tone:
		GameTypes.NeonTone.HAZARD:
			return hazard_color
		GameTypes.NeonTone.GLIMMER:
			return glimmer_color
		GameTypes.NeonTone.PLAYER:
			return player_color
	return custom


## Verilen kalitede ışık lekesi görünür mü.
func shows_blob(quality: GameTypes.Quality) -> bool:
	return quality >= blob_min_quality


## Vuruş nabzının gücü (0–1): vuruş anında 1, beat_pulse_length içinde karesel söner.
## beat: tempo ızgarasının başından beri geçen vuruş sayısı (kesirli).
func beat_pulse(beat: float) -> float:
	var fade: float = clampf(1.0 - fposmod(beat, 1.0) / beat_pulse_length, 0.0, 1.0)
	return fade * fade


## Renk dalgasının ilerleyişi (0 ekranın altında – 1 üstünde): geçişten beri geçen süreye göre.
func wave_progress(elapsed: float) -> float:
	return clampf(elapsed / wave_time, 0.0, 1.0)


## Dalganın önünün y'si: progress 0'da bottom, 1'de top (ekranda ya da dünyada aynı).
func wave_front(progress: float, top: float, bottom: float) -> float:
	return lerpf(bottom, top, progress)


## y'deki bir şeyin yeni palete ne kadar geçtiği (0 eski – 1 yeni): dalganın önünün altında
## (geçtiği yer) yeni, üstünde eski; aradaki wave_blend bandında yumuşak.
func wave_weight(y: float, front: float) -> float:
	return clampf((y - front) / wave_blend + 0.5, 0.0, 1.0)


## Dalganın ekranda yukarıdan ratio kesrindeki (0 üst – 1 alt) yere varma süresi (sn).
func wave_reach_time(ratio: float) -> float:
	return wave_time * (1.0 - clampf(ratio, 0.0, 1.0))
