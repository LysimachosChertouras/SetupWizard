extends Node
class_name GridShifter

# Reference to the main zone (Parent)
@onready var zone: DropZone = get_parent()

# --- PUBLIC API ---

# Calculates indentation relative to the parent block's line start
func get_indent_x(target_row_index: int, item: Area2D) -> float:
	var size = zone.collision_shape.shape.size
	var top_left = zone.collision_shape.position - (size / 2)
	var max_rows = int(size.y / zone.grid_size)
	var max_cols = int(size.x / zone.grid_size)
	
	# 1. Gather all valid blocks within the DropZone bounds
	var all_blocks = []
	var raw_nodes = get_tree().get_nodes_in_group("pickup_items")
	
	for block in raw_nodes:
		if not is_instance_valid(block) or not block is CodeBlock: continue
		if block == item: continue 
		
		# Ignore items currently being held
		if block.has_node("CollisionShape2D"):
			if block.get_node("CollisionShape2D").disabled:
				continue
		
		# CRITICAL: Use logical position (meta) to calculate the row for indentation
		var current_y = block.get_meta("target_global_y", block.global_position.y)
		var block_local = zone.to_local(Vector2(block.global_position.x, current_y)) - top_left
		
		# Center sampling for stable detection
		var row = floor((block_local.y + zone.grid_size / 2.0) / zone.grid_size)
		var col = floor((block_local.x + zone.grid_size / 2.0) / zone.grid_size)
		
		if col >= 0 and col < max_cols and row >= 0 and row < max_rows:
			all_blocks.append({
				"node": block,
				"row": int(row),
				"col": int(col)
			})

	# 2. Sort blocks Bottom-to-Top, Right-to-Left (Reading Backwards)
	all_blocks.sort_custom(func(a, b):
		if a.row != b.row:
			return a.row > b.row 
		return a.col > b.col 
	)

	# 3. Find the Parent Scope
	var parent_row_index = -1
	var bracket_stack = 0
	
	for b_data in all_blocks:
		if b_data.row < target_row_index:
			if b_data.node.token_data:
				var code = b_data.node.token_data.code_string
				if "}" in code:
					bracket_stack += 1
				if "{" in code:
					if bracket_stack > 0:
						bracket_stack -= 1
					else:
						parent_row_index = b_data.row
						break 
	
	# 4. Calculate Indentation based on Parent Row
	var indent_col = 0.0
	if parent_row_index != -1:
		var min_col = 99999
		for b_data in all_blocks:
			if b_data.row == parent_row_index:
				if b_data.col < min_col:
					min_col = b_data.col
		
		if min_col != 99999:
			indent_col = min_col + 1

	# Adjustment: Closing brackets should un-indent themselves
	if item is CodeBlock and item.token_data:
		if "}" in item.token_data.code_string:
			indent_col -= 1
			
	if indent_col < 0: indent_col = 0
	
	return indent_col * zone.grid_size

