extends Node
## Ses yöneticisi: efekt havuzu, müzik çalma ve geçişleri.
##
## Olayları Events'ten dinler. Engine.time_scale değiştiğinde müziğin pitch_scale
## değerini aynı orana çeker (ritim senkronu, ADR-008).
## M0-06 iskeleti: ses veri yolu adları. Uygulama M2-05 ve M3'te eklenecek.

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
