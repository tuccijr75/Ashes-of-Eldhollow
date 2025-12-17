extends CharacterBody2D

@export var move_speed: float = 220.0

func _ready() -> void:
	add_to_group("player")
	GameLog.info("Player", "Player ready")

func _physics_process(_delta: float) -> void:
	var axis := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = axis * move_speed
	move_and_slide()
