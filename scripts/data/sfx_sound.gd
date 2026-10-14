class_name SfxSound
extends Resource
## Bir ses efekti (M3-15, architecture.md §8.8): SfxBank'in içinde alt kaynak; tools/sfx_prep.py
## üretir. Ses düzeyi dosyaya işlenmez, volume_db alanındadır (müzikle dengeli, ölçüm).

## Hangi olayda çalar.
@export var event: GameTypes.Sfx = GameTypes.Sfx.FLIP
## OGG Vorbis (döngüsüz).
@export var stream: AudioStream
## Müzikle dengeleyen ses düzeyi düzeltmesi.
@export_range(-24.0, 6.0, 0.1, "suffix:dB") var volume_db: float = 0.0
## Her çalışta perde bu oranda rastgele oynar; sık çalan ses tekrar ettikçe yorulmasın (kozmetik).
@export_range(0.0, 0.2, 0.01) var pitch_jitter: float = 0.0
## Atıf (CREDITS.md ve ileride Hakkında ekranı; .clauderules §7).
@export var title: String = ""
@export var author: String = ""
@export var license: String = ""
@export var source_url: String = ""


## Çalınca sürdüğü gerçek süre (sn); perde yükselince kısalır.
func duration(pitch: float) -> float:
	if stream == null or pitch <= 0.0:
		return 0.0
	return stream.get_length() / pitch