func shift_rows_down(from_row_index: int, amount: int = 1, ignore_item: Area2D = null) -> bool:
	var size = zone.collision_shape.shape.size
	var max_rows = int(size.y / zone.grid_size)
	
	var blocks_to_shift = _get_blocks_below_row(from_row_index, ignore_item)
	if blocks_to_shift.is_empty(): return true

	# Bounds check using logical destination
	for b in blocks_to_shift:
		if b.row + amount >= max_rows:
			return false

	for b in blocks_to_shift:
		var block = b.node
		var current_target_y = block.get_meta("target_global_y", block.global_position.y)
		var new_target_y = current_target_y + (zone.grid_size * amount)
		
		block.set_meta("target_global_y", new_target_y)
		
		var tween = create_tween()
		tween.tween_property(block, "global_position:y", new_target_y, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	return true

func shift_rows_up(from_row_index: int, amount: int = 1, ignore_item: Area2D = null) -> bool:
	var blocks_to_shift = _get_blocks_below_row(from_row_index + 1, ignore_item)
	if blocks_to_shift.is_empty(): return true

	for b in blocks_to_shift:
		if b.row - amount < 0: return false
	
	if _is_range_occupied(from_row_index - amount + 1, from_row_index, ignore_item):
		return false
			
	for b in blocks_to_shift:
		var block = b.node
		var current_target_y = block.get_meta("target_global_y", block.global_position.y)
		var new_target_y = current_target_y - (zone.grid_size * amount)
		
		block.set_meta("target_global_y", new_target_y)
		
		var tween = create_tween()
		tween.tween_property(block, "global_position:y", new_target_y, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	return true

func can_accommodate_block(global_pos: Vector2, width_units: int, ignore_item: Area2D) -> bool:
	var size = zone.collision_shape.shape.size
	var top_left = zone.collision_shape.position - (size / 2)
	var local_pos = zone.to_local(global_pos) - top_left
	
	var drop_row_index = int(floor((local_pos.y + zone.grid_size / 2.0) / zone.grid_size))
	var drop_start_x = floor((local_pos.x + zone.grid_size / 2.0) / zone.grid_size) * zone.grid_size
	var drop_end_x = drop_start_x + (width_units * zone.grid_size)
	
	if drop_end_x > size.x: return false

	# Logic for structure spacing check
	if zone.spawner and ignore_item is CodeBlock and ignore_item.token_data:
		var code = ignore_item.token_data.code_string
		if code in zone.spawner.structures:
			var blueprint = zone.spawner.structures[code]
			var max_y = 0
			for p in blueprint: if p["y"] > max_y: max_y = int(p["y"])
			
			if max_y > 0:
				var blocks_below = _get_blocks_below_row(drop_row_index + 1, ignore_item)
				for b in blocks_below:
					if b.row + max_y >= int(size.y / zone.grid_size): return false

	return true

func request_space_for_block(global_pos: Vector2, width_units: int, ignore_item: Area2D):
	var size = zone.collision_shape.shape.size
	var top_left = zone.collision_shape.position - (size / 2)
	var local_pos = zone.to_local(global_pos) - top_left
	
	var drop_row_y = floor((local_pos.y + zone.grid_size / 2.0) / zone.grid_size) * zone.grid_size
	var drop_row_index = int(floor((local_pos.y + zone.grid_size / 2.0) / zone.grid_size))
	var drop_start_x = floor((local_pos.x + zone.grid_size / 2.0) / zone.grid_size) * zone.grid_size
	var drop_end_x = drop_start_x + (width_units * zone.grid_size)
	
	var structure_handled_rows = false
	
	# 1. Structure Vertical Push
	if zone.spawner and ignore_item is CodeBlock and ignore_item.token_data:
		var code = ignore_item.token_data.code_string
		if code in zone.spawner.structures:
			var blueprint = zone.spawner.structures[code]
			var max_y = 0
			for p in blueprint: if p["y"] > max_y: max_y = int(p["y"])
			if max_y > 0:
				shift_rows_down(drop_row_index + 1, max_y, ignore_item)
				
				# Push blocks on the current row down to clear space for the structure head
				var current_row_blocks = _get_horizontal_shift_blocks(drop_row_y, drop_start_x, ignore_item)
				for b in current_row_blocks:
					var block = b.node
					var next_y = block.get_meta("target_global_y", block.global_position.y) + zone.grid_size
					block.set_meta("target_global_y", next_y)
					var tween = create_tween()
					tween.tween_property(block, "global_position:y", next_y, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				
				structure_handled_rows = true
	
	# 2. Horizontal Shift (If not pushing rows)
	if not structure_handled_rows:
		var horizontal_blocks = _get_horizontal_shift_blocks(drop_row_y, drop_start_x, ignore_item)
		if not horizontal_blocks.is_empty():
			var min_x = 99999.0
			for b in horizontal_blocks: if b.x < min_x: min_x = b.x
			
			var overlap = drop_end_x - min_x
			if overlap > 0:
				var shift = ceil(overlap / zone.grid_size) * zone.grid_size
				for b in horizontal_blocks:
					var block = b.node
					var cur_x = block.get_meta("target_global_x", block.global_position.x)
					var next_x = cur_x + shift
					block.set_meta("target_global_x", next_x)
					var tween = create_tween()
					tween.tween_property(block, "global_position:x", next_x, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# --- INTERNAL HELPERS ---

func _get_blocks_below_row(from_row_index: int, ignore_item: Area2D = null) -> Array:
	var size = zone.collision_shape.shape.size
	var top_left = zone.collision_shape.position - (size / 2)
	var max_rows = int(size.y / zone.grid_size)
	var max_cols = int(size.x / zone.grid_size)
	var blocks = []
	
	for block in get_tree().get_nodes_in_group("pickup_items"):
		if block == ignore_item or not block is CodeBlock: continue
		if block.has_node("CollisionShape2D") and block.get_node("CollisionShape2D").disabled: continue
		
		var cur_y = block.get_meta("target_global_y", block.global_position.y)
		var block_local = zone.to_local(Vector2(block.global_position.x, cur_y)) - top_left
		var row = floor((block_local.y + zone.grid_size / 2.0) / zone.grid_size)
		var col = floor((block_local.x + zone.grid_size / 2.0) / zone.grid_size)
		
		if col >= 0 and col < max_cols and row >= 0 and row < max_rows:
			if row >= from_row_index:
				blocks.append({"node": block, "row": int(row)})
	return blocks

func _get_horizontal_shift_blocks(drop_row_y: float, drop_start_x: float, ignore_item: Area2D) -> Array:
	var blocks = []
	var size = zone.collision_shape.shape.size
	var top_left = zone.collision_shape.position - (size / 2)
	for block in get_tree().get_nodes_in_group("pickup_items"):
		if block == ignore_item or not block is CodeBlock: continue
		if block.has_node("CollisionShape2D") and block.get_node("CollisionShape2D").disabled: continue
		
		var cur_y = block.get_meta("target_global_y", block.global_position.y)
		var cur_x = block.get_meta("target_global_x", block.global_position.x)
		var block_local = zone.to_local(Vector2(cur_x, cur_y)) - top_left
		
		if is_equal_approx(floor((block_local.y + zone.grid_size / 2.0) / zone.grid_size) * zone.grid_size, drop_row_y) and block_local.x >= drop_start_x:
			blocks.append({"node": block, "x": block_local.x})
	return blocks

func _is_range_occupied(start_row: int, end_row: int, ignore_item: Area2D = null) -> bool:
	var results = _get_blocks_below_row(start_row, ignore_item)
	for b in results:
		if b.row <= end_row: return true
	return false
