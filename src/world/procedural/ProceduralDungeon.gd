class_name ProceduralDungeon
extends RefCounted

static func generate(profile_id: String, rng_seed: int) -> Dictionary:
	var p := ProceduralProfiles.get_profile(profile_id)
	if p.is_empty():
		return _fallback(rng_seed, "unknown_profile")

	var attempts := 0
	var max_attempts := 8
	var cur_seed := rng_seed
	while attempts < max_attempts:
		attempts += 1
		var gen := _generate_once(p, cur_seed)
		var grid: Array = gen.get("grid", [])
		var entrance: Vector2i = gen.get("entrance", Vector2i.ZERO)
		var exit: Vector2i = gen.get("exit", Vector2i.ZERO)
		var v := MapValidator.validate(grid, entrance, exit)
		if bool(v.get("ok", false)):
			gen["profile_id"] = profile_id
			gen["attempts"] = attempts
			return gen
		GameLog.warn("ProcGen", "Invalid map %s seed=%s attempt=%d reason=%s" % [profile_id, str(cur_seed), attempts, str(v.get("reason"))])
		cur_seed = int(cur_seed) + 1

	GameLog.error("ProcGen", "Failed to generate valid map %s after %d attempts; using fallback" % [profile_id, max_attempts])
	return _fallback(rng_seed, "regen_failed")

static func _generate_once(p: Dictionary, rng_seed: int) -> Dictionary:
	var algo := str(p.get("algorithm", ""))
	var w := int(p.get("width", 40))
	var h := int(p.get("height", 28))
	match algo:
		"bsp":
			return BSPGenerator.generate(w, h, rng_seed, p.get("room_min", Vector2i(5,5)), p.get("room_max", Vector2i(10,8)), int(p.get("max_depth", 4)))
		"cellular":
			return CellularGenerator.generate(w, h, rng_seed, float(p.get("fill_prob", 0.45)), int(p.get("steps", 5)))
		"room_graph":
			return RoomGraphGenerator.generate(w, h, rng_seed, int(p.get("room_count", 10)), p.get("room_min", Vector2i(5,5)), p.get("room_max", Vector2i(12,10)))
		"fixed":
			return _arena_fixed(w, h, rng_seed)
		_:
			return _fallback(rng_seed, "unknown_algorithm")

static func _arena_fixed(w: int, h: int, rng_seed: int) -> Dictionary:
	var grid := []
	grid.resize(h)
	for y in h:
		var row := []
		row.resize(w)
		for x in w:
			var border := x == 0 or y == 0 or x == w - 1 or y == h - 1
			row[x] = 0 if border else 1
		grid[y] = row
	var entrance := Vector2i(2, h / 2)
	var exit := Vector2i(w - 3, h / 2)
	return {"grid": grid, "entrance": entrance, "exit": exit, "seed": rng_seed, "profile_id": "arena", "attempts": 1}

static func _fallback(rng_seed: int, reason: String) -> Dictionary:
	# Always-valid corridor map.
	var w := 32
	var h := 22
	var grid := []
	grid.resize(h)
	for y in h:
		var row := []
		row.resize(w)
		for x in w:
			row[x] = 0
		grid[y] = row
	for x in range(1, w - 1):
		(grid[h / 2] as Array)[x] = 1
	var entrance := Vector2i(1, h / 2)
	var exit := Vector2i(w - 2, h / 2)
	return {"grid": grid, "entrance": entrance, "exit": exit, "seed": rng_seed, "profile_id": "fallback", "attempts": 1, "fallback_reason": reason}
