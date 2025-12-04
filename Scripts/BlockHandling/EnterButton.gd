extends Area2D

var row_index: int = 0
var parent_zone: DropZone

func setup(zone: DropZone, row: int):
	parent_zone = zone
	row_index = row
	
	# Optional: Set a label text to show line number (1, 2, 3...)
	var label = get_node_or_null("Label")
	if label:
		label.text = str(row_index + 1)

func _on_input_event(viewport, event, shape_idx):
	if event.is_action_pressed("Primary Action"):
		if parent_zone:
			# Trigger the shift
			parent_zone.shift_rows_down(row_index)
			
			# Optional: Visual feedback (pop animation)
			var tween = create_tween()
			tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.1)
			tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
