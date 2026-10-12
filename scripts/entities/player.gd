class_name Player
extends CharacterBody2D
## Oyuncu: Enerji Çekirdeği (architecture.md §8.1). Sabit hızla tırmanır, aktif duvara doğru
## çekilir; dokunuş yerçekimini öbür duvara çevirir. Çevirme yalnızca duvara tutunurken olur.
## Debug'da ölümsüzken (Events.debug_invincibility_changed) darbeler yok sayılır ve yarı saydamdır.
## Girdi olayları yalnızca not edilir; karar bir sonraki fizik adımında verilir (.clauderules §5).
## Çevirince Events.player_flipped yayar. Hurtbox bir tehlikeye değince yalnızca
## Events.player_died yayar ve donar; tehlikenin koduna dokunmaz (architecture.md §7.3).
## Duvar boşluğu (M2-11): duvar bitince oyuncu dışarı kayar. Coyote süresince çevirme hâlâ olur;
## süre dolduğunda koridorun dışındaysa player_died(FELL). Debug ölümsüzlüğünde duvar çizgisine
## geri konur.

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

@onready var _body: CollisionShape2D = $Body
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _collector: Collector = $Collector


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_hurtbox.hit.connect(_on_hurtbox_hit)
	Events.debug_invincibility_changed.connect(_on_debug_invincibility_changed)


func _unhandled_input(event: InputEvent) -> void:
	if is_tap(event):
		get_viewport().set_input_as_handled()
		_flip_requested = true


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	# Çarpışma kutusu gövdeden küçüktür; oran her adımda okunur (canlı ayar paneli).
	_hurtbox.set_size((_body.shape as RectangleShape2D).size * tuning.hurtbox_scale)
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
	if is_on_wall():
		velocity.x = 0.0
		_coyote_left = tuning.coyote_time
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)
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


## Aktif duvar sağda mı (Run ve testler için).
func is_gravity_right() -> bool:
	return _gravity_dir > 0.0


func is_alive() -> bool:
	return _alive


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


## Kalkan M2-16'da gelir; o zamana kadar her darbe ölümdür.
func _on_hurtbox_hit() -> void:
	if not _alive or _invincible:
		return
	_alive = false
	_flip_requested = false
	_buffer_left = 0.0
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)


func _on_debug_invincibility_changed(enabled: bool) -> void:
	_invincible = enabled
	modulate.a = INVINCIBLE_ALPHA if enabled else 1.0


func _flip() -> void:
	_gravity_dir = -_gravity_dir
	# Coyote çevirmesinde dışarı doğru birikmiş hız silinir; geçiş duvardan başlar gibi olur.
	velocity.x = 0.0
	_coyote_left = 0.0
	Events.player_flipped.emit()


## Koridorun dışına çıkan oyuncu düşmüştür (duvar çizgisi + gövdenin yarısı).
func _check_fall() -> void:
	var half_body: float = (_body.shape as RectangleShape2D).size.x * 0.5
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
