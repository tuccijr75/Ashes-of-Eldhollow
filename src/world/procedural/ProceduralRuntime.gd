extends Node2D

@export var dungeon_id: String = ""
@export var profile_id: String = "crypt"
@export var dungeon_seed: int = 0

@onready var _tile_map: TileMap = $TileMap

func _ready() -> void:
	_tile_map.tile_set = DB.get_runtime_tileset()
	var runtime_tile: int = max(1, DB.get_runtime_tile_size())
	var scale_factor := 32.0 / float(runtime_tile)
	_tile_map.scale = Vector2(scale_factor, scale_factor)
	_build()

func set_map(grid: Array, entrance: Vector2i, exit: Vector2i) -> void:
	# Allows WorldStream to push a generated map into this runtime.
	_tile_map.tile_set = DB.get_runtime_tileset()
	_tile_map.clear()
	var floor_tile_id := 3
	var floor_map: Dictionary = DB.get_tile_mapping(floor_tile_id)
	var floor_sid := DB.get_fallback_source_id()
	var floor_atlas := DB.get_fallback_atlas()
	if not floor_map.is_empty():
		floor_sid = int(floor_map.get("source_id"))
		floor_atlas = floor_map.get("atlas")
	for y in grid.size():
		var row: Array = grid[y]
		for x in row.size():
			if int(row[x]) == 1:
				_tile_map.set_cell(0, Vector2i(x, y), floor_sid, floor_atlas)
	GameLog.info("Proc", "Rendered dungeon %s (%s)" % [dungeon_id, profile_id])

func _build() -> void:
	# If no map pushed, load via WorldStream procedural state.
	var blob: Dictionary = WorldSys.get_or_create_procedural(dungeon_id, profile_id, dungeon_seed)
	dungeon_seed = int(blob.get("seed", dungeon_seed))
	set_map(blob.get("grid", []), blob.get("entrance", Vector2i.ZERO), blob.get("exit", Vector2i.ZERO))

