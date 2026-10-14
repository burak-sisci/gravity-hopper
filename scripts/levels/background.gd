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
##
## Renk dalgası (M3-08, ADR-051): sektör geçişinde yeni palet ekranın altından üstüne yayılır.
## Dalganın altında ağ yeni renkte (WaveGrid), üstünde eski renkte (Grid) çizilir; eski arka
## plan rengi dalganın üstünü örter (Wash; ekranın temizleme rengi o an yenidir). Dalganın
## önünde vurgu renginde parlak bir çizgi yürür (Crest). Run start_wave, her adımda set_wave ve
## sonunda end_wave çağırır; dalga sırasında katmanlar her kare yeniden çizilir.

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
## Renk dalgası: sürüyor mu, ilerleyişi (önceki ve bu fizik adımı) ve önün ekrandaki y'si.
## Dalga yokken ön sonsuzda: eski katmanlar her şeyi çizer.
var _wave_active: bool = false
var _prev_wave: float = 0.0
var _wave: float = 0.0
var _front: float = INF
## Dalganın üstünde kalan eski arka plan rengi ve yeni paletin çevre, vurgu ve nabız rengi.
var _wash_color: Color = Color.BLACK
var _wave_ambient: Color = Color.WHITE
var _wave_accent: Color = Color.WHITE
var _wave_pulse_tint: Color = Color.WHITE

@onready var _wash: Node2D = %Wash
@onready var _grid: Node2D = %Grid
@onready var _far: Node2D = %Far
@onready var _near: Node2D = %Near
@onready var _wave_grid: Node2D = %WaveGrid
@onready var _wave_far: Node2D = %WaveFar
@onready var _wave_near: Node2D = %WaveNear
@onready var _flash: Node2D = %Flash
@onready var _crest: Node2D = %Crest


func _enter_tree() -> void:
	add_to_group(Neon.GROUP)


func _ready() -> void:
	var style: NeonStyle = Neon.STYLE
	for target: Node2D in [_far, _wave_far]:
		target.draw.connect(_draw_layer.bind(target, style.grid_far_cell, style.grid_far_width,
				style.grid_far_alpha, 0.0, target == _wave_far))
	for target: Node2D in [_near, _wave_near]:
		target.draw.connect(_draw_layer.bind(target, style.grid_near_cell, style.grid_near_width,
				style.grid_near_alpha, style.grid_node_alpha, target == _wave_near))
	_flash.draw.connect(_draw_flash)
	_wash.draw.connect(_draw_wash)
	_crest.draw.connect(_draw_crest)
	_crest.material = Neon.additive_material()
	get_viewport().size_changed.connect(_on_view_resized)
	_on_view_resized()
	apply_quality()


func _process(_delta: float) -> void:
	var fraction: float = Engine.get_physics_interpolation_fraction()
	if _grid.visible:
		_show_scroll(lerpf(_prev_scroll, _scroll, fraction))
	if _wave_active:
		_show_wave(lerpf(_prev_wave, _wave, fraction))


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
	_wave_grid.modulate = Color.WHITE.lerp(_wave_pulse_tint, pulse)
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
	_pulse_tint = _pulse_tint_for(ambient, accent)


## Renk dalgasını başlatır: from_background dalganın üstünde kalan eski arka plan rengi; yeni
## renkler dalganın altındaki ağa uygulanır. Ön ekranın altından başlar.
func start_wave(from_background: Color, to_ambient: Color, to_accent: Color) -> void:
	_wave_active = true
	_prev_wave = 0.0
	_wave = 0.0
	_wash_color = from_background
	_wave_far.self_modulate = to_ambient
	_wave_near.self_modulate = to_ambient
	_wave_ambient = to_ambient
	_wave_accent = to_accent
	_wave_pulse_tint = _pulse_tint_for(to_ambient, to_accent)
	apply_quality()
	if is_node_ready():
		_show_wave(0.0)


## Dalganın bu fizik adımındaki ilerleyişi (NeonStyle.wave_progress: 0 alt – 1 üst).
func set_wave(progress: float) -> void:
	_prev_wave = _wave
	_wave = progress


## Dalgayı bitirir; yeni renkleri Run set_colors ile verir.
func end_wave() -> void:
	_wave_active = false
	_front = INF
	apply_quality()
	_far.queue_redraw()
	_near.queue_redraw()
	_flash.queue_redraw()


## Renk dalgası sürüyor mu.
func is_wave_active() -> bool:
	return _wave_active


## Dalganın önünün ekrandaki y'si (dalga yokken INF).
func wave_front() -> float:
	return _front


## Ağı geçerli kaliteye göre gösterir (Neon.set_quality çağırır).
func apply_quality() -> void:
	_grid.visible = Neon.quality >= Neon.STYLE.grid_min_quality
	_flash.visible = _grid.visible
	_far.visible = Neon.quality >= Neon.STYLE.grid_far_min_quality
	_wave_grid.visible = _wave_active and _grid.visible
	_wave_far.visible = _far.visible
	_wash.visible = _wave_active
	_crest.visible = _wave_active


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
	_wave_near.position.y = _near.position.y
	_wave_far.position.y = _far.position.y
	_flash.position.y = _near.position.y
	var row: int = layer_row(camera_y, near_parallax, style.grid_near_cell)
	if row != _near_row:
		_near_row = row
		_flash.queue_redraw()


