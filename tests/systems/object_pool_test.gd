extends GdUnitTestSuite
## ObjectPool (M2-04, architecture.md §8.7): örnekler baştan oluşur, boştaki örnek gizli,
## işlemsiz ve fizik dünyasının dışındadır.

const SPIKE_SCENE: PackedScene = preload("res://scenes/entities/spike.tscn")

var _parent: Node2D


func before_test() -> void:
	_parent = auto_free(Node2D.new()) as Node2D
	add_child(_parent)


func test_reserve_creates_hidden_disabled_instances() -> void:
	var pool: ObjectPool = ObjectPool.new(SPIKE_SCENE, _parent)
	pool.reserve(3)
	pool.reserve(2)
	assert_int(pool.size()).is_equal(3)
	assert_int(pool.free_count()).is_equal(3)
	assert_int(_parent.get_child_count()).is_equal(3)
	for child: Node in _parent.get_children():
		assert_bool((child as Node2D).visible).is_false()
		assert_int(child.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)


func test_acquire_and_release_reuse_the_same_nodes() -> void:
	var pool: ObjectPool = ObjectPool.new(SPIKE_SCENE, _parent)
	pool.reserve(2)
	var a: Node2D = pool.acquire()
	assert_bool(a.visible).is_true()
	assert_int(a.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)
	assert_int(pool.free_count()).is_equal(1)
	pool.release(a)
	assert_bool(a.visible).is_false()
	assert_int(pool.free_count()).is_equal(2)
	assert_object(pool.acquire()).is_same(a)
	assert_int(pool.grown).is_equal(0)
	assert_int(_parent.get_child_count()).is_equal(2)


func test_empty_pool_grows_and_reports_it() -> void:
	var pool: ObjectPool = ObjectPool.new(SPIKE_SCENE, _parent)
	pool.reserve(1)
	pool.acquire()
	var extra: Node2D = pool.acquire()
	assert_object(extra).is_not_null()
	assert_int(pool.grown).is_equal(1)
	assert_int(pool.size()).is_equal(2)


func test_released_hazard_leaves_physics() -> void:
	var sensor: Area2D = Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 4
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	sensor.add_child(shape)
	_parent.add_child(sensor)
	var pool: ObjectPool = ObjectPool.new(SPIKE_SCENE, _parent)
	pool.reserve(1)
	var spike: Node2D = pool.acquire()
	await _frames(3)
	assert_int(sensor.get_overlapping_areas().size()).is_equal(1)
	pool.release(spike)
	await _frames(3)
	assert_int(sensor.get_overlapping_areas().size()).is_equal(0)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame
