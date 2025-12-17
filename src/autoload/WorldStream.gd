extends Node

signal player_region_changed(new_region_id: String, old_region_id: String)

const REGION_SCENE := preload("res://src/world/regions/RegionRuntime.tscn")
const PROC_SCENE := preload("res://src/world/procedural/ProceduralRuntime.tscn")

var _initialized := false

var _player_region_id: String = ""

# region_id -> Node2D (RegionRuntime instances)
var _loaded_regions: Dictionary = {}

# dungeon_id -> {profile_id, seed, cleared, grid, entrance, exit}
var _procedural_states: Dictionary = {}

# One active procedural instance at a time.
var _loaded_procedural: Node2D = null

# Built from res://maps/*.json at runtime
var _region_defs: Dictionary = {} # region_id -> {map_path, bounds, entry, tile_size, center_px, stream_radius_px}

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	GameLog.info("WorldStream", "World streaming initialized")
	_reload_region_defs()
	if _procedural_states.is_empty():
		_procedural_states = {}

func _ready() -> void:
	ensure_initialized()

func _process(_delta: float) -> void:
	if not _initialized:
		return
	if _loaded_procedural != null:
		return
	var player := _player()
	if player == null:
		return
	_stream_update(player.global_position)

func get_loaded_region_ids() -> Array:
	return _loaded_regions.keys()

func get_all_region_ids() -> Array:
	return _region_defs.keys()

func get_player_region_id() -> String:
	return _player_region_id

func get_region_center_px(region_id: String) -> Vector2:
	var def: Dictionary = _region_defs.get(region_id, {})
	return def.get("center_px", Vector2.ZERO)

func debug_stream_tick_at(pos: Vector2) -> void:
	# Intended for tests and debug tooling.
	_exit_procedural_if_needed()
	_stream_update(pos)

func teleport_player_to_region(region_id: String) -> bool:
	ensure_initialized()
	# If currently in a procedural dungeon, exit back to overworld streaming.
	_exit_procedural_if_needed()
	var def = _region_defs.get(region_id)
	if def == null:
		GameLog.warn("WorldStream", "Unknown region: %s" % region_id)
		return false
	var player := _player()
	if player == null:
		return false
	var entry: Array = def.get("entry", [0, 0])
	var bounds: Dictionary = def.get("bounds", {"x": 0, "y": 0})
	var tile_size := int(def.get("tile_size", 32))
	var wx := (int(bounds.get("x", 0)) + int(entry[0])) * tile_size
	var wy := (int(bounds.get("y", 0)) + int(entry[1])) * tile_size
	player.global_position = Vector2(wx, wy)
	_stream_update(player.global_position)
	return true

func enter_procedural_dungeon(dungeon_id: String, profile_id: String, dungeon_seed: int = 0) -> bool:
	ensure_initialized()
	if dungeon_id.is_empty() or profile_id.is_empty():
		return false
	# Unload overworld regions so we keep memory bounded.
	_unload_all_regions()
	_exit_procedural_if_needed()

	var player := _player()
	if player == null:
		GameLog.warn("WorldStream", "No player for procedural dungeon")

	var inst := PROC_SCENE.instantiate() as Node2D
	inst.name = "Dungeon_%s" % dungeon_id
	inst.set("dungeon_id", dungeon_id)
	inst.set("profile_id", profile_id)
	inst.set("dungeon_seed", dungeon_seed)
	_loaded_procedural = inst
	get_tree().root.add_child(inst)

	# Teleport player to entrance if possible.
	var blob := get_or_create_procedural(dungeon_id, profile_id, dungeon_seed)
	var entrance: Vector2i = blob.get("entrance", Vector2i(1, 1))
	if player != null:
		player.global_position = Vector2(entrance.x * 32, entrance.y * 32)
	GameLog.info("WorldStream", "Entered procedural dungeon %s (%s)" % [dungeon_id, profile_id])
	return true

func force_regenerate_procedural(dungeon_id: String) -> bool:
	ensure_initialized()
	var st: Dictionary = _procedural_states.get(dungeon_id, {})
	if st.is_empty():
		return false
	if bool(st.get("cleared", false)):
		GameLog.warn("WorldStream", "Refusing to regenerate cleared dungeon %s" % dungeon_id)
		return false
	var profile_id := str(st.get("profile_id", "crypt"))
	var next_seed := int(st.get("seed", RNG.get_seed())) + 1
	_procedural_states.erase(dungeon_id)
	get_or_create_procedural(dungeon_id, profile_id, next_seed)
	if _loaded_procedural != null and str(_loaded_procedural.get("dungeon_id")) == dungeon_id:
		_loaded_procedural.call_deferred("_build")
	return true

func mark_procedural_cleared(dungeon_id: String) -> void:
	ensure_initialized()
	var st: Dictionary = _procedural_states.get(dungeon_id, {})
	if st.is_empty():
		st = {"profile_id": "crypt", "seed": RNG.get_seed()}
	st["cleared"] = true
	_procedural_states[dungeon_id] = st
	GameLog.info("WorldStream", "Marked procedural cleared: %s" % dungeon_id)

func get_or_create_procedural(dungeon_id: String, profile_id: String, dungeon_seed: int = 0) -> Dictionary:
	ensure_initialized()
	if _procedural_states.has(dungeon_id):
		return _procedural_states[dungeon_id]
	var use_seed := dungeon_seed if dungeon_seed != 0 else RNG.get_seed()
	var gen := ProceduralDungeon.generate(profile_id, int(use_seed))
	gen["profile_id"] = profile_id
	gen["cleared"] = false
	_procedural_states[dungeon_id] = gen
	return gen

