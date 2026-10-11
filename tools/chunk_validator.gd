class_name ChunkValidator
extends RefCounted
## Desen parçası doğrulayıcısı (M2-05, architecture.md §8.2). Bir parçanın izinli her sektör
## hızında adil biçimde geçilebildiğini kare kare (60 Hz) dener. Yalnızca geliştirici aracıdır:
## tools/validate_chunks.gd ve testler kullanır, yayın sürümüne girmez.
##
## Oyuncu modeli: duvardan duvara geçiş Player ile aynı fizikle hesaplanır. Oyuncu kusursuz
## zamanlar ama insandır: yere indikten sonra en az REACTION_MARGIN bekler. Böylece iki çevirme
## arası en az "geçiş süresi + tepki payı" olur (GDD §13).
##
## Parça her giriş durumundan geçilebilmeli: iki duvarda yeni inmiş olarak ve önceki parçadan
## kalan yarım geçişlerin her anında. Böylece parçalar hangi sırayla gelirse gelsin birleşim
## yeri de adil kalır. Tehlikeler kutu (AABB) olarak alınır; bu, birkaç piksel temkinlidir.

## Engelin ekrana girmesiyle oyuncuya değmesi arasındaki en kısa süre (GDD §13).
const MIN_WARNING_TIME: float = 1.2
## Yere inişle bir sonraki çevirme arasında insanın en az ihtiyaç duyduğu süre (GDD §13).
## Başlangıç değeri; M2-18 oyun testinde gözden geçirilir.
const REACTION_MARGIN: float = 0.2
## Sektörlerin tırmanış hızı (m/sn) ve temposu (BPM), GDD §12. M2-08'de SectorDef'ten okunur.
const SECTOR_SPEEDS: Array[Vector2] = [
	Vector2(12.0, 100.0), Vector2(14.0, 110.0), Vector2(16.0, 120.0),
	Vector2(18.0, 128.0), Vector2(20.0, 140.0),
]
const PHYSICS_DT: float = 1.0 / 60.0
## Tehlike fizik katmanı (project.godot → layer_names: hazard = 3. katman).
const HAZARD_LAYER: int = 4
const PLAYER_SCENE_PATH: String = "res://scenes/entities/player.tscn"

var _tuning: TuningConfig
var _body_size: Vector2


func _init(tuning: TuningConfig, body_size: Vector2) -> void:
	_tuning = tuning
	_body_size = body_size


## Oyuncu gövdesinin boyu, sahnesinden (örnek oluşturmadan) okunur.
static func player_body_size() -> Vector2:
	var state: SceneState = (load(PLAYER_SCENE_PATH) as PackedScene).get_state()
	for node: int in state.get_node_count():
		if state.get_node_name(node) != &"Body":
			continue
		for prop: int in state.get_node_property_count(node):
			if state.get_node_property_name(node, prop) == &"shape":
				return (state.get_node_property_value(node, prop) as RectangleShape2D).size
	push_error("ChunkValidator: oyuncu gövdesi bulunamadı")
	return Vector2.ZERO


## Kamera kuralı: her sektör hızında engel en az MIN_WARNING_TIME önceden görünür.
func view_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var reach: float = TuningConfig.to_px(_tuning.lookahead) - _hurt_half().y
	for i: int in SECTOR_SPEEDS.size():
		var warning: float = reach / TuningConfig.to_px(SECTOR_SPEEDS[i].x)
		if warning < MIN_WARNING_TIME:
			errors.append("S%d: engel %s sn önceden görünüyor (en az %s)" % [
				i + 1, ("%.2f" % warning).replace(".", ","), ("%.1f" % MIN_WARNING_TIME).replace(".", ","),
			])
	return errors


## Her sektörde en az bir parça seçilebilmeli; yoksa ChunkSpawner o sektörde durur.
static func coverage_errors(chunks: Array[ChunkInfo]) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	for sector: int in range(1, SECTOR_SPEEDS.size() + 1):
		var found: bool = false
		for chunk: ChunkInfo in chunks:
			found = found or chunk.allows_sector(sector)
		if not found:
			errors.append("S%d için parça yok" % sector)
	return errors


## Parçanın izinli tüm sektörlerdeki sorunları; boşsa parça geçerlidir.
func chunk_errors(chunk: ChunkInfo) -> PackedStringArray:
	var errors: PackedStringArray = chunk.design_errors()
	if not errors.is_empty():
		return errors
	for sector: int in range(chunk.min_sector, chunk.max_sector + 1):
		for message: String in sector_errors(chunk, sector):
			errors.append("S%d: %s" % [sector, message])
	return errors


