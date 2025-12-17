extends Node2D

@export var enemy_name: String = "Unknown" 
@export var tier: int = 1
@export var region_id: String = ""
@export var aggro_radius: float = 60.0

@onready var _area: Area2D = $Area2D
@onready var _shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var _label: Label = $Label

var _triggered := false

func _ready() -> void:
	add_to_group("interactable")
	var c := CircleShape2D.new()
	c.radius = aggro_radius
	_shape.shape = c
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_label.text = enemy_name

func get_interaction_priority() -> int:
	# Prefer enemies over NPCs when both are in range.
	return 20

func get_interaction_dialog_runtime() -> RefCounted:
	return EncounterRuntime.new(enemy_name, tier, region_id)

func on_interacted() -> void:
	# One-shot encounter.
	queue_free()

func _on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		InteractionSys.register_candidate(self)
		# Auto-trigger sometimes for tension.
		if not _triggered and RNG.randf() < 0.25:
			_triggered = true

func _on_body_exited(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		InteractionSys.unregister_candidate(self)
