class_name SpeedLines
extends Node2D
## Hız çizgileri (M3-13, architecture.md §9, GDD §13): dünyanın ardında, ekranda aşağı akan ince
## dikey çizgiler. Dünyadan hızlı düşerek oyuna gerçekte olmayan bir hız katarlar. Tırmanış hızı
## arttıkça (NeonStyle.speed_feel) sayıları, boyları, parlaklıkları ve düşüş hızları artar; yeni
## sektörün değerine speed_feel_rate hızıyla yaklaşır. Ölümde yeniden doğmaz, akarken söner.
## Yalnızca görseldir: konum ve sapmalar kozmetik rastgelelikle (global randf) seçilir, turun
## RNG'sine dokunmaz. Çizgiler kurulurken ayrılan sabit dizilerde durur (en çok
## speed_line_count.y); ekranın altından çıkan çizgi üstten yeniden doğar. Hepsi tek dokuyla
## (dikey gradyan: kuyruk saydam, baş parlak) ve toplamsal çizilir.
## Background'ın çocuğu (ekran koordinatı); Background set_speed, set_color ve stop'u aşağı
## çağırır. Hız verilmeden (0) çizgi yoktur. Sayı kaliteyle azalır (parçacık oranları).

## Çizgi dokusunun yüksekliği (px); doku çizginin boyuna gerilir.
const TEXTURE_HEIGHT: int = 64

static var _texture: GradientTexture2D = null

var _climb_px: float = 0.0
## Gösterilen hız hissi; hedefe (sektörün hissi) yaklaşır.
var _feel: float = 0.0
var _target_feel: float = 0.0
var _color: Color = Color.WHITE
## Ölümden sonra sönme (1 = tam görünür).
var _fade: float = 1.0
var _stopped: bool = false
## Çizilen çizgi sayısı (hız hissine ve kaliteye göre).
var _active: int = 0
## Çizgiler: x, başın (alt uç) y'si, boy ve hız sapması (−1 – 1).
var _x: PackedFloat32Array = PackedFloat32Array()
var _y: PackedFloat32Array = PackedFloat32Array()
var _length_jitter: PackedFloat32Array = PackedFloat32Array()
var _speed_jitter: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	material = Neon.additive_material()
	var count: int = Neon.STYLE.speed_line_count.y
	_x.resize(count)
	_y.resize(count)
	_length_jitter.resize(count)
	_speed_jitter.resize(count)
	for i: int in count:
		_respawn(i, true)
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	var style: NeonStyle = Neon.STYLE
	_feel = move_toward(_feel, _target_feel, style.speed_feel_rate * delta)
	if _stopped:
		_fade = move_toward(_fade, 0.0, delta / style.speed_line_fade)
	else:
		_set_active(style.speed_line_amount(_feel, Neon.quality))
	var speed: float = _climb_px * lerpf(style.speed_line_speed.x, style.speed_line_speed.y, _feel)
	var bottom: float = get_viewport_rect().size.y
	for i: int in _active:
		_y[i] += speed * (1.0 + style.speed_line_jitter * _speed_jitter[i]) * delta
		if not _stopped and _y[i] - line_length(i) > bottom:
			_respawn(i, false)
	queue_redraw()


func _draw() -> void:
	var style: NeonStyle = Neon.STYLE
	var width: float = style.speed_line_width
	var tint: Color = Color(_color,
			lerpf(style.speed_line_alpha.x, style.speed_line_alpha.y, _feel) * _fade)
	for i: int in _active:
		var length: float = line_length(i)
		draw_texture_rect(_streak_texture(), Rect2(_x[i] - width * 0.5, _y[i] - length, width,
				length), false, tint)


## Tırmanış hızı (m/sn). instant ise his hemen yerindedir ve ekran çizgilerle dolu başlar (tur
## başı); değilse his yavaşça yeni değere gider, yeni çizgiler ekranın üstünden girer.
func set_speed(climb_speed: float, instant: bool) -> void:
	_climb_px = TuningConfig.to_px(climb_speed)
	_target_feel = Neon.STYLE.speed_feel(climb_speed)
	visible = _climb_px > 0.0
	if instant:
		_feel = _target_feel
		_active = Neon.STYLE.speed_line_amount(_feel, Neon.quality)
		for i: int in _active:
			_respawn(i, true)


## Çizgilerin rengi (sektörün çevre rengi).
func set_color(color: Color) -> void:
	_color = color
	queue_redraw()


## Ölüm: çizgiler yeniden doğmaz, speed_line_fade içinde söner.
func stop() -> void:
	_stopped = true


func active_count() -> int:
	return _active


func feel() -> float:
	return _feel


func head_y(index: int) -> float:
	return _y[index]


## Çizginin boyu: hız hissine göre, kendi sapmasıyla.
func line_length(index: int) -> float:
	var style: NeonStyle = Neon.STYLE
	return lerpf(style.speed_line_length.x, style.speed_line_length.y, _feel) \
			* (1.0 + style.speed_line_jitter * _length_jitter[index])


## Görünür çizgi sayısını değiştirir; yeni çizgiler ekranın üstünden, aralıklı girer.
func _set_active(count: int) -> void:
	count = mini(count, _x.size())
	for i: int in range(_active, count):
		_respawn(i, false)
	_active = count


## Çizgiyi yeni bir yere koyar: anywhere ise ekranın herhangi bir yerine, değilse üst kenarın
## üstüne (yarım ekran boyu içinde rastgele bir mesafeye; hepsi aynı anda girmesin).
func _respawn(index: int, anywhere: bool) -> void:
	var view: Vector2 = get_viewport_rect().size
	_x[index] = randf() * view.x
	_length_jitter[index] = randf_range(-1.0, 1.0)
	_speed_jitter[index] = randf_range(-1.0, 1.0)
	if anywhere:
		_y[index] = randf() * (view.y + line_length(index))
	else:
		_y[index] = -randf() * view.y * 0.5


static func _streak_texture() -> GradientTexture2D:
	if _texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0)])
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.width = 1
		_texture.height = TEXTURE_HEIGHT
		_texture.fill_from = Vector2(0.0, 0.0)
		_texture.fill_to = Vector2(0.0, 1.0)
	return _texture
