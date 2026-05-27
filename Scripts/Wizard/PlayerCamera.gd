extends Camera2D

## Drag your StaticBody2D here IF you are in the Main scene.
## If the player is in a separate scene, leave this empty and 
## add your StaticBody2D to the "camera_boundaries" group instead.
@export var boundary_node: Node2D

## Optional: Distance from the walls where the camera should stop.
@export var camera_margin: int = 0

@export_group("Performance & Smoothing")
## If the player moves using physics (move_and_slide), 
## this SHOULD be set to Physics to prevent jitter.
@export_enum("Idle", "Physics") var process_mode_selection: int = 1

@export_group("Aspect Ratio & Zoom")
## If enabled, the camera will automatically adjust zoom to fit the target resolution.
@export var auto_zoom: bool = true
## The resolution you designed your game for (e.g., 640x360).
@export var target_resolution := Vector2(640, 360)
## Additional zoom multiplier. 1.0 is default. 
## Set to 2.0 to be twice as close, 0.5 to be twice as far.
@export var zoom_level: float = 1.0

func _ready() -> void:
	# 1. Sync Camera timing with Player timing
	# This is the most common fix for "staggering" movement.
	if process_mode_selection == 1:
		process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	else:
		process_callback = Camera2D.CAMERA2D_PROCESS_IDLE

	# 2. Camera Essentials
	enabled = true
	position_smoothing_enabled = true
	# Increased speed slightly for more responsive following
	position_smoothing_speed = 8.0
	
	# Listen for window size changes to update zoom dynamically
	if auto_zoom:
		get_tree().get_root().size_changed.connect(_update_zoom)
		_update_zoom()
	
	# We wait for the physics shapes and transforms to be fully ready 
	# and updated in the global world space.
	call_deferred("_setup_camera_limits")

func _update_zoom() -> void:
	if not auto_zoom: return
	
	var screen_size = get_viewport_rect().size
	# Calculate the base scale to fit the target resolution
	var base_scale = min(screen_size.x / target_resolution.x, screen_size.y / target_resolution.y)
	
	# Apply the custom zoom multiplier
	var final_zoom = base_scale * zoom_level
	
	# Prevent zoom from being zero or negative
	final_zoom = max(final_zoom, 0.01)
	zoom = Vector2(final_zoom, final_zoom)

func _setup_camera_limits() -> void:
	# Auto-discovery logic for separate scenes
	if not boundary_node:
		var bounds_group = get_tree().get_nodes_in_group("camera_boundaries")
		if bounds_group.size() > 0:
			boundary_node = bounds_group[0]
			print("PlayerCamera: Auto-detected boundary node via group.")
	
	if not boundary_node:
		print("PlayerCamera Error: No boundary node assigned and none found in group 'camera_boundaries'.")
		return
		
	var shapes = _get_all_collision_shapes_recursive(boundary_node)
	
	if shapes.is_empty():
		print("PlayerCamera Error: No CollisionShape2D children found in boundary node.")
		return

	var total_rect: Rect2
	var first_shape = true

	for shape_node in shapes:
		if shape_node.shape is RectangleShape2D:
			shape_node.force_update_transform()
			var rect_shape = shape_node.shape as RectangleShape2D
			var actual_size = rect_shape.size * shape_node.global_scale
			var global_pos = shape_node.global_position
			var current_rect = Rect2(global_pos - (actual_size / 2.0), actual_size)
			
			if first_shape:
				total_rect = current_rect
				first_shape = false
			else:
				total_rect = total_rect.merge(current_rect)

	limit_left = int(total_rect.position.x) + camera_margin
	limit_top = int(total_rect.position.y) + camera_margin
	limit_right = int(total_rect.end.x) - camera_margin
	limit_bottom = int(total_rect.end.y) - camera_margin
	
	reset_smoothing()
	print("Camera limits successfully locked to: ", total_rect)

func _get_all_collision_shapes_recursive(parent: Node) -> Array[CollisionShape2D]:
	var found_shapes: Array[CollisionShape2D] = []
	for child in parent.get_children():
		if child is CollisionShape2D:
			found_shapes.append(child)
		found_shapes.append_array(_get_all_collision_shapes_recursive(child))
	return found_shapes
