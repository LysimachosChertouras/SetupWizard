extends Node2D

@onready var pickup_area: Area2D = $"../PickupArea"

var nearby_items: Array[Area2D] = []
var player: Node2D = null

# --- CHILD COMPONENTS ---
var inventory: OrbitingInventory
# Type hint restored
var placement_controller: PlacementController

# --- STATE ---
var typing_focus_active: bool = false

func _ready() -> void:
	inventory = OrbitingInventory.new()
	add_child(inventory)
	
	placement_controller = PlacementController.new()
	add_child(placement_controller)

func init(p: Node2D) -> void:
	player = p
	inventory.init(p)
	placement_controller.init(p, inventory)
	
	pickup_area.area_entered.connect(_on_area_entered)
	pickup_area.area_exited.connect(_on_area_exited)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			inventory.cycle_items(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			inventory.cycle_items(-1)
	
	if event is InputEventKey and event.pressed:
		var active_item = inventory.get_last_item()
		
		if active_item and active_item is CodeBlock and active_item.token_data and active_item.token_data.is_writable:
			if event.keycode == KEY_ENTER:
				typing_focus_active = false
				inventory.set_paused(false)
				get_viewport().set_input_as_handled()
				return
			
			if typing_focus_active:
				active_item.handle_typing_input(event)
				get_viewport().set_input_as_handled()

func process_input() -> void:
	if Input.is_action_just_pressed("Primary Action"):
		var did_pickup = try_pick_up_nearby_item()
		
		if not did_pickup:
			placement_controller.try_drop_current_item()
			typing_focus_active = false 
			inventory.set_paused(false)

func is_player_typing() -> bool:
	return typing_focus_active

# --- PICKUP LOGIC ---
func try_pick_up_nearby_item() -> bool:
	if nearby_items.is_empty(): return false
	
	var mouse_pos = get_global_mouse_position()
	
	var target_item = PhysicsUtils.get_item_under_point(
		get_world_2d(), 
		mouse_pos, 
		nearby_items
	)
			
	if target_item:
		# --- SPAWNER LOGIC ---
		var item_to_pickup = target_item
		var is_spawner = target_item.has_method("spawn_copy")
		
		if is_spawner:
			# Create a clone to put in inventory
			item_to_pickup = target_item.spawn_copy()
			# Must add to scene before adding to inventory so _ready runs
			player.get_parent().add_child(item_to_pickup)
		
		if inventory.add_item(item_to_pickup):
			# If we picked up a blank block, start typing
			if item_to_pickup is CodeBlock:
				item_to_pickup.clear_linked_structure()
				if item_to_pickup.token_data and item_to_pickup.token_data.is_writable:
					typing_focus_active = true
					inventory.set_paused(true)
			
			# If it was a normal item, remove it from the ground
			# If it was a spawner, leave the original there!
			if not is_spawner:
				nearby_items.erase(target_item)
				if target_item.has_node("CollisionShape2D"):
					target_item.get_node("CollisionShape2D").set_deferred("disabled", true)
			
			return true
		else:
			# Inventory Full: If we made a clone, delete it so it doesn't clutter the world
			if is_spawner:
				item_to_pickup.queue_free()
			
	return false

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("pickup_items"):
		nearby_items.append(area)

func _on_area_exited(area: Area2D) -> void:
	if area in nearby_items:
		nearby_items.erase(area)
