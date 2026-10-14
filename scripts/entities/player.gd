class_name Player
extends CharacterBody2D
## Oyuncu: Enerji Çekirdeği (architecture.md §8.1). Sabit hızla tırmanır, aktif duvara doğru
## çekilir; dokunuş yerçekimini öbür duvara çevirir. Çevirme yalnızca duvara tutunurken olur.
## Debug'da ölümsüzken (Events.debug_invincibility_changed) darbeler yok sayılır ve yarı saydamdır.
## Girdi olayları yalnızca not edilir; karar bir sonraki fizik adımında verilir (.clauderules §5).
## Çevirince Events.player_flipped yayar. Hurtbox bir tehlikeye değince yalnızca
## Events.player_died yayar ve donar; tehlikenin koduna dokunmaz (architecture.md §7.3).
## Kalkan (M2-16): darbeyi Shield emer, 1 sn dokunulmazlık gelir; yukarı shield_broken yayılır
## (Run çöküş duvarını çeker) ve Events.shield_changed duyurulur. Düşme ve duvara karşı korumaz.
## Kıl payı (M2-14): GrazeDetector bir tehlikenin çarpmadan geçtiğini bildirince yukarı near_missed
## yayar; Run komboyu yönetir.
## Duvar boşluğu (M2-11): duvar bitince oyuncu dışarı kayar. Coyote süresince çevirme hâlâ olur;
## süre dolduğunda koridorun dışındaysa player_died(FELL). Debug ölümsüzlüğünde duvar çizgisine
## geri konur.
## Görsel (M3-04): neon elmas (Visual, NeonShape) ve iz (Trail). İz her fizik adımında konumu
## alır; ölünce kayıt sürer, böylece iz çekirdeğe doğru toplanır.
## Ölümde kısa donma (M3-10): Run set_held() ile oyuncuyu ve izini bir süre yerinde tutar.
## Sıkışma-uzama (M3-11, yalnızca görsel): çevirmede çekirdek yana uzar, duvara inince basılır
## (SquashStretch, Visual'ın ölçeği); çarpışma şekilleri değişmez. Duvara iniş yukarı landed ile
## bildirilir (Run iniş kıvılcımını çıkarır). Ölüm patlamasında Run hide_core() çağırır.

## Bir tehlike çarpışma kutusuna değmeden kıl payı alanından geçti (Run bağlar).
signal near_missed
## Kalkan bir darbeyi emdi (Run çöküş duvarını çeker).
signal shield_broken
## Oyuncu duvara indi: at duvara değilen nokta (dünya), side duvarın yönü (Run kıvılcımı çıkarır).
signal landed(at: Vector2, side: float)

## Debug ölümsüzlüğünde görünürlük (oyuncu ölümsüz olduğunu görsün).
const INVINCIBLE_ALPHA: float = 0.45

## Ayarlar Run tarafından atanır (aşağı çağrı).
var tuning: TuningConfig
## Tırmanış hızı (m/sn); Run, bulunulan sektörden atar (M2-08).
var climb_speed: float = 0.0

## Aktif duvar yönü: -1 sol, +1 sağ.
var _gravity_dir: float = -1.0
var _flip_requested: bool = false
## Dokunma tamponunda kalan süre (sn). Havadaki dokunuş bu süre içinde duvara değilirse uygulanır.
var _buffer_left: float = 0.0
var _alive: bool = true
var _invincible: bool = false
## Duvardan ayrıldıktan sonra çevirmenin hâlâ kabul edildiği süre (coyote). Çevirince sıfırlanır.
var _coyote_left: float = 0.0
## Run'ın ölüm donması: oyuncu ve izi yerinde kalır (yalnızca görsel; ölü oyuncu).
var _held: bool = false
## Önceki adımda duvara yaslı mıydı (iniş anı: yaslı değilken yaslanmak).
var _was_on_wall: bool = false
var _squash: SquashStretch = SquashStretch.new()

