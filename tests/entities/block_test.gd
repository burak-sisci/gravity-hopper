extends GdUnitTestSuite
## Diken ve veri bloğu (M3-05, architecture.md §9): tehlike kırmızısıyla, sivri köşeli çizilir.
## Bloğun görüntüsü vuruşla süzülür; çarpışma kutusu yerinde kalır (yalnızca görsel, ADR-035).

const BLOCK_SCENE: PackedScene = preload("res://scenes/entities/block.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/entities/spike.tscn")
const BLOCK_CHUNK: PackedScene = preload("res://scenes/levels/chunks/block_center_01.tscn")


func test_hazards_show_hazard_red_with_sharp_corners() -> void:
	for scene: PackedScene in [SPIKE_SCENE, BLOCK_SCENE]:
		var hazard: Node2D = auto_free(scene.instantiate()) as Node2D
		add_child(hazard)
		var visual: NeonShape = hazard.get_node("Visual") as NeonShape
		assert_object(visual.shown_color()).is_equal(Neon.STYLE.hazard_color)
		assert_bool(visual.sharp).is_true()


func test_hover_moves_only_the_visual() -> void:
	var block: Block = _add_block()
	var shape: CollisionShape2D = block.get_node("Shape") as CollisionShape2D
	var visual: Node2D = block.get_node("Visual") as Node2D
	var shape_before: Transform2D = shape.transform
	var size_before: Vector2 = (shape.shape as RectangleShape2D).size
	var lowest: float = 0.0
	var highest: float = 0.0
	# 8 vuruş, sekizde bir vuruş adımla.
	for i: int in 64:
		block.set_beat(i * 0.125)
		lowest = minf(lowest, visual.position.y)
		highest = maxf(highest, visual.position.y)
		assert_float(visual.position.x).is_equal(0.0)
	var amplitude: float = Neon.STYLE.block_hover_px
	assert_float(highest).is_equal_approx(amplitude, 0.01)
	assert_float(lowest).is_equal_approx(-amplitude, 0.01)
	assert_object(shape.transform).is_equal(shape_before)
	assert_vector((shape.shape as RectangleShape2D).size).is_equal(size_before)
	assert_vector(block.position).is_equal(Vector2.ZERO)


func test_data_rows_stay_inside_the_block() -> void:
	var block: Block = _add_block()
	var size: Vector2 = ((block.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D).size
	var box: Rect2 = Rect2(-size * 0.5, size)
	var rows: int = 0
	for child: Node in block.get_node("Visual").get_children():
		var line: Line2D = child as Line2D
		if line == null or line.closed:
			continue
		rows += 1
		for point: Vector2 in line.points:
			assert_bool(box.has_point(point)).override_failure_message("%s dışarıda" % point).is_true()
	assert_int(rows).is_equal(Neon.STYLE.block_rows.size())


func test_chunk_passes_the_beat_to_blocks() -> void:
	var chunk: ChunkInfo = auto_free(BLOCK_CHUNK.instantiate()) as ChunkInfo
	add_child(chunk)
	# Süzülmenin tepesi turun dörtte birinde.
	chunk.set_beat(Neon.STYLE.block_hover_beats * 0.25)
	var blocks: int = 0
	for item: Node2D in chunk.items():
		if item is Block:
			blocks += 1
			var visual: Node2D = item.get_node("Visual") as Node2D
			assert_float(visual.position.y).is_equal_approx(Neon.STYLE.block_hover_px, 0.01)
	assert_int(blocks).is_greater(0)


func _add_block() -> Block:
	var block: Block = auto_free(BLOCK_SCENE.instantiate()) as Block
	add_child(block)
	return block
