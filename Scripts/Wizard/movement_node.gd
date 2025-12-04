extends Node2D

@export var max_speed := 300.0
@export var acceleration := 1500.0
@export var friction := 1000.0


func update(player: CharacterBody2D, delta: float) -> void:
	var direction := Input.get_axis("Left", "Right")
	var velocity := player.velocity

	# --- Horizontal movement ---
	if direction != 0:
		velocity.x += direction * acceleration * delta
	else:
		# Apply friction
		if velocity.x > 0:
			velocity.x = max(velocity.x - friction * delta, 0)
		elif velocity.x < 0:
			velocity.x = min(velocity.x + friction * delta, 0)

	
	var directionY := Input.get_axis("Up", "Down")
	

	# --- Vertical movement ---
	if directionY != 0:
		velocity.y += directionY * acceleration * delta
	else:
		# Apply friction
		if velocity.y > 0:
			velocity.y = max(velocity.y - friction * delta, 0)
		elif velocity.y < 0:
			velocity.y = min(velocity.y + friction * delta, 0)
			
	#Clamp global velocity
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	# --- Move the player ---
	player.velocity = velocity
	player.move_and_slide()
