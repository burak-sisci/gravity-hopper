class_name Trail
extends NeonLine
## Oyuncunun neon izi (M3-04, architecture.md §9): geçmiş konumlardan beslenen, ucu sivrilip
## sönen NeonLine. Sahibi (Player) konumunu her fizik adımında record() ile bildirir; çizim
## _process'te yapılır. Baş ve kuyruk fizik ara değerleme kesriyle birlikte kayar, böylece
## izin süresi ve boyu ekran yenileme hızından bağımsızdır (60 ve 120 Hz'de aynı).
## Noktalar sahibinin yerel koordinatındadır: baş, oyuncunun çizildiği yerdedir.
## Hızla uzayan iz (M3-13): süre stretch katıyla uzar (hız hissi, NeonStyle.trail_stretch).
## Süre değişince kayıtlar korunur; uzarken eklenen kayıtlar kuyruktaki konumdadır, iz yeni boyuna
## kendiliğinden uzar.
## Kozmetik iz (M4-08): apply_def() renk geçişini, kalınlığı, parlamayı ve boyu TrailDef'ten alır.
## Varsayılan iz (tanım yok ya da renksiz) beyazdan sektörün çevre rengine söner; renkli izde
## yalnızca saydam parlama rengi sektörü izler.

## İzin süre çarpanı (Player.set_trail_stretch verir).
var stretch: float = 1.0
## Kayıtlı konumlar (dünya), en yenisi başta: tick_count() + 2 adet.
var _history: PackedVector2Array = PackedVector2Array()
## Kuşanılan iz; null = varsayılan.
var _def: TrailDef
## Sektörün çevre rengi (son set_ambient).
var _ambient: Color = Color.WHITE


func _init() -> void:
	# GDScript üst sınıfın kurucusunu kendiliğinden çağırmaz; çizgiler orada kurulur.
	super()
	width = Neon.STYLE.trail_width
	var taper: Curve = Curve.new()
	taper.add_point(Vector2(0.0, 1.0))
	taper.add_point(Vector2(1.0, 0.0))
	width_curve = taper
	var fade: Gradient = Gradient.new()
	gradient = fade
	_update_colors()


func _process(_delta: float) -> void:
	if _history.is_empty():
		return
	var world: PackedVector2Array = points_at(Engine.get_physics_interpolation_fraction())
	points = Transform2D(0.0, -world[0]) * world


## İzin kaç fizik adımı geriye uzandığı (süre NeonStyle'da; izin boy çarpanı ve hız uzaması).
func tick_count() -> int:
	var duration: float = Neon.STYLE.trail_duration * stretch * _length_scale()
	return maxi(roundi(duration * Engine.physics_ticks_per_second), 1)


## Kuşanılan izi uygular (Player.set_trail; null = varsayılan iz). Kayıtlar korunur.
func apply_def(def: TrailDef) -> void:
	_def = def
	width = Neon.STYLE.trail_width * (def.width_scale if def != null else 1.0)
	glow_width_scale = def.glow_scale if def != null else 1.0
	_update_colors()


func trail_def() -> TrailDef:
	return _def


## Sahibi her fizik adımında çağırır: bu adımın sonundaki konum (dünya).
func record(world_position: Vector2) -> void:
	var size: int = tick_count() + 2
	if _history.is_empty():
		reset(world_position)
		return
	if _history.size() != size:
		_resize(size)
	for i: int in range(size - 1, 0, -1):
		_history[i] = _history[i - 1]
	_history[0] = world_position


## İzi siler: bütün kayıtlar bu konumda (yeni tur, ışınlanma).
func reset(world_position: Vector2) -> void:
	_history.resize(tick_count() + 2)
	_history.fill(world_position)


## Süre değişti: kayıtlar korunur, yeni kayıtlar kuyruğun konumunda.
func _resize(size: int) -> void:
	var tail: Vector2 = _history[_history.size() - 1]
	var old: int = _history.size()
	_history.resize(size)
	for i: int in range(old, size):
		_history[i] = tail


## İzin dünya noktaları, verilen ara değerleme kesrinde (0 = son fizik adımı). Baş, oyuncunun
## çizildiği yer: önceki ve son adımın arası. Kuyruk da aynı kesirle kayar; iz hep tick_count()
## adımlık süreyi kaplar.
func points_at(fraction: float) -> PackedVector2Array:
	var count: int = _history.size()
	var result: PackedVector2Array = _history.duplicate()
	if count < 3:
		return result
	result[0] = _history[1].lerp(_history[0], fraction)
	result[count - 1] = _history[count - 1].lerp(_history[count - 2], fraction)
	return result


## Sektörün çevre rengi (Player.set_ambient, palet geçişinde): varsayılan iz oyuncunun beyazından
## bu renge söner, parlama bu renktedir. Renkli izde yalnızca saydam parlama rengi bunu izler.
func set_ambient(ambient: Color) -> void:
	_ambient = ambient
	_update_colors()


func _length_scale() -> float:
	return _def.length_scale if _def != null else 1.0


## Renk geçişi eşit aralıklı, kuyruk saydama söner.
func _update_colors() -> void:
	var colors: PackedColorArray = PackedColorArray([Neon.STYLE.player_color, _ambient])
	if _def != null and not _def.follows_ambient():
		colors = _def.colors.duplicate()
	var last: int = colors.size() - 1
	colors[last] = Color(colors[last], 0.0)
	var offsets: PackedFloat32Array = PackedFloat32Array()
	for i: int in colors.size():
		offsets.append(float(i) / last)
	gradient.offsets = offsets
	gradient.colors = colors
	var glow: Color = _ambient
	if _def != null and _def.glow_color.a > 0.0:
		glow = _def.glow_color
	glow_color = glow