## Parçanın tek bir sektör hızındaki sorunları.
func sector_errors(chunk: ChunkInfo, sector: int) -> PackedStringArray:
	var speed: Vector2 = SECTOR_SPEEDS[sector - 1]
	var beat: float = ChunkInfo.beat_px(speed.x, speed.y)
	var half_width: float = TuningConfig.to_px(_tuning.corridor_width) * 0.5
	var hazards: Array[Rect2] = []
	var names: Array[String] = []
	var errors: PackedStringArray = PackedStringArray()
	var top: float = -chunk.height_px(beat)
	for item: Node2D in chunk.items():
		var world: Vector2 = ChunkInfo.world_position(chunk.design_position(item), beat, half_width)
		for rect: Rect2 in _hazard_rects(item, world):
			if rect.position.y < top or rect.end.y > 0.0:
				errors.append("%s parçanın sınırından taşıyor" % item.name)
			hazards.append(rect)
			var item_beat: float = -chunk.design_position(item).y / ChunkInfo.BEAT_GRID_PX
			names.append("%s (%s. vuruş)" % [item.name, String.num(item_beat, 1).replace(".", ",")])
	if not errors.is_empty() or hazards.is_empty():
		return errors
	var sim: Simulation = Simulation.new(hazards, _hurt_half(), half_width - _body_size.x * 0.5,
			TuningConfig.to_px(speed.x), top, _tuning)
	var failure: String = sim.first_failure(names)
	if not failure.is_empty():
		errors.append(failure)
	return errors


func _hurt_half() -> Vector2:
	return _body_size * _tuning.hurtbox_scale * 0.5


## Bir öğenin dünyadaki tehlike kutuları (tehlike katmanındaki çarpışma şekilleri).
func _hazard_rects(item: Node2D, world: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var area: CollisionObject2D = item as CollisionObject2D
	if area == null or not (area.collision_layer & HAZARD_LAYER):
		return rects
	var item_xform: Transform2D = Transform2D(item.rotation, item.scale, item.skew, world)
	for child: Node in item.get_children():
		var points: PackedVector2Array = PackedVector2Array()
		if child is CollisionPolygon2D:
			points = (child as CollisionPolygon2D).transform * (child as CollisionPolygon2D).polygon
		elif child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			var shape_node: CollisionShape2D = child as CollisionShape2D
			var r: Rect2 = shape_node.shape.get_rect()
			points = shape_node.transform * PackedVector2Array([
				r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y),
			])
		if points.is_empty():
			continue
		points = item_xform * points
		var rect: Rect2 = Rect2(points[0], Vector2.ZERO)
		for point: Vector2 in points:
			rect = rect.expand(point)
		rects.append(rect)
	return rects


