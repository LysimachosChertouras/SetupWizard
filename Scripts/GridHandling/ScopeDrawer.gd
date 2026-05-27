extends Node2D
class_name ScopeDrawer

@onready var zone: DropZone = get_parent()

# Visual Settings
@export var line_color: Color = Color(1, 1, 1, 0.2) # Faint white
@export var line_width: float = 1.5

func _process(_delta):
	# Redraw every frame to handle moving blocks smoothly
	queue_redraw()

func _draw():
	if not zone or not zone.collision_shape: return
	
	# 1. Gather all valid blocks inside the zone
	var blocks = []
	var all_nodes = get_tree().get_nodes_in_group("pickup_items")
	var top_left = zone.collision_shape.position - (zone.collision_shape.shape.size / 2)
	
	for node in all_nodes:
		if not node is CodeBlock: continue
		
		# Ignore held items (visual noise)
		if node.has_node("CollisionShape2D") and node.get_node("CollisionShape2D").disabled:
			continue
		
		# Check if block is roughly inside the zone
		# We use local coordinates relative to the DropZone center
		var local_pos = zone.to_local(node.global_position)
		var relative_pos = local_pos - top_left
		var row = round(relative_pos.y / zone.grid_size)
		var col = round(relative_pos.x / zone.grid_size)
		
		# Basic bounds check
		if row >= 0 and col >= 0:
			blocks.append({
				"node": node,
				"row": int(row),
				"col": int(col),
				"pos": local_pos # Draw relative to Zone Center
			})
	
	# 2. Sort by Row then Column to ensure we parse top-to-bottom
	blocks.sort_custom(func(a, b):
		if a.row != b.row: return a.row < b.row
		return a.col < b.col
	)
	
	# 3. Stack Logic to connect pairs
	# Stack stores: { "center_y": float }
	var scope_stack = []
	
	for b in blocks:
		var block = b.node
		if not block.token_data: continue
		var code = block.token_data.code_string
		
		# Calculate Center of the block
		var center_y = b.pos.y + (zone.grid_size / 2.0)
		var center_x = b.pos.x + (zone.grid_size / 2.0)
		
		# A. OPEN BRACKET '{'
		if "{" in code:
			scope_stack.append({
				"y": center_y 
			})
			
		# B. CLOSE BRACKET '}'
		if "}" in code:
			if not scope_stack.is_empty():
				var start_data = scope_stack.pop_back()
				
				# Top of the line (Row of the '{')
				var p_top = Vector2(center_x, start_data.y)
				
				# Bottom of the line (Row of the '}')
				var p_bottom = Vector2(center_x, center_y)
				
				# Draw Simple Vertical Line
				if p_bottom.y > p_top.y:
					draw_line(p_top, p_bottom, line_color, line_width)
