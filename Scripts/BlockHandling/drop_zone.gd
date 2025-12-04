extends Area2D
class_name DropZone

@export var grid_size := 32
@export var grid_color := Color(1, 1, 1, 0.3)
@export var border_color := Color.WHITE

# Drag your EnterButton.tscn here in the Inspector!
@export var row_button_scene: PackedScene

@onready var collision_shape = $CollisionShape2D
@onready var spawner: StructureSpawner = $StructureSpawner

func _ready():
	add_to_group("drop_zones")
	queue_redraw()
	# Generate the buttons automatically
	call_deferred("_spawn_row_buttons")

func _spawn_row_buttons():
	if not row_button_scene or not collision_shape: return
	
	var size = collision_shape.shape.size
	var top_left = collision_shape.position - (size / 2)
	var rows_count = int(size.y / grid_size)
	
	for i in range(rows_count):
		var btn = row_button_scene.instantiate()
		add_child(btn)
		
		var btn_pos = top_left + Vector2(-grid_size, i * grid_size) + Vector2(grid_size/2.0, grid_size/2.0)
		
		btn.position = btn_pos
		btn.setup(self, i)
		
		# --- VISUAL SCALING (Sprite Only) ---
		var sprite = btn.get_node_or_null("Sprite2D")
		if sprite and sprite.texture:
			var texture_size = sprite.texture.get_size()
			if texture_size.x > 0 and texture_size.y > 0:
				# Only scale the sprite, not the whole object
				sprite.scale = Vector2(grid_size, grid_size) / texture_size

		# --- COLLISION SIZING (Force exact size) ---
		var collider = btn.get_node_or_null("CollisionShape2D")
		if collider:
			var shape = collider.shape
			# If no shape exists, create one
			if not shape:
				shape = RectangleShape2D.new()
				collider.shape = shape
			
			# Force it to match the grid cell exactly
			if shape is RectangleShape2D:
				shape.size = Vector2(grid_size, grid_size)

func _draw():
	if not collision_shape or not collision_shape.shape: return
	var size = collision_shape.shape.size
	var top_left = collision_shape.position - (size / 2)
	var rect = Rect2(top_left, size)

	draw_rect(rect, border_color, false, 2.0)
	for x in range(0, int(size.x), grid_size):
		draw_line(top_left + Vector2(x, 0), top_left + Vector2(x, size.y), grid_color)
	for y in range(0, int(size.y), grid_size):
		draw_line(top_left + Vector2(0, y), top_left + Vector2(size.x, y), grid_color)

func on_item_placed(item: CodeBlock):
	if not item.token_data: return
	if spawner:
		spawner.try_spawn(item.token_data.code_string, item, grid_size, get_parent(), self)

func get_snapped_global_position(target_global_pos: Vector2) -> Vector2:
	var local_pos = to_local(target_global_pos)
	var size = collision_shape.shape.size
	var top_left = collision_shape.position - (size / 2)
	var shifted_pos = local_pos - top_left
	var grid_x = floor(shifted_pos.x / grid_size) * grid_size
	var grid_y = floor(shifted_pos.y / grid_size) * grid_size
	return to_global(Vector2(grid_x, grid_y) + top_left)

