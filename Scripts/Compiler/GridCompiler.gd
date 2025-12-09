extends Node
class_name GridCompiler

# Assign the DropZone in the Inspector
@export var target_zone: DropZone

# For testing (Press 'P' to print code)
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		var result = scan_grid()
		print("--- COMPILED CODE ---")
		print(result)
		print("---------------------")

# The Main Scanner Function
func scan_grid() -> String:
	if not target_zone: 
		print("Error: No DropZone assigned to Compiler.")
		return ""

	# 1. Get Grid Dimensions from the Zone
	var shape = target_zone.collision_shape.shape
	var zone_size = shape.size
	var grid_size = target_zone.grid_size
	
	# Calculate Top-Left start point (World Coords)
	# We use the DropZone's position minus half size to find the corner
	var shape_top_left = target_zone.collision_shape.global_position - (zone_size / 2)
	
	# We want to check the CENTER of each cell
	var start_pos = shape_top_left + Vector2(grid_size/2.0, grid_size/2.0)
	
	var cols = int(zone_size.x / grid_size)
	var rows = int(zone_size.y / grid_size)
	
	var full_text = ""
	
	# Optimization: Cache the list of blocks once
	# Explicitly cast Array[Node] to Array[Area2D] to satisfy strict typing
	var raw_nodes = get_tree().get_nodes_in_group("pickup_items")
	var all_blocks: Array[Area2D] = []
	for node in raw_nodes:
		if node is Area2D:
			all_blocks.append(node)
	
	# 2. Loop through Rows (Y)
	for y in range(rows):
		var current_line = ""
		var x = 0
		
		# 3. Loop through Columns (X) using while so we can skip manually
		while x < cols:
			# Calculate world position to check
			var check_pos = start_pos + Vector2(x * grid_size, y * grid_size)
			
			# Check for a block using the PhysicsUtils helper
			var block = PhysicsUtils.get_item_under_point(
				target_zone.get_world_2d(),
				check_pos,
				all_blocks
			)
			
			if block and block is CodeBlock and block.token_data:
				# Found a block! Add its code string.
				current_line += block.token_data.code_string + " "
				
				# SKIPPER LOGIC:
				# If block is 3 units wide, we occupy x, x+1, x+2.
				# We are currently at x. The loop does x += 1 naturally.
				# We need to add extra jumps for the extra width.
				if block.token_data.width_units > 1:
					x += (block.token_data.width_units - 1)
			
			x += 1 # Move to next column
			
		# End of Row cleanup
		current_line = current_line.strip_edges() # Remove trailing spaces
		if current_line != "":
			full_text += current_line + "\n"
		
	return full_text
