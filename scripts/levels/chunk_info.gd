class_name ChunkInfo
extends Node2D
## Desen parçasının kökü (architecture.md §8.2). Parça `scenes/levels/chunks/` altında bir
## sahnedir; çocukları (tehlikeler, ileride Glimmer) vuruş ızgarasına göre yerleşir.
##
## Tasarım uzayı: kök parçanın alt kenarıdır, parça yukarı (eksi y) uzanır. 1 vuruş = 100 px,
## öğeler yarım vuruşa (50 px) oturur. Yatayda koridor 900 px (duvarlar ±450) çizilir.
## Dünyaya yerleşirken yalnızca konumlar ölçeklenir (y vuruş boyuna, x koridor genişliğine);
## şekiller esnemez.

## Parçadaki bir Glimmer toplandı (M2-13); ChunkSpawner yukarı iletir.
signal glimmer_collected(value: int)

## Tasarımda bir vuruşun dikey boyu.
const BEAT_GRID_PX: float = 100.0
## Öğelerin oturduğu en küçük dikey adım: yarım vuruş.
const Y_STEP_PX: float = 50.0
## Öğelerin oturduğu yatay adım (1 m).
const X_STEP_PX: float = 50.0
## Tasarımdaki koridorun yarı genişliği (18 m). Duvara yapışık öğeler x = ±bu değerde durur.
const DESIGN_HALF_WIDTH: float = 450.0
## Tehlike fizik katmanı (project.godot → layer_names: hazard = 3. katman).
const HAZARD_LAYER: int = 4
## Bir dakikadaki saniye (vuruş boyu hesabı).
const SECONDS_PER_MINUTE: float = 60.0

## Zorluk (1 kolay – 10 en zor). Seçimde sektör içi hedef zorluğa göre ağırlık verilir (M2-10).
@export_range(1, 10) var difficulty: int = 1
## Parçanın çıkabileceği ilk sektör.
@export_range(1, 5) var min_sector: int = 1
## Parçanın çıkabileceği son sektör.
@export_range(1, 5) var max_sector: int = 5
## Parçanın boyu (vuruş). Tasarımda 0 ile -length_beats × 100 px arası.
@export_range(1, 64) var length_beats: int = 8
## Seçim etiketleri (ör. intro, breather). Tehlike türü etiketlenmez; çocuklardan okunur.
@export var tags: Array[StringName] = []

## layout'un son kullandığı vuruş boyu (px); parçanın dünyadaki boyu buna göredir.
var laid_out_beat_px: float = BEAT_GRID_PX

## Çocukların tasarımdaki konumları; yerleşim her çağrıda bunlardan yeniden hesaplanır.
var _design_positions: Dictionary[Node2D, Vector2] = {}
## Vuruşla yanıp sönen lazerler (M2-12).
var _lasers: Array[Laser] = []
## Toplanabilirler (M2-13).
var _glimmers: Array[Glimmer] = []
## Vuruşla süzülen veri blokları (M3-05).
var _blocks: Array[Block] = []


func _ready() -> void:
	for item: Node2D in items():
		_design_positions[item] = item.position
		if item is Laser:
			_lasers.append(item as Laser)
		elif item is Block:
			_blocks.append(item as Block)
		elif item is Glimmer:
			var glimmer: Glimmer = item as Glimmer
			_glimmers.append(glimmer)
			glimmer.collected.connect(glimmer_collected.emit)


## Bir sektörün dünyadaki vuruş boyu (px): tırmanış hızı × 60 / BPM.
static func beat_px(climb_speed: float, bpm: float) -> float:
	return TuningConfig.to_px(climb_speed) * SECONDS_PER_MINUTE / bpm


## Tasarımdaki bir konumun dünyadaki karşılığı: y vuruş boyuna, x koridor genişliğine ölçeklenir.
static func world_position(design: Vector2, world_beat_px: float, half_width: float) -> Vector2:
	return Vector2(design.x * half_width / DESIGN_HALF_WIDTH, design.y * world_beat_px / BEAT_GRID_PX)


## Havuzdan yeniden gelen parçayı sıfırlar: Glimmer'lar yeniden etkinleşir (§8.7).
func reset() -> void:
	for glimmer: Glimmer in _glimmers:
		glimmer.reset()


## Vuruş konumunu (tempo ızgarasının başından beri geçen vuruş) lazerlere, bloklara ve
## Glimmer'lara iletir.
## Parça tam vuruşta başladığı için evreleri parçanın yerinden bağımsızdır.
func set_beat(beat: float) -> void:
	for laser: Laser in _lasers:
		laser.set_beat(beat)
	for block: Block in _blocks:
		block.set_beat(beat)
	for glimmer: Glimmer in _glimmers:
		glimmer.set_beat(beat)


## Parçanın duvar boşlukları (M2-11).
func gaps() -> Array[WallGap]:
	var result: Array[WallGap] = []
	for child: Node in get_children():
		if child is WallGap:
			result.append(child as WallGap)
	return result