# --- VERTICAL SHIFT LOGIC (Enter Button) ---
func shift_rows_down(from_row_index: int) -> bool:
	var size = collision_shape.shape.size
	var top_left = collision_shape.position - (size / 2)
	var max_rows = int(size.y / grid_size)
	
	var blocks_to_shift = []
	var all_blocks = get_tree().get_nodes_in_group("pickup_items")
	
	for block in all_blocks:
		if not block is CodeBlock: continue
		
		if block.has_node("CollisionShape2D"):
			if block.get_node("CollisionShape2D").disabled:
				continue
		
		var block_local = to_local(block.global_position) - top_left
		var row = floor(block_local.y / grid_size)
		var col = floor(block_local.x / grid_size)
		
		if col >= 0 and col < int(size.x / grid_size) and row >= 0 and row < max_rows:
			if row >= from_row_index:
				blocks_to_shift.append({"node": block, "row": row})

	if blocks_to_shift.is_empty():
		return true

	for b in blocks_to_shift:
		if b.row >= max_rows - 1:
			print("Cannot shift rows: Block would fall out of bounds.")
			return false

	for b in blocks_to_shift:
		var block = b.node
		var tween = create_tween()
		tween.tween_property(block, "global_position", block.global_position + Vector2(0, grid_size), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	return true

# --- HORIZONTAL SHIFT LOGIC (Insert Mode) ---
func can_accommodate_block(global_pos: Vector2, width_units: int, ignore_item: Area2D) -> bool:
	# 1. Check Main Block
	if not _check_rect_fit(global_pos, width_units, ignore_item):
		return false
		
	# 2. Check Structure Parts (if any)
	if spawner and ignore_item is CodeBlock and ignore_item.token_data:
		var code = ignore_item.token_data.code_string
		if code in spawner.structures:
			var blueprint = spawner.structures[code]
			for part in blueprint:
				var offset = Vector2(part["x"] * grid_size, part["y"] * grid_size)
				var part_pos = global_pos + offset
				# Assume structure parts (brackets) are 1 unit wide
				if not _check_rect_fit(part_pos, 1, ignore_item):
					return false
					
	return true

func request_space_for_block(global_pos: Vector2, width_units: int, ignore_item: Area2D):
	# 1. Shift for Main Block
	_shift_blocks_at(global_pos, width_units, ignore_item)
	
	# 2. Shift for Structure Parts
	if spawner and ignore_item is CodeBlock and ignore_item.token_data:
		var code = ignore_item.token_data.code_string
		if code in spawner.structures:
			var blueprint = spawner.structures[code]
			for part in blueprint:
				var offset = Vector2(part["x"] * grid_size, part["y"] * grid_size)
				var part_pos = global_pos + offset
				# Assume structure parts are 1 unit wide
				_shift_blocks_at(part_pos, 1, ignore_item)

# --- INTERNAL HELPERS ---

func _check_rect_fit(global_pos: Vector2, width_units: int, ignore_item: Area2D) -> bool:
	var local_pos = to_local(global_pos)
	var size = collision_shape.shape.size
	var top_left = collision_shape.position - (size / 2)
	var shifted_pos = local_pos - top_left
	
	var max_x_width = size.x
	var drop_row_y = floor(shifted_pos.y / grid_size) * grid_size
	var drop_start_x = floor(shifted_pos.x / grid_size) * grid_size
	var drop_end_x = drop_start_x + (width_units * grid_size)
	
	if drop_end_x > max_x_width:
		return false

	var blocks_to_shift = _get_blocks_in_way(drop_row_y, drop_start_x, ignore_item)

	if blocks_to_shift.is_empty():
		return true

	var closest_block_x = 99999.0
	for b in blocks_to_shift:
		if b.x < closest_block_x:
			closest_block_x = b.x
			
	var overlap = drop_end_x - closest_block_x
	
	if overlap > 0:
		var shift_units = ceil(overlap / grid_size)
		var shift_pixels = shift_units * grid_size
		
		for b in blocks_to_shift:
			var new_end_x = b.end_x + shift_pixels
			if new_end_x > max_x_width:
				return false 

	return true

func _shift_blocks_at(global_pos: Vector2, width_units: int, ignore_item: Area2D):
	var local_pos = to_local(global_pos)
	var size = collision_shape.shape.size
	var top_left = collision_shape.position - (size / 2)
	var shifted_pos = local_pos - top_left
	
	var drop_row_y = floor(shifted_pos.y / grid_size) * grid_size
	var drop_start_x = floor(shifted_pos.x / grid_size) * grid_size
	var drop_end_x = drop_start_x + (width_units * grid_size)
	
	var blocks_to_move = _get_blocks_in_way(drop_row_y, drop_start_x, ignore_item)

	if blocks_to_move.is_empty(): return

	var closest_block_x = 99999.0
	for b in blocks_to_move:
		if b.x < closest_block_x:
			closest_block_x = b.x
			
	var overlap = drop_end_x - closest_block_x
	
	if overlap > 0:
		var shift_units = ceil(overlap / grid_size)
		var shift_pixels = shift_units * grid_size
		
		for b in blocks_to_move:
			var block = b.node
			var tween = create_tween()
			tween.tween_property(block, "global_position", block.global_position + Vector2(shift_pixels, 0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _get_blocks_in_way(row_y: float, start_x: float, ignore_item: Area2D) -> Array:
	var blocks_in_way = []
	var all_blocks = get_tree().get_nodes_in_group("pickup_items")
	var top_left = collision_shape.position - (collision_shape.shape.size / 2)
	
	for block in all_blocks:
		if block == ignore_item: continue
		if not block is CodeBlock: continue
		
		var block_local = to_local(block.global_position) - top_left
		var block_y = floor(block_local.y / grid_size) * grid_size
		var block_x = floor(block_local.x / grid_size) * grid_size
		
		if is_equal_approx(block_y, row_y) and block_x >= start_x:
			var block_w = 1
			if block.token_data: block_w = block.token_data.width_units
			blocks_in_way.append({
				"node": block,
				"x": block_x,
				"end_x": block_x + (block_w * grid_size)
			})
	return blocks_in_way
