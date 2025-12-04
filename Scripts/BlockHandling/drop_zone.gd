extends Area2D
class_name DropZone

@export var grid_size := 32
@export var grid_color := Color(1, 1, 1, 0.3)
@export var border_color := Color.WHITE

@onready var collision_shape = $CollisionShape2D
@onready var spawner: StructureSpawner = $StructureSpawner

func _ready():
	add_to_group("drop_zones")
	queue_redraw()

func _draw():
	if not collision_shape or not collision_shape.shape: return
	var size = collision_shape.shape.size
	var top_left = collision_shape.position - (size / 2)
	var rect = Rect2(top_left, size)

	draw_rect(rect, border_color, false, 2.0)
	for x in range(0, int(size.x), grid_size):
		draw_line(top_left + Vector2(x, 0), top_left + Vector2(x, size.y), grid_color)
	for y in range(0, int(size.y), grid_size):
		draw_line(top_left + Vector2(0, y), top_left + Vector2(size.x, y), grid_color)

func on_item_placed(item: CodeBlock):
	if not item.token_data: return
	if spawner:
		spawner.try_spawn(item.token_data.code_string, item, grid_size, get_parent(), self)

func get_snapped_global_position(target_global_pos: Vector2) -> Vector2:
	var local_pos = to_local(target_global_pos)
	var size = collision_shape.shape.size
	var top_left = collision_shape.position - (size / 2)
	var shifted_pos = local_pos - top_left
	var grid_x = floor(shifted_pos.x / grid_size) * grid_size
	var grid_y = floor(shifted_pos.y / grid_size) * grid_size
	return to_global(Vector2(grid_x, grid_y) + top_left)

# --- NEW: SIMULATION CHECK ---
func can_accommodate_block(global_pos: Vector2, width_units: int, ignore_item: Area2D) -> bool:
	# 1. Setup Grid math
	var local_pos = to_local(global_pos)
	var size = collision_shape.shape.size
	var top_left = collision_shape.position - (size / 2)
	var shifted_pos = local_pos - top_left
	
	# Boundaries (in local coords relative to top-left of grid)
	var max_x_width = size.x
	
	var drop_row_y = floor(shifted_pos.y / grid_size) * grid_size
	var drop_start_x = floor(shifted_pos.x / grid_size) * grid_size
	var drop_end_x = drop_start_x + (width_units * grid_size)
	
	# Basic check: Does the new block itself fit?
	if drop_end_x > max_x_width:
		return false

	# 2. Find blocks that WOULD shift
	var blocks_to_shift = []
	var all_blocks = get_tree().get_nodes_in_group("pickup_items")
	
	for block in all_blocks:
		if block == ignore_item: continue
		if not block is CodeBlock: continue
		
		var block_local = to_local(block.global_position) - top_left
		var block_y = floor(block_local.y / grid_size) * grid_size
		var block_x = floor(block_local.x / grid_size) * grid_size
		
		# Same Row, To the Right
		if is_equal_approx(block_y, drop_row_y) and block_x >= drop_start_x:
			# Store the block and its current right edge
			var block_w = 1
			if block.token_data: block_w = block.token_data.width_units
			blocks_to_shift.append({
				"x": block_x,
				"end_x": block_x + (block_w * grid_size)
			})

	if blocks_to_shift.is_empty():
		return true

	# 3. Calculate Shift Amount
	var closest_block_x = 99999.0
	for b in blocks_to_shift:
		if b.x < closest_block_x:
			closest_block_x = b.x
			
	var overlap = drop_end_x - closest_block_x
	
	if overlap > 0:
		var shift_units = ceil(overlap / grid_size)
		var shift_pixels = shift_units * grid_size
		
		# 4. Final Check: Will any shifted block go out of bounds?
		for b in blocks_to_shift:
			var new_end_x = b.end_x + shift_pixels
			if new_end_x > max_x_width:
				return false # FAILURE: Block would fall off the edge

	return true # SUCCESS: Everything fits

# --- SHIFTING LOGIC (Kept same) ---
func request_space_for_block(global_pos: Vector2, width_units: int, ignore_item: Area2D):
	var local_pos = to_local(global_pos)
	var size = collision_shape.shape.size
	var top_left = collision_shape.position - (size / 2)
	var shifted_pos = local_pos - top_left
	
	var drop_row_y = floor(shifted_pos.y / grid_size) * grid_size
	var drop_start_x = floor(shifted_pos.x / grid_size) * grid_size
	var drop_end_x = drop_start_x + (width_units * grid_size)
	
	var blocks_to_move = []
	var all_blocks = get_tree().get_nodes_in_group("pickup_items")
	
	for block in all_blocks:
		if block == ignore_item: continue
		if not block is CodeBlock: continue
		
		var block_local = to_local(block.global_position) - top_left
		var block_y = floor(block_local.y / grid_size) * grid_size
		var block_x = floor(block_local.x / grid_size) * grid_size
		
		if is_equal_approx(block_y, drop_row_y) and block_x >= drop_start_x:
			blocks_to_move.append({"node": block, "x": block_x})

	if blocks_to_move.is_empty(): return

	var closest_block_x = 99999.0
	for b in blocks_to_move:
		if b.x < closest_block_x:
			closest_block_x = b.x
			
	var overlap = drop_end_x - closest_block_x
	
	if overlap > 0:
		var shift_units = ceil(overlap / grid_size)
		var shift_pixels = shift_units * grid_size
		
		for b in blocks_to_move:
			var block = b.node
			var tween = create_tween()
			tween.tween_property(block, "global_position", block.global_position + Vector2(shift_pixels, 0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
