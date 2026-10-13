class_name Background
extends CanvasLayer
## Arka plan veri ağı (M3-07, architecture.md §9, ADR-050): dünyanın ardında ekranı kaplayan
## ızgara. Uzak ve yakın katman kamerayla farklı oranlarda kayar (paralaks); yakın katmanın
## kesişimlerinde düğüm noktaları durur. Vuruşta ağ vurgu rengine çekilip parlar, her vuruşta
## başka düğümler yanıp söner. Yalnızca görseldir.
## Shader değil çizgi geometrisi: tam ekran shader Redmi'de kareyi 8,4 ms'den 13,5 ms'ye
## çıkardı (her pikseli işliyor); çizgiler ekranın yalnızca küçük bir kısmını boyar.
## Katmanlar bir kez çizilir (beyaz, saydamlıkla); renk self_modulate, nabız Grid'in modulate'i,
## kayma konumla olur. Yeniden çizim yalnızca ekran boyu değişince ve parlayan düğümler için.
## Kalite (Neon.GROUP): yüksekte iki katman, ortada yalnızca yakın katman, düşükte ağ yok (düz
## renk: ekranın temizleme rengi, yani sektörün arka plan rengi).
## Run her fizik adımında set_scroll ve set_beat çağırır; ağ _process'te fizik ara değerleme
## kesriyle kayar, böylece kameranın çizildiği yerle aynı akıcılıkta ilerler.

## Parlayan düğümlerin seçimi bu kadar vuruşta bir tekrarlanır.
const FLASH_CYCLE: int = 1024
## Parlayan düğümün ışık lekesinin yarıçapı (düğüm yarıçapının katı).
const FLASH_HALO_RATIO: float = 4.0
## Nabız renk oranında çevre renginin kanal tabanı (sıfıra bölmeyi önler; Corridor'daki gibi).
const MIN_CHANNEL: float = 0.05

var _prev_scroll: float = 0.0
var _scroll: float = 0.0
## Ekranın tasarım birimindeki boyu (katmanlar buna göre çizilir).
var _view: Vector2 = Vector2.ZERO
## Nabız tepesindeki modulate: kanal kanal vurgu / çevre oranı, saydamlık artışıyla.
var _pulse_tint: Color = Color.WHITE
var _accent: Color = Color.WHITE
## Parlayan düğümlerin vuruşu ve yakın katmanın satır sayacı (layer_row).
var _flash_beat: int = -1
var _near_row: int = 0

@onready var _grid: Node2D = %Grid
@onready var _far: Node2D = %Far
@onready var _near: Node2D = %Near
@onready var _flash: Node2D = %Flash


func _enter_tree() -> void:
	add_to_group(Neon.GROUP)


func _ready() -> void:
	var style: NeonStyle = Neon.STYLE
	_far.draw.connect(_draw_layer.bind(_far, style.grid_far_cell, style.grid_far_width,
			style.grid_far_alpha, 0.0))
	_near.draw.connect(_draw_layer.bind(_near, style.grid_near_cell, style.grid_near_width,
			style.grid_near_alpha, style.grid_node_alpha))
	_flash.draw.connect(_draw_flash)
	get_viewport().size_changed.connect(_on_view_resized)
	_on_view_resized()
	apply_quality()


func _process(_delta: float) -> void:
	if _grid.visible:
		_show_scroll(lerpf(_prev_scroll, _scroll, Engine.get_physics_interpolation_fraction()))


## Kameranın bu fizik adımındaki y'si (dünya). Ağ bunun paralaks oranı kadarıyla kayar.
func set_scroll(camera_y: float) -> void:
	_prev_scroll = _scroll
	_scroll = camera_y


## Kaydırmayı ara değerlemesiz yerine koyar (tur başı).
func reset_scroll(camera_y: float) -> void:
	_prev_scroll = camera_y
	_scroll = camera_y
	if is_node_ready():
		_show_scroll(camera_y)


## Vuruş nabzı: beat, tempo ızgarasının başından beri geçen vuruş sayısı.
func set_beat(beat: float) -> void:
	var pulse: float = Neon.STYLE.beat_pulse(beat)
	_grid.modulate = Color.WHITE.lerp(_pulse_tint, pulse)
	_flash.modulate.a = pulse
	var index: int = posmod(floori(beat), FLASH_CYCLE)
	if index != _flash_beat:
		_flash_beat = index
		_flash.queue_redraw()


## Ağın rengi sektörün çevre rengi; nabız ve parlayan düğümler vurgu rengi.
func set_colors(ambient: Color, accent: Color) -> void:
	_far.self_modulate = ambient
	_near.self_modulate = ambient
	_accent = accent
	_flash.queue_redraw()
	var boost: float = Neon.STYLE.beat_pulse_boost
	var tint: Color = Color(accent.r / maxf(ambient.r, MIN_CHANNEL) * boost,
			accent.g / maxf(ambient.g, MIN_CHANNEL) * boost,
			accent.b / maxf(ambient.b, MIN_CHANNEL) * boost,
			1.0 + Neon.STYLE.grid_pulse_alpha)
	_pulse_tint = Color.WHITE.lerp(tint, Neon.STYLE.beat_pulse_gain)


