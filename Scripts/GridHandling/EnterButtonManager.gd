extends Node
class_name EnterButtonManager

# Assign your EnterButton.tscn here in the Inspector
@export var enter_button_scene: PackedScene

@onready var zone: DropZone = get_parent()

func _ready():
	# Wait one frame to ensure DropZone is ready
	call_deferred("_spawn_buttons")

func _spawn_buttons():
	if not enter_button_scene or not zone.collision_shape: return
	
	var size = zone.collision_shape.shape.size
	var top_left = zone.collision_shape.position - (size / 2)
	var rows_count = int(size.y / zone.grid_size)
	
	for i in range(rows_count):
		var btn = enter_button_scene.instantiate()
		zone.add_child(btn)
		
		var btn_pos = top_left + Vector2(-zone.grid_size, i * zone.grid_size) + Vector2(zone.grid_size/2.0, zone.grid_size/2.0)
		
		btn.position = btn_pos
		btn.setup(zone, i)
		
		# --- FIX 1: Auto-Resize Logic ---
		# Only scale the SPRITE, not the root node. 
		# This ensures the CollisionShape stays at exactly 1.0 scale.
		var sprite = btn.get_node_or_null("Sprite2D")
		if sprite and sprite.texture:
			var texture_size = sprite.texture.get_size()
			if texture_size.x > 0 and texture_size.y > 0:
				sprite.scale = Vector2(zone.grid_size, zone.grid_size) / texture_size
		
		# --- Collision Sizing ---
		var collider = btn.get_node_or_null("CollisionShape2D")
		if collider:
			var shape = collider.shape
			if not shape:
				shape = RectangleShape2D.new()
				collider.shape = shape
			if shape is RectangleShape2D:
				# Since root scale is 1.0, this sets the hitbox to exactly grid_size pixels
				shape.size = Vector2(zone.grid_size, zone.grid_size)
