extends Area2D
class_name BlockSpawner

@export var token_data: TokenData
const BLOCK_SCENE = preload("res://Scenes/code_block.tscn")

func _ready():
	add_to_group("pickup_items")
	_update_visuals()

func _update_visuals():
	if not token_data: return
	
	var label = get_node_or_null("Label")
	var background = get_node_or_null("Background")
	var collider = get_node_or_null("CollisionShape2D") # NEW: Get the collider
	
	# Calculate width (32 is grid size)
	var width = token_data.width_units * 32
	
	if label:
		label.text = token_data.display_text
		label.add_theme_color_override("font_color", token_data.block_color)
	
	if background:
		background.size = Vector2(width, 32)
		background.modulate = Color(0.9, 0.9, 0.9)
	
	# Force the physics shape to match the visual size
	if collider:
		var shape = collider.shape
		if not shape:
			shape = RectangleShape2D.new()
			collider.shape = shape
			
		if shape is RectangleShape2D:
			shape.size = Vector2(width, 32)
			# Center the collider (assuming origin is top-left like CodeBlock)
			collider.position = Vector2(width / 2.0, 32 / 2.0)

# This function is called by PickupNode
func spawn_copy() -> CodeBlock:
	var new_block = BLOCK_SCENE.instantiate()
	new_block.global_position = global_position
	new_block.token_data = token_data
	return new_block
