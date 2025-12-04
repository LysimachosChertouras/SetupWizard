extends Node2D

func _ready():
	# 1. Load the pieces
	var block_scene = load("res://Scenes/code_block.tscn")
	var int_data = load("res://Resources/Tokens/Keywords/Int.tres") # Check your specific path!
	
	if block_scene and int_data:
		# 2. Create the block
		var new_block = block_scene.instantiate()
		
		# 3. Add it to the Main scene (The World)
		add_child(new_block) 
		
		# 4. Setup the block
		new_block.setup(int_data)
		
		# 5. Place it near the Wizard
		# We find the wizard node to get his position
		var wizard = $Wizard 
		new_block.global_position = wizard.global_position + Vector2(100, 0)
