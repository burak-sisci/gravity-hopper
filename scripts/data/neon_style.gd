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
