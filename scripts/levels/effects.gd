class_name Effects
extends Node2D
## Tur içi parçacık patlamaları (M3-11, architecture.md §9): iniş kıvılcımı, Glimmer patlaması,
## ölüm patlaması ve final patlaması (M4-13). Her tür için birkaç CPUParticles2D tur kurulurken bir
## kez oluşturulur ve sırayla yeniden kullanılır (halka); tur sırasında düğüm oluşmaz
## (.clauderules §6). Parçacıklar dünya
## koordinatındadır: yayıcı yeni bir yere taşınınca eski parçacıkları yerinde söner.
## Görünüş NeonStyle'daki BurstStyle'lardan gelir; parçacık sayısı efekt kalitesiyle azalır
## (Neon.GROUP → apply_quality). Run aşağı çağrıyla kullanır; Effects oyunu tanımaz.
## Final patlaması (Büyük Depolama Birimi): her yayıcı verilen renklerden birinde (bütün
## sektörlerin renkleri) aynı anda patlar. Parçacıkları yayıcının koordinatındadır ve Run
## yayıcıları oyuncuyla taşır (track_finale): oyuncu saniyede 1100 px tırmanırken patlama onun
## çevresinde kalır.

## Her türün halkasındaki yayıcı sayısı: art arda gelen patlamalar birbirini kesmesin.
const SPARK_EMITTERS: int = 3
const GLIMMER_EMITTERS: int = 3
const DEATH_EMITTERS: int = 1
const FINALE_EMITTERS: int = 5


## Bir patlama türünün yayıcı halkası.
class Ring:
	var style: BurstStyle
	var emitters: Array[CPUParticles2D] = []
	var next: int = 0


var _ambient: Color = Color.WHITE
var _spark_ring: Ring
var _glimmer_ring: Ring
var _death_ring: Ring
var _finale_ring: Ring


func _ready() -> void:
	add_to_group(Neon.GROUP)
	_spark_ring = _make_ring(Neon.STYLE.landing_spark, SPARK_EMITTERS)
	_glimmer_ring = _make_ring(Neon.STYLE.glimmer_burst, GLIMMER_EMITTERS)
	_death_ring = _make_ring(Neon.STYLE.death_burst, DEATH_EMITTERS)
	_finale_ring = _make_ring(Neon.STYLE.finale_burst, FINALE_EMITTERS)
	for emitter: CPUParticles2D in _finale_ring.emitters:
		emitter.local_coords = true
	apply_quality()


## İniş kıvılcımı: duvara değilen noktadan (at) koridorun içine saçılır. side: duvarın yönü.
func landing_spark(at: Vector2, side: float) -> void:
	_fire(_spark_ring, at, Vector2(-side, 0.0))


## Glimmer patlaması: toplanan Glimmer'ın yerinde, her yöne.
func glimmer_burst(at: Vector2) -> void:
	_fire(_glimmer_ring, at, Vector2.UP)


## Ölüm patlaması: çekirdeğin yerinde, her yöne.
func death_burst(at: Vector2) -> void:
	_fire(_death_ring, at, Vector2.UP)


## Final patlaması: bütün yayıcılar at'ta, sırayla colors'ın renklerinde, her yöne.
func finale_burst(at: Vector2, colors: Array[Color]) -> void:
	if colors.is_empty():
		return
	for i: int in _finale_ring.emitters.size():
		var emitter: CPUParticles2D = _finale_ring.emitters[i]
		_paint(_finale_ring.style, emitter.color_ramp, colors[i % colors.size()])
		_restart(emitter, at, Vector2.UP)


## Final patlamasını oyuncuyla taşır (parçacıklar yayıcının koordinatında).
func track_finale(at: Vector2) -> void:
	for emitter: CPUParticles2D in _finale_ring.emitters:
		emitter.global_position = at


## Final patlamasının yayıcıları (testler).
func finale_emitters() -> Array[CPUParticles2D]:
	return _finale_ring.emitters.duplicate() if _finale_ring != null else []


## Sektörün çevre rengi (Run, palet değişince çağırır): renk kaynağı CUSTOM olan patlamalar.
## Final patlamasının renkleri kendi verilir; çevre rengi onu boyamaz.
func set_ambient(color: Color) -> void:
	_ambient = color
	for ring: Ring in _rings():
		for emitter: CPUParticles2D in ring.emitters:
			_color_ramp(ring.style, emitter.color_ramp)


