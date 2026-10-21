class_name UpgradeCatalog
extends Resource
## Yükseltmelerin listesi (architecture.md §10), mağazadaki sırayla.

@export var upgrades: Array[UpgradeDef] = []


## Yükseltme tanımı; bilinmeyen kimlikte null.
func get_def(id: StringName) -> UpgradeDef:
	for def: UpgradeDef in upgrades:
		if def.id == id:
			return def
	return null


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for def: UpgradeDef in upgrades:
		out.append(def.id)
	return out
