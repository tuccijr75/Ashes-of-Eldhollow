extends Node

# Tracks interactable objects near the player.
# Interactables are expected to expose:
# - func get_interaction_priority() -> int (higher = preferred)
# - func get_interaction_dialog_runtime() -> RefCounted (optional)
# - func get_interaction_dialog_path() -> String (optional)
# - func on_interacted() -> void (optional)

var _candidates: Array[Node] = []

func _ready() -> void:
	GameLog.info("InteractionSys", "Ready")

func register_candidate(node: Node) -> void:
	if node == null:
		return
	if _candidates.has(node):
		return
	_candidates.append(node)

func unregister_candidate(node: Node) -> void:
	if node == null:
		return
	_candidates.erase(node)

func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func _best_candidate() -> Node:
	var player := _player()
	if player == null:
		return null
	var best: Node = null
	var best_pri := -999999
	var best_dist := INF
	for n in _candidates:
		if n == null or not is_instance_valid(n):
			continue
		if not (n is Node2D):
			continue
		var pri := 0
		if n.has_method("get_interaction_priority"):
			pri = int(n.call("get_interaction_priority"))
		var dist := (n as Node2D).global_position.distance_to(player.global_position)
		# Prefer higher priority; break ties by distance.
		if pri > best_pri or (pri == best_pri and dist < best_dist):
			best = n
			best_pri = pri
			best_dist = dist
	return best

func try_interact(dialog_overlay: Node) -> bool:
	# Returns true if an interaction was performed.
	if dialog_overlay == null:
		return false
	var n := _best_candidate()
	if n == null:
		return false
	# Runtime-based dialogs first.
	if n.has_method("get_interaction_dialog_runtime") and dialog_overlay.has_method("open_runtime"):
		var rt = n.call("get_interaction_dialog_runtime")
		if rt != null:
			var ok := bool(dialog_overlay.call("open_runtime", rt, "encounter"))
			if ok:
				# If this runtime supports async fetch (RPGGO), provide minimal context
				# and request a UI refresh when the result arrives.
				if rt.has_method("start_fetch"):
					var rid := ""
					var ws := get_node_or_null("/root/WorldSys")
					if ws != null and ws.has_method("get_player_region_id"):
						rid = str(ws.call("get_player_region_id"))
					var ctx := {"location": rid, "recent_events": []}
					var refresh_cb := Callable()
					if dialog_overlay.has_method("refresh_active_dialog"):
						refresh_cb = Callable(dialog_overlay, "refresh_active_dialog")
					rt.call("start_fetch", ctx, refresh_cb)
				if n.has_method("on_interacted"):
					n.call("on_interacted")
				return true
	# Path-based dialogs fallback.
	if n.has_method("get_interaction_dialog_path") and dialog_overlay.has_method("open_path"):
		var p := str(n.call("get_interaction_dialog_path"))
		if not p.is_empty():
			var ok2 := bool(dialog_overlay.call("open_path", p, "npc"))
			if ok2:
				if n.has_method("on_interacted"):
					n.call("on_interacted")
				return true
	return false
