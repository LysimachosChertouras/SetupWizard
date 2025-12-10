extends Node
class_name StructureSpawner

const BLOCK_SCENE = preload("res://Scenes/code_block.tscn")

# --- TOKEN REGISTRY (Exported) ---
# Maps Short Names -> File Paths
@export var token_registry: Dictionary = {
	"ParenOpen": "res://Resources/Tokens/Symbols/ParenOpen.tres",
	"ParenClose": "res://Resources/Tokens/Symbols/ParenClose.tres",
	"BraceOpen": "res://Resources/Tokens/Symbols/BraceOpen.tres",
	"BraceClose": "res://Resources/Tokens/Symbols/BraceClose.tres"
}

# --- BLUEPRINTS (Exported) ---
# Format: { "x": Grid Offset, "y": Grid Offset, "token": Registry Key }
@export var structures: Dictionary = {
	# IF: Standard check
	"if": [
		{ "x": 1, "y": 0, "token": "ParenOpen" },
		{ "x": 3, "y": 0, "token": "ParenClose" }, # Gap of 1 (at x=2)
		{ "x": 4, "y": 0, "token": "BraceOpen" },
		{ "x": 0, "y": 2, "token": "BraceClose" }
	],
	
	# WHILE: Same shape as IF
	"while": [
		{ "x": 2, "y": 0, "token": "ParenOpen" },
		{ "x": 5, "y": 0, "token": "ParenClose" }, 
		{ "x": 6, "y": 0, "token": "BraceOpen" },
		{ "x": 0, "y": 2, "token": "BraceClose" }
	],
	
	# FOR: Needs a much wider gap for iterators
	"for": [
		{ "x": 1, "y": 0, "token": "ParenOpen" },
		{ "x": 6, "y": 0, "token": "ParenClose" }, # Gap of 4 (x=2,3,4,5)
		{ "x": 7, "y": 0, "token": "BraceOpen" },
		{ "x": 0, "y": 2, "token": "BraceClose" }
	],
	
	# ELSE: No parentheses, just braces
	"else": [
		{ "x": 1, "y": 0, "token": "BraceOpen" },
		{ "x": 0, "y": 2, "token": "BraceClose" }
	],
	
	# FUNC: Standard function definition
	"func": [
		{ "x": 1, "y": 0, "token": "ParenOpen" },
		{ "x": 3, "y": 0, "token": "ParenClose" },
		{ "x": 4, "y": 0, "token": "BraceOpen" },
		{ "x": 0, "y": 2, "token": "BraceClose" }
	]
}

# Updated signature to accept the root_block object and the zone
func try_spawn(code_string: String, root_block: CodeBlock, grid_size: int, world_container: Node, zone: DropZone):
	if code_string in structures:
		var blueprint = structures[code_string]
		
		# 1. Check if the structure fits inside the zone
		if _check_bounds(blueprint, root_block.global_position, grid_size, zone):
			_spawn_blueprint(blueprint, root_block, grid_size, world_container)
		else:
			print("Structure blocked: Out of bounds")

func _check_bounds(blueprint: Array, root_pos: Vector2, grid_size: int, zone: DropZone) -> bool:
	var shape = zone.get_node("CollisionShape2D")
	var size = shape.shape.size
	var zone_top_left = shape.global_position - (size / 2)
	var zone_bottom_right = shape.global_position + (size / 2)
	
	for part in blueprint:
		var offset = Vector2(part["x"] * grid_size, part["y"] * grid_size)
		# Check the center of the potential new block
		var check_pos = root_pos + offset + Vector2(grid_size/2.0, grid_size/2.0)
		
		# AABB Check
		if check_pos.x < zone_top_left.x or check_pos.x > zone_bottom_right.x:
			return false
		if check_pos.y < zone_top_left.y or check_pos.y > zone_bottom_right.y:
			return false
			
	return true

func _spawn_blueprint(blueprint: Array, root_block: CodeBlock, grid_size: int, container: Node):
	for part in blueprint:
		var token_key = part["token"]
		
		# Look up in the Registry
		if not token_key in token_registry: 
			print("Error: Token key not found in registry: ", token_key)
			continue
			
		var resource_ref = token_registry[token_key]
		var token_data = null
		
		# Handle both String paths and direct Resources
		if resource_ref is String:
			token_data = load(resource_ref)
		elif resource_ref is TokenData:
			token_data = resource_ref
			
		if not token_data: 
			print("Error: Could not load token data for: ", token_key)
			continue
			
		var new_block = BLOCK_SCENE.instantiate()
		container.call_deferred("add_child", new_block)
		new_block.setup(token_data)
		
		var offset = Vector2(part["x"] * grid_size, part["y"] * grid_size)
		new_block.global_position = root_block.global_position + offset
		
		# Add to the parent's list so we can delete them later
		root_block.linked_blocks.append(new_block)