@onready var _body: CollisionShape2D = $Body
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _collector: Collector = $Collector
@onready var _graze: GrazeDetector = $GrazeDetector
@onready var _shield: Shield = $Shield
@onready var _trail: Trail = $Trail
@onready var _visual: NeonShape = $Visual


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_trail.reset(position)
	_hurtbox.hit.connect(_on_hurtbox_hit)
	_graze.grazed.connect(_on_grazed)
	_shield.changed.connect(Events.shield_changed.emit)
	Events.debug_shield_requested.connect(give_shield)
	Events.debug_invincibility_changed.connect(_on_debug_invincibility_changed)


func _unhandled_input(event: InputEvent) -> void:
	if is_tap(event):
		get_viewport().set_input_as_handled()
		_flip_requested = true


func _physics_process(delta: float) -> void:
	if _held:
		return
	if not _alive:
		_trail.record(position)
		return
	_shield.tick(delta)
	# Çarpışma kutusu gövdeden küçüktür; oran her adımda okunur (canlı ayar paneli).
	var hurt_size: Vector2 = (_body.shape as RectangleShape2D).size * tuning.hurtbox_scale
	_hurtbox.set_size(hurt_size)
	_graze.set_size(hurt_size, TuningConfig.to_px(tuning.graze_margin))
	_collector.set_radius(TuningConfig.to_px(tuning.pickup_radius))
	if _flip_requested:
		_flip_requested = false
		if is_on_wall() or _coyote_left > 0.0:
			_flip()
		else:
			_buffer_left = tuning.input_buffer_time
	# Yatay: duvar teması fizikle. Yalnızca yatay hız verilir; yüzen kipteki kayma, çarpan
	# hareketin hızını korumak için yan hareketi tırmanışa ekler (M1-04'te %8 fazla ölçüldü).
	var max_side: float = TuningConfig.to_px(tuning.max_side_speed)
	var accel: float = TuningConfig.to_px(tuning.gravity_accel)
	velocity = Vector2(clampf(velocity.x + _gravity_dir * accel * delta, -max_side, max_side), 0.0)
	# Duvar parçalarının birleşim yerinde kayma dikeyde ≈ 0,02 px itebiliyor (M2-10'da ölçüldü);
	# dikey konum yalnızca tırmanıştan gelsin diye geri alınır.
	var climb_y: float = position.y
	move_and_slide()
	position.y = climb_y
	# Duvara yaslanınca yan hız sıfırlanır; yoksa duvarın içine doğru birikir ve çevirmeden
	# sonra önce o hızı eritmek gerekir (karakter duvardan geç ayrılırdı).
	var on_wall: bool = is_on_wall()
	if on_wall:
		velocity.x = 0.0
		_coyote_left = tuning.coyote_time
		if not _was_on_wall:
			_land()
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)
	_was_on_wall = on_wall
	# Dokunma tamponu: havadayken yapılan dokunuş, duvara değilen adımda uygulanır.
	if _buffer_left > 0.0:
		if is_on_wall():
			_buffer_left = 0.0
			_flip()
		else:
			_buffer_left -= delta
	# Dikey: tırmanış doğrudan konumla, tam sabit hızda. Engeller vuruş ızgarasına göre
	# yerleştiği için (architecture.md §8.2) hızda sapma olmamalı.
	position.y -= TuningConfig.to_px(climb_speed) * delta
	if _coyote_left <= 0.0:
		_check_fall()
	_trail.record(position)
	_squash.advance(delta)
	_visual.scale = _squash.visual_scale()
	_visual.position = _squash.visual_offset(_half_body(), _gravity_dir)


## Aktif duvar sağda mı (Run ve testler için).
func is_gravity_right() -> bool:
	return _gravity_dir > 0.0


func is_alive() -> bool:
	return _alive


## Kalkan takar (yükseltme M4'te; şimdilik debug, Events.debug_shield_requested).
func give_shield() -> void:
	if _alive:
		_shield.give()


