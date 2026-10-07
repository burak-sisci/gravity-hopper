class_name TapHint
extends Control
## "DOKUN / TAP" ipucu. Metin çeviri anahtarından (UI_TAP) gelir ve yavaşça nabız gibi soluklaşır.
## Yalnızca görseldir: dokunuşları yakalamaz (mouse_filter = IGNORE), oyun dünyasını tanımaz.

const PULSE_MIN_ALPHA: float = 0.35
const PULSE_HALF_SEC: float = 0.6

@onready var _label: Label = %Label


func _ready() -> void:
	var tween: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_label, "modulate:a", PULSE_MIN_ALPHA, PULSE_HALF_SEC)
	tween.tween_property(_label, "modulate:a", 1.0, PULSE_HALF_SEC)
