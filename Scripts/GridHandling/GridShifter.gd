extends Node
class_name GridShifter

# Reference to the main zone (Parent)
@onready var zone: DropZone = get_parent()

# --- PUBLIC API ---

func shift_rows_down(from_row_index: int, amount: int = 1) -> bool:
	var size = zone.collision_shape.shape.size
	# Removed unused 'top_left' variable here
	var max_rows = int(size.y / zone.grid_size)
	
	# 1. Identify blocks to move
	var blocks_to_shift = _get_blocks_below_row(from_row_index)

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
				var blocks_below = _get_blocks_below_row(drop_row_index + 1)
				for b in blocks_below:
					if b.row + max_y_offset >= max_rows:
						return false
				
				# Also check if pushing the CURRENT row down by 1 would go out of bounds
				var blocks_current = _get_horizontal_shift_blocks(drop_row_y, drop_start_x, ignore_item)
				if not blocks_current.is_empty():
					if drop_row_index + 1 >= max_rows:
						return false

	# 3. Check Horizontal Shifting (Only if NOT wrapping logic, but simple check assumes worst case)
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
	
	# --- VERTICAL STRUCTURE SHIFT ---
	if zone.spawner and ignore_item is CodeBlock and ignore_item.token_data:
		var code = ignore_item.token_data.code_string
		if code in zone.spawner.structures:
			var blueprint = zone.spawner.structures[code]
			var max_y_offset = 0
			for part in blueprint:
				if part["y"] > max_y_offset:
					max_y_offset = int(part["y"])
			
			if max_y_offset > 0:
				# 1. Shift everything BELOW us down by the full structure height
				shift_rows_down(drop_row_index + 1, max_y_offset)
				
				# 2. Check the CURRENT row for overlap (The "Wrap" Logic)
				var blocks_on_current_row = _get_horizontal_shift_blocks(drop_row_y, drop_start_x, ignore_item)
				
				if not blocks_on_current_row.is_empty():
					# Instead of pushing right, push them DOWN by 1 (into the body)
					for b in blocks_on_current_row:
						var block = b.node
						var tween = create_tween()
						tween.tween_property(block, "global_position", block.global_position + Vector2(0, zone.grid_size), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
					
					# Mark that we handled the current row, so we don't double-shift horizontally
					structure_handled_overlap = true
	
	# --- HORIZONTAL SHIFT ---
	# Only run if we didn't just wrap the blocks downwards
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

func _get_blocks_below_row(from_row_index: int) -> Array:
	var size = zone.collision_shape.shape.size
	var top_left = zone.collision_shape.position - (size / 2)
	var max_rows = int(size.y / zone.grid_size)
	var blocks = []
	
	var all_blocks = get_tree().get_nodes_in_group("pickup_items")
	for block in all_blocks:
		if not block is CodeBlock: continue
		if block.has_node("CollisionShape2D"):
			if block.get_node("CollisionShape2D").disabled:
				continue
		
		var block_local = zone.to_local(block.global_position) - top_left
		var row = round(block_local.y / zone.grid_size)
		var col = round(block_local.x / zone.grid_size)
		
		if col >= 0 and col < int(size.x / zone.grid_size) and row >= 0 and row < max_rows:
			if row >= from_row_index:
				blocks.append({"node": block, "row": int(row)})
	return blocks

func _get_horizontal_shift_blocks(drop_row_y: float, drop_start_x: float, ignore_item: Area2D) -> Array:
	var blocks = []
	var top_left = zone.collision_shape.position - (zone.collision_shape.shape.size / 2)
	var all_blocks = get_tree().get_nodes_in_group("pickup_items")
	
	for block in all_blocks:
		if block == ignore_item: continue
		if not block is CodeBlock: continue
		
		var block_local = zone.to_local(block.global_position) - top_left
		var block_y = floor(block_local.y / zone.grid_size) * zone.grid_size
		var block_x = floor(block_local.x / zone.grid_size) * zone.grid_size
		
		if is_equal_approx(block_y, drop_row_y) and block_x >= drop_start_x:
			var block_w = 1
			if block.token_data: block_w = block.token_data.width_units
			blocks.append({
				"node": block, 
				"x": block_x,
				"end_x": block_x + (block_w * zone.grid_size)
			})
	return blocks
