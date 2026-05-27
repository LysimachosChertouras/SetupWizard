extends CharacterBody2D


@onready var movement = $MovementNode
@onready var pickup = $PickupNode

func _physics_process(delta):
	if pickup.is_player_typing():
		return
	else:
		movement.update(self, delta)

func _ready() -> void:
	pickup.init(self)

func _process(_delta: float) -> void:
	pickup.process_input()
