extends Camera2D

## Drag your StaticBody2D (the one with 4 shapes) here.
@export var boundary_node: Node2D

## Optional: Distance from the walls where the camera should stop.
## If your walls are thick and you want the camera to stop at the inner edge,
## you can use a positive margin (e.g., 32).
@export var camera_margin: int = 32

func _ready() -> void:
	# 1. Camera Essentials
	enabled = true
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0
	
	# We wait for the physics shapes to be fully ready in the scene
	call_deferred("_setup_camera_limits")

func _setup_camera_limits() -> void:
	if not boundary_node:
		print("PlayerCamera: No boundary node assigned.")
		return
		
	# Find all CollisionShape2D children
	var shapes = _get_all_collision_shapes(boundary_node)
	
	if shapes.is_empty():
		print("PlayerCamera Error: No CollisionShape2D children found in boundary node.")
		return

	# Use Rect2 to calculate the total area covered by all 4 shapes
	var total_rect: Rect2
	var first_shape = true

	for shape_node in shapes:
		if shape_node.shape is RectangleShape2D:
			var rect_shape = shape_node.shape as RectangleShape2D
			var size = rect_shape.size
			var global_pos = shape_node.global_position
			
			# Calculate the rect for this specific wall/ceiling/floor
			var current_rect = Rect2(global_pos - (size / 2), size)
			
			if first_shape:
				total_rect = current_rect
				first_shape = false
			else:
				# Merge this shape's area into the total area
				total_rect = total_rect.merge(current_rect)

	# 2. Apply the calculated limits to the camera
	# We use the outer bounds of your 4 shapes.
	limit_left = int(total_rect.position.x) + camera_margin
	limit_top = int(total_rect.position.y) + camera_margin
	limit_right = int(total_rect.end.x) - camera_margin
	limit_bottom = int(total_rect.end.y) - camera_margin
	
	print("Camera limits merged from ", shapes.size(), " shapes. Total Size: ", total_rect.size)

# Helper function to find all collision children
func _get_all_collision_shapes(parent: Node) -> Array[CollisionShape2D]:
	var found_shapes: Array[CollisionShape2D] = []
	for child in parent.get_children():
		if child is CollisionShape2D:
			found_shapes.append(child)
	return found_shapes
