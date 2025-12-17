extends Node

const NPC_SCENE := preload("res://src/entities/npc/NPCActor.tscn")
const ENEMY_SCENE := preload("res://src/entities/enemy/EnemyActor.tscn")

func _ready() -> void:
	GameLog.info("WorldPopulator", "Ready")

func populate_region(region_node: Node2D, region_data: Dictionary, tile_size: int) -> void:
	var bounds: Dictionary = region_data.get("bounds", {"x": 0, "y": 0})
	var bx := int(bounds.get("x", 0))
	var by := int(bounds.get("y", 0))
	# Spawn static NPCs from map JSON.
	var npcs: Array = region_data.get("npcs", [])
	for n in npcs:
		if not (n is Dictionary):
			continue
		var nd: Dictionary = n
		var npc_id := str(nd.get("id", ""))
		var pos: Array = nd.get("pos", [0, 0])
		if npc_id.is_empty() or pos.size() < 2:
			continue
		var lx := float(int(pos[0]) - bx) * tile_size
		var ly := float(int(pos[1]) - by) * tile_size
		_spawn_npc(region_node, npc_id, Vector2(lx, ly))

	# Spawn travelers / villagers between exits (lightly randomized).
	var exits: Array = region_data.get("exits", [])
	if exits.size() > 0 and RNG.randf() < 0.65:
		var count := RNG.randi_range(0, 2)
		for i in range(count):
			var ex = exits[RNG.randi_range(0, exits.size() - 1)]
			if ex is Dictionary:
				var coords: Array = (ex as Dictionary).get("coords", [0, 0])
				if coords.size() >= 2:
					var base := Vector2(float(int(coords[0]) - bx) * tile_size, float(int(coords[1]) - by) * tile_size)
					var jitter := Vector2(RNG.randi_range(-24, 24), RNG.randi_range(-24, 24))
					_spawn_npc(region_node, "traveler_%d" % RNG.randi_range(1, 3), base + jitter)

	# Spawn a random enemy in field/combat regions (rarely in town/dungeon).
	var rtype := str(region_data.get("type", "field"))
	var allow_enemy := (rtype == "field" or rtype == "combat")
	if allow_enemy and RNG.randf() < 0.55:
		_spawn_random_enemy(region_node, region_data, tile_size)

func _spawn_npc(region_node: Node2D, npc_id: String, local_px: Vector2) -> void:
	var inst := NPC_SCENE.instantiate() as Node2D
	inst.set("npc_id", npc_id)
	inst.global_position = region_node.global_position + local_px
	region_node.add_child(inst)

func _spawn_random_enemy(region_node: Node2D, region_data: Dictionary, tile_size: int) -> void:
	var rid := str(region_data.get("id", ""))
	var bounds: Dictionary = region_data.get("bounds", {"x": 0, "y": 0})
	var bx := int(bounds.get("x", 0))
	var by := int(bounds.get("y", 0))
	# Map region ids -> encounter regions.
	var encounter_region := _encounter_region_for_map_region(rid)
	var pick := EncounterSys.pick_spawn(encounter_region, Game.chapter)
	if pick.is_empty():
		return
	var spawn_points: Array = region_data.get("spawn_points", [])
	var local_px := Vector2(128, 128)
	if spawn_points.size() > 0:
		var sp = spawn_points[RNG.randi_range(0, spawn_points.size() - 1)]
		if sp is Array and (sp as Array).size() >= 2:
			local_px = Vector2(float(int(sp[0]) - bx) * tile_size, float(int(sp[1]) - by) * tile_size)
	# Jitter it so it isn't always on a tile corner.
	local_px += Vector2(RNG.randi_range(-32, 32), RNG.randi_range(-32, 32))

	var inst := ENEMY_SCENE.instantiate() as Node2D
	inst.set("enemy_name", str(pick.get("name", "Unknown")))
	inst.set("tier", int(pick.get("tier", 1)))
	inst.set("region_id", rid)
	inst.global_position = region_node.global_position + local_px
	region_node.add_child(inst)

func _encounter_region_for_map_region(region_id: String) -> String:
	# Best-effort mapping into the encounter table.
	match region_id:
		"village", "chapel", "ashpath", "stonebridge", "forest", "graveyard", "village_reborn":
			return "West Eldhollow"
		"fenmire_crossing", "fenmire_marsh", "fens_hut", "whispering_glen":
			return "Fenmire Wastes"
		"vale_bones":
			return "Vale of Bones"
		"hollow_city", "herald_arena":
			return "Hollow City"
		"whitespire_tundra", "skyreach_monastery", "frozen_wastes", "ice_caverns", "mountain_pass", "ashen_steppe", "sableglass_dunes", "mirror_wastes", "umbral_reaches", "deep_ice":
			return "Northern Wastes"
		"emberfall_crags", "cinderway_caldera":
			return "Blightlands"
		"dreadmire_causeway":
			return "Fenmire Wastes"
		"nerenthis_depths":
			return "Nerenthis Depths"
		"lava_chasm", "temple_choice", "temple_final", "final_arena":
			return "Blightlands"
		_:
			return "West Eldhollow"
