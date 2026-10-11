class_name ObjectPool
extends RefCounted
## Nesne havuzu (architecture.md §8.7, .clauderules §6). Bir sahnenin örnekleri tur başında
## oluşturulur (reserve); tur sırasında acquire() / release() ile döner, düğüm oluşturulmaz.
## Boştaki örnek gizli ve işlemsizdir (PROCESS_MODE_DISABLED): içindeki çarpışma alanları da
## fizik dünyasından çıkar (CollisionObject2D.disable_mode varsayılanı REMOVE).

## Havuz tükendiği için tur sırasında oluşturulan örnek sayısı. 0 değilse havuz küçük kurulmuştur.
var grown: int = 0

var _scene: PackedScene
var _parent: Node
var _all: Array[Node2D] = []
var _free: Array[Node2D] = []


func _init(scene: PackedScene, parent: Node) -> void:
	_scene = scene
	_parent = parent


## Havuzda en az count örnek olmasını sağlar. Yalnızca tur kurulurken çağrılır.
func reserve(count: int) -> void:
	while _all.size() < count:
		_free.append(_create())


## Boştaki bir örneği etkinleştirip verir. Havuz tükenmişse uyarır ve yenisini oluşturur;
## böylece harita bozulmaz (seçim havuza bağlı değildir), ama sorun testte görünür.
func acquire() -> Node2D:
	if _free.is_empty():
		grown += 1
		push_warning("ObjectPool: %s tükendi; tur sırasında örnek oluşturuldu" % _scene.resource_path)
		_free.append(_create())
	var node: Node2D = _free.pop_back()
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.visible = true
	return node


func release(node: Node2D) -> void:
	_deactivate(node)
	_free.append(node)


## Havuzun ilk örneği; sahnenin verisini (ör. ChunkInfo alanları) okumak için.
func peek() -> Node2D:
	if _all.is_empty():
		reserve(1)
	return _all[0]


func size() -> int:
	return _all.size()


func free_count() -> int:
	return _free.size()


func _create() -> Node2D:
	var node: Node2D = _scene.instantiate() as Node2D
	_deactivate(node)
	_parent.add_child(node)
	_all.append(node)
	return node


static func _deactivate(node: Node2D) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.visible = false
