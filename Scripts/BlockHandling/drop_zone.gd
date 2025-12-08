extends Area2D
class_name DropZone

@export var grid_size := 32
@export var grid_color := Color(1, 1, 1, 0.3)
@export var border_color := Color.WHITE

# Drag your EnterButton.tscn here in the Inspector!
@export var row_button_scene: PackedScene

@onready var collision_shape = $CollisionShape2D
@onready var spawner: StructureSpawner = $StructureSpawner
@onready var shifter: GridShifter = $GridShifter

func _ready():
	add_to_group("drop_zones")
	queue_redraw()
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
		
		var sprite = btn.get_node_or_null("Sprite2D")
		if sprite and sprite.texture:
			var texture_size = sprite.texture.get_size()
			if texture_size.x > 0 and texture_size.y > 0:
				btn.scale = Vector2(grid_size, grid_size) / texture_size
		
		var collider = btn.get_node_or_null("CollisionShape2D")
		if collider:
			var shape = collider.shape
			if not shape:
				shape = RectangleShape2D.new()
				collider.shape = shape
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

# --- DELEGATED FUNCTIONS ---

func shift_rows_down(from_row_index: int, amount: int = 1) -> bool:
	if shifter:
		return shifter.shift_rows_down(from_row_index, amount)
	return false

func can_accommodate_block(global_pos: Vector2, width_units: int, ignore_item: Area2D) -> bool:
	if shifter:
		return shifter.can_accommodate_block(global_pos, width_units, ignore_item)
	return true

func request_space_for_block(global_pos: Vector2, width_units: int, ignore_item: Area2D):
	if shifter:
		shifter.request_space_for_block(global_pos, width_units, ignore_item)
