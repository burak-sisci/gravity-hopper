class_name MusicCatalog
extends Resource
## Turlarda çalabilecek müzik parçaları (architecture.md §8.3, ADR-040;
## data/music/music_catalog.tres, tools/music_prep.py üretir). Her tur bir parçayı rastgele
## çalar; seçim yalnızca turun tohumundan gelir. Böylece aynı tohum (günlük meydan okuma, testler)
## hep aynı parçayı ve aynı tempoyu verir. Seçim, desen parçalarının RunRng dizisini kaydırmasın
## diye ayrı bir diziden çekilir.

## Seçim dizisinin tohumu turun tohumundan bununla türetilir.
const PICK_SALT: int = 0x5EED_0A11

@export var tracks: Array[MusicTrack] = []


func count() -> int:
	return tracks.size()


## Turun parçası (katalog boşsa null).
func pick(run_seed: int) -> MusicTrack:
	if tracks.is_empty():
		return null
	return tracks[RunRng.new(run_seed ^ PICK_SALT).range_int(0, tracks.size() - 1)]


## Katalogdaki farklı tempolar (küçükten büyüğe); doğrulayıcı her parçayı bunların hepsinde dener.
func tempos() -> Array[float]:
	var result: Array[float] = []
	for track: MusicTrack in tracks:
		if not result.has(track.bpm):
			result.append(track.bpm)
	result.sort()
	return result


## En hızlı tempo (havuzlar en kısa vuruşa göre kurulur).
func max_bpm() -> float:
	var result: float = 0.0
	for track: MusicTrack in tracks:
		result = maxf(result, track.bpm)
	return result
