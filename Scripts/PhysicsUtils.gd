class_name PhysicsUtils

# Finds a DropZone at a specific point in the world
static func get_drop_zone_at_point(world: World2D, point: Vector2) -> DropZone:
	var space_state = world.direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_point(query)
	for result in results:
		if result.collider is DropZone:
			return result.collider
	return null

# Finds if an item from a specific list (valid_items) is under the mouse
static func get_item_under_point(world: World2D, point: Vector2, valid_items: Array[Area2D]) -> Area2D:
	var space_state = world.direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var collider = result.collider
		# Check if the thing we hit is actually one of the nearby items we care about
		if collider in valid_items:
			return collider
			
	return null
