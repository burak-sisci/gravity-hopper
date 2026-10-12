class_name Glimmer
extends Area2D
## Glimmer (M2-13, GDD §9): desen parçasının içindeki toplanabilir. Yuvarlaktır (şekil dili:
## toplanabilir = yuvarlak). Oyuncunun toplama alanı (collector katmanı) değince kendini gizler
## ve yukarı collected yayar; değeri Run'daki RunStats hesaplar. Oyuncuyu tanımaz.
## Parça havuzdan yeniden gelince reset() ile yeniden etkinleşir.

signal collected(value: int)

## Temel değer; kombo çarpanı RunStats'ta uygulanır.
@export var value: int = 1

var _taken: bool = false

@onready var _shape: CollisionShape2D = $Shape


func _ready() -> void:
	area_entered.connect(_on_area_entered)


## Yeniden etkinleştirir (parça havuzdan geldiğinde).
func reset() -> void:
	_taken = false
	visible = true
	_shape.set_deferred("disabled", false)


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
