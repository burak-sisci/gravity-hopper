class_name Conductor
extends Node
## Ritim saati (architecture.md §8.3, M2-07). Tek doğru zaman kaynağı oyun zamanıdır (run_time):
## ölçeklenmiş delta ile ilerler, ses ona hizalanır. Her vuruşta Events.beat yayar.
##
## Run her fizik adımında advance() çağırır (aşağı çağrı); böylece run_time oyuncunun konumuyla
## aynı adımda ilerler. Oyuncu turun başındaki yüksekliğinden vuruş ızgarasıyla tırmandığı için
## yarım vuruşa oturan engeller tam vuruş anlarında geçer (§8.2).
## Ses AudioManager'dadır (servis çağrısı); Conductor sahneye ses düğümü eklemez.

const SECONDS_PER_MINUTE: float = 60.0
## Kayan nokta payı: vuruş anına tam denk gelen adım o vuruşu sayar.
const BEAT_EPSILON: float = 0.000001

## Sektörün temposu (vuruş/dk). M2-08'de SectorDef'ten gelir; şimdilik S1 (GDD §12).
@export var bpm: float = 100.0

## Turun başından beri geçen oyun zamanı (sn, Engine.time_scale ile ölçeklenmiş).
var run_time: float = 0.0
## Son yayılan vuruşun sıra numarası (vuruş 0 turun başlangıcıdır ve yayılmaz).
var beat_index: int = 0


## Bir vuruşun süresi (sn).
func beat_length() -> float:
	return SECONDS_PER_MINUTE / bpm


## Oyun zamanını ilerletir; geçilen her vuruş için Events.beat yayar ve sesi hizalar.
func advance(delta: float) -> void:
	run_time += delta
	while (beat_index + 1) * beat_length() <= run_time + BEAT_EPSILON:
		beat_index += 1
		Events.beat.emit(beat_index)
	AudioManager.sync_beat_clock(run_time, bpm)
