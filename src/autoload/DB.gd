extends Node

const QUESTS_PATH := "res://data/quests.json"
const ENCOUNTERS_PATH := "res://data/encounters.json"
const DIALOGS_DIR := "res://data/dialogs"
const TILESET_MANIFEST_PATH := "res://assets/tilesets/tileset_manifest.json"
const TILESET_IMPORT_MAP_PATH := "res://assets/tilesets/tileset_import_map.json"
const RUNTIME_TILE_SIZE := 16

var quests: Array = []
var encounters: Array = []

var _valid_tile_ids: Dictionary = {} # int -> true
var _missing_tile_logged: Dictionary = {} # key -> true

var _runtime_tileset: TileSet
var _tile_id_to_mapping: Dictionary = {} # int -> {source_id:int, atlas:Vector2i}
var _fallback_source_id: int = -1
var _fallback_atlas := Vector2i(0, 0)
var _missing_sheet_logged: Dictionary = {} # key -> true

func _ready() -> void:
	load_all()

func load_all() -> void:
	quests = _load_json_array_safe(QUESTS_PATH)
	encounters = _load_json_array_safe(ENCOUNTERS_PATH)
	_load_tileset_manifest()
	_ensure_runtime_tileset()
	GameLog.info("DB", "Loaded quests=%d encounters=%d" % [quests.size(), encounters.size()])
	GameLog.info("DB", "Tileset tile IDs loaded=%d" % _valid_tile_ids.size())
	GameLog.info("DB", "Runtime tiles mapped=%d" % _tile_id_to_mapping.size())

func get_runtime_tile_size() -> int:
	return RUNTIME_TILE_SIZE

func get_runtime_tileset() -> TileSet:
	_ensure_runtime_tileset()
	return _runtime_tileset

func get_tile_mapping(tile_id: int) -> Dictionary:
	_ensure_runtime_tileset()
	return _tile_id_to_mapping.get(tile_id, {})

func get_fallback_source_id() -> int:
	_ensure_runtime_tileset()
	return _fallback_source_id

func get_fallback_atlas() -> Vector2i:
	_ensure_runtime_tileset()
	return _fallback_atlas

func is_valid_tile_id(tile_id: int) -> bool:
	return _valid_tile_ids.has(tile_id)

func log_missing_tile_once(context: String, tile_id: int) -> void:
	var key := "%s:%d" % [context, tile_id]
	if _missing_tile_logged.has(key):
		return
	_missing_tile_logged[key] = true
	GameLog.error("Tiles", "Missing tile id=%d (%s)" % [tile_id, context])

func _load_tileset_manifest() -> void:
	_valid_tile_ids = {}
	if not FileAccess.file_exists(TILESET_MANIFEST_PATH):
		GameLog.warn("DB", "Missing tileset manifest: %s" % TILESET_MANIFEST_PATH)
		return
	var txt := FileAccess.get_file_as_string(TILESET_MANIFEST_PATH)
	var parsed = JSON.parse_string(txt)
	if parsed == null or not (parsed is Dictionary):
		GameLog.error("DB", "Invalid tileset manifest JSON: %s" % TILESET_MANIFEST_PATH)
		return
	var tiles: Array = parsed.get("tiles", [])
	for t in tiles:
		if t is Dictionary and t.has("id"):
			_valid_tile_ids[int(t.get("id"))] = true

func _ensure_runtime_tileset() -> void:
	if _runtime_tileset != null:
		return
	_runtime_tileset = TileSet.new()
	_runtime_tileset.tile_size = Vector2i(RUNTIME_TILE_SIZE, RUNTIME_TILE_SIZE)
	_tile_id_to_mapping = {}
	_missing_sheet_logged = {}
	_add_fallback_source()
	_load_tileset_import_map()

func _add_fallback_source() -> void:
	var img := Image.create(RUNTIME_TILE_SIZE, RUNTIME_TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.0, 1.0, 1.0))
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(RUNTIME_TILE_SIZE, RUNTIME_TILE_SIZE)
	_fallback_source_id = _runtime_tileset.add_source(src)
	src.create_tile(_fallback_atlas)

