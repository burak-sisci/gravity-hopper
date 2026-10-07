class_name Player
extends CharacterBody2D
## Oyuncu: Enerji Çekirdeği (architecture.md §8.1). Sabit hızla tırmanır, aktif duvara doğru
## çekilir; dokunuş yerçekimini öbür duvara çevirir. Çevirme yalnızca duvara tutunurken olur.
## Girdi olayları yalnızca not edilir; karar bir sonraki fizik adımında verilir (.clauderules §5).
## Çevirince Events.player_flipped yayar. Hurtbox bir tehlikeye değince yalnızca
## Events.player_died yayar ve donar; tehlikenin koduna dokunmaz (architecture.md §7.3).

## Ayarlar Run tarafından atanır (aşağı çağrı).
var tuning: TuningConfig

## Aktif duvar yönü: -1 sol, +1 sağ.
var _gravity_dir: float = -1.0
var _flip_requested: bool = false
## Dokunma tamponunda kalan süre (sn). Havadaki dokunuş bu süre içinde duvara değilirse uygulanır.
var _buffer_left: float = 0.0
var _alive: bool = true

@onready var _body: CollisionShape2D = $Body
@onready var _hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_hurtbox.hit.connect(_on_hurtbox_hit)


func _unhandled_input(event: InputEvent) -> void:
	if _is_tap(event):
		get_viewport().set_input_as_handled()
		_flip_requested = true


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	# Çarpışma kutusu gövdeden küçüktür; oran her adımda okunur (canlı ayar paneli).
	_hurtbox.set_size((_body.shape as RectangleShape2D).size * tuning.hurtbox_scale)
	if _flip_requested:
		_flip_requested = false
		if is_on_wall():
			_flip()
		else:
			_buffer_left = tuning.input_buffer_time
	# Yatay: duvar teması fizikle. Yalnızca yatay hız verilir; yüzen kipteki kayma, çarpan
	# hareketin hızını korumak için yan hareketi tırmanışa ekler (M1-04'te %8 fazla ölçüldü).
	var max_side: float = TuningConfig.to_px(tuning.max_side_speed)
	var accel: float = TuningConfig.to_px(tuning.gravity_accel)
	velocity = Vector2(clampf(velocity.x + _gravity_dir * accel * delta, -max_side, max_side), 0.0)
	move_and_slide()
	# Duvara yaslanınca yan hız sıfırlanır; yoksa duvarın içine doğru birikir ve çevirmeden
	# sonra önce o hızı eritmek gerekir (karakter duvardan geç ayrılırdı).
	if is_on_wall():
		velocity.x = 0.0
	# Dokunma tamponu: havadayken yapılan dokunuş, duvara değilen adımda uygulanır.
	if _buffer_left > 0.0:
		if is_on_wall():
			_buffer_left = 0.0
			_flip()
		else:
			_buffer_left -= delta
	# Dikey: tırmanış doğrudan konumla, tam sabit hızda. Engeller vuruş ızgarasına göre
	# yerleştiği için (architecture.md §8.2) hızda sapma olmamalı.
	position.y -= TuningConfig.to_px(tuning.climb_speed) * delta


## Aktif duvar sağda mı (Run ve testler için).
func is_gravity_right() -> bool:
	return _gravity_dir > 0.0


func is_alive() -> bool:
	return _alive


## Kalkan M2-12'de gelir; o zamana kadar her darbe ölümdür.
func _on_hurtbox_hit() -> void:
	if not _alive:
		return
	_alive = false
	_flip_requested = false
	_buffer_left = 0.0
	Events.player_died.emit(GameTypes.DeathCause.HAZARD)


func _flip() -> void:
	_gravity_dir = -_gravity_dir
	Events.player_flipped.emit()


## Her parmağın basışı sayılır; dokunuştan türetilen sahte fare olayı yok sayılır, yoksa her
## dokunuş iki kez sayılır (S-07). PC'de sol tık ve boşluk.
static func _is_tap(event: InputEvent) -> bool:
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
