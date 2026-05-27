extends Area2D
class_name LevelPortal

@export_group("Configuration")
## The ID must match one of the names in GlobalState's 'level_order' list.
@export var level_id: String = "level_1_math"

## Using @export_file gives us a file picker in the Inspector without pre-loading the scene into RAM.
## Default set to empty to prevent unintended teleportation from unconfigured portals.
@export_file("*.tscn") var target_scene_path: String = ""

@export_group("Visuals")
@export var locked_color: Color = Color(0.2, 0.2, 0.2, 0.8)
@export var unlocked_color: Color = Color.WHITE

@onready var label = $Label # Assuming you have a Label child for the level name

# Internal state to track if the wizard is standing in the portal
var _is_player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Update visual state immediately
	_update_visuals()
	
	# Listen for any progress changes while the player is in the Hub
	if GlobalState.has_signal("progress_updated"):
		GlobalState.progress_updated.connect(_update_visuals)

func _unhandled_input(event: InputEvent) -> void:
	# Check for Space bar press only if the player is actually standing in the portal
	if _is_player_in_range and (event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE)):
		if GlobalState.is_level_unlocked(level_id):
			_teleport()
		else:
			# Optional: Play a "locked" sound effect here
			print("Portal: Level is currently locked!")

func _update_visuals():
	var unlocked = GlobalState.is_level_unlocked(level_id)
	
	modulate = unlocked_color if unlocked else locked_color
	
	if label:
		var base_name = level_id.replace("_", " ").capitalize()
		if not unlocked:
			label.text = "??? (Locked)"
		else:
			# Visual prompt removed as requested
			label.text = base_name

func _on_body_entered(body: Node2D):
	if body.is_in_group("player") or body is CharacterBody2D:
		_is_player_in_range = true
		_update_visuals()

func _on_body_exited(body: Node2D):
	if body.is_in_group("player") or body is CharacterBody2D:
		_is_player_in_range = false
		_update_visuals()

func _teleport():
	if target_scene_path == "" or target_scene_path == null:
		print("Portal Error: No target scene path set for ", level_id)
		return
		
	# Change the entire game world to the new level
	get_tree().change_scene_to_file(target_scene_path)