## Dalganın önünü yerine koyar; önün iki yanı her kare yeniden çizilir.
func _show_wave(progress: float) -> void:
	_front = Neon.STYLE.wave_front(progress, 0.0, _view.y)
	for item: Node2D in [_wash, _crest, _far, _near, _wave_far, _wave_near, _flash]:
		item.queue_redraw()


func _on_view_resized() -> void:
	_view = get_viewport().get_visible_rect().size
	for item: Node2D in [_far, _near, _wave_far, _wave_near, _flash]:
		item.queue_redraw()


## Bir katman: dikey çizgiler ekranın ortasından hizalı, yatay çizgiler satır satır; ekranı bir
## hücre taşar ki kayarken kenar boş kalmasın. Düğümler kesişimlerde (node_alpha > 0 ise).
## Dalga sırasında eski katman önün üstünü, yeni katman (below_front) altını çizer.
func _draw_layer(target: Node2D, cell: float, width: float, alpha: float, node_alpha: float,
		below_front: bool) -> void:
	var cut: float = _front - target.position.y
	var top: float = maxf(-cell, cut if below_front else -INF)
	var bottom: float = minf(_view.y + cell, INF if below_front else cut)
	if bottom <= top:
		return
	var columns: Array[float] = _column_xs(cell)
	var lines: PackedVector2Array = PackedVector2Array()
	for x: float in columns:
		lines.append_array([Vector2(x, top), Vector2(x, bottom)])
	var rows: int = _row_count(cell)
	var crossings: Array[float] = []
	for row: int in range(-1, rows):
		var y: float = row * cell
		if y >= top and y < bottom:
			lines.append_array([Vector2(0.0, y), Vector2(_view.x, y)])
			crossings.append(y)
	target.draw_multiline(lines, Color(1.0, 1.0, 1.0, alpha), width, true)
	if node_alpha <= 0.0:
		return
	var node_color: Color = Color(1.0, 1.0, 1.0, node_alpha)
	for y: float in crossings:
		for x: float in columns:
			target.draw_circle(Vector2(x, y), Neon.STYLE.grid_node_radius, node_color, true, -1.0,
					true)


## O vuruşta parlayan düğümler: vurgu renginde nokta ve çevresinde yumuşak ışık lekesi. Dalga
## sırasında önün altındakiler yeni paletin vurgusunda.
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
	var wave_color: Color = Color(_wave_accent, style.grid_flash_alpha)
	# Katmanın yerel satırı r, desendeki satır r - layer_row'dur (ekranın üstü r = -1).
	var first_row: int = -_near_row - 1
	for node: Vector2i in flash_nodes(_flash_beat, first_row, columns.size(), rows,
			style.grid_flash_density):
		var at: Vector2 = Vector2(columns[node.x], (node.y + _near_row) * cell)
		var tint: Color = wave_color if at.y + _flash.position.y >= _front else color
		_flash.draw_texture_rect(Neon.blob_texture(), Rect2(at - halo * 0.5, halo), false, tint)
		_flash.draw_circle(at, radius, tint, true, -1.0, true)


## Dalganın üstünde eski arka plan rengi (altında ekranın temizleme rengi, yani yeni renk).
func _draw_wash() -> void:
	if _front > 0.0:
		_wash.draw_rect(Rect2(0.0, 0.0, _view.x, minf(_front, _view.y)), _wash_color)


## Dalganın önü: vurgu renginde çizgi ve (orta kaliteden itibaren) çevresinde yeni çevre renginde
## ışık bandı.
func _draw_crest() -> void:
	var style: NeonStyle = Neon.STYLE
	if Neon.quality >= style.wave_glow_min_quality:
		var height: float = style.wave_glow_height
		_crest.draw_texture_rect(Neon.halo_texture(),
				Rect2(0.0, _front - height * 0.5, _view.x, height), false,
				Color(_wave_ambient, style.wave_glow_alpha))
	_crest.draw_line(Vector2(0.0, _front), Vector2(_view.x, _front), _wave_accent,
			style.wave_crest_width, true)


## Nabız tepesindeki modulate: kanal kanal vurgu / çevre oranı (× parlaklık), saydamlık artışıyla.
func _pulse_tint_for(ambient: Color, accent: Color) -> Color:
	var boost: float = Neon.STYLE.beat_pulse_boost
	var tint: Color = Color(accent.r / maxf(ambient.r, MIN_CHANNEL) * boost,
			accent.g / maxf(ambient.g, MIN_CHANNEL) * boost,
			accent.b / maxf(ambient.b, MIN_CHANNEL) * boost,
			1.0 + Neon.STYLE.grid_pulse_alpha)
	return Color.WHITE.lerp(tint, Neon.STYLE.beat_pulse_gain)


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
