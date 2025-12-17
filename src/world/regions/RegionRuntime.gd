extends Node2D

@export var map_path: String = ""
@export var region_id: String = ""

var _tile_size: int = 32
var _bounds := {"x": 0, "y": 0, "w": 0, "h": 0}

@onready var _tile_map: TileMap = $TileMap

func _ready() -> void:
	_tile_map.tile_set = DB.get_runtime_tileset()
	_load_and_build()

func _load_and_build() -> void:
	if map_path.is_empty() or region_id.is_empty():
		GameLog.error("Region", "Missing map_path or region_id")
		return
	if not FileAccess.file_exists(map_path):
		GameLog.error("Region", "Missing map file: %s" % map_path)
		return
	var txt := FileAccess.get_file_as_string(map_path)
	var parsed = JSON.parse_string(txt)
	if parsed == null or not (parsed is Dictionary):
		GameLog.error("Region", "Invalid map JSON: %s" % map_path)
		return
	var tile_size := int(parsed.get("tileSize", 32))
	_tile_size = tile_size
	var runtime_tile: int = max(1, DB.get_runtime_tile_size())
	var scale_factor := float(tile_size) / float(runtime_tile)
	_tile_map.scale = Vector2(scale_factor, scale_factor)

	var region: Dictionary = _find_region(parsed.get("regions", []), region_id)
	if region.is_empty():
		GameLog.error("Region", "Region id not found: %s in %s" % [region_id, map_path])
		return
	_bounds = region.get("bounds", _bounds)
	position = Vector2(float(_bounds.get("x", 0)) * tile_size, float(_bounds.get("y", 0)) * tile_size)

	_build_layer(region.get("layout", []))
	if WorldPopulator != null and WorldPopulator.has_method("populate_region"):
		WorldPopulator.populate_region(self, region, _tile_size)

func _find_region(regions_v: Variant, rid: String) -> Dictionary:
	if not (regions_v is Array):
		return {}
	for r in (regions_v as Array):
		if r is Dictionary and str((r as Dictionary).get("id", "")) == rid:
			return r
	return {}

func _build_layer(layout: Array) -> void:
	_tile_map.clear()
	if layout.is_empty():
		GameLog.warn("Region", "Empty layout for %s" % region_id)
		return
	# Best-effort: validate tile IDs against tileset_manifest; render placeholder on missing.
	for y in layout.size():
		var row = layout[y]
		if not (row is Array):
			continue
		for x in row.size():
			var tile_id := int(row[x])
			if tile_id == 0:
				continue
			if not DB.is_valid_tile_id(tile_id):
				DB.log_missing_tile_once("region=%s map=%s" % [region_id, map_path], tile_id)
			var mapping: Dictionary = DB.get_tile_mapping(tile_id)
			if mapping.is_empty():
				_tile_map.set_cell(0, Vector2i(x, y), DB.get_fallback_source_id(), DB.get_fallback_atlas())
			else:
				_tile_map.set_cell(0, Vector2i(x, y), int(mapping.get("source_id")), mapping.get("atlas"))