## Parçacık sayısını geçerli kaliteye göre ayarlar (Neon.set_quality çağırır). Sayı değişince
## yayıcı yeniden kurulur; bu yalnızca kalite değişiminde olur.
func apply_quality() -> void:
	var rings: Array[Ring] = _rings()
	if _finale_ring != null:
		rings.append(_finale_ring)
	for ring: Ring in rings:
		var amount: int = Neon.STYLE.particle_amount(ring.style.amount, Neon.quality)
		for emitter: CPUParticles2D in ring.emitters:
			if emitter.amount != amount:
				emitter.amount = amount


## Halkadaki yayıcılar (testler ve tezgâh için): kıvılcım, Glimmer, ölüm sırasıyla.
func emitters() -> Array[CPUParticles2D]:
	var result: Array[CPUParticles2D] = []
	for ring: Ring in _rings():
		result.append_array(ring.emitters)
	return result


func _rings() -> Array[Ring]:
	if _spark_ring == null:
		return []
	return [_spark_ring, _glimmer_ring, _death_ring]


## Halkanın sıradaki yayıcısını yerine taşır ve patlatır. Ara değerleme sıfırlanır; yoksa yayıcı
## eski yerinden kayarak gelir ve ilk parçacıklar arada bir çizgiye saçılırdı.
func _fire(ring: Ring, at: Vector2, direction: Vector2) -> void:
	var emitter: CPUParticles2D = ring.emitters[ring.next]
	ring.next = (ring.next + 1) % ring.emitters.size()
	_restart(emitter, at, direction)


func _restart(emitter: CPUParticles2D, at: Vector2, direction: Vector2) -> void:
	emitter.global_position = at
	emitter.direction = direction
	emitter.reset_physics_interpolation()
	emitter.restart()


func _make_ring(style: BurstStyle, count: int) -> Ring:
	var ring: Ring = Ring.new()
	ring.style = style
	for i: int in count:
		var emitter: CPUParticles2D = _make_emitter(style)
		add_child(emitter)
		ring.emitters.append(emitter)
	return ring


## Tek seferlik, hepsi aynı anda çıkan, toplamsal ışık lekeleri. Parçacık ömrü boyunca küçülür
## ve söner; uzayan türlerde (kıvılcım) hareket yönünde çizgi gibi görünür.
func _make_emitter(style: BurstStyle) -> CPUParticles2D:
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.local_coords = false
	emitter.texture = Neon.blob_texture()
	emitter.material = Neon.additive_material()
	emitter.amount = style.amount
	emitter.lifetime = style.lifetime
	emitter.spread = style.spread
	emitter.gravity = Vector2.ZERO
	emitter.initial_velocity_min = style.speed.x
	emitter.initial_velocity_max = style.speed.y
	emitter.damping_min = style.damping
	emitter.damping_max = style.damping
	emitter.scale_amount_min = style.size.x
	emitter.scale_amount_max = style.size.y
	if style.stretch > 1.0:
		emitter.particle_flag_align_y = true
		emitter.split_scale = true
		emitter.scale_curve_x = _shrink_curve(1.0)
		emitter.scale_curve_y = _shrink_curve(style.stretch)
	else:
		emitter.scale_amount_curve = _shrink_curve(1.0)
	emitter.color_ramp = Gradient.new()
	_color_ramp(style, emitter.color_ramp)
	return emitter


## Ömür boyunca start'tan sıfıra inen eğri.
func _shrink_curve(start: float) -> Curve:
	var curve: Curve = Curve.new()
	curve.max_value = maxf(start, 1.0)
	curve.add_point(Vector2(0.0, start))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


## Başta beyaza çekilmiş sıcak çekirdek, ortada kendi rengi, sonda saydam.
func _color_ramp(style: BurstStyle, ramp: Gradient) -> void:
	_paint(style, ramp, Neon.STYLE.tone_color(style.tone, _ambient))


func _paint(style: BurstStyle, ramp: Gradient, color: Color) -> void:
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([
		color.lerp(Color.WHITE, style.whiten), color, Color(color, 0.0),
	])
