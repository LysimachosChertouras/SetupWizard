extends Node
class_name GridScanner

# Assign your DropZone in the Inspector
@export var target_zone: DropZone
# Assign the Interpreter node here (or let it auto-connect)
@export var interpreter: CodeInterpreter

func _ready() -> void:
	# 1. AUTO-CONNECT INTERPRETER
	# If not assigned manually, look for a child node that is a CodeInterpreter
	if not interpreter:
		for child in get_children():
			if child is CodeInterpreter:
				interpreter = child
				print("GridScanner: Auto-connected to Interpreter.")
				break

# For testing (Press 'P' to print code)
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		var result = scan_grid()
		print("--- RAW CODE STREAM ---")
		print(result)
		print("-----------------------")
		
		# Send to Interpreter
		if interpreter:
			interpreter.run_code(result)
		else:
			print("GridScanner Error: No Interpreter connected! Add CodeInterpreter as a child.")

# The Main Scanner Function
func scan_grid() -> String:
	# 2. AUTO-CONNECT DROP ZONE
	# If no zone is assigned, try to find one automatically in the main scene
	if not target_zone: 
		var zones = get_tree().get_nodes_in_group("drop_zones")
		if zones.size() > 0:
			target_zone = zones[0]
	
	if not target_zone: 
		print("Error: No DropZone assigned to Scanner.")
		return ""

	# 1. Get Grid Dimensions from the Zone
	var shape = target_zone.collision_shape.shape
	var zone_size = shape.size
	var grid_size = target_zone.grid_size
	
	var shape_top_left = target_zone.collision_shape.global_position - (zone_size / 2)
	var start_pos = shape_top_left + Vector2(grid_size/2.0, grid_size/2.0)
	
	var cols = int(zone_size.x / grid_size)
	var rows = int(zone_size.y / grid_size)
	
	var full_text = ""
	
	# Optimization: Cache the list of blocks
	var raw_nodes = get_tree().get_nodes_in_group("pickup_items")
	var all_blocks: Array[Area2D] = []
	for node in raw_nodes:
		if node is Area2D:
			all_blocks.append(node)
	
	# 2. Loop through Rows (Y)
	for y in range(rows):
		var x = 0
		
		# 3. Loop through Columns (X)
		while x < cols:
			var check_pos = start_pos + Vector2(x * grid_size, y * grid_size)
			
			var block = PhysicsUtils.get_item_under_point(
				target_zone.get_world_2d(),
				check_pos,
				all_blocks
			)
			
			if block and block is CodeBlock and block.token_data:
				# Found a block! Add its code string.
				full_text += block.token_data.code_string + " "
				
				# SKIPPER LOGIC:
				if block.token_data.width_units > 1:
					x += (block.token_data.width_units - 1)
			
			x += 1 # Move to next column
			
		# End of Row: Just add a space, NOT a newline.
		full_text += " "
		
	# Clean up double spaces
	while "  " in full_text:
		full_text = full_text.replace("  ", " ")
		
	return full_text.strip_edges()
