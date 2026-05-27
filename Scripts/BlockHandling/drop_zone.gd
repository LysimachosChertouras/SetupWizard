extends Area2D
class_name DropZone

@export var grid_size := 32
@export var grid_color := Color(1, 1, 1, 0.3)
@export var border_color := Color.WHITE

@export var grid_visual: Sprite2D

# Drag your EnterButton.tscn here in the Inspector!
@export var row_button_scene: PackedScene

@onready var collision_shape = $CollisionShape2D
@onready var spawner: StructureSpawner = $StructureSpawner
@onready var shifter: GridShifter = $GridShifter
@onready var button_manager: EnterButtonManager = $EnterButtonManager

# Cache for the player's inventory
var _inventory_ref: OrbitingInventory = null

func _ready():
	add_to_group("drop_zones")
# Start with the grid hidden
	if grid_visual:
		grid_visual.visible = false

func _process(_delta: float) -> void:
	_update_grid_visibility()

func _update_grid_visibility() -> void:
	if not grid_visual: return
	
	# Try to find the inventory if we don't have it yet
	if not is_instance_valid(_inventory_ref):
		var inv_nodes = get_tree().get_nodes_in_group("player_inventory")
		if inv_nodes.size() > 0:
			_inventory_ref = inv_nodes[0]
	
	# Update visibility based on whether the inventory has blocks
	if is_instance_valid(_inventory_ref):
		var is_holding_item = not _inventory_ref.is_empty()
		
		# Only update if the state actually changed to save performance
		if grid_visual.visible != is_holding_item:
			grid_visual.visible = is_holding_item
	else:
		# Fallback: Hide if no inventory found
		if grid_visual.visible:
			grid_visual.visible = false


func on_item_placed(item: CodeBlock):
	if not item.token_data: return
	if spawner:
		spawner.try_spawn(item.token_data.code_string, item, grid_size, get_parent(), self)

func get_snapped_global_position(target_global_pos: Vector2, item: Area2D = null) -> Vector2:
	var local_pos = to_local(target_global_pos)
	var size = collision_shape.shape.size
	var top_left = collision_shape.position - (size / 2)
	var shifted_pos = local_pos - top_left
	
	var grid_y = floor(shifted_pos.y / grid_size) * grid_size
	var grid_x = floor(shifted_pos.x / grid_size) * grid_size
	
	# --- APPLY INDENTATION FORCE ---
	if shifter and item:
		var row_index = int(floor(shifted_pos.y / grid_size))
		if shifter.has_method("get_indent_x"):
			var indent_x = shifter.get_indent_x(row_index, item)
			if grid_x < indent_x:
				grid_x = indent_x
	
	return to_global(Vector2(grid_x, grid_y) + top_left)

# --- DELEGATED FUNCTIONS ---

func shift_rows_down(from_row_index: int, amount: int = 1, ignore_item: Area2D = null) -> bool:
	if shifter:
		return shifter.shift_rows_down(from_row_index, amount, ignore_item)
	return false

# NEW: Vertical Shift Up
func shift_rows_up(from_row_index: int, amount: int = 1, ignore_item: Area2D = null) -> bool:
	if shifter:
		return shifter.shift_rows_up(from_row_index, amount, ignore_item)
	return false

func can_accommodate_block(global_pos: Vector2, width_units: int, ignore_item: Area2D) -> bool:
	if shifter:
		return shifter.can_accommodate_block(global_pos, width_units, ignore_item)
	return true

func request_space_for_block(global_pos: Vector2, width_units: int, ignore_item: Area2D):
	if shifter:
		shifter.request_space_for_block(global_pos, width_units, ignore_item)
