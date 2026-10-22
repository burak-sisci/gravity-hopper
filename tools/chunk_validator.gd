class_name ChunkValidator
extends RefCounted
## Desen parçası doğrulayıcısı (M2-05, architecture.md §8.2). Bir parçanın izinli her sektör
## hızında ve müzik kataloğundaki her tempoda (M2-20: tempo turun parçasından gelir) adil biçimde
## geçilebildiğini kare kare (60 Hz) dener. Yalnızca geliştirici aracıdır: tools/validate_chunks.gd
## ve testler kullanır, yayın sürümüne girmez.
##
## Oyuncu modeli: duvardan duvara geçiş Player ile aynı fizikle hesaplanır. Oyuncu kusursuz
## zamanlar ama insandır: yere indikten sonra en az REACTION_MARGIN bekler. Böylece iki çevirme
## arası en az "geçiş süresi + tepki payı" olur (GDD §13).
##
## Glimmer (M2-13): her Glimmer adil bir yolda toplanabilmeli (girişten sona güvenli bir yol,
## toplama alanı Glimmer'a değiyor) ve riskli yolda olmalı: bir tehlikeye ya da boşluğa dikeyde
## en fazla bir vuruş uzakta.
##
## Lazer (M2-12): ışın yalnızca açık olduğu karelerde tehlikedir. Açık olup olmadığı oyundaki
## kuralla (Laser.is_on_at) oyuncunun parça içindeki vuruş konumundan hesaplanır; parçalar tam
## vuruşta başladığı için bu, oyundaki vuruş saatiyle aynıdır.
##
## Duvar boşluğu (M2-11): gövde tamamen boşluğun içindeyken o duvarda (ya da oraya inerken)
## bulunmak düşmek sayılır. Coyote süresi tanınmaz; doğrulama oyundan biraz daha sıkıdır.
##
## Hareketli tehlikeler (M4-10): dönen şekil ve hareketli blok her karede, oyuncunun vuruş
## konumundaki duruşuyla (MovingHazard.polygon_at, oyundaki set_beat ile aynı hesap) denenir.
## Kutuya çevrilmezler: eğik çubuğun kutusu çok temkinli olurdu; gövde kutusu ile dışbükey çokgen
## ayırıcı eksen yöntemiyle kesiştirilir.
##
## Parça her giriş durumundan geçilebilmeli: iki duvarda yeni inmiş olarak ve önceki parçadan
## kalan yarım geçişlerin her anında. Böylece parçalar hangi sırayla gelirse gelsin birleşim
## yeri de adil kalır. Tehlikeler kutu (AABB) olarak alınır; bu, birkaç piksel temkinlidir.

## Engelin ekrana girmesiyle oyuncuya değmesi arasındaki en kısa süre (GDD §13).
const MIN_WARNING_TIME: float = 1.2
## Yere inişle bir sonraki çevirme arasında insanın en az ihtiyaç duyduğu süre (GDD §13).
## Başlangıç değeri; M2-18 oyun testinde gözden geçirilir.
const REACTION_MARGIN: float = 0.2
const PHYSICS_DT: float = 1.0 / 60.0
## Tehlike fizik katmanı (project.godot → layer_names: hazard = 3. katman).
const HAZARD_LAYER: int = 4
const PLAYER_SCENE_PATH: String = "res://scenes/entities/player.tscn"

var _tuning: TuningConfig
var _body_size: Vector2
## Sektörlerin hızı buradan okunur; katalogda olmayan sektörler denenmez.
var _sectors: SectorCatalog
## Turlarda çalabilecek tempolar (müzik kataloğundan).
var _tempos: Array[float] = []


func _init(tuning: TuningConfig, body_size: Vector2, sectors: SectorCatalog,
		music: MusicCatalog) -> void:
	_tuning = tuning
	_body_size = body_size
	_sectors = sectors
	_tempos = music.tempos()


## Denenen tempolar (araç özeti).
func tempos() -> Array[float]:
	return _tempos.duplicate()


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
	for sector: int in range(1, _sectors.count() + 1):
		var warning: float = reach / _sectors.def_at(sector).climb_px()
		if warning < MIN_WARNING_TIME:
			errors.append("S%d: engel %s sn önceden görünüyor (en az %s)" % [
				sector, ("%.2f" % warning).replace(".", ","),
				("%.1f" % MIN_WARNING_TIME).replace(".", ","),
			])
	return errors


