class_name MusicTrack
extends Resource
## Bir müzik parçası (architecture.md §8.3, ADR-040, ADR-065). Dosyalar data/music/<id>.tres;
## tools/music/build.py üretir. Ses dosyası ilk vuruşla başlar (0. saniye = turun 0. vuruşu) ve
## döngü tam ölçüdür: loop_start'tan dosyanın sonuna kadar çalar, sonra loop_start'a döner.
## Turun temposu çalan parçanın temposudur (kullanıcı kararı, 2026-10-13).

## Conductor'daki sabitle aynı. Conductor'a başvurulmaz: Conductor Events autoload'unu kullanır,
## ekransız araçlar (tools/validate_chunks.gd) autoload'ları tanımaz.
const SECONDS_PER_MINUTE: float = 60.0

## Parçanın kısa adı (dosya adıyla aynı; debug günlüğü ve testler).
@export var id: StringName = &""
## OGG Vorbis; döngü ayarı çalınırken loop_start'tan verilir.
@export var stream: AudioStream
## Tempo. Engeller bu vuruşlara ve yarım vuruşlara oturur.
@export_range(60.0, 200.0, 0.5, "suffix:BPM") var bpm: float = 100.0
## Döngünün başladığı an (sn, dosyanın başından; tam vuruş).
@export_range(0.0, 600.0, 0.001, "suffix:sn") var loop_start: float = 0.0
## Parçalar arasında eşit duyulan ses düzeyi için düzeltme.
@export_range(-24.0, 6.0, 0.1, "suffix:dB") var volume_db: float = 0.0
## Atıf (CREDITS.md ve ileride Hakkında ekranı; .clauderules §7).
@export var title: String = ""
@export var author: String = ""
@export var license: String = ""
@export var source_url: String = ""


## Bir vuruşun süresi (sn).
func beat_length() -> float:
	return SECONDS_PER_MINUTE / bpm


## Parçanın süresi (sn).
func length() -> float:
	return stream.get_length() if stream != null else 0.0


## Turun başından beri geçen vuruş saatine (sn) denk gelen çalma konumu: önce baştan sona, sonra
## loop_start ile son arasında döner.
func position_at(beat_time: float) -> float:
	var end: float = length()
	if beat_time < end or end <= loop_start:
		return maxf(beat_time, 0.0)
	return loop_start + fposmod(beat_time - loop_start, end - loop_start)
