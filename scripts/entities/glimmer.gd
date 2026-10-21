class_name Glimmer
extends Area2D
## Glimmer (M2-13, GDD §9): desen parçasının içindeki toplanabilir. Yuvarlaktır (şekil dili:
## toplanabilir = yuvarlak). Oyuncunun toplama alanı (collector katmanı) değince kendini gizler
## ve yukarı collected yayar; değeri Run'daki RunStats hesaplar. Oyuncuyu tanımaz.
## Parça havuzdan yeniden gelince reset() ile yeniden etkinleşir.
## Görünüş (M3-06): yeşil neon daire (NeonShape, ışık lekesi); her vuruşta büyüyüp söner.
## Daire çarpışma yarıçapından kurulur. Vuruşu ChunkInfo'dan alır (set_beat).
## Toplanınca yeri de bildirilir (M3-11): Run orada Glimmer patlamasını çıkarır.
## Mıknatıs (M4-04): Run oyuncunun yerini ChunkInfo üstünden aşağı verir (attract); menzile
## giren Glimmer yakalanır ve toplanana dek oraya akar. Yerini parçanın yerleşimi geri kurar.

signal collected(value: int, at: Vector2)

## Temel değer; kombo çarpanı RunStats'ta uygulanır.
@export var value: int = 1

var _taken: bool = false
## Çarpışma dairesinin yarıçapı (px).
var _radius: float = 0.0
## Mıknatısın çekiş hızı (px/sn); 0 = yakalanmamış.
var _pull_speed: float = 0.0

@onready var _shape: CollisionShape2D = $Shape
@onready var _visual: NeonShape = $Visual


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_radius = (_shape.shape as CircleShape2D).radius
	var segments: int = Neon.STYLE.glimmer_segments
	var circle: PackedVector2Array = PackedVector2Array()
	for i: int in segments:
		circle.append(Vector2.from_angle(TAU * i / segments) * _radius)
	_visual.polygon = circle
	_visual.fill_alpha = Neon.STYLE.glimmer_fill_alpha


## Yeniden etkinleştirir (parça havuzdan geldiğinde; yerini parçanın yerleşimi kurar).
func reset() -> void:
	_taken = false
	_pull_speed = 0.0
	visible = true
	_shape.set_deferred("disabled", false)


## Vuruş konumuna göre parıldar: vuruşta büyür, vuruş nabzıyla söner (yalnızca görsel).
func set_beat(beat: float) -> void:
	var grow: float = Neon.STYLE.glimmer_pulse_scale * Neon.STYLE.beat_pulse(beat)
	_visual.scale = Vector2.ONE * (1.0 + grow)


## Mıknatıs (M4-04): menzile girince yakalanır, sonra her adımda hızlanarak hedefe akar
## (menzilden çıksa da bırakılmaz). Toplanınca durur.
func attract(target: Vector2, magnet: Magnet, delta: float) -> void:
	if _taken:
		return
	if _pull_speed <= 0.0 and not magnet.captures(global_position.distance_to(target), _radius):
		return
	_pull_speed = magnet.pull_speed(_pull_speed, delta)
	global_position = global_position.move_toward(target, _pull_speed * delta)


func is_taken() -> bool:
	return _taken


func is_pulled() -> bool:
	return _pull_speed > 0.0


func _on_area_entered(_area: Area2D) -> void:
	if _taken:
		return
	_taken = true
	visible = false
	# Fizik bildirimi sırasında şekil değiştirilemez; bir sonraki adımda kapanır.
	_shape.set_deferred("disabled", true)
	collected.emit(value, global_position)
