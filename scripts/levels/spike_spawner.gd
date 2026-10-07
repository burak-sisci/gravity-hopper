class_name SpikeSpawner
extends Node2D
## Geçici engel yerleştirici (M1-08). Düz aralıklı dikenler; her dikenin hangi duvarda
## olduğunu RunRng seçer. M2'de desen sistemi (ChunkSpawner) bunun yerini alır.
##
## Sabit sayıda diken tur başında oluşturulur; görünür alanın altında kalan diken, en öndeki
## dikenin bir aralık ilerisine taşınır (tur sırasında düğüm oluşturulmaz, .clauderules §6).
## Dikenler hep aynı sırayla taşındığı için aynı tohum her zaman aynı diziyi verir.

const SPIKE_SCENE: PackedScene = preload("res://scenes/entities/spike.tscn")
## En dar aralıkta (4 m) en uzun ekranı ve öndeki payı dolduracak kadar diken.
const POOL_SIZE: int = 20
## Diken, görünür alanın bu kadar altına inince öne taşınır (diken boyu 70 px).
const RECYCLE_MARGIN: float = 100.0

## Yerleştirme günlüğü: sırayla her dikenin tarafı (true = sol). Testler ve hata ayıklama için.
var placed_left: Array[bool] = []

var _rng: RunRng
var _tuning: TuningConfig
var _spikes: Array[Node2D] = []
var _next_y: float = 0.0


## Dikenleri oluşturur ve start_y'nin üstüne sırayla yerleştirir.
func setup(rng: RunRng, tuning: TuningConfig, start_y: float) -> void:
	_rng = rng
	_tuning = tuning
	_next_y = start_y - TuningConfig.to_px(tuning.spike_start_gap)
	for i: int in POOL_SIZE:
		var spike: Node2D = SPIKE_SCENE.instantiate() as Node2D
		add_child(spike)
		_spikes.append(spike)
		_place_next(spike)


## Duvarlara hizalar ve görünür alanın altında kalan dikenleri öne taşır.
func update_view(view_bottom: float, half_width: float) -> void:
	for spike: Node2D in _spikes:
		if spike.position.y > view_bottom + RECYCLE_MARGIN:
			_place_next(spike)
		spike.position.x = -half_width if spike.scale.x > 0.0 else half_width


func _place_next(spike: Node2D) -> void:
	var on_left: bool = _rng.chance(0.5)
	placed_left.append(on_left)
	spike.position.y = _next_y
	# Diken sol duvarda sağa, sağ duvarda sola bakar.
	spike.scale.x = 1.0 if on_left else -1.0
	spike.reset_physics_interpolation()
	_next_y -= TuningConfig.to_px(_tuning.spike_spacing)
