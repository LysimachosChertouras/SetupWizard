extends Node
# Important: Add this in Project -> Project Settings -> Autoload
# Set the Path to this file and the Name to "GlobalState"

# List your levels in the order you want them to be played
@export var level_order: Array[String] = [
	"variables_intro",
	"math_basics",
	"if_statements",
	"maze_training_1",
	"loop_mastery"
]

var completed_levels: Array[String] = []

signal progress_updated

func mark_level_complete(level_id: String):
	if not level_id in completed_levels:
		completed_levels.append(level_id)
		print("GlobalState: Level ", level_id, " completed!")
		progress_updated.emit()

## Returns true if the level is the first one, or if the previous level is complete.
func is_level_unlocked(level_id: String) -> bool:
	var index = level_order.find(level_id)
	
	# If level isn't in our list at all, assume it's a secret/unlocked level
	if index == -1: return true 
	
	# First level is always unlocked
	if index == 0: return true
	
	# Check if the level BEFORE this one is in the completed list
	var previous_level = level_order[index - 1]
	return previous_level in completed_levels
