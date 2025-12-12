extends Node
class_name GridShifter

# Reference to the main zone (Parent)
@onready var zone: DropZone = get_parent()

# --- PUBLIC API ---

# Calculates indentation relative to the parent block's line start
func get_indent_x(target_row_index: int, item: Area2D) -> float:
	var top_left = zone.collision_shape.position - (zone.collision_shape.shape.size / 2)
	
	# 1. Gather all valid blocks
	var all_blocks = []
	var raw_nodes = get_tree().get_nodes_in_group("pickup_items")
	for block in raw_nodes:
		if not is_instance_valid(block) or not block is CodeBlock: continue
		if block == item: continue 
		
		# Ignore held items
		if block.has_node("CollisionShape2D"):
			if block.get_node("CollisionShape2D").disabled:
				continue
		
		all_blocks.append(block)

	# 2. Sort blocks to read backwards (Bottom-Up, Right-to-Left)
	all_blocks.sort_custom(func(a, b):
		var a_pos = zone.to_local(a.global_position)
		var b_pos = zone.to_local(b.global_position)
		var a_row = round(a_pos.y / zone.grid_size)
		var b_row = round(b_pos.y / zone.grid_size)
		
		if a_row != b_row:
			return a_row > b_row 
		
		var a_col = round(a_pos.x / zone.grid_size)
		var b_col = round(b_pos.x / zone.grid_size)
		return a_col > b_col 
	)

	# 3. Find the Parent Scope
	var parent_row_index = -1
	var bracket_stack = 0
	
	for block in all_blocks:
		var block_pos = zone.to_local(block.global_position) - top_left
		var row = int(round(block_pos.y / zone.grid_size))
		
		if row < target_row_index:
			if block.token_data:
				var code = block.token_data.code_string
				if "}" in code:
					bracket_stack += 1
				if "{" in code:
					if bracket_stack > 0:
						bracket_stack -= 1
					else:
						parent_row_index = row
						break 
	
	# 4. Calculate Indentation based on Parent Row
	var indent_col = 0.0
	
	if parent_row_index != -1:
		var min_col = 99999
		for block in all_blocks:
			var block_pos = zone.to_local(block.global_position) - top_left
			var row = int(round(block_pos.y / zone.grid_size))
			var col = int(round(block_pos.x / zone.grid_size))
			
			if row == parent_row_index:
				if col < min_col:
					min_col = col
		
		if min_col != 99999:
			indent_col = min_col + 1

	if item is CodeBlock and item.token_data:
		if "}" in item.token_data.code_string:
			indent_col -= 1
			
	if indent_col < 0: indent_col = 0
	
	return indent_col * zone.grid_size

