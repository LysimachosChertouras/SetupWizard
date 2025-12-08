extends Area2D
class_name CodeBlock

# EXPORT THIS so you can set it in the Inspector!
@export var token_data: TokenData

# Components
@onready var background = $Background
@onready var label = $Label
@onready var collider = $CollisionShape2D
@onready var snap_point = $SnapPoint

# Keep track of structure blocks spawned by this block
var linked_blocks: Array[Node] = []
var highlight_overlay: ColorRect

# Standard Grid Size
const UNIT_SIZE = 32 

# STATE
var is_resource_unique: bool = false # Tracks if we have duplicated the data yet

func _ready():
	add_to_group("pickup_items")
	
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
		label.add_theme_color_override("font_color", token_data.block_color)
		
		# Force Center Alignment
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if background:
		background.modulate = Color.WHITE
		_apply_size_changes()

func _apply_size_changes():
	if not token_data: return
	var width_px = token_data.width_units * UNIT_SIZE
	
	if background:
		background.size = Vector2(width_px, UNIT_SIZE)
	if label:
		label.size = Vector2(width_px, UNIT_SIZE)
	if collider:
		var shape = RectangleShape2D.new()
		shape.size = Vector2(width_px, UNIT_SIZE)
		collider.shape = shape
		collider.position = Vector2(width_px / 2.0, UNIT_SIZE / 2.0)
	if snap_point:
		snap_point.position.x = width_px

func get_snap_global_position() -> Vector2:
	if snap_point:
		return snap_point.global_position
	return global_position + Vector2(32, 0)

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

	# 1. SAFETY: Duplicate resource on first edit
	if not is_resource_unique:
		token_data = token_data.duplicate()
		is_resource_unique = true

	var text_changed = false

	# 2. Backspace
	if event.keycode == KEY_BACKSPACE:
		if token_data.code_string.length() > 0:
			token_data.code_string = token_data.code_string.left(-1)
			token_data.display_text = token_data.code_string
			text_changed = true
	
	# 3. Typing
	elif event.unicode >= 32 and event.unicode <= 126:
		var char_typed = char(event.unicode)
		token_data.code_string += char_typed
		token_data.display_text += char_typed
		text_changed = true

	# 4. Updates
	if text_changed:
		_check_syntax_highlighting()
		_refresh_visuals_from_typing()

func _check_syntax_highlighting():
	var current_word = token_data.code_string
	var db = get_node_or_null("/root/KeywordDB")
	
	if db:
		var new_color = db.get_keyword_color(current_word)
		token_data.block_color = new_color
		label.add_theme_color_override("font_color", new_color)

func _refresh_visuals_from_typing():
	label.text = token_data.display_text
	
	# Elastic Width Logic
	var font = label.get_theme_font("font")
	var font_size = label.get_theme_font_size("font_size")
	var text_size = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var total_needed_width = text_size + 6 
	
	var new_units = ceil((total_needed_width - 1.0) / float(UNIT_SIZE))
	if new_units < 1: new_units = 1
	
	if new_units != token_data.width_units:
		token_data.width_units = int(new_units)
		_apply_size_changes()
