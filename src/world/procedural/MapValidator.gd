class_name MapValidator
extends RefCounted

static func is_walkable(cell_value: int) -> bool:
	return cell_value == 1

static func validate(grid: Array, entrance: Vector2i, exit: Vector2i) -> Dictionary:
	var res := {
		"ok": false,
		"reason": "unknown",
		"reachable": 0,
		"total_walkable": 0
	}
	if grid.is_empty():
		res.reason = "empty_grid"
		return res
	var h := grid.size()
	var w := (grid[0] as Array).size() if grid[0] is Array else 0
	if w <= 0:
		res.reason = "invalid_grid"
		return res
	if not _in_bounds(entrance, w, h) or not _in_bounds(exit, w, h):
		res.reason = "entrance_or_exit_oob"
		return res
	if not is_walkable(_cell(grid, entrance)) or not is_walkable(_cell(grid, exit)):
		res.reason = "entrance_or_exit_not_walkable"
		return res

	var total := 0
	for y in h:
		var row: Array = grid[y]
		for x in row.size():
			if is_walkable(int(row[x])):
				total += 1
	res.total_walkable = total
	if total <= 0:
		res.reason = "no_walkable"
		return res

	var reachable := _flood_count(grid, entrance)
	res.reachable = reachable
	if reachable <= 0:
		res.reason = "entrance_unreachable"
		return res

	if not _has_path(grid, entrance, exit):
		res.reason = "no_path_entrance_to_exit"
		return res

	if reachable != total:
		res.reason = "isolated_rooms"
		return res

	res.ok = true
	res.reason = "ok"
	return res

static func _has_path(grid: Array, start: Vector2i, goal: Vector2i) -> bool:
	var h := grid.size()
	var w := (grid[0] as Array).size()
	var q: Array[Vector2i] = [start]
	var visited := {}
	visited[start] = true
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		if p == goal:
			return true
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = p + d
			if not _in_bounds(n, w, h):
				continue
			if visited.has(n):
				continue
			if not is_walkable(_cell(grid, n)):
				continue
			visited[n] = true
			q.push_back(n)
	return false

static func _flood_count(grid: Array, start: Vector2i) -> int:
	var h := grid.size()
	var w := (grid[0] as Array).size()
	var q: Array[Vector2i] = [start]
	var visited := {}
	visited[start] = true
	var count := 0
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		count += 1
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = p + d
			if not _in_bounds(n, w, h):
				continue
			if visited.has(n):
				continue
			if not is_walkable(_cell(grid, n)):
				continue
			visited[n] = true
			q.push_back(n)
	return count

static func _cell(grid: Array, p: Vector2i) -> int:
	return int((grid[p.y] as Array)[p.x])

static func _in_bounds(p: Vector2i, w: int, h: int) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h
