class_name Magnet
extends RefCounted
## Mıknatıs yükseltmesi (M4-04, GDD §10, architecture.md §8.6): oyuncunun toplama alanının
## ötesine menzil ekler. Menzile giren Glimmer yakalanır ve toplanana dek hızlanarak oyuncuya
## akar; menzilden çıksa da bırakılmaz. Run tur başında yükten (RunLoadout) kurar ve her adımda
## oyuncunun yerini ChunkSpawner üstünden Glimmer'lara aşağı iletir; Glimmer oyuncuyu tanımaz.
## Yalnızca Glimmer'ın yerini değiştirir: parça havuzdan gelince yerleşim tasarım konumlarından
## yeniden kurulur, harita değişmez. Değerler her çağrıda TuningConfig'ten okunur (canlı ayar).

var _tuning: TuningConfig
var _range_m: float = 0.0


func _init(tuning: TuningConfig, range_m: float) -> void:
	_tuning = tuning
	_range_m = range_m


## Glimmer'ın merkezinin yakalandığı en büyük uzaklık (px): toplama alanı + mıknatıs menzili +
## Glimmer'ın yarıçapı (iki daire değince).
func reach_px(glimmer_radius: float) -> float:
	return TuningConfig.to_px(_tuning.pickup_radius + _range_m) + glimmer_radius


func captures(distance: float, glimmer_radius: float) -> bool:
	return distance <= reach_px(glimmer_radius)


## Yakalanmış Glimmer'ın bu adımdaki hızı (px/sn): yakalandığı adımda (speed 0) ilk hız, sonra
## ivmeyle artar.
func pull_speed(speed: float, delta: float) -> float:
	if speed <= 0.0:
		return TuningConfig.to_px(_tuning.magnet_pull_speed)
	return speed + TuningConfig.to_px(_tuning.magnet_pull_accel) * delta
