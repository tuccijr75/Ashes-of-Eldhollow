extends Node

const NPCS_PATH := "res://data/npcs.json"

var npcs: Dictionary = {} # id -> {name, dialog}

func _ready() -> void:
	load_all()
	GameLog.info("NPCDB", "Loaded npc defs=%d" % npcs.size())

func load_all() -> void:
	npcs = {}
	if not FileAccess.file_exists(NPCS_PATH):
		GameLog.warn("NPCDB", "Missing NPCS file: %s" % NPCS_PATH)
		return
	var txt := FileAccess.get_file_as_string(NPCS_PATH)
	var parsed = JSON.parse_string(txt)
	if parsed == null or not (parsed is Dictionary):
		GameLog.error("NPCDB", "Invalid NPCS JSON")
		return
	npcs = parsed as Dictionary

func get_npc_def(npc_id: String) -> Dictionary:
	return npcs.get(npc_id, {})
