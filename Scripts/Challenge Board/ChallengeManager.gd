extends Node
class_name LevelChallengeManager

@export_group("References")
@export var interpreter: Node # Duck typed for safety
## Drag your Apprentice.tscn file from the FileSystem dock into here!
@export var apprentice_scene: PackedScene 
## Drag your CodeBlock.tscn (or BlockSpawner.tscn) here!
@export var block_spawner_scene: PackedScene 
## The Node2D or TileMap that holds your maze. Drag it here!
@export var tile_container: Node2D 
## NEW: Create an empty Node2D where you want blocks to spawn and drag it here!
@export var block_spawn_point: Node2D 

@export_group("Math UI")
@export var math_title_label: Label
@export var math_instruction_label: RichTextLabel
@export var math_console_output: RichTextLabel 
@export var math_memory_inspector: RichTextLabel 

@export_group("Maze UI")
@export var maze_title_label: Label
@export var maze_instruction_label: RichTextLabel
@export var maze_console_output: RichTextLabel 
@export var maze_memory_inspector: RichTextLabel 

var current_challenge: LevelChallengeData
var is_running: bool = false
var active_apprentice: Node2D = null # Internal reference to the spawned character
var active_console: RichTextLabel = null # Automatically tracks which console to print to
var active_memory_inspector: RichTextLabel = null # Automatically tracks which memory inspector to update

func _ready() -> void:
	add_to_group("challenge_managers")
	if interpreter:
		if interpreter.has_signal("execution_finished"):
			interpreter.execution_finished.connect(_on_execution_finished)
		if interpreter.has_signal("log_message"):
			interpreter.log_message.connect(_on_interpreter_log)
		if interpreter.has_signal("error_occurred"):
			interpreter.error_occurred.connect(_on_interpreter_error)
		
		# Hook up real-time memory updates if the signals exist
		if interpreter.has_signal("memory_updated"):
			interpreter.memory_updated.connect(func(_vars): _update_memory_ui())
		elif interpreter.has_signal("step_started"):
			interpreter.step_started.connect(func(_idx): _update_memory_ui())
	else:
		push_warning("ChallengeManager: No interpreter assigned!")

func load_challenge(challenge_data: LevelChallengeData) -> void:
	if not challenge_data:
		push_error("ChallengeManager: load_challenge() was called, but the data is NULL!")
		return
		
	current_challenge = challenge_data
	print("ChallengeManager: Successfully loaded challenge data -> '", current_challenge.title, "'")
	
	match current_challenge.type:
		0: # 0 represents ChallengeType.MATH
			print("ChallengeManager: Setting up MATH mode.")
			
			# Setup Math UI
			if math_title_label: math_title_label.text = current_challenge.title
			if math_instruction_label: math_instruction_label.text = current_challenge.description
			active_console = math_console_output
			active_memory_inspector = math_memory_inspector
			
			# Setup Math Logic
			if interpreter and "memory" in interpreter:
				interpreter.memory.clear()
				_update_memory_ui() # Clear the inspector visually
				
			_spawn_allowed_blocks()
				
		1: # 1 represents ChallengeType.MAZE
			print("ChallengeManager: Setting up MAZE mode.")
			
			# Setup Maze UI
			if maze_title_label: maze_title_label.text = current_challenge.title
			if maze_instruction_label: maze_instruction_label.text = current_challenge.description
			active_console = maze_console_output
			active_memory_inspector = maze_memory_inspector
			
			# Setup Maze Logic
			if interpreter and "memory" in interpreter:
				interpreter.memory.clear()
				_update_memory_ui() # Clear the inspector visually
			
			_spawn_apprentice()
			_spawn_allowed_blocks()

func _spawn_apprentice():
	if not apprentice_scene:
		push_error("ChallengeManager: No Apprentice scene assigned in the Inspector!")
		return
		
	# Clean up any existing apprentice if we are reloading
	if is_instance_valid(active_apprentice):
		active_apprentice.queue_free()
		
	active_apprentice = apprentice_scene.instantiate()
	
	# Add them to the Level root so they exist in world space
	get_parent().call_deferred("add_child", active_apprentice)
	
	# FIX: Offset by the TileContainer's position so they spawn exactly on the maze!
	var offset = tile_container.global_position if tile_container else Vector2.ZERO
	var start_pixel_pos = offset + Vector2(current_challenge.start_pos.x * 32, current_challenge.start_pos.y * 32)
	active_apprentice.setup(start_pixel_pos, current_challenge)
	
	# Magically link the new Apprentice to the Interpreter!
	if interpreter and "apprentice" in interpreter:
		interpreter.set("apprentice", active_apprentice)

