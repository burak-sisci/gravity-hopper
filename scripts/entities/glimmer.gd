class_name Glimmer
extends Area2D
## Glimmer (M2-13, GDD §9): desen parçasının içindeki toplanabilir. Yuvarlaktır (şekil dili:
## toplanabilir = yuvarlak). Oyuncunun toplama alanı (collector katmanı) değince kendini gizler
## ve yukarı collected yayar; değeri Run'daki RunStats hesaplar. Oyuncuyu tanımaz.
## Parça havuzdan yeniden gelince reset() ile yeniden etkinleşir.
## Görünüş (M3-06): yeşil neon daire (NeonShape, ışık lekesi); her vuruşta büyüyüp söner.
## Daire çarpışma yarıçapından kurulur. Vuruşu ChunkInfo'dan alır (set_beat).

signal collected(value: int)

## Temel değer; kombo çarpanı RunStats'ta uygulanır.
@export var value: int = 1

var _taken: bool = false

@onready var _shape: CollisionShape2D = $Shape
@onready var _visual: NeonShape = $Visual


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	var radius: float = (_shape.shape as CircleShape2D).radius
	var segments: int = Neon.STYLE.glimmer_segments
	var circle: PackedVector2Array = PackedVector2Array()
	for i: int in segments:
		circle.append(Vector2.from_angle(TAU * i / segments) * radius)
	_visual.polygon = circle
	_visual.fill_alpha = Neon.STYLE.glimmer_fill_alpha


## Yeniden etkinleştirir (parça havuzdan geldiğinde).
func reset() -> void:
	_taken = false
	visible = true
	_shape.set_deferred("disabled", false)


## Vuruş konumuna göre parıldar: vuruşta büyür, vuruş nabzıyla söner (yalnızca görsel).
func set_beat(beat: float) -> void:
	var grow: float = Neon.STYLE.glimmer_pulse_scale * Neon.STYLE.beat_pulse(beat)
	_visual.scale = Vector2.ONE * (1.0 + grow)


func is_taken() -> bool:
	return _taken


func _on_area_entered(_area: Area2D) -> void:
	if _taken:
		return
	_taken = true
	visible = false
	# Fizik bildirimi sırasında şekil değiştirilemez; bir sonraki adımda kapanır.
	_shape.set_deferred("disabled", true)
	collected.emit(value)
