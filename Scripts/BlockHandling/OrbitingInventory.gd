extends Node
class_name OrbitingInventory

@export var orbit_radius := 100.0
@export var orbit_speed := 2.0
@export var max_items := 5

var held_items: Array[Area2D] = []
var orbit_angle := 0.0
var player: Node2D = null

#Track which item is selected without moving them
var selected_index: int = 0

#Pause state for the orbit
var is_paused: bool = false

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
	# Automatically select the new item you just picked up
	selected_index = held_items.size() - 1
	orbit_angle = 0.0 
	return true

func remove_item(item: Area2D) -> void:
	var index = held_items.find(item)
	if index != -1:
		held_items.remove_at(index)
		
		# Reset visuals when removing
		item.modulate = Color.WHITE
		item.scale = Vector2.ONE
		
		# Also try to turn off custom highlight if it exists
		if item.has_method("set_highlight"):
			item.set_highlight(false)
		
		# Adjust selected_index if we removed an item before it
		if index < selected_index:
			selected_index -= 1
		
		# Clamp index to be safe (if we removed the last item)
		if selected_index >= held_items.size():
			selected_index = max(0, held_items.size() - 1)

# Renamed behavior: Returns the SELECTED item, not necessarily the last one
func get_last_item() -> Area2D:
	if held_items.is_empty():
		return null
	# Safety check
	if selected_index < 0 or selected_index >= held_items.size():
		selected_index = 0
	return held_items[selected_index]

func is_empty() -> bool:
	return held_items.is_empty()

func has_item(item: Area2D) -> bool:
	return item in held_items

func cycle_items(direction: int) -> void:
	if held_items.size() < 2: return
	
	# Just move the pointer, don't move the items!
	selected_index += direction
	
	# Wrap around
	if selected_index >= held_items.size():
		selected_index = 0
	elif selected_index < 0:
		selected_index = held_items.size() - 1

func _update_orbit(delta: float) -> void:
	# Clean up invalid items
	for i in range(held_items.size() - 1, -1, -1):
		if not is_instance_valid(held_items[i]):
			held_items.remove_at(i)
			if selected_index >= held_items.size():
				selected_index = max(0, held_items.size() - 1)

	if held_items.is_empty() or not player:
		return
		
	#Only update angle if not paused
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
			var offset = Vector2(cos(total_angle) * a, sin(total_angle) * b)
			item.global_position = player.global_position + offset
			
			# --- UPDATED: HIGHLIGHT LOGIC ---
			# We use 'modulate' (Brightness) which works on every object type immediately
			# 1.2 is 20% brighter than normal
			if i == selected_index:
				item.modulate = Color(1.2, 1.2, 1.2)
				# Add a tiny scale pop that isn't large enough to blur text
				
				
				# Optional: Still call the custom method if you fixed the CodeBlock script
				if item.has_method("set_highlight"):
					item.set_highlight(true)
			else:
				item.modulate = Color.WHITE
				item.scale = Vector2.ONE
				
				if item.has_method("set_highlight"):
					item.set_highlight(false)