func _exit_procedural_if_needed() -> void:
	if _loaded_procedural != null:
		_loaded_procedural.queue_free()
		_loaded_procedural = null

func _unload_all_regions() -> void:
	for rid in _loaded_regions.keys():
		_unload_region(str(rid))

func _stream_update(player_pos: Vector2) -> void:
	var candidates = []
	for rid in _region_defs.keys():
		var def: Dictionary = _region_defs[rid]
		var center: Vector2 = def.get("center_px", Vector2.ZERO)
		var dist := player_pos.distance_to(center)
		var radius := float(def.get("stream_radius_px", 900.0))
		var in_radius := dist <= radius
		candidates.append({"id": rid, "dist": dist, "in": in_radius})
	candidates.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))

	# Track the best-guess "current" region for UI/triggers.
	if candidates.size() > 0:
		var next_region := str(candidates[0]["id"])
		if next_region != _player_region_id:
			var old := _player_region_id
			_player_region_id = next_region
			player_region_changed.emit(_player_region_id, old)

	var want = []
	for c in candidates:
		if bool(c["in"]):
			want.append(str(c["id"]))
			if want.size() >= max(1, Config.max_simultaneous_regions):
				break
	if want.is_empty() and candidates.size() > 0:
		want.append(str(candidates[0]["id"]))

	for rid in want:
		_request_region(rid)
	for loaded_id in _loaded_regions.keys():
		if not want.has(str(loaded_id)):
			_unload_region(str(loaded_id))
	_enforce_limit()

func _request_region(region_id: String) -> void:
	if _loaded_regions.has(region_id):
		return
	var def = _region_defs.get(region_id)
	if def == null:
		GameLog.warn("WorldStream", "Cannot load unknown region: %s" % region_id)
		return
	var inst := REGION_SCENE.instantiate() as Node2D
	inst.name = "Region_%s" % region_id
	inst.set("map_path", str(def.get("map_path", "")))
	inst.set("region_id", str(region_id))
	_loaded_regions[region_id] = inst
	get_tree().root.add_child(inst)
	GameLog.info("WorldStream", "Loaded region: %s" % region_id)

func _enforce_limit() -> void:
	var max_regions: int = max(1, Config.max_simultaneous_regions)
	while _loaded_regions.size() > max_regions:
		var farthest := _pick_farthest_loaded()
		if farthest.is_empty():
			break
		_unload_region(farthest)

func _pick_farthest_loaded() -> String:
	var player := _player()
	if player == null:
		return ""
	var p := player.global_position
	var best_id := ""
	var best_dist := -1.0
	for rid in _loaded_regions.keys():
		var def: Dictionary = _region_defs.get(str(rid), {})
		var center: Vector2 = def.get("center_px", Vector2.ZERO)
		var dist := p.distance_to(center)
		if dist > best_dist:
			best_dist = dist
			best_id = str(rid)
	return best_id

func _unload_region(region_id: String) -> void:
	var node: Node = _loaded_regions.get(region_id)
	if node != null:
		node.queue_free()
	_loaded_regions.erase(region_id)
	GameLog.info("WorldStream", "Unloaded region: %s" % region_id)

func _reload_region_defs() -> void:
	_region_defs = {}
	var dir := DirAccess.open("res://maps")
	if dir == null:
		GameLog.warn("WorldStream", "Missing res://maps directory")
		return
	for f in dir.get_files():
		if not str(f).ends_with(".json"):
			continue
		var map_path := "res://maps/%s" % str(f)
		var defs := _extract_regions_from_map(map_path)
		for rid in defs.keys():
			_region_defs[rid] = defs[rid]
	GameLog.info("WorldStream", "Region defs loaded: %d" % _region_defs.size())

func _extract_regions_from_map(map_path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(map_path):
		return out
	var txt := FileAccess.get_file_as_string(map_path)
	var parsed = JSON.parse_string(txt)
	if parsed == null or not (parsed is Dictionary):
		GameLog.error("WorldStream", "Invalid map JSON: %s" % map_path)
		return out
	var tile_size := int(parsed.get("tileSize", 32))
	var regions: Array = parsed.get("regions", [])
	for r in regions:
		if not (r is Dictionary):
			continue
		var rid := str(r.get("id", ""))
		if rid.is_empty():
			continue
		var bounds: Dictionary = r.get("bounds", {"x": 0, "y": 0, "w": 0, "h": 0})
		var cx := (float(bounds.get("x", 0)) + float(bounds.get("w", 0)) * 0.5) * tile_size
		var cy := (float(bounds.get("y", 0)) + float(bounds.get("h", 0)) * 0.5) * tile_size
		var rad = float(max(float(bounds.get("w", 0)), float(bounds.get("h", 0)))) * float(tile_size) * 1.2 + 240.0
		out[rid] = {
			"map_path": map_path,
			"tile_size": tile_size,
			"bounds": bounds,
			"entry": r.get("entry", [0, 0]),
			"center_px": Vector2(cx, cy),
			"stream_radius_px": rad
		}
	return out

func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func get_save_blob() -> Dictionary:
	return {
		"loaded_regions": get_loaded_region_ids(),
		"procedural_states": _procedural_states
	}

func load_from_save_blob(blob) -> void:
	# Streaming is proximity-based; saves do not force-load regions.
	_loaded_regions = {}
	_procedural_states = {}
	_exit_procedural_if_needed()
	if blob is Dictionary and blob.has("procedural_states"):
		var ps = blob.get("procedural_states")
		if ps is Dictionary:
			_procedural_states = ps
	ensure_initialized()
