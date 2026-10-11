class_name Conductor
extends Node
## Ritim saati (architecture.md §8.3, M2-07). Tek doğru zaman kaynağı oyun zamanıdır (run_time):
## ölçeklenmiş delta ile ilerler, ses ona hizalanır. Her vuruşta Events.beat yayar.
##
## Run her fizik adımında advance() çağırır (aşağı çağrı); böylece run_time oyuncunun konumuyla
## aynı adımda ilerler. Oyuncu turun başındaki yüksekliğinden vuruş ızgarasıyla tırmandığı için
## yarım vuruşa oturan engeller tam vuruş anlarında geçer (§8.2).
## Sektör değişince Run set_tempo() ile yeni tempoyu ve vuruş ızgarasının başlangıç anını verir;
## vuruşlar o andan sayılır (M2-08).
## Ses AudioManager'dadır (servis çağrısı); Conductor sahneye ses düğümü eklemez.

const SECONDS_PER_MINUTE: float = 60.0
## Kayan nokta payı: vuruş anına tam denk gelen adım o vuruşu sayar.
const BEAT_EPSILON: float = 0.000001

## Sektörün temposu (vuruş/dk). Run, sektörden set_tempo() ile verir.
@export var bpm: float = 100.0

## Turun başından beri geçen oyun zamanı (sn, Engine.time_scale ile ölçeklenmiş).
var run_time: float = 0.0
## Turun başından beri yayılan vuruş sayısı (Events.beat'in sıra numarası).
var beat_index: int = 0

## Şu anki tempo ızgarasının başladığı oyun zamanı ve o ızgarada yayılan vuruş sayısı.
## Izgaranın 0. vuruşu (tur ya da sektör başı) yayılmaz.
var _tempo_origin: float = 0.0
var _tempo_beats: int = 0


## Bir vuruşun süresi (sn).
func beat_length() -> float:
	return SECONDS_PER_MINUTE / bpm


## Şu anki tempo ızgarasının başından beri geçen süre (ses bu süreye hizalanır).
func beat_time() -> float:
	return run_time - _tempo_origin


## Tempoyu değiştirir; yeni vuruş ızgarası origin anında başlar (geçmişte olabilir).
func set_tempo(new_bpm: float, origin: float) -> void:
	bpm = new_bpm
	_tempo_origin = origin
	_tempo_beats = 0


## Oyun zamanını ilerletir; geçilen her vuruş için Events.beat yayar ve sesi hizalar.
func advance(delta: float) -> void:
	run_time += delta
	while (_tempo_beats + 1) * beat_length() <= beat_time() + BEAT_EPSILON:
		_tempo_beats += 1
		beat_index += 1
		Events.beat.emit(beat_index)
	AudioManager.sync_beat_clock(beat_time(), bpm)
