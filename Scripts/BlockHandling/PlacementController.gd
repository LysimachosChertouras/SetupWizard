extends Node2D
class_name PlacementController

@export var orbit_place_radius := 100
const DEFAULT_GRID_SIZE = 32
# UPDATED: Correct filename
const BLOCK_SCENE = preload("res://Scenes/code_block.tscn")

var player: Node2D
var inventory: OrbitingInventory
var ghost_preview: GhostPreview

func _ready() -> void:
	ghost_preview = GhostPreview.new()
	add_child(ghost_preview)

func _process(_delta: float) -> void:
	_update_ghost_preview()

func init(p: Node2D, inv: OrbitingInventory) -> void:
	player = p
	inventory = inv

func try_drop_current_item() -> void:
	if not inventory or inventory.is_empty(): return
	var item = inventory.get_last_item()
	_drop_item(item)

# --- INSTANT PLACE LOGIC ---
func quick_place_token(token_data: TokenData) -> void:
	if not token_data: return
	
	var drop_data = _get_current_drop_target()
	if not drop_data.is_valid:
		return 
		
	var new_block = BLOCK_SCENE.instantiate()
	new_block.setup(token_data) 
	
	# Re-calculate snap using this specific new block
	var zone = drop_data.zone
	var precise_pos = zone.get_snapped_global_position(drop_data.raw_pos, new_block)
	
	if is_location_occupied(precise_pos, new_block):
		print("Cannot quick place: Spot Occupied")
		new_block.queue_free()
		return
		
	zone.get_parent().add_child(new_block)
	new_block.global_position = precise_pos
	
	zone.on_item_placed(new_block)

# --- INTERNAL LOGIC ---
func _update_ghost_preview() -> void:
	if not inventory or inventory.is_empty():
		ghost_preview.hide_preview()
		return

	var item = inventory.get_last_item()
	if not is_instance_valid(item):
		ghost_preview.hide_preview()
		return

	var drop_data = _get_current_drop_target()
	
	if drop_data.is_valid:
		var zone = drop_data.zone
		var snapped_pos = drop_data.snapped_pos
		
		# Get width units from the item
		var width_units = 1
		if item is CodeBlock and item.token_data:
			width_units = item.token_data.width_units
			
		# FIX: Use the Zone's smart logic instead of the dumb 'is_occupied' check
		if zone.has_method("can_accommodate_block"):
			if zone.can_accommodate_block(snapped_pos, width_units, item):
				ghost_preview.update_preview(snapped_pos, item)
			else:
				# Show red or hide if it really doesn't fit (e.g. out of bounds)
				ghost_preview.hide_preview()
		else:
			# Fallback if zone doesn't support shifting logic
			if is_location_occupied(snapped_pos, item):
				ghost_preview.hide_preview()
			else:
				ghost_preview.update_preview(snapped_pos, item)
	else:
		ghost_preview.hide_preview()

func _drop_item(item: Area2D) -> void:
	if not is_instance_valid(item) or not inventory.has_item(item): return
	
	var drop_data = _get_current_drop_target()
	
	if drop_data.is_valid:
		var snapped_pos = drop_data.snapped_pos
		var zone = drop_data.zone
		
		var width_units = 1
		if item is CodeBlock and item.token_data:
			width_units = item.token_data.width_units
			
		# SAFETY: Force disable collision before asking the zone to calculate shifts.
		# This ensures the GridShifter doesn't see THIS block as an obstacle to itself.
		if item.has_node("CollisionShape2D"):
			item.get_node("CollisionShape2D").set_deferred("disabled", true)
			# We also force it immediately for logic checks in this frame
			item.get_node("CollisionShape2D").disabled = true
			
		if zone.has_method("can_accommodate_block"):
			if not zone.can_accommodate_block(snapped_pos, width_units, item):
				print("Cannot drop: Shift would push blocks out of bounds!")
				# Re-enable collision if drop failed
				if item.has_node("CollisionShape2D"):
					item.get_node("CollisionShape2D").set_deferred("disabled", false)
				return

		if zone.has_method("request_space_for_block"):
			zone.request_space_for_block(snapped_pos, width_units, item)
		
		item.global_position = snapped_pos
		
		# Re-enable collision after the logic is done
		if item.has_node("CollisionShape2D"):
			item.get_node("CollisionShape2D").set_deferred("disabled", false)
		
		inventory.remove_item(item)
		item.rotation = 0
		
		if item is CodeBlock:
			zone.on_item_placed(item)
	else:
		print("Invalid Drop: Must be inside a Drop Zone!")

func _get_current_drop_target() -> Dictionary:
	if not player: return { "is_valid": false }
	
	var mouse_pos = get_global_mouse_position()
	var target_pos: Vector2
	var distance = player.global_position.distance_to(mouse_pos)
	
	if distance <= orbit_place_radius:
		target_pos = mouse_pos
	else:
		var dir = (mouse_pos - player.global_position).normalized()
		target_pos = player.global_position + dir * orbit_place_radius
	
	# Switched to local helper function to resolve parser error
	var zone = _get_drop_zone_at_point(target_pos)
	
	if zone:
		# UPDATED: Pass the held item to get indent-aware snap
		var held_item = null
		if inventory and not inventory.is_empty():
			held_item = inventory.get_last_item()
			
		var calculated_snap_pos = zone.get_snapped_global_position(target_pos, held_item)
		
		return {
			"is_valid": true,
			"zone": zone,
			"snapped_pos": calculated_snap_pos,
			"raw_pos": target_pos # Saved for quick_place logic
		}
	
	return { "is_valid": false }

func is_location_occupied(pos: Vector2, item: Area2D) -> bool:
	var width_units = 1
	if item is CodeBlock and item.token_data:
		width_units = item.token_data.width_units
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	# FIX: Explicitly exclude all items in the inventory from the check
	# This prevents orbiting items from blocking the placement raycast
	var exclusions = []
	if inventory and not inventory.is_empty():
		for held in inventory.held_items:
			if is_instance_valid(held):
				exclusions.append(held.get_rid())
	
	# Also exclude the item we are actively trying to place (redundancy)
	if is_instance_valid(item):
		exclusions.append(item.get_rid())
		
	query.exclude = exclusions
	
	for i in range(width_units):
		var check_offset = Vector2(i * DEFAULT_GRID_SIZE + DEFAULT_GRID_SIZE/2.0, DEFAULT_GRID_SIZE/2.0)
		query.position = pos + check_offset
		
		var results = space_state.intersect_point(query)
		for result in results:
			if result.collider is CodeBlock:
				return true
				
	return false

# --- HELPER: Local implementation to avoid dependency issues ---
func _get_drop_zone_at_point(point: Vector2) -> DropZone:
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
