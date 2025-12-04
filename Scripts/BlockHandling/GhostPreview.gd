extends Node2D
class_name GhostPreview

var ghost_bg: NinePatchRect
var ghost_label: Label
const DEFAULT_GRID_SIZE = 32

func _ready() -> void:
	# 1. Create the Background (The Box)
	ghost_bg = NinePatchRect.new()
	ghost_bg.modulate = Color(1, 1, 1, 0.5) # 50% Transparent
	ghost_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't block clicks
	
	# 2. Create the Label (The Text)
	ghost_label = Label.new()
	ghost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Build the hierarchy
	ghost_bg.add_child(ghost_label)
	add_child(ghost_bg)
	
	# Make independent of player movement
	ghost_bg.set_as_top_level(true)
	ghost_bg.hide()

func update_preview(snapped_pos: Vector2, item: Area2D):
	# 1. Update Position
	ghost_bg.global_position = snapped_pos
	
	# 2. Update Visuals based on the block we are holding
	if item is CodeBlock:
		# Copy the texture from the block's background node
		var item_bg = item.get_node_or_null("Background")
		if item_bg:
			ghost_bg.texture = item_bg.texture
			ghost_bg.patch_margin_left = item_bg.patch_margin_left
			ghost_bg.patch_margin_right = item_bg.patch_margin_right
			ghost_bg.patch_margin_top = item_bg.patch_margin_top
			ghost_bg.patch_margin_bottom = item_bg.patch_margin_bottom
		
		# Copy the text and data
		if item.token_data:
			# Size
			var width = item.token_data.width_units * DEFAULT_GRID_SIZE
			ghost_bg.size = Vector2(width, DEFAULT_GRID_SIZE)
			ghost_label.size = Vector2(width, DEFAULT_GRID_SIZE)
			
			# Text
			ghost_label.text = item.token_data.display_text
			ghost_label.add_theme_color_override("font_color", item.token_data.block_color)
	
	ghost_bg.show()

func hide_preview():
	if ghost_bg:
		ghost_bg.hide()
