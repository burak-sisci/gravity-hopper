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
## Duvar vinyeti (M2-15, M3-09'da inceltildi): yalnızca ekranın iki kenarında, koridorun
## dışında kalan dar şeritler; alt dış köşede en koyu, yukarı ve içeri doğru söner. Duvarın
## kendisi artık ekranda göründüğü için vinyet engellerin üstüne düşmez.
## Kıl payı (M3-12, GDD §15): her kıl payında oyuncunun hemen altında (ileri görüş 28 m = 1400 px;
## geçilmiş bölge, gelen engelleri örtmez) "KIL PAYI!" büyüyerek belirip söner; altında Glimmer
## çarpanı ×2 / ×3 olunca kombo göstergesi çıkar, zincir bitince kaybolur. Bu canlandırmalar
## gerçek zamanla oynar; yavaş çekim onları yavaşlatmaz.
## Neon yazılar (M3-18): bütün yazılar NeonLabel. Yükseklik, kıl payı ve afiş sektörün vurgu
## renginde parlar; yeni sektörde renk, dalga afişe varınca (afişle birlikte) değişir. Rekor
## satırı rekor çizgisinin sarısında, Glimmer sayacı ve kombo Glimmer yeşilinde.
## Yazıların gösterebileceği bütün harfler açılışta ve dil değişince önceden çizilir
## (NeonLabel.warm_glyphs, M3-19): tur sırasında ilk kez çizilen harf takılma yapmasın.
## Final (M4-13): Büyük Depolama Birimi'ne varınca (Events.great_storage_reached) sektör afişinin
## yerine, aynı dalga zamanlamasıyla "BÜYÜK DEPOLAMA BİRİMİ" afişi oyuncu renginde gelir ve
## FINALE_BANNER_TIME görünür.

## Sayılarda görünebilecek rakamlar (önceden çizilir).
const DIGITS: String = "0123456789"
## Çöküş duvarı yakınken kenarlardaki kırmızı vinyetin en yüksek görünürlüğü (GDD §14).
const VIGNETTE_MAX_ALPHA: float = 1.0
## Afişin ekranda kaldığı süre ve sönme süresi (sn).
const BANNER_TIME: float = 2.0
const BANNER_FADE: float = 0.4
## Final afişinin ekranda kaldığı süre (sn).
const FINALE_BANNER_TIME: float = 3.5
## Dalga afişe varınca afişin başladığı büyüklük ve yerine oturma süresi (sn).
const BANNER_POP_SCALE: float = 1.25
const BANNER_POP_TIME: float = 0.25
## Kıl payı yazısının ve kombo göstergesinin başladığı büyüklük ve yerine oturma süresi (sn).
const NEAR_MISS_POP_SCALE: float = 1.4
const COMBO_POP_SCALE: float = 1.6
const POP_TIME: float = 0.15
## Kıl payı yazısının ekranda kaldığı ve söndüğü süre (sn).
const NEAR_MISS_TIME: float = 0.45
const NEAR_MISS_FADE: float = 0.3

## Sektör adları ve renkleri için (veri; dünyaya erişim değil).
@export var sectors: SectorCatalog

var _glimmers: int = 0
var _height_m: int = 0
## Kalıcı rekor (Events.best_height_changed; M4-02).
var _best_m: int = 0
## Afişte gösterilen sektör (0 = afiş yok).
var _banner_sector: int = 0
## Afiş final afişi mi (sektör adı yerine Büyük Depolama Birimi).
var _banner_finale: bool = false
var _banner_tween: Tween
## Gösterilen Glimmer çarpanı (1 = kombo göstergesi gizli).
var _multiplier: int = 1
var _near_miss_tween: Tween
var _combo_tween: Tween

@onready var _height_label: NeonLabel = %HeightLabel
@onready var _best_label: NeonLabel = %BestLabel
@onready var _sector_banner: NeonLabel = %SectorBanner
@onready var _glimmer_label: NeonLabel = %GlimmerLabel
@onready var _vignette: Control = %WallVignette
@onready var _near_miss_label: NeonLabel = %NearMissLabel
@onready var _combo_label: NeonLabel = %ComboLabel


func _ready() -> void:
	Events.run_started.connect(_on_run_started)
	Events.height_changed.connect(_on_height_changed)
	Events.best_height_changed.connect(_on_best_height_changed)
	Events.sector_entered.connect(_on_sector_entered)
	Events.great_storage_reached.connect(_on_great_storage_reached)
	Events.glimmer_collected.connect(_on_glimmer_collected)
	Events.wall_proximity_changed.connect(_on_wall_proximity_changed)
	Events.near_miss.connect(_on_near_miss)
	Events.combo_ended.connect(_on_combo_ended)
	_sector_banner.visible = false
	_near_miss_label.visible = false
	_refresh()
	_warm_glyphs()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
		_warm_glyphs()


func _on_run_started(_run_seed: int, start_sector: int) -> void:
	_height_m = 0
	_glimmers = 0
	_vignette.modulate.a = 0.0
	_multiplier = 1
	if _near_miss_tween != null:
		_near_miss_tween.kill()
	_near_miss_label.visible = false
	_tint(start_sector)
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


