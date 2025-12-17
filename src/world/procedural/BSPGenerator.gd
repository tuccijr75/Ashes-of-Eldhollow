class_name BSPGenerator
extends RefCounted

# Produces a grid of 0=wall, 1=floor

static func generate(width: int, height: int, rng_seed: int, room_min: Vector2i, room_max: Vector2i, max_depth: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var grid := _make_grid(width, height, 0)
	var leaves: Array = []
	_learn_split(rng, Rect2i(1, 1, width - 2, height - 2), 0, max_depth, leaves)

	var room_centers: Array[Vector2i] = []
	for leaf in leaves:
		var r: Rect2i = leaf
		var rw := rng.randi_range(room_min.x, min(room_max.x, r.size.x))
		var rh := rng.randi_range(room_min.y, min(room_max.y, r.size.y))
		var rx := rng.randi_range(r.position.x, r.position.x + r.size.x - rw)
		var ry := rng.randi_range(r.position.y, r.position.y + r.size.y - rh)
		var room := Rect2i(rx, ry, rw, rh)
		_carve_rect(grid, room, 1)
		room_centers.append(_center(room))

	# Connect rooms in insertion order with L corridors
	for i in range(1, room_centers.size()):
		_carve_corridor(grid, room_centers[i - 1], room_centers[i])

	var entrance := room_centers[0] if room_centers.size() > 0 else Vector2i(1, 1)
	var exit := room_centers[room_centers.size() - 1] if room_centers.size() > 1 else Vector2i(width - 2, height - 2)
	(grid[entrance.y] as Array)[entrance.x] = 1
	(grid[exit.y] as Array)[exit.x] = 1

	return {"grid": grid, "entrance": entrance, "exit": exit, "seed": rng_seed}

static func _learn_split(rng: RandomNumberGenerator, rect: Rect2i, depth: int, max_depth: int, leaves: Array) -> void:
	if depth >= max_depth:
		leaves.append(rect)
		return
	var can_split_h := rect.size.y >= 10
	var can_split_v := rect.size.x >= 10
	if not can_split_h and not can_split_v:
		leaves.append(rect)
		return

	var split_h := false
	if can_split_h and can_split_v:
		split_h = rng.randf() < 0.5
	elif can_split_h:
		split_h = true

	if split_h:
		var split := rng.randi_range(4, rect.size.y - 4)
		var a := Rect2i(rect.position.x, rect.position.y, rect.size.x, split)
		var b := Rect2i(rect.position.x, rect.position.y + split, rect.size.x, rect.size.y - split)
		_learn_split(rng, a, depth + 1, max_depth, leaves)
		_learn_split(rng, b, depth + 1, max_depth, leaves)
	else:
		var split := rng.randi_range(4, rect.size.x - 4)
		var a := Rect2i(rect.position.x, rect.position.y, split, rect.size.y)
		var b := Rect2i(rect.position.x + split, rect.position.y, rect.size.x - split, rect.size.y)
		_learn_split(rng, a, depth + 1, max_depth, leaves)
		_learn_split(rng, b, depth + 1, max_depth, leaves)

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
