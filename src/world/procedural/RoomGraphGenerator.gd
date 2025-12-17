class_name RoomGraphGenerator
extends RefCounted

# 0=wall, 1=floor

static func generate(width: int, height: int, rng_seed: int, room_count: int, room_min: Vector2i, room_max: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var grid := _make_grid(width, height, 0)
	var rooms: Array[Rect2i] = []
	var tries := 0
	while rooms.size() < room_count and tries < room_count * 30:
		tries += 1
		var rw := rng.randi_range(room_min.x, room_max.x)
		var rh := rng.randi_range(room_min.y, room_max.y)
		var rx := rng.randi_range(1, width - rw - 2)
		var ry := rng.randi_range(1, height - rh - 2)
		var r := Rect2i(rx, ry, rw, rh)
		if _overlaps_any(r, rooms, 2):
			continue
		rooms.append(r)
		_carve_rect(grid, r, 1)

	var centers: Array[Vector2i] = []
	for r in rooms:
		centers.append(_center(r))

	# Connect with a simple MST-like greedy: start at 0, always connect nearest unconnected.
	var connected := {}
	if centers.size() > 0:
		connected[0] = true
	while connected.size() < centers.size():
		var best_a := -1
		var best_b := -1
		var best_dist := 1e30
		for ai in connected.keys():
			var aidx := int(ai)
			for bidx in range(centers.size()):
				if connected.has(bidx):
					continue
				var d := centers[aidx].distance_to(centers[bidx])
				if d < best_dist:
					best_dist = d
					best_a = aidx
					best_b = bidx
		if best_a == -1 or best_b == -1:
			break
		_carve_corridor(grid, centers[best_a], centers[best_b])
		connected[best_b] = true

	var entrance := centers[0] if centers.size() > 0 else Vector2i(1, 1)
	var exit := centers[centers.size() - 1] if centers.size() > 1 else Vector2i(width - 2, height - 2)
	(grid[entrance.y] as Array)[entrance.x] = 1
	(grid[exit.y] as Array)[exit.x] = 1

	return {"grid": grid, "entrance": entrance, "exit": exit, "seed": rng_seed}

static func _overlaps_any(r: Rect2i, rooms: Array[Rect2i], pad: int) -> bool:
	var pr := Rect2i(r.position - Vector2i(pad, pad), r.size + Vector2i(pad * 2, pad * 2))
	for o in rooms:
		if pr.intersects(o):
			return true
	return false

static func _carve_corridor(grid: Array, a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	var y := a.y
	while x != b.x:
		(grid[y] as Array)[x] = 1
		x += 1 if b.x > x else -1
	while y != b.y:
		(grid[y] as Array)[x] = 1
		y += 1 if b.y > y else -1
	(grid[b.y] as Array)[b.x] = 1

static func _carve_rect(grid: Array, rect: Rect2i, value: int) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		var row: Array = grid[y]
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			row[x] = value

static func _center(rect: Rect2i) -> Vector2i:
	return Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)

static func _make_grid(w: int, h: int, fill: int) -> Array:
	var g := []
	g.resize(h)
	for y in h:
		var row := []
		row.resize(w)
		for x in w:
			row[x] = fill
		g[y] = row
	return g
