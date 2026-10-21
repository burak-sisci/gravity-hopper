class_name TrailCatalog
extends Resource
## Kozmetik izlerin listesi (M4-08, architecture.md §10), mağazadaki sırayla. İlki varsayılan izdir
## (kayıttaki "trail_default", herkeste açık).

@export var trails: Array[TrailDef] = []


## İz tanımı; bilinmeyen kimlikte null.
func get_def(id: StringName) -> TrailDef:
	for def: TrailDef in trails:
		if def.id == id:
			return def
	return null


func default_def() -> TrailDef:
	return trails[0] if not trails.is_empty() else null


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for def: TrailDef in trails:
		out.append(def.id)
	return out