func has_shield() -> bool:
	return _shield.active


## İzin rengini paletin çevre rengine çeker (Run, palet geçişinde çağırır; yalnızca görsel).
func set_ambient(color: Color) -> void:
	_trail.set_ambient(color)


## İzin süre çarpanı (Run, sektörün hız hissiyle verir; M3-13, yalnızca görsel).
func set_trail_stretch(stretch: float) -> void:
	_trail.stretch = stretch


## Bir girdi olayı çevirme dokunuşu mu? Her parmağın basışı sayılır; dokunuştan türetilen
## sahte fare olayı yok sayılır, yoksa her dokunuş iki kez sayılır (S-07). PC'de sol tık ve boşluk.
static func is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT \
				and mouse.device != InputEvent.DEVICE_ID_EMULATION
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return key.pressed and not key.echo and key.keycode == KEY_SPACE
	return false


## Ölüm donması (Run çağırır): oyuncu ve izi yerinde kalır. İz ara değerlemeyi de bırakır;
## yoksa kayıt durunca kuyruğu iki adım arasında titrerdi.
func set_held(held: bool) -> void:
	_held = held
	_trail.set_process(not held)


## Çekirdeği ve kalkan halkasını gizler (Run, ölüm patlamasında çağırır). İz, çekirdeğin
## kaldığı yere toplanmayı sürdürür.
func hide_core() -> void:
	_visual.visible = false
	_shield.visible = false


## Oyuncuyu öldürür (çöküş duvarı gibi dışarıdan gelen ölümler; Run çağırır).
## Ölümsüzken yok sayılır.
func die(cause: GameTypes.DeathCause) -> void:
	if not _alive or _invincible:
		return
	_alive = false
	_flip_requested = false
	_buffer_left = 0.0
	Events.player_died.emit(cause)


## Kalkan M2-16'da gelir; o zamana kadar her darbe ölümdür.
func _on_hurtbox_hit(area: Area2D) -> void:
	# Değen tehlike, kalkan ya da ölümsüzlükle geçilse de kıl payı sayılmaz.
	_graze.mark_hit(area)
	if not _alive or _invincible or _shield.is_in_grace():
		return
	if _shield.active:
		_shield.consume(tuning.shield_grace)
		shield_broken.emit()
		return
	_alive = false
	_flip_requested = false
	_buffer_left = 0.0
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)


func _on_grazed() -> void:
	if _alive:
		near_missed.emit()


func _on_debug_invincibility_changed(enabled: bool) -> void:
	_invincible = enabled
	modulate.a = INVINCIBLE_ALPHA if enabled else 1.0


func _flip() -> void:
	_gravity_dir = -_gravity_dir
	# Coyote çevirmesinde dışarı doğru birikmiş hız silinir; geçiş duvardan başlar gibi olur.
	velocity.x = 0.0
	_coyote_left = 0.0
	_squash.kick(Neon.STYLE.stretch_on_flip)
	Events.player_flipped.emit()


## Duvara iniş: çekirdek duvara basılır, değilen nokta yukarı bildirilir.
func _land() -> void:
	_squash.kick(-Neon.STYLE.squash_on_landing)
	landed.emit(global_position + Vector2(_gravity_dir * _half_body(), 0.0), _gravity_dir)


func _half_body() -> float:
	return (_body.shape as RectangleShape2D).size.x * 0.5


## Koridorun dışına çıkan oyuncu düşmüştür (duvar çizgisi + gövdenin yarısı).
func _check_fall() -> void:
	var half_body: float = _half_body()
	var edge: float = TuningConfig.to_px(tuning.corridor_width) * 0.5 + half_body
	if absf(position.x) <= edge:
		return
	if _invincible:
		position.x = signf(position.x) * (edge - 2.0 * half_body)
		velocity.x = 0.0
		return
	_alive = false
	_flip_requested = false
	_buffer_left = 0.0
	Events.player_died.emit(GameTypes.DeathCause.FELL)