## Boşluğun dünyadaki aralığı (parçanın ebeveyninin uzayında): x = üst y, y = alt y. Son
## yerleşime göre; boy vuruşla ölçeklenir.
func gap_range(gap: WallGap) -> Vector2:
	var bottom: float = position.y + gap.position.y
	return Vector2(bottom - gap.length * laid_out_beat_px / BEAT_GRID_PX, bottom)


## Parçadaki tehlike türleri: tehlike sahnesinin dosya adı (spike) ve boşluklar için gap.
## Sektörün izinli tehlikeleriyle karşılaştırılır (SectorDef.allowed_hazards).
func hazard_types() -> Array[StringName]:
	var result: Array[StringName] = []
	for item: Node2D in items():
		var type: StringName = &""
		if item is WallGap:
			type = &"gap"
		elif _is_hazard(item) and not item.scene_file_path.is_empty():
			type = StringName(item.scene_file_path.get_file().get_basename())
		if not type.is_empty() and not result.has(type):
			result.append(type)
	return result


## Parçanın öğeleri: doğrudan çocuk olan Node2D'ler.
func items() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child: Node in get_children():
		if child is Node2D:
			result.append(child as Node2D)
	return result


## Öğenin tasarımdaki konumu (parça yerleşmiş olsa da). Parça ağaçta değilse şu anki konumudur.
func design_position(item: Node2D) -> Vector2:
	return _design_positions.get(item, item.position)


func allows_sector(sector: int) -> bool:
	return sector >= min_sector and sector <= max_sector


## Parçanın dünyadaki boyu (px) verilen vuruş boyunda.
func height_px(world_beat_px: float) -> float:
	return length_beats * world_beat_px


## Parçanın dünyadaki üst kenarı (son yerleşime göre).
func top_y() -> float:
	return position.y - height_px(laid_out_beat_px)


## Tasarım konumlarını dünyaya ölçekler. Tekrar çağrılabilir (havuzdan gelen parça, yeni sektör).
## Konumlar _ready'de alındığı için parça ağaçta olmalı.
func layout(world_beat_px: float, half_width: float) -> void:
	laid_out_beat_px = world_beat_px
	for item: Node2D in _design_positions:
		item.position = world_position(_design_positions[item], world_beat_px, half_width)


## Tasarım kurallarına uymayan her şeyi listeler; boşsa parça geçerlidir. Testler ve doğrulama
## aracı (M2-05) kullanır. Tasarım konumlarına bakar; layout'tan sonra da aynı sonucu verir.
func design_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if min_sector > max_sector:
		errors.append("sektör aralığı ters: %d > %d" % [min_sector, max_sector])
	var top: float = -length_beats * BEAT_GRID_PX
	for item: Node2D in items():
		var at: Vector2 = design_position(item)
		if not _on_step(at.y, Y_STEP_PX) or at.y > 0.0 or at.y < top:
			errors.append("%s: y=%s yarım vuruşa oturmuyor ya da 0…%s dışında" % [
				item.name, at.y, top,
			])
		if not _on_step(at.x, X_STEP_PX) or absf(at.x) > DESIGN_HALF_WIDTH:
			errors.append("%s: x=%s 1 m adımına oturmuyor ya da koridor dışında" % [item.name, at.x])
		if item is WallGap:
			errors.append_array(_gap_errors(item as WallGap, at, top))
		# Duvardaki tehlike koridora bakar: sol duvarda scale.x > 0, sağ duvarda < 0.
		elif item is Glimmer:
			pass
		elif is_equal_approx(absf(at.x), DESIGN_HALF_WIDTH) and signf(item.scale.x) == signf(at.x):
			errors.append("%s: duvardaki öğe koridora bakmıyor (scale.x=%s)" % [
				item.name, item.scale.x,
			])
	return errors


## Boşluk duvardadır, boyu yarım vuruş katıdır ve parçanın içinde kalır.
func _gap_errors(gap: WallGap, at: Vector2, top: float) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if not is_equal_approx(absf(at.x), DESIGN_HALF_WIDTH):
		errors.append("%s: boşluk duvarda değil (x=%s)" % [gap.name, at.x])
	if not _on_step(gap.length, Y_STEP_PX) or gap.length <= 0.0:
		errors.append("%s: boşluk boyu %s yarım vuruşun katı değil" % [gap.name, gap.length])
	if at.y - gap.length < top:
		errors.append("%s: boşluk parçanın üstünden taşıyor" % gap.name)
	return errors


## Tehlike katmanındaki çarpışma nesnesi mi (Glimmer gibi toplanabilirler değil).
static func _is_hazard(item: Node2D) -> bool:
	var body: CollisionObject2D = item as CollisionObject2D
	return body != null and (body.collision_layer & HAZARD_LAYER) != 0


static func _on_step(value: float, step: float) -> bool:
	return is_equal_approx(value / step, roundf(value / step))
