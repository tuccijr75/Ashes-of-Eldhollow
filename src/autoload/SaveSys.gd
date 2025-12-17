extends Node

const SAVE_DIR := "user://saves"
const SAVE_PATH := SAVE_DIR + "/save_01.json"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	GameLog.info("SaveSys", "Save system ready")

func save_game() -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var payload := {
		"version": 2,
		"chapter": Game.chapter,
		# Keep legacy field for compatibility (now backed by WorldFlags).
		"flags": WorldFlags.export_flags(),
		"world_flags": WorldFlags.get_save_blob(),
		"player_state": Game.player_state,
		"rng_seed": RNG.get_seed(),
		"quests": QuestDirector.get_save_blob(),
		"world": WorldSys.get_save_blob(),
		"rpggo_cache": (GameState.get_save_blob() if (GameState != null and GameState.has_method("get_save_blob")) else {})
	}
	var json := JSON.stringify(payload, "\t")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		GameLog.error("SaveSys", "Failed to open save file for write")
		return false
	f.store_string(json)
	f.flush()
	GameLog.info("SaveSys", "Saved %s" % SAVE_PATH)
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		GameLog.warn("SaveSys", "No save found (starting fresh)")
		return false
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed = JSON.parse_string(txt)
	if parsed == null or not (parsed is Dictionary):
		GameLog.error("SaveSys", "Invalid save JSON (ignoring)")
		return false
	# Ensure quest graph exists before loading quest state.
	QuestSys.ensure_initialized()

	Game.chapter = str(parsed.get("chapter", "I"))
	# Prefer WorldFlags blob if present; fallback to legacy flags dict.
	if (parsed as Dictionary).has("world_flags"):
		WorldFlags.load_from_save_blob((parsed as Dictionary).get("world_flags"))
	else:
		var raw_flags = (parsed as Dictionary).get("flags", {})
		if raw_flags is Dictionary:
			WorldFlags.import_flags(raw_flags, false)
	# Keep legacy view wired.
	Game.flags = WorldFlags.get_flags_ref()
	Game.player_state = parsed.get("player_state", {})
	RNG.set_seed(int(parsed.get("rng_seed", Config.default_seed)))
	# QuestDirector blob (v2). If legacy QuestSys blob is found, QuestSys can migrate.
	var qb = (parsed as Dictionary).get("quests", {})
	if qb is Dictionary and (qb as Dictionary).has("states"):
		QuestSys.load_from_save_blob(qb)
	else:
		QuestDirector.load_from_save_blob(qb)
	WorldSys.load_from_save_blob(parsed.get("world", {}))
	# RPGGO cache is optional; restore for offline-first continuity.
	if (parsed as Dictionary).has("rpggo_cache") and GameState != null and GameState.has_method("load_from_save_blob"):
		GameState.load_from_save_blob((parsed as Dictionary).get("rpggo_cache"))
	GameLog.info("SaveSys", "Loaded save")
	return true