## Her sektörde en az bir parça seçilebilmeli; yoksa ChunkSpawner o sektörde durur.
func coverage_errors(chunks: Array[ChunkInfo]) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	for sector: int in range(1, _sectors.count() + 1):
		var found: bool = false
		for chunk: ChunkInfo in chunks:
			found = found or chunk.allows_sector(sector)
		if not found:
			errors.append("S%d için parça yok" % sector)
	return errors


## Parçanın izinli tüm sektörlerdeki (katalogda olanlar) ve tüm tempolardaki sorunları; boşsa
## parça geçerlidir.
func chunk_errors(chunk: ChunkInfo) -> PackedStringArray:
	var errors: PackedStringArray = chunk.design_errors()
	if not errors.is_empty():
		return errors
	for sector: int in range(chunk.min_sector, mini(chunk.max_sector, _sectors.count()) + 1):
		var allowed: Array[StringName] = _sectors.def_at(sector).allowed_hazards
		for type: StringName in chunk.hazard_types():
			if not allowed.has(type):
				errors.append("S%d: '%s' bu sektörde izinli değil" % [sector, type])
		for bpm: float in _tempos:
			for message: String in sector_errors(chunk, sector, bpm):
				errors.append("S%d %s BPM: %s" % [sector, String.num(bpm), message])
	return errors


## Parçanın tek bir sektör hızında ve tempodaki sorunları.
func sector_errors(chunk: ChunkInfo, sector: int, bpm: float) -> PackedStringArray:
	var def: SectorDef = _sectors.def_at(sector)
	var beat: float = def.beat_px(bpm)
	var half_width: float = TuningConfig.to_px(_tuning.corridor_width) * 0.5
	var hazards: Array[Rect2] = []
	var hazard_names: Array[String] = []
	## Her tehlike kutusunun lazeri (sürekli tehlikelerde null).
	var lasers: Array[Laser] = []
	var gaps: Array[Vector3] = []
	var gap_names: Array[String] = []
	var movers: Array[MovingHazard] = []
	## Her hareketli tehlikeyi dünyaya yerleştiren dönüşüm ve taradığı alan.
	var mover_xforms: Array[Transform2D] = []
	var mover_reaches: Array[Rect2] = []
	var mover_names: Array[String] = []
	var x_scale: float = half_width / ChunkInfo.DESIGN_HALF_WIDTH
	var errors: PackedStringArray = PackedStringArray()
	var top: float = -chunk.height_px(beat)
	var body_half_h: float = _body_size.y * 0.5
	for item: Node2D in chunk.items():
		var world: Vector2 = ChunkInfo.world_position(chunk.design_position(item), beat, half_width)
		var item_beat: float = -chunk.design_position(item).y / ChunkInfo.BEAT_GRID_PX
		var label: String = "%s (%s. vuruş)" % [item.name, String.num(item_beat, 1).replace(".", ",")]
		if item is MovingHazard:
			var xform: Transform2D = Transform2D(item.rotation, item.scale, item.skew, world)
			var reach: Rect2 = xform * (item as MovingHazard).swept_rect(x_scale)
			if reach.position.y < top or reach.end.y > 0.0:
				errors.append("%s parçanın sınırından taşıyor" % item.name)
			movers.append(item as MovingHazard)
			mover_xforms.append(xform)
			mover_reaches.append(reach)
			mover_names.append(label)
		if item is WallGap:
			# Gövde tamamen boşluktayken duvar yoktur: bölge her iki uçtan gövdenin yarısı kadar dar.
			var gap: WallGap = item as WallGap
			var gap_top: float = world.y - gap.length * beat / ChunkInfo.BEAT_GRID_PX
			if world.y - gap_top > 2.0 * body_half_h:
				gaps.append(Vector3(gap.side(), gap_top + body_half_h, world.y - body_half_h))
				gap_names.append(label)
		for rect: Rect2 in _hazard_rects(item, world):
			if rect.position.y < top or rect.end.y > 0.0:
				errors.append("%s parçanın sınırından taşıyor" % item.name)
			hazards.append(rect)
			hazard_names.append(label)
			lasers.append(item as Laser)
	for i: int in movers.size():
		errors.append_array(_speed_errors(movers[i], mover_names[i], bpm, x_scale))
	if not errors.is_empty():
		return errors
	if hazards.is_empty() and gaps.is_empty() and movers.is_empty():
		# Tehlikesiz parçada Glimmer riskli yolda olamaz.
		for item: Node2D in chunk.items():
			if item is Glimmer:
				errors.append("%s riskli yolda değil: parçada tehlike yok" % item.name)
		return errors
	var sim: Simulation = Simulation.new(hazards, _hurt_half(), half_width - _body_size.x * 0.5,
			def.climb_px(), top, _tuning)
	sim.set_gaps(gaps)
	sim.set_lasers(lasers, beat)
	sim.set_movers(movers, mover_xforms, x_scale)
	# Simulation sıra numarasıyla okur: önce tehlike kutuları, sonra hareketliler, sonra boşluklar.
	var names: Array[String] = hazard_names + mover_names + gap_names
	var failure: String = sim.first_failure(names)
	if not failure.is_empty():
		errors.append(failure)
		return errors
	errors.append_array(_glimmer_errors(chunk, sim, beat, half_width, hazards + mover_reaches,
			gaps))
	return errors


