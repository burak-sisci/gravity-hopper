class_name TensionMix
extends Resource
## Gerilim karışımı (M3-16, architecture.md §8.8): çöküş duvarı yaklaştıkça müzik boğuklaşır
## (Music yolundaki alçak geçiren süzgeç) ve döngülü gerilim sesi yükselir.
## data/audio/tension_mix.tres; döngüyü ve volume_db'yi tools/sfx_prep.py hazırlar.
## Yakınlık Events.wall_proximity_changed'den gelir: 0 duvar ekranın altında, 1 oyuncuya değince.

## Sessiz sayılan düzey: yakınlık 0'da gerilim sesi bu düzeydedir (çalar zaten durur).
const SILENT_DB: float = -80.0

@export_group("Süzgeç")
## Duvar ekrana girerken müziğin kesim frekansı (açık: duyulur bir fark yok).
@export_range(1000.0, 20000.0, 100.0, "suffix:Hz") var open_hz: float = 12000.0
## Duvar oyuncuya değerken kesim frekansı (en boğuk). Müziğin enerjisi 250–600 Hz'de olduğu için
## telefon hoparlöründe düzey 2–3 dB düşer; duyulan fark tınıdadır.
@export_range(200.0, 4000.0, 10.0, "suffix:Hz") var closed_hz: float = 700.0
## Yakınlığın üssü. Kesim frekansı açıktan boğuğa logaritmik ölçekte iner (kulak öyle duyar);
## 1'den büyük olunca boğuklaşma geç başlar.
@export_range(0.25, 4.0, 0.05) var filter_curve: float = 1.0

@export_group("Gerilim sesi")
## Döngülü ses (OGG, loop açık).
@export var stream: AudioStream
## Duvar oyuncuya değerken ses düzeyi (müzikle dengeli; tools/sfx_prep.py yazar).
@export_range(-40.0, 6.0, 0.1, "suffix:dB") var volume_db: float = 0.0
## Yakınlığın üssü: genlik = yakınlık ^ üs. Büyüdükçe ses geç yükselir.
@export_range(0.25, 4.0, 0.05) var volume_curve: float = 1.5
## Perde, duvar ekrana girerken.
@export_range(0.5, 2.0, 0.01) var pitch_far: float = 1.0
## Perde, duvar oyuncuya değerken (yükselen perde aciliyet verir).
@export_range(0.5, 2.0, 0.01) var pitch_near: float = 1.2

@export_group("Geçiş")
## Ses, yakınlığa bu zaman sabitiyle yetişir (sn). Kalkan kırılınca duvar birden yaklaşır;
## süzgeç ve ses sıçramadan yetişir.
@export_range(0.0, 1.0, 0.01, "suffix:s") var smoothing: float = 0.15

@export_group("Atıf")
@export var title: String = ""
@export var author: String = ""
@export var license: String = ""
@export var source_url: String = ""


## Yakınlıktaki kesim frekansı (Hz).
func cutoff_at(proximity: float) -> float:
	var t: float = pow(clampf(proximity, 0.0, 1.0), filter_curve)
	return open_hz * pow(closed_hz / open_hz, t)


## Yakınlıktaki gerilim sesi düzeyi (dB).
func volume_at(proximity: float) -> float:
	var p: float = clampf(proximity, 0.0, 1.0)
	if p <= 0.0:
		return SILENT_DB
	return maxf(SILENT_DB, volume_db + linear_to_db(pow(p, volume_curve)))


## Yakınlıktaki gerilim sesi perdesi.
func pitch_at(proximity: float) -> float:
	return lerpf(pitch_far, pitch_near, clampf(proximity, 0.0, 1.0))
