class_name CellularGenerator
extends RefCounted

# 0=wall, 1=floor

static func generate(width: int, height: int, rng_seed: int, fill_prob: float, steps: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var grid := _make_grid(width, height, 0)

	for y in range(1, height - 1):
		for x in range(1, width - 1):
			(grid[y] as Array)[x] = 1 if rng.randf() > fill_prob else 0

	for _i in steps:
		grid = _step(grid)

	# Ensure at least one connected cavern by flood from a chosen floor.
	var entrance := _pick_any_floor(grid)
	if entrance == Vector2i(-1, -1):
		entrance = Vector2i(width / 2, height / 2)
		(grid[entrance.y] as Array)[entrance.x] = 1

	var exit := _farthest_floor(grid, entrance)
	if exit == Vector2i(-1, -1):
		exit = Vector2i(width - 2, height - 2)
		(grid[exit.y] as Array)[exit.x] = 1

	return {"grid": grid, "entrance": entrance, "exit": exit, "seed": rng_seed}

static func _step(grid: Array) -> Array:
	var h := grid.size()
	var w := (grid[0] as Array).size()
	var out := _make_grid(w, h, 0)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var walls := _count_walls(grid, x, y)
			var v := int((grid[y] as Array)[x])
			if v == 1:
				(out[y] as Array)[x] = 1 if walls <= 4 else 0
			else:
				(out[y] as Array)[x] = 1 if walls <= 3 else 0
	return out

static func _count_walls(grid: Array, x: int, y: int) -> int:
	var c := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var v := int((grid[y + dy] as Array)[x + dx])
			if v == 0:
				c += 1
	return c

static func _pick_any_floor(grid: Array) -> Vector2i:
	var h := grid.size()
	var w := (grid[0] as Array).size()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if int((grid[y] as Array)[x]) == 1:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

static func _farthest_floor(grid: Array, start: Vector2i) -> Vector2i:
	# BFS distance, return farthest reachable floor.
	var h := grid.size()
	var w := (grid[0] as Array).size()
	var q: Array[Vector2i] = [start]
	var dist := {}
	dist[start] = 0
	var best := start
	var best_d := 0
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		var d0 := int(dist[p])
		if d0 > best_d:
			best_d = d0
			best = p
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = p + d
			if n.x <= 0 or n.y <= 0 or n.x >= w - 1 or n.y >= h - 1:
				continue
			if dist.has(n):
				continue
			if int((grid[n.y] as Array)[n.x]) != 1:
				continue
			dist[n] = d0 + 1
			q.push_back(n)
	return best

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
