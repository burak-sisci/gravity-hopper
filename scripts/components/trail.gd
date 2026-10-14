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

## İzin süre çarpanı (Player.set_trail_stretch verir).
var stretch: float = 1.0
## Kayıtlı konumlar (dünya), en yenisi başta: tick_count() + 2 adet.
var _history: PackedVector2Array = PackedVector2Array()


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
	set_ambient(Color.WHITE)


func _process(_delta: float) -> void:
	if _history.is_empty():
		return
	var world: PackedVector2Array = points_at(Engine.get_physics_interpolation_fraction())
	points = Transform2D(0.0, -world[0]) * world


## İzin kaç fizik adımı geriye uzandığı (süre NeonStyle'da).
func tick_count() -> int:
	return maxi(roundi(Neon.STYLE.trail_duration * stretch * Engine.physics_ticks_per_second), 1)


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


## İzin rengi: çekirdek oyuncunun beyazından paletin çevre rengine söner; parlama çevre renginde.
func set_ambient(ambient: Color) -> void:
	glow_color = ambient
	gradient.colors = PackedColorArray([Neon.STYLE.player_color, Color(ambient, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
