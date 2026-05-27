extends Node
class_name GridScanner

@export var target_zone: DropZone
@export var interpreter: CodeInterpreter

## Updated to use the new class name: LevelChallengeManager
@export var challenge_manager: LevelChallengeManager

## A visual node (like a ColorRect or Sprite) that acts as the 'Execution Pointer'.
@export var execution_pointer: Node2D

# Signals to notify other systems
signal execution_started
signal execution_finished_visual

# Mapping to link token indices to physical blocks
var token_to_block_map: Array[CodeBlock] = []
var _last_highlighted_block: CodeBlock = null

func _ready() -> void:
	if not interpreter:
		for child in get_children():
			if child is CodeInterpreter:
				interpreter = child
				break
	
	if not challenge_manager:
		var managers = get_tree().get_nodes_in_group("challenge_managers")
		if managers.size() > 0:
			# Safety cast to the new class name
			challenge_manager = managers[0] as LevelChallengeManager
	
	if interpreter:
		if not interpreter.step_started.is_connected(_on_interpreter_step):
			interpreter.step_started.connect(_on_interpreter_step)
		if not interpreter.execution_finished.is_connected(_on_execution_finished):
			interpreter.execution_finished.connect(_on_execution_finished)
	
	if execution_pointer:
		execution_pointer.hide()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		run_visual_execution()

func run_visual_execution():
	var code_data = scan_grid_with_mapping()
	
	if interpreter:
		token_to_block_map = code_data.blocks
		
		if _last_highlighted_block:
			_last_highlighted_block.set_highlight(false)
			_last_highlighted_block = null
			
		execution_started.emit()
		interpreter.run_code(code_data.code)
	else:
		print("GridScanner Error: No CodeInterpreter assigned!")

func scan_grid_with_mapping() -> Dictionary:
	if not target_zone: 
		var zones = get_tree().get_nodes_in_group("drop_zones")
		if zones.size() > 0: target_zone = zones[0]
	
	if not target_zone: return {"code": "", "blocks": []}

	var shape = target_zone.collision_shape.shape
	var zone_size = shape.size
	var grid_size = target_zone.grid_size
	var shape_top_left = target_zone.collision_shape.global_position - (zone_size / 2)
	var start_pos = shape_top_left + Vector2(grid_size/2.0, grid_size/2.0)
	var cols = int(zone_size.x / grid_size)
	var rows = int(zone_size.y / grid_size)
	
	var full_text = ""
	var mapping: Array[CodeBlock] = []
	var all_blocks: Array[Area2D] = []
	
	for node in get_tree().get_nodes_in_group("pickup_items"):
		if node is Area2D: 
			all_blocks.append(node)
	
	for y in range(rows):
		var x = 0
		while x < cols:
			var check_pos = start_pos + Vector2(x * grid_size, y * grid_size)
			var block = PhysicsUtils.get_item_under_point(target_zone.get_world_2d(), check_pos, all_blocks)
			
			if block and block is CodeBlock and block.token_data:
				var block_code = block.token_data.code_string
				var block_tokens = interpreter._tokenize(block_code)
				for t in block_tokens:
					full_text += t + " "
					mapping.append(block)
				
				if block.token_data.width_units > 1:
					x += (block.token_data.width_units - 1)
			x += 1
		full_text += " "
		
	return {"code": full_text.strip_edges(), "blocks": mapping}

func _on_interpreter_step(index: int):
	if _last_highlighted_block:
		_last_highlighted_block.set_highlight(false)
	
	if index < token_to_block_map.size():
		var block = token_to_block_map[index]
		if is_instance_valid(block):
			block.set_highlight(true)
			_last_highlighted_block = block
			
			if execution_pointer:
				if not execution_pointer.visible:
					execution_pointer.show()
					execution_pointer.modulate.a = 0.0
				
				var grid_h = target_zone.grid_size if target_zone else 32
				var target_y = block.global_position.y + (grid_h / 2.0)
				
				var tween = create_tween().set_parallel(true)
				tween.tween_property(execution_pointer, "global_position:y", target_y, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tween.tween_property(execution_pointer, "modulate:a", 1.0, 0.2)
				
				if target_zone:
					execution_pointer.global_position.x = target_zone.collision_shape.global_position.x

func _on_execution_finished():
	if _last_highlighted_block:
		_last_highlighted_block.set_highlight(false)
		_last_highlighted_block = null
		
	if execution_pointer:
		var tween = create_tween()
		tween.tween_property(execution_pointer, "modulate:a", 0.0, 0.3)
		tween.finished.connect(func(): 
			execution_pointer.hide()
			execution_finished_visual.emit()
		)
	else:
		execution_finished_visual.emit()