## Glimmer kuralları: adil bir yolda toplanabilir ve bir vuruş yakınında tehlike var.
func _glimmer_errors(chunk: ChunkInfo, sim: Simulation, beat: float, half_width: float,
		hazards: Array[Rect2], gaps: Array[Vector3]) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var pickup: float = TuningConfig.to_px(_tuning.pickup_radius)
	for item: Node2D in chunk.items():
		if not item is Glimmer:
			continue
		var at: Vector2 = ChunkInfo.world_position(chunk.design_position(item), beat, half_width)
		if not sim.collectible(at, pickup + _glimmer_radius(item as Glimmer)):
			errors.append("%s hiçbir adil yolda toplanamıyor" % item.name)
		var near: bool = false
		for rect: Rect2 in hazards:
			near = near or (at.y > rect.position.y - beat and at.y < rect.end.y + beat)
		for zone: Vector3 in gaps:
			near = near or (at.y > zone.y - beat and at.y < zone.z + beat)
		if not near:
			errors.append("%s riskli yolda değil: bir vuruş içinde tehlike yok" % item.name)
	return errors


## Hareketli tehlike bir fizik adımında, kendi kalınlığı + oyuncu çarpışma kutusunun dar kenarı
## kadar yer değiştirmemeli: yoksa iki adım arasında oyuncunun içinden geçip değmeyebilir (oyun da
## doğrulayıcı da kare kare bakar). Hareket her vuruşta yinelendiği için iki vuruş denenir.
func _speed_errors(mover: MovingHazard, label: String, bpm: float,
		x_scale: float) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var rest: PackedVector2Array = mover.rest_polygon()
	var box: Rect2 = Rect2(rest[0], Vector2.ZERO)
	for point: Vector2 in rest:
		box = box.expand(point)
	var hurt: Vector2 = _hurt_half() * 2.0
	var limit: float = minf(box.size.x, box.size.y) + minf(hurt.x, hurt.y)
	var beat_step: float = PHYSICS_DT * bpm / ChunkInfo.SECONDS_PER_MINUTE
	var worst: float = 0.0
	var before: PackedVector2Array = mover.polygon_at(0.0, x_scale)
	for step: int in range(1, ceili(2.0 / beat_step) + 1):
		var after: PackedVector2Array = mover.polygon_at(step * beat_step, x_scale)
		for i: int in after.size():
			worst = maxf(worst, before[i].distance_to(after[i]))
		before = after
	if worst >= limit:
		errors.append("%s çok hızlı: bir adımda %s px (en çok %s)" % [
			label, String.num(worst, 0), String.num(limit, 0),
		])
	return errors


static func _glimmer_radius(glimmer: Glimmer) -> float:
	var shape: CollisionShape2D = glimmer.get_node_or_null("Shape") as CollisionShape2D
	if shape != null and shape.shape is CircleShape2D:
		return (shape.shape as CircleShape2D).radius
	return 0.0


