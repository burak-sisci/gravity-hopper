class_name RecordLine
extends NeonLine
## Rekor çizgisi (M3-14, GDD §8, architecture.md §9): oyun dünyasında, rekorun yüksekliğinde
## koridoru boydan boya geçen parlayan yatay çizgi. Oyuncu yaklaştıkça (record_heat_distance
## içinde) kalınlaşır ve parlar, vuruşta beyaza çekilerek nabız atar; oyuncu çizgiye varınca bir
## kez beyaz parlayıp söner ve o turda bir daha görünmez.
## Yalnızca görseldir: çarpışması yoktur, oyuncuyu tanımaz. Run yerini place ile verir, oyuncunun
## y'sini ve vuruşu her fizik adımında track ile aşağı çağırır. Rekor yoksa görünmez.
## Rekor kalıcıdır (Progression.best_height_m, M4-02; Main her tura verir).
## Çizgiye varıldığı adımda yukarı passed yayılır (Run, Events.record_broken'a çevirir; M3-15).

signal passed

## Yaklaşma: 0 uzakta – 1 çizgide.
var _heat: float = 0.0
## Vuruş nabzı (NeonStyle.beat_pulse).
var _pulse: float = 0.0
var _passed: bool = false
## Geçişten sonra kalan parlama (1 → 0).
var _flash: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta / Neon.STYLE.record_fade)
	_show()
	if _flash <= 0.0:
		visible = false
		set_process(false)


## Çizgiyi dünya y'sine koyar; half_width: koridorun yarı genişliği (px).
func place(y: float, half_width: float) -> void:
	position = Vector2(0.0, y)
	points = PackedVector2Array([Vector2(-half_width, 0.0), Vector2(half_width, 0.0)])
	_heat = 0.0
	_pulse = 0.0
	_passed = false
	visible = true
	_show()


## Oyuncunun dünya y'si ve vuruş konumu (vuruş ızgarasının başından beri geçen vuruş).
func track(player_y: float, beat: float) -> void:
	if not visible or _passed:
		return
	var style: NeonStyle = Neon.STYLE
	var distance_m: float = (player_y - position.y) / TuningConfig.PX_PER_M
	if distance_m <= 0.0:
		_passed = true
		_flash = 1.0
		set_process(true)
		passed.emit()
	else:
		_heat = 1.0 - clampf(distance_m / style.record_heat_distance, 0.0, 1.0)
		_pulse = style.beat_pulse(beat)
	_show()


## Oyuncu çizgiye vardı mı (bu turda).
func is_passed() -> bool:
	return _passed


func heat() -> float:
	return _heat


func _show() -> void:
	var style: NeonStyle = Neon.STYLE
	var shown_width: float
	var alpha: float
	var whiten: float
	if _passed:
		shown_width = lerpf(style.record_width.y, style.record_flash_width, _flash)
		alpha = style.record_alpha.y * _flash
		whiten = _flash
	else:
		shown_width = lerpf(style.record_width.x, style.record_width.y, _heat)
		alpha = lerpf(style.record_alpha.x, style.record_alpha.y, _heat)
		whiten = style.record_pulse_gain * _pulse
	if not is_equal_approx(width, shown_width):
		width = shown_width
	var tint: Color = style.record_color.lerp(Color.WHITE, whiten)
	if not tint.is_equal_approx(color):
		color = tint
	modulate.a = alpha
