extends Node
class_name OrbitingInventory

@export var orbit_radius := 100.0
@export var orbit_speed := 2.0
@export var max_items := 5

var held_items: Array[Area2D] = []
var orbit_angle := 0.0
var player: Node2D = null

# Track which item is selected without moving them
var selected_index: int = 0
# Pause state
var is_paused: bool = false

const GRID_SIZE = 32

func _process(delta: float) -> void:
	_update_orbit(delta)

func init(p: Node2D) -> void:
	player = p

func set_paused(state: bool) -> void:
	is_paused = state

func add_item(item: Area2D) -> bool:
	if held_items.size() >= max_items:
		return false
		
	held_items.append(item)
	selected_index = held_items.size() - 1
	orbit_angle = 0.0 
	return true

func remove_item(item: Area2D) -> void:
	var index = held_items.find(item)
	if index != -1:
		held_items.remove_at(index)
		
		item.modulate = Color.WHITE
		item.scale = Vector2.ONE
		
		if item.has_method("set_highlight"):
			item.set_highlight(false)
		
		if index < selected_index:
			selected_index -= 1
		
		if selected_index >= held_items.size():
			selected_index = max(0, held_items.size() - 1)

func get_last_item() -> Area2D:
	if held_items.is_empty():
		return null
	if selected_index < 0 or selected_index >= held_items.size():
		selected_index = 0
	return held_items[selected_index]

func is_empty() -> bool:
	return held_items.is_empty()

func has_item(item: Area2D) -> bool:
	return item in held_items

func cycle_items(direction: int) -> void:
	if held_items.size() < 2: return
	
	selected_index += direction
	
	if selected_index >= held_items.size():
		selected_index = 0
	elif selected_index < 0:
		selected_index = held_items.size() - 1

func _update_orbit(delta: float) -> void:
	for i in range(held_items.size() - 1, -1, -1):
		if not is_instance_valid(held_items[i]):
			held_items.remove_at(i)
			if selected_index >= held_items.size():
				selected_index = max(0, held_items.size() - 1)

	if held_items.is_empty() or not player:
		return
	
	if not is_paused:
		orbit_angle += orbit_speed * delta
		
	var a = 70
	var b = 70
		
	var num_items = held_items.size()
	for i in range(num_items):
		if is_instance_valid(held_items[i]):
			var item = held_items[i]
			
			var angle_offset = (2 * PI / max_items) * i
			var total_angle = orbit_angle + angle_offset
			var orbit_pos = Vector2(cos(total_angle) * a, sin(total_angle) * b)
			
			# We calculate the visual center of the item to ensure 
			# it orbits with the center of the block
			var center_offset = Vector2(GRID_SIZE / 2.0, GRID_SIZE / 2.0)
			
			if item is CodeBlock and item.token_data:
				var w = item.token_data.width_units * GRID_SIZE
				center_offset = Vector2(w / 2.0, GRID_SIZE / 2.0)
			
			# Apply offset so the center of the block is on the orbit path
			item.global_position = player.global_position + orbit_pos - center_offset
			
			if i == selected_index:
				item.modulate = Color(1.2, 1.2, 1.2)
				item.scale = Vector2(1.1, 1.1)
				if item.has_method("set_highlight"):
					item.set_highlight(true)
			else:
				item.modulate = Color.WHITE
				item.scale = Vector2.ONE
				if item.has_method("set_highlight"):
					item.set_highlight(false)
