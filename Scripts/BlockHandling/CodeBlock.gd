extends Area2D
class_name CodeBlock

# --- EXPORTS ---
@export var token_data: TokenData

## How many blocks are in this stack?
## 1 = A single block (default).
## -1 = Infinite source (spawner behavior).
## >1 = Limited stack (spawns copies until it runs out).
@export var stack_count: int = 1

# Components
@onready var background = $Background
@onready var label = $Label
@onready var collider = $CollisionShape2D

## NEW: Reference to the Label you created in the Godot Editor.
## Make sure it is named "CountLabel" and is a child of the root node.
@onready var count_label: Label = $CountLabel

# Keep track of structure blocks spawned by this block
var linked_blocks: Array[Node] = []
var highlight_overlay: ColorRect

# Standard Grid Size
const UNIT_SIZE = 32 

# STATE
var is_resource_unique: bool = false 

func _ready():
	add_to_group("pickup_items")
	
	# Create a highlight for when the block is selected in orbit
	if background:
		highlight_overlay = ColorRect.new()
		highlight_overlay.color = Color(1, 0.9, 0.4, 0.4) 
		highlight_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_child(highlight_overlay)
		highlight_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		highlight_overlay.hide()
	
	if token_data:
		setup(token_data)

func setup(data: TokenData):
	token_data = data
	if label:
		label.text = token_data.display_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", token_data.block_color)
	
	if background:
		background.modulate = Color.WHITE
		_apply_size_changes()
	
	_update_stack_label()

## UPDATED: No longer creates the label or calculates positions manually.
## It simply updates the text of your Editor-placed Label.
func _update_stack_label():
	if not count_label: return
	
	if stack_count == 1:
		count_label.hide()
	elif stack_count == -1:
		count_label.text = "∞"
		count_label.show()
	else:
		count_label.text = str(stack_count)
		count_label.show()

func _apply_size_changes():
	if not token_data: return
	var width_px = token_data.width_units * UNIT_SIZE
	if background: background.size = Vector2(width_px, UNIT_SIZE)
	if label: label.size = Vector2(width_px, UNIT_SIZE)
	if collider:
		var shape = RectangleShape2D.new()
		shape.size = Vector2(width_px, UNIT_SIZE)
		collider.shape = shape
		collider.position = Vector2(width_px / 2.0, UNIT_SIZE / 2.0)

## Creates a physical copy of this block for the player to hold
func spawn_copy() -> CodeBlock:
	# FIX: Using scene_file_path ensures we load the correct file even if renamed or moved.
	if scene_file_path == "":
		print("CodeBlock Error: scene_file_path is empty. Is this block a local scene instance?")
		return null
		
	var new_block = load(scene_file_path).instantiate()
	new_block.token_data = self.token_data
	new_block.stack_count = 1 
	return new_block

func decrement_stack():
	if stack_count > 1:
		stack_count -= 1
		_update_stack_label()
	elif stack_count == 1:
		queue_free()

func clear_linked_structure():
	for block in linked_blocks:
		if is_instance_valid(block):
			block.queue_free()
	linked_blocks.clear()

func set_highlight(active: bool):
	if highlight_overlay:
		highlight_overlay.visible = active

# --- TYPING LOGIC ---
func handle_typing_input(event: InputEventKey):
	if not token_data or not token_data.is_writable: return
	if not is_resource_unique:
		token_data = token_data.duplicate()
		is_resource_unique = true

	var text_changed = false
	if event.keycode == KEY_BACKSPACE:
		if token_data.code_string.length() > 0:
			token_data.code_string = token_data.code_string.left(-1)
			token_data.display_text = token_data.code_string
			text_changed = true
	elif event.unicode >= 32 and event.unicode <= 126:
		var char_typed = char(event.unicode)
		token_data.code_string += char_typed
		token_data.display_text += char_typed
		text_changed = true

	if text_changed:
		_check_syntax_highlighting()
		_refresh_visuals_from_typing()

func _check_syntax_highlighting():
	var current_word = token_data.code_string
	var new_color = KeywordDB.get_keyword_color(current_word)
	token_data.block_color = new_color
	label.add_theme_color_override("font_color", new_color)

func _refresh_visuals_from_typing():
	label.text = token_data.display_text
	var font = label.get_theme_font("font")
	var font_size = label.get_theme_font_size("font_size")
	var text_size = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var total_needed_width = text_size + 6 
	var new_units = ceil((total_needed_width - 1.0) / float(UNIT_SIZE))
	if new_units < 1: new_units = 1
	if new_units != token_data.width_units:
		token_data.width_units = int(new_units)
		_apply_size_changes()
