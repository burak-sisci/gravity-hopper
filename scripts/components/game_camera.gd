class_name GameCamera
extends Camera2D
## Oyun kamerası: sabit ileri görüş kuralı (architecture.md §3). Hedefin üstünde her cihazda
## aynı mesafe görünür; uzun ekranlardaki fazla dikey alan hedefin altına gider. Yatayda
## koridorun ortası (x = 0) ekranın ortasıdır. Run her fizik adımında follow() çağırır.
## Sarsıntı (M3-10, §9): travma modeli. add_trauma() travmayı artırır (en çok 1), travma
## shake_decay hızıyla söner; ofset = shake_offset × travma² × gürültü. Yalnızca yatayda:
## oyuncunun üstünde görünen mesafe sarsıntıda da değişmez. Yalnızca görsel (ofset); view_top /
## view_bottom ve desen üretimi sarsıntıdan etkilenmez. Sarsıntı fizik adımında hesaplanır: fizik
## ara değerlemesi kamerayı zaten fizik adımında günceller, ofset de konumla aynı adımda değişir.

## Gürültünün düğüm sayısı (döngüsel). Düğümler sırayla sola ve sağa, genlikleri rastgele.
const NOISE_KEYS: int = 64
## Düğüm genliğinin alt sınırı: sarsıntı hiçbir düğümde sönük kalmaz.
const NOISE_MIN: float = 0.5

## Ayarlar Run tarafından atanır (aşağı çağrı). Atanmamışsa sarsıntı yok.
var tuning: TuningConfig

var _trauma: float = 0.0
## Sarsıntının gürültüde ilerlediği süre (sn).
var _shake_time: float = 0.0
var _keys: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	# Ara değerleme açıkken motor bunu zaten zorlar (uyarıyla); açıkça seçilir.
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	# Kozmetik: global rastgelelik serbest (.clauderules §5).
	_keys.resize(NOISE_KEYS)
	for i: int in NOISE_KEYS:
		_keys[i] = randf_range(NOISE_MIN, 1.0) * (1.0 if i % 2 == 0 else -1.0)


func _physics_process(delta: float) -> void:
	if _trauma <= 0.0 or tuning == null:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return
	_trauma = maxf(_trauma - tuning.shake_decay * delta, 0.0)
	_shake_time += delta
	var shake: float = shake_noise(_shake_time * tuning.shake_frequency)
	offset = Vector2(TuningConfig.to_px(tuning.shake_offset) * _trauma * _trauma * shake, 0.0)


## Kamerayı, hedefin üstünde lookahead_px kadar alan görünecek şekilde konumlar.
func follow(target_y: float, lookahead_px: float) -> void:
	var view_height: float = get_viewport_rect().size.y
	position = Vector2(0.0, target_y - lookahead_px + view_height * 0.5)


## Sarsıntı ekler (0–1; toplam en çok 1).
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Şu anki travma (test için).
func trauma() -> float:
	return _trauma


## Sarsıntı gürültüsü (-1–1): düğümler arası yumuşak geçiş; at = süre × sıklık.
func shake_noise(at: float) -> float:
	var key: int = floori(at)
	var from: float = _keys[posmod(key, NOISE_KEYS)]
	var to: float = _keys[posmod(key + 1, NOISE_KEYS)]
	return lerpf(from, to, smoothstep(0.0, 1.0, at - key))


## Görünür alanın üst kenarı (dünya koordinatı).
func view_top() -> float:
	return position.y - get_viewport_rect().size.y * 0.5


## Görünür alanın alt kenarı (dünya koordinatı).
func view_bottom() -> float:
	return position.y + get_viewport_rect().size.y * 0.5
