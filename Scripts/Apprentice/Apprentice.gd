extends CharacterBody2D
class_name Apprentice

@onready var sprite = $Sprite2D
const TILE_SIZE = 32

## Signal sent back to the Interpreter when an action finishes
signal action_finished

## Initializes the apprentice position and syncs GlobalState
func setup(start_global_pos: Vector2, _extra_data = null):
	global_position = start_global_pos
	if "apprentice_pos" in GlobalState:
		GlobalState.apprentice_pos = global_position

func move_tile(direction: Vector2):
	# Reverted: Direct movement without collision checks or raycasts
	await _play_move_animation(direction)
	
	# Finish the action so the code continues to the next line
	action_finished.emit()

func _play_move_animation(direction: Vector2):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var target_pos = global_position + (direction * TILE_SIZE)
	tween.tween_property(self, "global_position", target_pos, 0.2)
	
	# Update GlobalState so the Memory Inspector stays accurate
	if "apprentice_pos" in GlobalState:
		GlobalState.apprentice_pos = target_pos
	
	await tween.finished
