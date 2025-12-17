extends Node2D

@export var npc_id: String = ""
@export var talk_radius: float = 56.0

@onready var _area: Area2D = $Area2D
@onready var _shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var _label: Label = $Label

const RPGGO_DIALOG_SCRIPT := preload("res://services/rpggo/RpggoDialogRuntime.gd")

func _ready() -> void:
	add_to_group("interactable")
	var c := CircleShape2D.new()
	c.radius = talk_radius
	_shape.shape = c
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_update_from_def()

func _update_from_def() -> void:
	var d: Dictionary = NPCDB.get_npc_def(npc_id)
	var name := str(d.get("name", npc_id))
	_label.text = name

func get_interaction_priority() -> int:
	return 10

func get_interaction_dialog_runtime() -> RefCounted:
	# Prefer RPGGO-generated dialogue when configured; fall back to scripted text.
	if GameState == null or not GameState.has_method("rpggo_enabled"):
		return null
	if not bool(GameState.call("rpggo_enabled")):
		return null
	var d: Dictionary = NPCDB.get_npc_def(npc_id)
	var name := str(d.get("name", npc_id))
	var fallback := _fallback_text_from_dialog_path(str(d.get("dialog", "")))
	return RPGGO_DIALOG_SCRIPT.new(npc_id, name, fallback)

func get_interaction_dialog_path() -> String:
	var d: Dictionary = NPCDB.get_npc_def(npc_id)
	return str(d.get("dialog", ""))

func _fallback_text_from_dialog_path(path: String) -> String:
	# Best-effort: extract the first line of scripted dialog to preserve offline play.
	if path.is_empty() or not FileAccess.file_exists(path):
		return "(They look at you, waiting.)"
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed is Array and (parsed as Array).size() > 0:
		var first = (parsed as Array)[0]
		if first is Dictionary:
			var t := str((first as Dictionary).get("text", ""))
			if not t.is_empty():
				return t
	return "(They look at you, waiting.)"

func _on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		InteractionSys.register_candidate(self)

func _on_body_exited(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		InteractionSys.unregister_candidate(self)
