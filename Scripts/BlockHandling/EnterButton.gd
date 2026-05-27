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

func _on_input_event(_viewport, event, _shape_idx):
	if not parent_zone: return
	
	# Primary: Move Down
	if event.is_action_pressed("Primary Action"):
		parent_zone.shift_rows_down(row_index)
		_play_animation()
		
	# Secondary: Move Up
	elif event.is_action_pressed("Secondary Action"):
		parent_zone.shift_rows_up(row_index)
		_play_animation()

func _play_animation():
	var visual_node = get_node_or_null("Sprite2D")
	if visual_node:
		if _base_scale == Vector2.ZERO:
			_base_scale = visual_node.scale
		
		if _tween:
			_tween.kill()
		
		visual_node.scale = _base_scale
		
		_tween = create_tween()
		_tween.tween_property(visual_node, "scale", _base_scale * 0.8, 0.1)
		_tween.tween_property(visual_node, "scale", _base_scale, 0.1)