func _hurt_half() -> Vector2:
	return _body_size * _tuning.hurtbox_scale * 0.5


## Bir öğenin dünyadaki tehlike kutuları (tehlike katmanındaki çarpışma şekilleri).
func _hazard_rects(item: Node2D, world: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var area: CollisionObject2D = item as CollisionObject2D
	# Hareketli tehlikeler kutuya çevrilmez; her karede duruşlarıyla denenir.
	if area == null or not (area.collision_layer & HAZARD_LAYER) or item is MovingHazard:
		return rects
	var item_xform: Transform2D = Transform2D(item.rotation, item.scale, item.skew, world)
	if item is Laser:
		# Lazerin şekli _ready'de kurulur; ağaçta olmayan parçada kutu dışa açık değerlerden alınır.
		var beam: Rect2 = (item as Laser).beam_rect()
		var corners: PackedVector2Array = item_xform * PackedVector2Array([
			beam.position, Vector2(beam.end.x, beam.position.y), beam.end,
			Vector2(beam.position.x, beam.end.y),
		])
		var box: Rect2 = Rect2(corners[0], Vector2.ZERO)
		for corner: Vector2 in corners:
			box = box.expand(corner)
		rects.append(box)
		return rects
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
	## Duvar boşluğu bölgeleri: (duvar -1/+1, üst y, alt y); o duvarda bu y'de bulunmak düşmektir.
	var _gaps: Array[Vector3] = []
	## Her tehlike kutusunun lazeri (null = sürekli) ve dünyadaki vuruş boyu.
	var _lasers: Array[Laser] = []
	var _beat_px: float = 1.0
	## Hareketli tehlikeler (M4-10), onları dünyaya yerleştiren dönüşümler ve koridor ölçeği.
	var _movers: Array[MovingHazard] = []
	var _mover_xforms: Array[Transform2D] = []
	var _x_scale: float = 1.0
	## Hareketlilerin son hesaplanan karedeki dünya çokgenleri ve kutuları (kare başına bir kez).
	var _posed_frame: int = -1
	var _mover_shapes: Array[PackedVector2Array] = []
	var _mover_bounds: Array[Rect2] = []
	var _hurt_half: Vector2
	var _wall_x: float
	var _step_y: float
	var _start_y: float
	var _frames: int
	## Yere indikten sonra çevirmeye izin verilen kare.
	var _dwell: int
	## Her karenin "buradan sona sağ çıkılır" tablosu (Glimmer toplanabilirliği için saklanır).
	var _safe_by_frame: Array[PackedByteArray] = []
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

	func set_gaps(gaps: Array[Vector3]) -> void:
		_gaps = gaps

	func set_lasers(lasers: Array[Laser], beat_px: float) -> void:
		_lasers = lasers
		_beat_px = beat_px

	func set_movers(movers: Array[MovingHazard], xforms: Array[Transform2D], x_scale: float) -> void:
		_movers = movers
		_mover_xforms = xforms
		_x_scale = x_scale
		_mover_shapes.resize(movers.size())
		_mover_bounds.resize(movers.size())
		_posed_frame = -1

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

	## Durumun bu karede değdiği tehlikelerin sıra numaraları: önce tehlike kutuları, sonra
	## hareketliler, en son duvar boşlukları (yalnızca o duvarda, duvar durumunda olana dokunur).
	func _hits(frame: int, state: int) -> Array[int]:
		var y: float = _y_of(frame)
		var body: Rect2 = Rect2(Vector2(_x_of(state), y) - _hurt_half, _hurt_half * 2.0)
		var result: Array[int] = []
		# Oyuncunun parça içindeki vuruş konumu (parçanın alt kenarı 0. vuruş).
		var beat: float = -y / _beat_px
		for i: int in _hazards.size():
			if i < _lasers.size() and _lasers[i] != null and not _lasers[i].is_on_at(beat):
				continue
			if body.intersects(_hazards[i]):
				result.append(i)
		_pose_movers(frame, beat)
		for i: int in _movers.size():
			if rect_hits_polygon(body, _mover_shapes[i], _mover_bounds[i]):
				result.append(_hazards.size() + i)
		if state < _wall_count():
			var side: float = 1.0 if _side(state) == 1 else -1.0
			var first_gap: int = _hazards.size() + _movers.size()
			for i: int in _gaps.size():
				if _gaps[i].x == side and y > _gaps[i].y and y < _gaps[i].z:
					result.append(first_gap + i)
		return result

	## Hareketlileri bu karenin vuruş konumundaki duruşlarına koyar (dünyada; kare başına bir kez).
	func _pose_movers(frame: int, beat: float) -> void:
		if frame == _posed_frame:
			return
		_posed_frame = frame
		for i: int in _movers.size():
			var shape: PackedVector2Array = _mover_xforms[i] * _movers[i].polygon_at(beat, _x_scale)
			var bounds: Rect2 = Rect2(shape[0], Vector2.ZERO)
			for point: Vector2 in shape:
				bounds = bounds.expand(point)
			_mover_shapes[i] = shape
			_mover_bounds[i] = bounds

	## Kutu ile dışbükey çokgen kesişiyor mu (ayırıcı eksen yöntemi: kutunun eksenleri sınır
	## kutusuyla, sonra çokgenin kenar dikmeleri). Değmek kesişmek sayılmaz (Rect2.intersects gibi).
	static func rect_hits_polygon(rect: Rect2, polygon: PackedVector2Array, bounds: Rect2) -> bool:
		if not rect.intersects(bounds):
			return false
		var corners: PackedVector2Array = PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
		var count: int = polygon.size()
		for i: int in count:
			var edge: Vector2 = polygon[(i + 1) % count] - polygon[i]
			var axis: Vector2 = Vector2(-edge.y, edge.x)
			var shape_span: Vector2 = span(polygon, axis)
			var rect_span: Vector2 = span(corners, axis)
			if shape_span.y <= rect_span.x or rect_span.y <= shape_span.x:
				return false
		return true

	## Noktaların eksen üzerindeki izdüşüm aralığı (x en küçük, y en büyük).
	static func span(points: PackedVector2Array, axis: Vector2) -> Vector2:
		var low: float = INF
		var high: float = -INF
		for point: Vector2 in points:
			var at: float = point.dot(axis)
			low = minf(low, at)
			high = maxf(high, at)
		return Vector2(low, high)

	## Sondan başa: safe[s] = bu karede s'de canlıyken parçanın sonuna sağ çıkılabilir mi?
	func _safe_at_start() -> PackedByteArray:
		var count: int = _state_count()
		var safe: PackedByteArray = PackedByteArray()
		safe.resize(count)
		safe.fill(1)
		_safe_by_frame.resize(_frames + 1)
		for frame: int in range(_frames, -1, -1):
			var current: PackedByteArray = PackedByteArray()
			current.resize(count)
			for state: int in count:
				if not _hits(frame, state).is_empty():
					continue
				if frame == _frames:
					current[state] = 1
					continue
				for next: int in _next_states(state):
					if safe[next] == 1:
						current[state] = 1
						break
			safe = current
			_safe_by_frame[frame] = current
		return safe

	## Girişten sona güvenli bir yolda, oyuncunun merkezi center'a radius kadar yaklaşıyor mu?
	## first_failure'dan sonra çağrılır (güvenli tablo kurulmuş olmalı).
	func collectible(center: Vector2, radius: float) -> bool:
		var count: int = _state_count()
		var current: PackedByteArray = PackedByteArray()
		current.resize(count)
		for state: int in _entry_states():
			current[state] = _safe_by_frame[0][state]
		for frame: int in range(0, _frames + 1):
			var y: float = _y_of(frame)
			if absf(y - center.y) <= radius:
				for state: int in count:
					if current[state] == 1 and Vector2(_x_of(state), y).distance_to(center) <= radius:
						return true
			if frame == _frames:
				break
			var next_frame: PackedByteArray = PackedByteArray()
			next_frame.resize(count)
			var safe_next: PackedByteArray = _safe_by_frame[frame + 1]
			for state: int in count:
				if current[state] == 0:
					continue
				for next: int in _next_states(state):
					if safe_next[next] == 1:
						next_frame[next] = 1
			current = next_frame
		return false

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
				var hits: Array[int] = _hits(frame, state)
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
