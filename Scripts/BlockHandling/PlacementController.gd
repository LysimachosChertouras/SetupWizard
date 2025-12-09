extends Node2D
class_name PlacementController

@export var orbit_place_radius := 100
const DEFAULT_GRID_SIZE = 32

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
		ghost_preview.update_preview(drop_data.snapped_pos, item)
	else:
		ghost_preview.hide_preview()

func _drop_item(item: Area2D) -> void:
	if not is_instance_valid(item) or not inventory.has_item(item): return
	
	var drop_data = _get_current_drop_target()
	
	if drop_data.is_valid:
		var snapped_pos = drop_data.snapped_pos
		var zone = drop_data.zone
		
		# --- Bounds Check & Shifting ---
		var width_units = 1
		if item is CodeBlock and item.token_data:
			width_units = item.token_data.width_units
			
		# 1. VALIDATION: Check if the shift fits inside the zone
		if zone.has_method("can_accommodate_block"):
			if not zone.can_accommodate_block(snapped_pos, width_units, item):
				print("Cannot drop: Shift would push blocks out of bounds!")
				# Optional: Play 'error' sound
				return

		# 2. SHIFT: Make room
		if zone.has_method("request_space_for_block"):
			zone.request_space_for_block(snapped_pos, width_units, item)
		
		# 3. DROP
		item.global_position = snapped_pos
		
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
	
	var zone = PhysicsUtils.get_drop_zone_at_point(get_world_2d(), target_pos)
	
	if zone:
		return {
			"is_valid": true,
			"zone": zone,
			"snapped_pos": zone.get_snapped_global_position(target_pos)
		}
	
	return { "is_valid": false }
