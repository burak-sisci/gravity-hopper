extends Control
## Minimal HUD (M1-10, GDD §20): sol üstte anlık yükseklik, altında oturum rekoru.
## Sektör afişi (M2-09): sektöre girince ya da tur bir sonraki sektörden başlayınca "SEKTÖR 2 ·
## VERİ AKIŞI" kısa süre görünüp söner. Adlar sektör kataloğundan (veri kaynağı) okunur.
## Afiş dalgayla gelir (M3-08): sektöre girince renk dalgası ekranın altından üstüne yayılır;
## afiş, dalga onun hizasına varınca (NeonStyle.wave_reach_time) kısa bir büyümeyle belirir.
## Tur sonraki sektörden başlıyorsa dalga yoktur, afiş hemen görünür.
## Yalnızca Events sinyallerini dinler; oyun dünyasındaki hiçbir düğüme erişmez (.clauderules §3).
## Metinler çeviri anahtarlarıyla kodda kurulur; dil değişince yeniden yazılır.
## Kök düğüm dokunuşları yutmaz (mouse_filter = IGNORE); yoksa dokunuş çevirme olmazdı.

## Çöküş duvarı yakınken kenarlardaki kırmızı vinyetin en yüksek görünürlüğü (GDD §14).
const VIGNETTE_MAX_ALPHA: float = 0.6
## Afişin ekranda kaldığı süre ve sönme süresi (sn).
const BANNER_TIME: float = 2.0
const BANNER_FADE: float = 0.4
## Dalga afişe varınca afişin başladığı büyüklük ve yerine oturma süresi (sn).
const BANNER_POP_SCALE: float = 1.25
const BANNER_POP_TIME: float = 0.25

## Sektör adları ve renkleri için (veri; dünyaya erişim değil).
@export var sectors: SectorCatalog

var _glimmers: int = 0
var _height_m: int = 0
## Bu uygulama oturumundaki en iyi yükseklik; kalıcı rekor M4'te Progression'a taşınır.
var _best_m: int = 0
## Afişte gösterilen sektör (0 = afiş yok).
var _banner_sector: int = 0
var _banner_tween: Tween

@onready var _height_label: Label = %HeightLabel
@onready var _best_label: Label = %BestLabel
@onready var _sector_banner: Label = %SectorBanner
@onready var _glimmer_label: Label = %GlimmerLabel
@onready var _vignette: TextureRect = %WallVignette


func _ready() -> void:
	Events.run_started.connect(_on_run_started)
	Events.height_changed.connect(_on_height_changed)
	Events.run_ended.connect(_on_run_ended)
	Events.sector_entered.connect(_on_sector_entered)
	Events.glimmer_collected.connect(_on_glimmer_collected)
	Events.wall_proximity_changed.connect(_on_wall_proximity_changed)
	_sector_banner.visible = false
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _on_run_started(_run_seed: int, start_sector: int) -> void:
	_height_m = 0
	_glimmers = 0
	_vignette.modulate.a = 0.0
	if start_sector > 1:
		_show_banner(start_sector)
	else:
		_hide_banner()
	_refresh()


## Duvar ekrana girince kenarlar kızarır; oyuncuya yaklaştıkça koyulaşır.
func _on_wall_proximity_changed(ratio: float) -> void:
	_vignette.modulate.a = ratio * VIGNETTE_MAX_ALPHA


func _on_glimmer_collected(value: int) -> void:
	_glimmers += value
	_refresh()


func _on_height_changed(meters: int) -> void:
	_height_m = meters
	_refresh()


func _on_run_ended(result: RunResult) -> void:
	_best_m = maxi(_best_m, result.height_m)
	_refresh()


## Sektör geçişi: afiş, renk dalgası afişin hizasına varınca gelir.
func _on_sector_entered(index: int) -> void:
	var center: float = _sector_banner.get_global_rect().get_center().y
	_show_banner(index, Neon.STYLE.wave_reach_time(center / get_viewport_rect().size.y))


## Afişi delay sn sonra gösterir (0 ise hemen, büyümesiz).
func _show_banner(index: int, delay: float = 0.0) -> void:
	_banner_sector = index
	_refresh()
	if _banner_tween != null:
		_banner_tween.kill()
	_sector_banner.visible = delay <= 0.0
	_sector_banner.modulate.a = 1.0
	_sector_banner.scale = Vector2.ONE
	_banner_tween = create_tween()
	if delay > 0.0:
		_banner_tween.tween_interval(delay)
		_banner_tween.tween_callback(_pop_banner)
		_banner_tween.tween_property(_sector_banner, "scale", Vector2.ONE, BANNER_POP_TIME) \
				.from(Vector2.ONE * BANNER_POP_SCALE).set_ease(Tween.EASE_OUT) \
				.set_trans(Tween.TRANS_CUBIC)
		_banner_tween.parallel().tween_property(_sector_banner, "modulate:a", 1.0,
				BANNER_POP_TIME).from(0.0)
	_banner_tween.tween_interval(BANNER_TIME)
	_banner_tween.tween_property(_sector_banner, "modulate:a", 0.0, BANNER_FADE)
	_banner_tween.tween_callback(_hide_banner)


## Dalga afişe vardı: afiş ortasından büyüyerek belirir.
func _pop_banner() -> void:
	_sector_banner.pivot_offset = _sector_banner.size * 0.5
	_sector_banner.visible = true


func _hide_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_sector = 0
	_sector_banner.visible = false


func _refresh() -> void:
	_height_label.text = tr("HUD_HEIGHT") % _height_m
	_best_label.text = tr("HUD_BEST") % _best_m
	_best_label.visible = _best_m > 0
	_glimmer_label.text = tr("HUD_GLIMMERS") % _glimmers
	if _banner_sector > 0 and sectors != null:
		var def: SectorDef = sectors.def_at(_banner_sector)
		_sector_banner.text = tr("HUD_SECTOR") % [_banner_sector, tr(def.name_key)]
		_sector_banner.add_theme_color_override("font_color", def.palette.accent)
