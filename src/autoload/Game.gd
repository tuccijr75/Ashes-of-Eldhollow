extends Node

var chapter: String = "I"
var flags: Dictionary = {}
var player_state: Dictionary = {}

var _initialized := false

func _ready() -> void:
	ensure_initialized()

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	GameLog.info("Game", "Initializing game state")
	WorldFlags.ensure_initialized()
	# Keep legacy access patterns working: Game.flags is a live view of WorldFlags.
	flags = WorldFlags.get_flags_ref()
	player_state = {"hp": 10, "max_hp": 10}

func set_flag(flag_id: String, value) -> void:
	WorldFlags.set_flag(flag_id, value)

func get_flag(flag_id: String, default_value = null):
	return WorldFlags.get_flag(flag_id, default_value)
