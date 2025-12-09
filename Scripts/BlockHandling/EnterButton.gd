extends Area2D

var row_index: int = 0
var parent_zone: DropZone

# Store the correct original size here
var _base_scale: Vector2 = Vector2.ZERO
var _tween: Tween

func setup(zone: DropZone, row: int):
	parent_zone = zone
	row_index = row
	
	var label = get_node_or_null("Label")
	if label:
		label.text = str(row_index + 1)

# When pressed
func _on_input_event(_viewport, event, _shape_idx):
	if event.is_action_pressed("Primary Action"):
		if parent_zone:
			parent_zone.shift_rows_down(row_index)
			
			# --- Safe Animation ---
			var visual_node = get_node_or_null("Sprite2D")
			if visual_node:
				# 1. Capture the correct size the first time we click
				if _base_scale == Vector2.ZERO:
					_base_scale = visual_node.scale
				
				# 2. Stop any running animation so they don't stack
				if _tween:
					_tween.kill()
				
				# 3. Reset to the correct size immediately
				visual_node.scale = _base_scale
				
				# 4. Animate relative to the base scale
				_tween = create_tween()
				_tween.tween_property(visual_node, "scale", _base_scale * 0.8, 0.1)
				_tween.tween_property(visual_node, "scale", _base_scale, 0.1)
