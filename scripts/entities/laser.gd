class_name Laser
extends Area2D
## Lazer ışını (M2-12, GDD §6). Duvara bağlı yatay ışın: kökü duvarda, +x yönünde length kadar
## koridora uzanır (sağ duvarda scale.x = -1). Vuruşla yanıp söner: açık penceresi vuruşa
## ortalıdır (her vuruşun çeyrek öncesinden çeyrek sonrasına kadar). Engeller yarım vuruş
## ızgarasında durduğu için oyuncu ışını ya tamamen açıkken ya tamamen kapalıyken geçer.
## on_phase = 0,5 ile yarım vuruşta yanan ışın, tam vuruşta geçilirken kapalıdır (aldatıcı).
## Açıkken tehlikedir, kapalıyken sönük bir çizgi. İki duvardan birer ışın, ortada açıklık
## bırakan bir lazer kapısı olur.
##
## Görünüş (M3-06): yanık ışın, kutu kalınlığında kırmızı neon çizgi (Blade) ve ucunda
## parlamasız sivri bir üçgendir (Tip; parlama kopyaları sivri uçta iz bırakıyordu); ortasında
## beyaza yakın bir çekirdek (Core) yanar. Uç kutudan taşar. Sönükken ince ray (Rail) kalır
## ve yanmadan hemen önce kalınlaşıp parlar (uyarı ışıması).
## Bıçak yalnızca çarpışma açıkken görünür: görüntü ve çarpışma aynı adımda değişir.
##
## Pasiftir: oyuncuyu tanımaz. Vuruşu Run → ChunkSpawner → ChunkInfo zinciriyle aşağıdan alır
## (set_beat). Doğrulayıcı aynı kuralı is_on_at() ile hesaplar.

## Işının açık kaldığı süre (vuruş).
const ON_LENGTH: float = 0.5
const THICKNESS: float = 16.0

## Işının koridora uzanan boyu (px; koridor 900 px).
@export_range(50.0, 900.0, 50.0, "suffix:px") var length: float = 450.0
## Açık penceresinin ortası, vuruş içinde (0 = vuruşta yanar, 0,5 = yarım vuruşta).
@export_range(0.0, 0.5, 0.5) var on_phase: float = 0.0

var _on: bool = true

@onready var _shape: CollisionShape2D = $Shape
@onready var _rail: NeonLine = $Rail
@onready var _blade: NeonLine = $Blade
@onready var _tip: Polygon2D = $Blade/Tip
@onready var _core: Line2D = $Blade/Core


func _ready() -> void:
	# Her ışının kendi şekli olur (sahnedeki şekil kaynağı örnekler arasında paylaşılırdı).
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(length, THICKNESS)
	_shape.shape = rect
	_shape.position = Vector2(length * 0.5, 0.0)
	_blade.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])
	_blade.width = THICKNESS
	var half: float = THICKNESS * 0.5
	_tip.polygon = PackedVector2Array([
		Vector2(length, -half), Vector2(length + Neon.STYLE.laser_tip_px, 0.0), Vector2(length, half),
	])
	_tip.color = _blade.shown_color()
	_core.points = _blade.points
	_core.width = THICKNESS * Neon.STYLE.laser_core_ratio
	_core.default_color = _blade.shown_color().lerp(Color.WHITE, Neon.STYLE.laser_core_whiten)
	_rail.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])
	_apply(true)


## Işının kendi uzayındaki kutusu (doğrulayıcı da kullanır; sahne ağaçta olmasa bile).
func beam_rect() -> Rect2:
	return Rect2(0.0, -THICKNESS * 0.5, length, THICKNESS)


## Verilen vuruş konumunda (tempo ızgarasının başından beri geçen vuruş) ışın açık mı?
func is_on_at(beat: float) -> bool:
	return fposmod(beat - on_phase + ON_LENGTH * 0.5, 1.0) < ON_LENGTH


## Uyarı ışımasının gücü (0–1): yanmadan laser_warn_beats önce 0'dan başlar, yanarken 0.
func warning_at(beat: float) -> float:
	if is_on_at(beat):
		return 0.0
	var until_on: float = fposmod(on_phase - ON_LENGTH * 0.5 - beat, 1.0)
	return clampf(1.0 - until_on / Neon.STYLE.laser_warn_beats, 0.0, 1.0)


## Run'dan gelen vuruş konumuna göre ışını yakar ya da söndürür.
func set_beat(beat: float) -> void:
	var on: bool = is_on_at(beat)
	if on != _on:
		_apply(on)
	if not on:
		_show_rail(warning_at(beat))


func is_on() -> bool:
	return _on


## Yanık ışın (bıçak) görünüyor mu.
func is_lit() -> bool:
	return _blade.visible


func _apply(on: bool) -> void:
	_on = on
	_shape.disabled = not on
	_blade.visible = on
	_rail.visible = not on
	if not on:
		_show_rail(0.0)


## Sönük ray: uyarı gücüyle kalınlaşıp parlar.
func _show_rail(warning: float) -> void:
	var style: NeonStyle = Neon.STYLE
	_rail.modulate.a = lerpf(style.laser_off_alpha, style.laser_warn_alpha, warning)
	var rail_width: float = lerpf(style.laser_off_width, style.laser_warn_width, warning)
	if not is_equal_approx(_rail.width, rail_width):
		_rail.width = rail_width