## Ağı geçerli kaliteye göre gösterir (Neon.set_quality çağırır).
func apply_quality() -> void:
	_grid.visible = Neon.quality >= Neon.STYLE.grid_min_quality
	_flash.visible = _grid.visible
	_far.visible = Neon.quality >= Neon.STYLE.grid_far_min_quality


## Kamera camera_y'deyken katmanın ekranın üstünden itibaren kaçıncı satırda olduğu (dünyada)
## ve satırın içindeki kayması (0 – cell, aşağı doğru). Kamera yukarı çıktıkça ağ aşağı kayar.
static func layer_row(camera_y: float, parallax: float, cell: float) -> int:
	return floori(-camera_y * parallax / cell)


static func layer_offset(camera_y: float, parallax: float, cell: float) -> float:
	return -camera_y * parallax - layer_row(camera_y, parallax, cell) * cell


## Vuruşta parlayan düğümler: (sütun, desendeki satır). Seçim vuruş sırasına ve düğümün desendeki
## yerine bağlıdır (kozmetik; turun RNG'sine dokunmaz): katman bir satır kayınca aynı düğüm
## yerinde parlamayı sürdürür. Satırlar first_row'dan başlar.
static func flash_nodes(beat_index: int, first_row: int, columns: int, rows: int,
		density: float) -> Array[Vector2i]:
	var lit: Array[Vector2i] = []
	for row: int in range(first_row, first_row + rows):
		for column: int in columns:
			if _hash01(beat_index, column, row) < density:
				lit.append(Vector2i(column, row))
	return lit


## 0–1 arası tamsayı özeti (aynı girdiye her cihazda aynı sonuç).
static func _hash01(a: int, b: int, c: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65536.0


func _show_scroll(camera_y: float) -> void:
	var style: NeonStyle = Neon.STYLE
	var near_parallax: float = style.grid_near_parallax
	_near.position.y = layer_offset(camera_y, near_parallax, style.grid_near_cell)
	_far.position.y = layer_offset(camera_y, style.grid_far_parallax, style.grid_far_cell)
	_flash.position.y = _near.position.y
	var row: int = layer_row(camera_y, near_parallax, style.grid_near_cell)
	if row != _near_row:
		_near_row = row
		_flash.queue_redraw()


func _on_view_resized() -> void:
	_view = get_viewport().get_visible_rect().size
	_far.queue_redraw()
	_near.queue_redraw()
	_flash.queue_redraw()


## Bir katman: dikey çizgiler ekranın ortasından hizalı, yatay çizgiler satır satır; ekranı bir
## hücre taşar ki kayarken kenar boş kalmasın. Düğümler kesişimlerde (node_alpha > 0 ise).
func _draw_layer(target: Node2D, cell: float, width: float, alpha: float,
		node_alpha: float) -> void:
	var color: Color = Color(1.0, 1.0, 1.0, alpha)
	var columns: Array[float] = _column_xs(cell)
	var lines: PackedVector2Array = PackedVector2Array()
	for x: float in columns:
		lines.append_array([Vector2(x, -cell), Vector2(x, _view.y + cell)])
	var rows: int = _row_count(cell)
	for row: int in range(-1, rows):
		lines.append_array([Vector2(0.0, row * cell), Vector2(_view.x, row * cell)])
	target.draw_multiline(lines, color, width, true)
	if node_alpha <= 0.0:
		return
	var node_color: Color = Color(1.0, 1.0, 1.0, node_alpha)
	for row: int in range(-1, rows):
		for x: float in columns:
			target.draw_circle(Vector2(x, row * cell), Neon.STYLE.grid_node_radius, node_color,
					true, -1.0, true)


## O vuruşta parlayan düğümler: vurgu renginde nokta ve çevresinde yumuşak ışık lekesi.
func _draw_flash() -> void:
	if _flash_beat < 0:
		return
	var style: NeonStyle = Neon.STYLE
	var cell: float = style.grid_near_cell
	var columns: Array[float] = _column_xs(cell)
	var rows: int = _row_count(cell) + 1
	var radius: float = style.grid_node_radius
	var halo: Vector2 = Vector2.ONE * radius * FLASH_HALO_RATIO * 2.0
	var color: Color = Color(_accent, style.grid_flash_alpha)
	# Katmanın yerel satırı r, desendeki satır r - layer_row'dur (ekranın üstü r = -1).
	var first_row: int = -_near_row - 1
	for node: Vector2i in flash_nodes(_flash_beat, first_row, columns.size(), rows,
			style.grid_flash_density):
		var at: Vector2 = Vector2(columns[node.x], (node.y + _near_row) * cell)
		_flash.draw_texture_rect(Neon.blob_texture(), Rect2(at - halo * 0.5, halo), false, color)
		_flash.draw_circle(at, radius, color, true, -1.0, true)


## Dikey çizgilerin x'leri: ekranın ortasından cell aralıkla, ekranın biraz dışına kadar.
func _column_xs(cell: float) -> Array[float]:
	var center: float = _view.x * 0.5
	var reach: int = ceili(center / cell)
	var xs: Array[float] = []
	for i: int in range(-reach, reach + 1):
		xs.append(center + i * cell)
	return xs


## Ekranı ve bir hücre payını kaplayan yatay çizgi sayısı (satır 0 ekranın üstünde).
func _row_count(cell: float) -> int:
	return ceili(_view.y / cell) + 1
