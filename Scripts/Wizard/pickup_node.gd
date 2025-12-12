extends Node2D

# Assign Symbol_Semicolon.tres here in the Inspector!
@export var quick_place_token: TokenData

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
	# 1. Scroll Wheel (Cycling Inventory)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			inventory.cycle_items(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			inventory.cycle_items(-1)
		
		# Middle Click to Place Semicolon
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if quick_place_token and placement_controller:
				placement_controller.quick_place_token(quick_place_token)
	
	# 2. Keyboard Logic
	if event is InputEventKey and event.pressed:
		var active_item = inventory.get_last_item()
		
		# Delete Key
		if event.keycode == KEY_DELETE and active_item:
			if typing_focus_active:
				typing_focus_active = false
				inventory.set_paused(false)
			
			if active_item is CodeBlock:
				active_item.clear_linked_structure()
			
			inventory.remove_item(active_item)
			active_item.queue_free()
			
			get_viewport().set_input_as_handled()
			return
		
		# Typing Logic
		if active_item and active_item is CodeBlock and active_item.token_data and active_item.token_data.is_writable:
			
			# ENTER KEY - Toggle Typing
			if event.keycode == KEY_ENTER:
				typing_focus_active = !typing_focus_active 
				inventory.set_paused(typing_focus_active) 
				get_viewport().set_input_as_handled()
				return
			
			if typing_focus_active:
				active_item.handle_typing_input(event)
				get_viewport().set_input_as_handled()

func process_input() -> void:
	# 1. PRIMARY ACTION (Pickup Normal / Drop fail / Type if new)
	if Input.is_action_just_pressed("Primary Action"):
		# Try pickup with Primary Logic (False = Primary)
		var did_pickup = try_pick_up_nearby_item(false)
		
		if not did_pickup:
			# If we didn't pick anything up, try dropping
			placement_controller.try_drop_current_item()
			typing_focus_active = false 
			inventory.set_paused(false)

	# 2. SECONDARY ACTION (Edit Existing)
	if Input.is_action_just_pressed("Secondary Action"):
		# Drop logic REMOVED. Secondary action is now strictly for Edit-Pickup.
		try_pick_up_nearby_item(true)

func is_player_typing() -> bool:
	return typing_focus_active

# --- PICKUP LOGIC ---
func try_pick_up_nearby_item(is_secondary_action: bool) -> bool:
	if nearby_items.is_empty(): return false
	
	var mouse_pos = get_global_mouse_position()
	
	var target_item = PhysicsUtils.get_item_under_point(
		get_world_2d(), 
		mouse_pos, 
		nearby_items
	)
			
	if target_item:
		# Check Context: Is it inside a grid?
		var in_grid = get_drop_zone_at_position(target_item.global_position) != null
		var is_spawner = target_item.has_method("spawn_copy")
		
		# --- LOGIC MATRIX ---
		var should_type = false
		
		if is_secondary_action:
			# SECONDARY: Only allowed Inside Grid + Writable
			if not in_grid: return false
			
			# Check if writable (needs to check the node or the token data)
			var writable = false
			if target_item is CodeBlock and target_item.token_data and target_item.token_data.is_writable:
				writable = true
			
			if not writable: return false
			
			should_type = true
			
		else:
			# PRIMARY:
			if in_grid:
				# Inside grid -> Pick up but DO NOT enter write mode
				should_type = false
			else:
				# Outside grid (Spawner or loose block) -> Enter write mode if writable
				should_type = true

		# --- EXECUTE PICKUP ---
		var item_to_pickup = target_item
		
		if is_spawner:
			# Primary only for spawners (Secondary check 'not in_grid' handles excluding them above)
			item_to_pickup = target_item.spawn_copy()
			player.get_parent().add_child(item_to_pickup)
		
		if inventory.add_item(item_to_pickup):
			if item_to_pickup is CodeBlock:
				item_to_pickup.clear_linked_structure()
				
				# Apply the logic calculated above
				if should_type and item_to_pickup.token_data and item_to_pickup.token_data.is_writable:
					typing_focus_active = true
					inventory.set_paused(true)
			
			if not is_spawner:
				nearby_items.erase(target_item)
				if target_item.has_node("CollisionShape2D"):
					target_item.get_node("CollisionShape2D").set_deferred("disabled", true)
			
			return true
		else:
			if is_spawner:
				item_to_pickup.queue_free()
			
	return false

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("pickup_items"):
		nearby_items.append(area)

func _on_area_exited(area: Area2D) -> void:
	if area in nearby_items:
		nearby_items.erase(area)

func get_drop_zone_at_position(point: Vector2) -> DropZone:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_point(query)
	for result in results:
		if result.collider is DropZone:
			return result.collider
	return null