## Bir parçanın tek sektördeki kare kare denemesi. Durumlar: duvarda (taraf, inişten beri kare)
## ve geçişte (hedef taraf, çevirmeden beri kare). Sondan başa "buradan sağ çıkılabilir mi?"
## tablosu kurulur; giriş durumlarının hepsi güvenli olmalı.
class Simulation:
	extends RefCounted

	var _hazards: Array[Rect2]
	var _hurt_half: Vector2
	var _wall_x: float
	var _step_y: float
	var _start_y: float
	var _frames: int
	## Yere indikten sonra çevirmeye izin verilen kare.
	var _dwell: int
	## Geçiş kare sayısı ve her karedeki x (sağa doğru; sola doğru için ters işaret).
	var _transit: PackedFloat32Array = PackedFloat32Array()

	func _init(hazards: Array[Rect2], hurt_half: Vector2, wall_x: float, climb_px: float,
			top: float, tuning: TuningConfig) -> void:
		_hazards = hazards
		_hurt_half = hurt_half
		_wall_x = wall_x
		_step_y = climb_px * PHYSICS_DT
		# Başlangıç: çarpışma kutusunun üstü parçanın alt kenarının hemen altında.
		_start_y = _hurt_half.y + 0.5
		_frames = ceili((_start_y + _hurt_half.y - top) / _step_y) + 1
		# Kayan nokta payı: 0,2 sn tam 12 kare sayılsın.
		_dwell = ceili(REACTION_MARGIN / PHYSICS_DT - 0.001)
		# Geçiş: Player._physics_process ile aynı (hız sınırlı ivme, duvara değince durur).
		var accel: float = TuningConfig.to_px(tuning.gravity_accel)
		var max_side: float = TuningConfig.to_px(tuning.max_side_speed)
		var x: float = -_wall_x
		var vx: float = 0.0
		_transit.append(x)
		while x < _wall_x:
			vx = minf(vx + accel * PHYSICS_DT, max_side)
			x = minf(x + vx * PHYSICS_DT, _wall_x)
			_transit.append(x)

	## Güvenli olmayan ilk giriş durumunun açıklaması; hepsi güvenliyse boş.
	func first_failure(names: Array[String]) -> String:
		var safe: PackedByteArray = _safe_at_start()
		for state: int in _entry_states():
			if safe[state] == 0:
				return _explain(state, names)
		return ""

	func _state_count() -> int:
		return _wall_count() + 2 * _landing()

	## Geçişin kaçıncı karede bittiği (o kare duvardadır).
	func _landing() -> int:
		return _transit.size() - 1

	func _wall_state(side: int, dwell: int) -> int:
		return side * (_dwell + 1) + dwell

	## Hedefi side olan geçişin k. karesi (1 ≤ k < iniş).
	func _transit_state(side: int, k: int) -> int:
		return _wall_count() + side * _landing() + (k - 1)

	func _wall_count() -> int:
		return 2 * (_dwell + 1)

	## Durumun tarafı: duvardaysa bulunduğu, geçişteyse gittiği duvar (0 sol, 1 sağ).
	func _side(state: int) -> int:
		if state < _wall_count():
			return 1 if state > _dwell else 0
		return 1 if state - _wall_count() >= _landing() else 0

	## Duvardaysa inişten beri, geçişteyse çevirmeden beri geçen kare.
	func _age(state: int) -> int:
		if state < _wall_count():
			return state - _side(state) * (_dwell + 1)
		return state - _wall_count() - _side(state) * _landing() + 1

	func _entry_states() -> Array[int]:
		var states: Array[int] = [_wall_state(0, 0), _wall_state(1, 0)]
		for side: int in 2:
			for k: int in range(1, _landing()):
				states.append(_transit_state(side, k))
		return states

	func _next_states(state: int) -> Array[int]:
		var side: int = _side(state)
		var age: int = _age(state)
		if state < _wall_count():
			var result: Array[int] = [_wall_state(side, mini(age + 1, _dwell))]
			if age == _dwell:
				result.append(_after_transit_step(1 - side, 1))
			return result
		return [_after_transit_step(side, age + 1)]

	func _after_transit_step(side: int, k: int) -> int:
		return _wall_state(side, 0) if k >= _landing() else _transit_state(side, k)

	func _x_of(state: int) -> float:
		var x: float = _wall_x if state < _wall_count() else _transit[_age(state)]
		return x if _side(state) == 1 else -x

	func _y_of(frame: int) -> float:
		return _start_y - frame * _step_y

	## Kutunun değdiği tehlikelerin sıra numaraları.
	func _hits(frame: int, x: float) -> Array[int]:
		var body: Rect2 = Rect2(Vector2(x, _y_of(frame)) - _hurt_half, _hurt_half * 2.0)
		var result: Array[int] = []
		for i: int in _hazards.size():
			if body.intersects(_hazards[i]):
				result.append(i)
		return result

	## Sondan başa: safe[s] = bu karede s'de canlıyken parçanın sonuna sağ çıkılabilir mi?
	func _safe_at_start() -> PackedByteArray:
		var count: int = _state_count()
		var safe: PackedByteArray = PackedByteArray()
		safe.resize(count)
		safe.fill(1)
		for frame: int in range(_frames, -1, -1):
			var current: PackedByteArray = PackedByteArray()
			current.resize(count)
			for state: int in count:
				if not _hits(frame, _x_of(state)).is_empty():
					continue
				if frame == _frames:
					current[state] = 1
					continue
				for next: int in _next_states(state):
					if safe[next] == 1:
						current[state] = 1
						break
			safe = current
		return safe

	## Girişten ileriye: tüm yolların tükendiği karede neye çarpıldığını anlatır.
	func _explain(entry: int, names: Array[String]) -> String:
		var alive: Array[int] = [entry]
		var hit_names: Array[String] = []
		for frame: int in range(0, _frames + 1):
			var next_alive: Array[int] = []
			var candidates: Array[int] = []
			if frame == 0:
				candidates = alive
			else:
				for state: int in alive:
					for next: int in _next_states(state):
						if not candidates.has(next):
							candidates.append(next)
			hit_names.clear()
			for state: int in candidates:
				var hits: Array[int] = _hits(frame, _x_of(state))
				if hits.is_empty():
					next_alive.append(state)
				for i: int in hits:
					if not hit_names.has(names[i]):
						hit_names.append(names[i])
			if next_alive.is_empty():
				var seconds: String = ("%.2f" % (frame * PHYSICS_DT)).replace(".", ",")
				return "%s girişte %s sn sonra geçilemiyor: %s" % [
					_entry_name(entry), seconds, "; ".join(hit_names),
				]
			alive = next_alive
		return "%s girişte geçilemiyor" % _entry_name(entry)

	func _entry_name(state: int) -> String:
		if state < _wall_count():
			return "sağ duvardan" if _side(state) == 1 else "sol duvardan"
		return "%s geçişin %d. karesinden" % ["sağa" if _side(state) == 1 else "sola", _age(state)]