func shift_rows_down(from_row_index: int, amount: int = 1, ignore_item: Area2D = null) -> bool:
	var size = zone.collision_shape.shape.size
	var max_rows = int(size.y / zone.grid_size)
	
	# 1. Identify blocks to move
	var blocks_to_shift = _get_blocks_below_row(from_row_index, ignore_item)

	if blocks_to_shift.is_empty():
		return true

	# 2. Check Bounds
	for b in blocks_to_shift:
		if b.row + amount >= max_rows:
			print("Cannot shift rows: Block would fall out of bounds.")
			return false

	# 3. Apply Shift
	for b in blocks_to_shift:
		var block = b.node
		var tween = create_tween()
		tween.tween_property(block, "global_position", block.global_position + Vector2(0, zone.grid_size * amount), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	return true

# --- NEW: Shift Rows Up ---
func shift_rows_up(from_row_index: int, amount: int = 1, ignore_item: Area2D = null) -> bool:
	# 1. Identify blocks to move (from the row BELOW the button, moving UP)
	var blocks_to_shift = _get_blocks_below_row(from_row_index + 1, ignore_item)

	if blocks_to_shift.is_empty():
		return true

	# 2. Check Bounds (Don't push off the top)
	for b in blocks_to_shift:
		if b.row - amount < 0:
			print("Cannot shift rows up: Block would fall out of bounds (Top).")
			return false
	
	# 3. Check Collision (Don't overwrite existing blocks)
	# We are moving blocks INTO the rows starting at [from_row_index].
	# We need to check if the destination rows [from_row_index, from_row_index - amount + 1] are occupied.
	# For amount=1, we check if 'from_row_index' is occupied.
	var check_start_row = from_row_index - amount + 1
	var check_end_row = from_row_index
	
	if _is_range_occupied(check_start_row, check_end_row, ignore_item):
		print("Cannot shift rows up: Destination row is occupied.")
		return false
			
	# 4. Apply Shift
	for b in blocks_to_shift:
		var block = b.node
		var tween = create_tween()
		tween.tween_property(block, "global_position", block.global_position - Vector2(0, zone.grid_size * amount), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	return true

func can_accommodate_block(global_pos: Vector2, width_units: int, ignore_item: Area2D) -> bool:
	var local_pos = zone.to_local(global_pos)
	var size = zone.collision_shape.shape.size
	var top_left = zone.collision_shape.position - (size / 2)
	var shifted_pos = local_pos - top_left
	
	var max_x_width = size.x
	var max_rows = int(size.y / zone.grid_size)
	
	var drop_row_index = int(floor(shifted_pos.y / zone.grid_size))
	var drop_row_y = floor(shifted_pos.y / zone.grid_size) * zone.grid_size
	var drop_start_x = floor(shifted_pos.x / zone.grid_size) * zone.grid_size
	var drop_end_x = drop_start_x + (width_units * zone.grid_size)
	
	# 1. Check Horizontal Bounds
	if drop_end_x > max_x_width:
		return false

	# 2. Check Vertical Bounds (Structure Insert)
	if zone.spawner and ignore_item is CodeBlock and ignore_item.token_data:
		var code = ignore_item.token_data.code_string
		if code in zone.spawner.structures:
			var blueprint = zone.spawner.structures[code]
			var max_y_offset = 0
			for part in blueprint:
				if part["y"] > max_y_offset:
					max_y_offset = int(part["y"])
			
			if max_y_offset > 0:
				var blocks_below = _get_blocks_below_row(drop_row_index + 1, ignore_item)
				for b in blocks_below:
					if b.row + max_y_offset >= max_rows:
						return false
				
				var blocks_current = _get_horizontal_shift_blocks(drop_row_y, drop_start_x, ignore_item)
				if not blocks_current.is_empty():
					if drop_row_index + 1 >= max_rows:
						return false

	var blocks_to_shift = _get_horizontal_shift_blocks(drop_row_y, drop_start_x, ignore_item)

	if blocks_to_shift.is_empty():
		return true

	var closest_block_x = 99999.0
	for b in blocks_to_shift:
		if b.x < closest_block_x:
			closest_block_x = b.x
			
	var overlap = drop_end_x - closest_block_x
	
	if overlap > 0:
		var shift_units = ceil(overlap / zone.grid_size)
		var shift_pixels = shift_units * zone.grid_size
		
		for b in blocks_to_shift:
			var new_end_x = b.end_x + shift_pixels
			if new_end_x > max_x_width:
				return false 

	return true

func request_space_for_block(global_pos: Vector2, width_units: int, ignore_item: Area2D):
	var local_pos = zone.to_local(global_pos)
	var top_left = zone.collision_shape.position - (zone.collision_shape.shape.size / 2)
	var shifted_pos = local_pos - top_left
	
	var drop_row_y = floor(shifted_pos.y / zone.grid_size) * zone.grid_size
	var drop_row_index = int(floor(shifted_pos.y / zone.grid_size))
	var drop_start_x = floor(shifted_pos.x / zone.grid_size) * zone.grid_size
	var drop_end_x = drop_start_x + (width_units * zone.grid_size)
	
	var structure_handled_overlap = false
	
	if zone.spawner and ignore_item is CodeBlock and ignore_item.token_data:
		var code = ignore_item.token_data.code_string
		if code in zone.spawner.structures:
			var blueprint = zone.spawner.structures[code]
			var max_y_offset = 0
			for part in blueprint:
				if part["y"] > max_y_offset:
					max_y_offset = int(part["y"])
			
			if max_y_offset > 0:
				shift_rows_down(drop_row_index + 1, max_y_offset, ignore_item)
				
				var blocks_on_current_row = _get_horizontal_shift_blocks(drop_row_y, drop_start_x, ignore_item)
				if not blocks_on_current_row.is_empty():
					for b in blocks_on_current_row:
						var block = b.node
						var tween = create_tween()
						tween.tween_property(block, "global_position", block.global_position + Vector2(0, zone.grid_size), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
					structure_handled_overlap = true
	
	if not structure_handled_overlap:
		var blocks_to_move = _get_horizontal_shift_blocks(drop_row_y, drop_start_x, ignore_item)

		if blocks_to_move.is_empty(): return

		var closest_block_x = 99999.0
		for b in blocks_to_move:
			if b.x < closest_block_x:
				closest_block_x = b.x
				
		var overlap = drop_end_x - closest_block_x
		
		if overlap > 0:
			var shift_units = ceil(overlap / zone.grid_size)
			var shift_pixels = shift_units * zone.grid_size
			
			for b in blocks_to_move:
				var block = b.node
				var tween = create_tween()
				tween.tween_property(block, "global_position", block.global_position + Vector2(shift_pixels, 0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# --- INTERNAL HELPERS ---

func _get_blocks_below_row(from_row_index: int, ignore_item: Area2D = null) -> Array:
	var size = zone.collision_shape.shape.size
	var top_left = zone.collision_shape.position - (size / 2)
	var max_rows = int(size.y / zone.grid_size)
	# FIX 2: Check horizontal bounds too
	var max_cols = int(size.x / zone.grid_size)
	var blocks = []
	
	var all_blocks = get_tree().get_nodes_in_group("pickup_items")
	for block in all_blocks:
		if block == ignore_item: continue
		if not block is CodeBlock: continue
		
		if block.has_node("CollisionShape2D"):
			if block.get_node("CollisionShape2D").disabled:
				continue
		
		var block_local = zone.to_local(block.global_position) - top_left
		var row = round(block_local.y / zone.grid_size)
		var col = round(block_local.x / zone.grid_size)
		
		# FIX 2: Strict bounds check for Row AND Column
		if col >= 0 and col < max_cols and row >= 0 and row < max_rows:
			if row >= from_row_index:
				blocks.append({"node": block, "row": int(row)})
	return blocks

func _get_horizontal_shift_blocks(drop_row_y: float, drop_start_x: float, ignore_item: Area2D) -> Array:
	var blocks = []
	var size = zone.collision_shape.shape.size
	var top_left = zone.collision_shape.position - (zone.collision_shape.shape.size / 2)
	var max_cols = int(size.x / zone.grid_size) 
	
	var all_blocks = get_tree().get_nodes_in_group("pickup_items")
	
	for block in all_blocks:
		if block == ignore_item: continue
		if not block is CodeBlock: continue
		
		if block.has_node("CollisionShape2D"):
			if block.get_node("CollisionShape2D").disabled:
				continue
		
		var block_local = zone.to_local(block.global_position) - top_left
		var block_y = floor(block_local.y / zone.grid_size) * zone.grid_size
		var block_x = floor(block_local.x / zone.grid_size) * zone.grid_size
		var col = round(block_local.x / zone.grid_size)
		
		if col < 0 or col >= max_cols: continue
		
		if is_equal_approx(block_y, drop_row_y) and block_x >= drop_start_x:
			var block_w = 1
			if block.token_data: block_w = block.token_data.width_units
			blocks.append({
				"node": block, 
				"x": block_x,
				"end_x": block_x + (block_w * zone.grid_size)
			})
	return blocks

# NEW: Checks if any blocks exist in the given row range
func _is_range_occupied(start_row: int, end_row: int, ignore_item: Area2D = null) -> bool:
	var size = zone.collision_shape.shape.size
	var top_left = zone.collision_shape.position - (size / 2)
	var max_cols = int(size.x / zone.grid_size)
	
	var all_blocks = get_tree().get_nodes_in_group("pickup_items")
	for block in all_blocks:
		if block == ignore_item: continue
		if not block is CodeBlock: continue
		
		if block.has_node("CollisionShape2D"):
			if block.get_node("CollisionShape2D").disabled:
				continue
		
		var block_local = zone.to_local(block.global_position) - top_left
		var row = round(block_local.y / zone.grid_size)
		var col = round(block_local.x / zone.grid_size)
		
		# Check if inside grid horizontally
		if col >= 0 and col < max_cols:
			# Check row range
			if row >= start_row and row <= end_row:
				return true
				
	return false