func _on_best_height_changed(meters: int) -> void:
	_best_m = meters
	_refresh()


## Kıl payı: yazı her seferinde büyüyerek belirir; çarpan büyüyünce kombo göstergesi de.
func _on_near_miss(_combo: int, multiplier: int) -> void:
	_near_miss_tween = _pop(_near_miss_label, _near_miss_tween, NEAR_MISS_POP_SCALE)
	_near_miss_tween.tween_interval(NEAR_MISS_TIME)
	_near_miss_tween.tween_property(_near_miss_label, "modulate:a", 0.0, NEAR_MISS_FADE)
	_near_miss_tween.tween_callback(_near_miss_label.hide)
	if multiplier == _multiplier:
		return
	_multiplier = multiplier
	_refresh()
	if multiplier > 1:
		_combo_tween = _pop(_combo_label, _combo_tween, COMBO_POP_SCALE)


func _on_combo_ended() -> void:
	_multiplier = 1
	_refresh()


## Etiketi ortasından büyüterek gösterir; önceki canlandırmasını keser. Tween gerçek zamanlıdır.
func _pop(label: Label, previous: Tween, from_scale: float) -> Tween:
	if previous != null:
		previous.kill()
	label.pivot_offset = label.size * 0.5
	label.visible = true
	label.modulate.a = 1.0
	var tween: Tween = create_tween().set_ignore_time_scale()
	tween.tween_property(label, "scale", Vector2.ONE, POP_TIME).from(Vector2.ONE * from_scale) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween


## Sektör geçişi: afiş, renk dalgası afişin hizasına varınca gelir.
func _on_sector_entered(index: int) -> void:
	_show_banner(index, _wave_delay())


## Final: aynı sektörün afişi final afişine döner (sector_entered'dan hemen sonra gelir).
func _on_great_storage_reached() -> void:
	_show_banner(maxi(_banner_sector, 1), _wave_delay(), true)


## Renk dalgasının afişin hizasına varma süresi (sn).
func _wave_delay() -> float:
	var center: float = _sector_banner.get_global_rect().get_center().y
	return Neon.STYLE.wave_reach_time(center / get_viewport_rect().size.y)


## Afişi delay sn sonra gösterir (0 ise hemen, büyümesiz). finale: sektör adı yerine final afişi.
func _show_banner(index: int, delay: float = 0.0, finale: bool = false) -> void:
	_banner_sector = index
	_banner_finale = finale
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
	_banner_tween.tween_interval(FINALE_BANNER_TIME if finale else BANNER_TIME)
	_banner_tween.tween_property(_sector_banner, "modulate:a", 0.0, BANNER_FADE)
	_banner_tween.tween_callback(_hide_banner)


## Dalga afişe vardı: afiş ortasından büyüyerek belirir.
func _pop_banner() -> void:
	_sector_banner.pivot_offset = _sector_banner.size * 0.5
	_sector_banner.visible = true
	_tint(_banner_sector)


## Sektörün vurgu rengini yükseklik ve kıl payı yazısına verir.
func _tint(index: int) -> void:
	if sectors == null:
		return
	var accent: Color = sectors.def_at(index).palette.accent
	_height_label.color = accent
	_near_miss_label.color = accent


func _hide_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_sector = 0
	_banner_finale = false
	_sector_banner.visible = false


## Her yazıya geçerli dilde gösterebileceği harfleri verir (afişe bütün sektörlerinkini).
func _warm_glyphs() -> void:
	_height_label.warm_glyphs = tr("HUD_HEIGHT") % 0 + DIGITS
	_best_label.warm_glyphs = tr("HUD_BEST") % 0 + DIGITS
	_glimmer_label.warm_glyphs = tr("HUD_GLIMMERS") % 0 + DIGITS
	_near_miss_label.warm_glyphs = tr("HUD_NEAR_MISS")
	_combo_label.warm_glyphs = tr("HUD_COMBO") % 0 + DIGITS
	var banners: String = DIGITS + tr("HUD_FINALE")
	if sectors != null:
		for index: int in range(1, sectors.count() + 1):
			banners += tr("HUD_SECTOR") % [index, tr(sectors.def_at(index).name_key)]
	_sector_banner.warm_glyphs = banners


func _refresh() -> void:
	_height_label.text = tr("HUD_HEIGHT") % _height_m
	_best_label.text = tr("HUD_BEST") % _best_m
	_best_label.visible = _best_m > 0
	_glimmer_label.text = tr("HUD_GLIMMERS") % _glimmers
	_near_miss_label.text = tr("HUD_NEAR_MISS")
	_combo_label.text = tr("HUD_COMBO") % _multiplier
	_combo_label.visible = _multiplier > 1
	if _banner_finale:
		_sector_banner.text = tr("HUD_FINALE")
		_sector_banner.color = Neon.STYLE.player_color
	elif _banner_sector > 0 and sectors != null:
		var def: SectorDef = sectors.def_at(_banner_sector)
		_sector_banner.text = tr("HUD_SECTOR") % [_banner_sector, tr(def.name_key)]
		_sector_banner.color = def.palette.accent