func _spawn_allowed_blocks():
	var container = block_spawn_point if block_spawn_point else tile_container
	if not container or not block_spawner_scene:
		push_warning("ChallengeManager: Cannot spawn tiles. Missing BlockSpawnPoint or BlockSpawnerScene.")
		return
		
	if not current_challenge.has_method("get_parsed_blocks"): return
	
	# Clear out old blocks if we are restarting the level
	for child in container.get_children():
		if child.is_in_group("pickup_items"):
			child.queue_free()
		
	var allowed_blocks = current_challenge.get_parsed_blocks()
	if allowed_blocks.is_empty(): return
	
	# Layout logic: Space them out horizontally in the container
	var current_x = 0
	for item_string in allowed_blocks:
		
		# --- FIX: Parse for stacks! Example: "int:3" ---
		var parts = item_string.split(":")
		var block_name = parts[0].strip_edges()
		var stack_amount = -1 # Infinite default
		
		if parts.size() > 1:
			stack_amount = parts[1].to_int()
			
		# Assumes your tokens are saved in the root of Resources/Tokens/. 
		var token_path = "res://Resources/Tokens/" + block_name + ".tres"
		if ResourceLoader.exists(token_path):
			var token_data = load(token_path)
			var spawner = block_spawner_scene.instantiate()
			
			container.add_child(spawner)
			
			if "token_data" in spawner:
				spawner.token_data = token_data
			
			# If using CodeBlock as the spawner, pass the stack limit!
			if "stack_count" in spawner:
				spawner.stack_count = stack_amount
				# Update the UI label immediately
				if spawner.has_method("_update_stack_label"):
					spawner.call("_update_stack_label")
			
			# Space them out based on their width
			spawner.position = Vector2(current_x, 0)
			current_x += (token_data.width_units * 32) + 16 # Add a 16px gap between spawners
		else:
			push_warning("ChallengeManager: Could not find TokenData for block: " + block_name)

func _on_execution_finished():
	is_running = false
	_update_memory_ui() # Final update just in case
	_check_victory_conditions()

func _check_victory_conditions():
	if not current_challenge: return
	var victory = false
	
	match current_challenge.type:
		0: # 0 represents ChallengeType.MATH
			victory = true
			var reqs = current_challenge.get_parsed_requirements()
			if reqs.is_empty():
				victory = false
			else:
				for var_name in reqs:
					var target_val = reqs[var_name]
					if not interpreter.memory.has(var_name) or str(interpreter.memory[var_name]) != str(target_val):
						victory = false
						break
					
		1: # 1 represents ChallengeType.MAZE
			if active_apprentice:
				# Check grid position relative to the TileContainer
				var offset = tile_container.global_position if tile_container else Vector2.ZERO
				var relative_pos = active_apprentice.global_position - offset
				var grid_pos = Vector2i(round(relative_pos.x / 32), round(relative_pos.y / 32))
				
				if grid_pos == current_challenge.end_pos:
					victory = true
	
	if victory: 
		print("LevelChallengeManager: Victory achieved!")
		if active_console: active_console.append_text("[color=green]SUCCESS![/color]\n")

func _on_interpreter_log(text: String):
	if active_console:
		active_console.append_text(text + "\n")

func _on_interpreter_error(message: String):
	if active_console:
		active_console.append_text("[color=red]ERROR: " + message + "[/color]\n")

# --- NEW: Memory UI Formatting ---
func _update_memory_ui():
	# Use the dynamically assigned memory inspector based on the current mode
	if not active_memory_inspector or not interpreter or not "memory" in interpreter:
		return
		
	var mem_text = "[b]--- Variables ---[/b]\n"
	var mem = interpreter.memory
	
	if mem.is_empty():
		mem_text += "[color=gray]No variables currently in memory.[/color]"
	else:
		for key in mem.keys():
			var val = mem[key]
			mem_text += str(key) + " = [color=yellow]" + str(val) + "[/color]\n"
			
	active_memory_inspector.text = mem_text