func _load_tileset_import_map() -> void:
	if not FileAccess.file_exists(TILESET_IMPORT_MAP_PATH):
		GameLog.warn("DB", "Missing tileset import map: %s" % TILESET_IMPORT_MAP_PATH)
		return
	var txt := FileAccess.get_file_as_string(TILESET_IMPORT_MAP_PATH)
	var parsed = JSON.parse_string(txt)
	if parsed == null or not (parsed is Dictionary):
		GameLog.error("DB", "Invalid tileset import map JSON: %s" % TILESET_IMPORT_MAP_PATH)
		return
	var sheet_sources: Dictionary = (parsed as Dictionary).get("sheetSources", {})
	var tile_overrides: Dictionary = (parsed as Dictionary).get("tileOverrides", {})

	var sheet_to_source_id := {}
	for sheet_id in sheet_sources.keys():
		var s: Dictionary = sheet_sources[sheet_id]
		var img_path := str(s.get("image", ""))
		if img_path.is_empty():
			continue
		if not img_path.begins_with("res://"):
			if img_path.begins_with("/"):
				img_path = img_path.substr(1)
			img_path = "res://" + img_path
		if not ResourceLoader.exists(img_path):
			_log_missing_sheet_once("missing_texture:%s" % img_path)
			continue
		var tex := load(img_path)
		if tex == null or not (tex is Texture2D):
			_log_missing_sheet_once("bad_texture:%s" % img_path)
			continue
		var tw := int(s.get("tileWidth", RUNTIME_TILE_SIZE))
		var th := int(s.get("tileHeight", RUNTIME_TILE_SIZE))
		if tw <= 0 or th <= 0:
			tw = RUNTIME_TILE_SIZE
			th = RUNTIME_TILE_SIZE
		if tw != RUNTIME_TILE_SIZE or th != RUNTIME_TILE_SIZE:
			# For now we only support the runtime tile size; mismatches use fallback.
			_log_missing_sheet_once("tile_size_mismatch:%s" % str(sheet_id))
			continue
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(tw, th)
		var sid := _runtime_tileset.add_source(src)
		sheet_to_source_id[sheet_id] = sid

	for tile_key in tile_overrides.keys():
		var tid := int(tile_key)
		var o: Dictionary = tile_overrides[tile_key]
		var sheet_id := str(o.get("sheetId", ""))
		if sheet_id.is_empty() or not sheet_to_source_id.has(sheet_id):
			continue
		var sid := int(sheet_to_source_id[sheet_id])
		var atlas := Vector2i(int(o.get("x", 0)), int(o.get("y", 0)))
		var src: TileSetAtlasSource = _runtime_tileset.get_source(sid)
		if src != null:
			var tex: Texture2D = src.texture
			if tex == null or not _atlas_coord_in_bounds(tex, src.texture_region_size, atlas):
				_log_missing_sheet_once("atlas_oob:%s:%s" % [str(sheet_id), str(atlas)])
				continue
			if not _atlas_has_tile(src, atlas):
				src.create_tile(atlas)
			_tile_id_to_mapping[tid] = {"source_id": sid, "atlas": atlas}

func _atlas_has_tile(src: TileSetAtlasSource, atlas: Vector2i) -> bool:
	# Godot provides TileSetAtlasSource.has_tile(atlas_coords) in 4.x.
	# Use has_method/call so this stays robust across minor API changes.
	if src == null:
		return false
	if src.has_method("has_tile"):
		return bool(src.call("has_tile", atlas))
	return false

func _atlas_coord_in_bounds(tex: Texture2D, region_size: Vector2i, atlas: Vector2i) -> bool:
	if tex == null:
		return false
	if region_size.x <= 0 or region_size.y <= 0:
		return false
	if atlas.x < 0 or atlas.y < 0:
		return false
	var ts: Vector2i = tex.get_size()
	var px := atlas.x * region_size.x
	var py := atlas.y * region_size.y
	return px + region_size.x <= ts.x and py + region_size.y <= ts.y

func _log_missing_sheet_once(key: String) -> void:
	if _missing_sheet_logged.has(key):
		return
	_missing_sheet_logged[key] = true
	GameLog.warn("Tiles", key)

func _load_json_array_safe(path: String) -> Array:
	if not FileAccess.file_exists(path):
		GameLog.warn("DB", "Missing data file: %s (using empty array)" % path)
		return []
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		GameLog.error("DB", "Invalid JSON: %s (using empty array)" % path)
		return []
	if parsed is Array:
		return parsed
	GameLog.error("DB", "Expected JSON array in %s (using empty array)" % path)
	return []
