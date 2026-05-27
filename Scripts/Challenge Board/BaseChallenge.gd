extends Node2D
class_name BaseChallenge

## This script belongs on the ROOT node of your level scenes.

@export_group("Level Configuration")
## Drag your Challenge resource (.tres) here.
@export var level_resource: LevelChallengeData

## CHANGED: Using the new class name LevelChallengeManager
@export var challenge_manager: Node

func _ready() -> void:
	# Wait for children to initialize
	await get_tree().process_frame
	
	if challenge_manager and level_resource:
		print("BaseChallenge: Initializing ", level_resource.title)
		challenge_manager.load_challenge(level_resource)
	else:
		if not challenge_manager:
			push_error("BaseChallenge Error: ChallengeManager node not assigned in the Inspector!")
		if not level_resource:
			push_warning("BaseChallenge Warning: No level resource (.tres) assigned!")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Optional: Add logic to return to Hub
		pass
