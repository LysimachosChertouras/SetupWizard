extends Resource
class_name LevelChallengeData

enum ChallengeType { MATH, MAZE }

@export_group("General")
@export var title: String = "New Challenge"
@export var type: ChallengeType = ChallengeType.MATH
@export_multiline var description: String = "Welcome, Apprentice..."

@export_group("Math Requirements")
@export_multiline var requirements_text: String = ""

@export_group("Inventory")
@export_multiline var allowed_blocks_text: String = ""

@export_group("Maze Settings")
@export var start_pos: Vector2i = Vector2i(0, 0)
@export var end_pos: Vector2i = Vector2i(5, 5)

func get_parsed_requirements() -> Dictionary:
	var reqs = {}
	var lines = requirements_text.split("\n", false)
	for line in lines:
		if ":" in line:
			var parts = line.split(":", false, 1)
			var var_name = parts[0].strip_edges()
			var var_val = parts[1].strip_edges()
			if var_name != "":
				reqs[var_name] = var_val
	return reqs

func get_parsed_blocks() -> Array[String]:
	var blocks: Array[String] = []
	var items = allowed_blocks_text.split(",", false)
	for item in items:
		var clean_item = item.strip_edges()
		if clean_item != "":
			blocks.append(clean_item)
	return blocks
