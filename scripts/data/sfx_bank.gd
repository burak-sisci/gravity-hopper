class_name SfxBank
extends Resource
## Olay → ses eşlemesi (M3-15, architecture.md §8.8): data/audio/sfx_bank.tres; tools/sfx_prep.py
## üretir. AudioManager olayları Events'ten dinler ve sesini buradan bulur.

## Efekt havuzundaki çalar sayısı: aynı anda çalabilen en çok efekt. Hepsi doluysa bitmesine en
## az kalan kesilir. Çalarlar oyun açılırken kurulur; tur sırasında düğüm oluşturulmaz.
@export_range(1, 32, 1) var voices: int = 8
@export var sounds: Array[SfxSound] = []


## Olayın sesi; yoksa null.
func sound_for(event: GameTypes.Sfx) -> SfxSound:
	for sound: SfxSound in sounds:
		if sound.event == event:
			return sound
	return null
