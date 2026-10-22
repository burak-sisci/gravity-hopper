class_name ColorMetrics
extends RefCounted
## Renk ölçüleri (ADR-076, ölçülebilir doğrulama): OKLab farkı, renk körlüğü benzetimi ve WCAG
## kontrastı. Renk kurallarını denetleyen testler kullanır; tools/ yayın sürümüne girmez.

enum Cvd { PROTAN, DEUTAN, TRITAN }

## Doğrusal sRGB → LMS ve küp kökü alınmış LMS → OKLab matrislerinin satırları (Björn Ottosson).
const TO_LMS: Array[Vector3] = [
	Vector3(0.4122214708, 0.5363325363, 0.0514459929),
	Vector3(0.2119034982, 0.6806995451, 0.1073969566),
	Vector3(0.0883024619, 0.2817188376, 0.6299787005),
]
const TO_LAB: Array[Vector3] = [
	Vector3(0.2104542553, 0.7936177850, -0.0040720468),
	Vector3(1.9779984951, -2.4285922050, 0.4505937099),
	Vector3(0.0259040371, 0.7827717662, -0.8086757660),
]
## Renk körlüğü benzetimi (Machado, Oliveira, Fernandes 2009, tam şiddet; doğrusal RGB'de).
const PROTAN: Array[Vector3] = [
	Vector3(0.152286, 1.052583, -0.204868),
	Vector3(0.114503, 0.786281, 0.099216),
	Vector3(-0.003882, -0.048116, 1.051998),
]
const DEUTAN: Array[Vector3] = [
	Vector3(0.367322, 0.860646, -0.227968),
	Vector3(0.280085, 0.672501, 0.047413),
	Vector3(-0.011820, 0.042940, 0.968881),
]
const TRITAN: Array[Vector3] = [
	Vector3(1.255528, -0.076749, -0.178779),
	Vector3(-0.078411, 0.930809, 0.147602),
	Vector3(0.004733, 0.691367, 0.303900),
]


## sRGB rengin OKLab karşılığı (L, a, b): eşit uzaklıkların gözde eşit fark gibi göründüğü uzay.
static func oklab(color: Color) -> Vector3:
	var linear: Color = color.srgb_to_linear()
	var rgb: Vector3 = Vector3(linear.r, linear.g, linear.b)
	var lms: Vector3 = Vector3(TO_LMS[0].dot(rgb), TO_LMS[1].dot(rgb), TO_LMS[2].dot(rgb))
	var root: Vector3 = Vector3(
			pow(maxf(lms.x, 0.0), 1.0 / 3.0),
			pow(maxf(lms.y, 0.0), 1.0 / 3.0),
			pow(maxf(lms.z, 0.0), 1.0 / 3.0))
	return Vector3(TO_LAB[0].dot(root), TO_LAB[1].dot(root), TO_LAB[2].dot(root))


## İki rengin OKLab farkı (gözün ayırdığı en küçük fark ≈ 0,02).
static func difference(a: Color, b: Color) -> float:
	return oklab(a).distance_to(oklab(b))


## Rengin verilen renk körlüğüyle görünüşü.
static func simulate_cvd(color: Color, kind: Cvd) -> Color:
	var rows: Array[Vector3] = PROTAN
	if kind == Cvd.DEUTAN:
		rows = DEUTAN
	elif kind == Cvd.TRITAN:
		rows = TRITAN
	var linear: Color = color.srgb_to_linear()
	var rgb: Vector3 = Vector3(linear.r, linear.g, linear.b)
	var seen: Color = Color(
			clampf(rows[0].dot(rgb), 0.0, 1.0),
			clampf(rows[1].dot(rgb), 0.0, 1.0),
			clampf(rows[2].dot(rgb), 0.0, 1.0))
	return seen.linear_to_srgb()


## İki rengin, verilen renk körlüğüyle görülen OKLab farkı.
static func cvd_difference(a: Color, b: Color, kind: Cvd) -> float:
	return difference(simulate_cvd(a, kind), simulate_cvd(b, kind))


## WCAG 2 kontrast oranı (1–21).
static func contrast_ratio(a: Color, b: Color) -> float:
	var high: float = maxf(_luminance(a), _luminance(b))
	var low: float = minf(_luminance(a), _luminance(b))
	return (high + 0.05) / (low + 0.05)


## Göreli parlaklık (doğrusal değerlerle).
static func _luminance(color: Color) -> float:
	var linear: Color = color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b
