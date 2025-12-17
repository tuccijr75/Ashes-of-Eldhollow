extends Node

signal graph_registered(graph_id: String)
signal node_activated(graph_id: String, node_id: String)
signal node_completed(graph_id: String, node_id: String)
signal effect_applied(graph_id: String, node_id: String, effect: Dictionary)

var _initialized := false

# graph_id -> QuestGraph
var _graphs: Dictionary = {}

# graph_id -> quest-local variables (Dictionary)
var _locals: Dictionary = {}

func _ready() -> void:
	ensure_initialized()

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_graphs = {}
	_locals = {}

func register_graph(graph: QuestGraph) -> bool:
	ensure_initialized()
	if graph == null:
		return false
	graph.ensure_initialized()
	var v: Dictionary = graph.validate()
	if not bool(v.get("ok", false)):
		GameLog.error("QuestDirector", "Graph invalid: %s" % JSON.stringify(v))
		return false
	if graph.graph_id.is_empty():
		return false
	_graphs[graph.graph_id] = graph
	if not _locals.has(graph.graph_id):
		_locals[graph.graph_id] = {}
	emit_signal("graph_registered", graph.graph_id)
	return true

func get_graph(graph_id: String) -> QuestGraph:
	ensure_initialized()
	return _graphs.get(graph_id) as QuestGraph

func get_local_vars(graph_id: String) -> Dictionary:
	ensure_initialized()
	var d: Dictionary = _locals.get(graph_id, {})
	return d

func set_local_var(graph_id: String, key: String, value) -> void:
	ensure_initialized()
	if not _locals.has(graph_id):
		_locals[graph_id] = {}
	var d: Dictionary = _locals[graph_id]
	d[key] = value
	_locals[graph_id] = d

func can_activate(graph_id: String, node_id: String) -> bool:
	var g := get_graph(graph_id)
	if g == null:
		return false
	var lv: Dictionary = get_local_vars(graph_id)
	return g.can_activate(node_id, WorldFlags, lv)

func activate(graph_id: String, node_id: String) -> bool:
	var g := get_graph(graph_id)
	if g == null:
		return false
	var lv: Dictionary = get_local_vars(graph_id)
	if not g.can_activate(node_id, WorldFlags, lv):
		return false
	var ok := g.activate(node_id)
	if ok:
		emit_signal("node_activated", graph_id, node_id)
	return ok

func can_complete(graph_id: String, node_id: String) -> bool:
	var g := get_graph(graph_id)
	if g == null:
		return false
	var lv: Dictionary = get_local_vars(graph_id)
	return g.can_complete(node_id, WorldFlags, lv)

func complete(graph_id: String, node_id: String) -> bool:
	var g := get_graph(graph_id)
	if g == null:
		return false
	var lv: Dictionary = get_local_vars(graph_id)
	if not g.can_complete(node_id, WorldFlags, lv):
		return false
	var res: Dictionary = g.complete(node_id)
	if not bool(res.get("ok", false)):
		return false
	var node: QuestNode = res.get("node")
	_apply_node_outcomes(graph_id, node)
	emit_signal("node_completed", graph_id, node_id)
	return true

func _apply_node_outcomes(graph_id: String, node: QuestNode) -> void:
	if node == null:
		return
	for eff in (node.outcomes as Array):
		if eff is Dictionary:
			_apply_effect(graph_id, node.node_id, eff)
	for lock_id in (node.locks_add as Array):
		var lid := str(lock_id)
		if not lid.is_empty():
			# Represent locks as flags for simplicity.
			WorldFlags.set_flag("LOCK_%s" % lid, true)

func _apply_effect(graph_id: String, node_id: String, eff: Dictionary) -> void:
	# Minimal effect set; extend via spec as needed.
	if eff.has("set_flag"):
		WorldFlags.set_flag(str(eff.get("set_flag")), eff.get("value"))
		emit_signal("effect_applied", graph_id, node_id, eff)
		return
	if eff.has("inc_flag"):
		var k := str(eff.get("inc_flag"))
		var delta := int(eff.get("delta", 1))
		var cur := int(WorldFlags.get_flag(k, 0))
		WorldFlags.set_flag(k, cur + delta)
		emit_signal("effect_applied", graph_id, node_id, eff)
		return
	if eff.has("set_clause"):
		# Mutually exclusive clause set selector.
		# Once set, it should not change (branch lock).
		var clause := str(eff.get("set_clause", ""))
		if clause.is_empty():
			return
		var cur_clause := WorldFlags.get_string("CLAUSE_SET", "")
		if cur_clause.is_empty():
			WorldFlags.set_flag("CLAUSE_SET", clause)
			emit_signal("effect_applied", graph_id, node_id, eff)
		return
	if eff.has("grant_seal"):
		var seal := str(eff.get("grant_seal", ""))
		if not seal.is_empty():
			WorldFlags.set_flag("SEAL_%s" % seal.to_upper(), true)
			emit_signal("effect_applied", graph_id, node_id, eff)
		return
	if eff.has("set_censure_mode"):
		WorldFlags.set_flag("CENSURE_MODE", str(eff.get("set_censure_mode")))
		emit_signal("effect_applied", graph_id, node_id, eff)
		return
	if eff.has("compute_boss_unlock"):
		compute_boss_unlock()
		emit_signal("effect_applied", graph_id, node_id, eff)
		return

func compute_boss_unlock() -> bool:
	# Rule: earn 3 of 5 domain seals + complete Keystone Trial,
	# plus resolve Censure either by reduction OR defiance.
	var seals := 0
	for k in ["SEAL_INK", "SEAL_BLOOD", "SEAL_SILENCE", "SEAL_DEBT", "SEAL_WITNESS"]:
		if WorldFlags.get_bool(k, false):
			seals += 1
	var keystone_ok := WorldFlags.get_bool("KEYSTONE_TRIAL_DONE", false)
	var cm := WorldFlags.get_string("CENSURE_MODE", "unresolved")
	var censure_ok := (cm == "reduced" or cm == "defied")
	var unlocked := seals >= 3 and keystone_ok and censure_ok
	WorldFlags.set_flag("BOSS_UNLOCKED", unlocked)
	return unlocked

func get_save_blob() -> Dictionary:
	ensure_initialized()
	var graphs_blob := {}
	for gid in _graphs.keys():
		var g: QuestGraph = _graphs[gid]
		if g != null:
			graphs_blob[str(gid)] = g.get_save_blob()
	return {"version": 1, "graphs": graphs_blob, "locals": _locals}

func load_from_save_blob(blob) -> void:
	ensure_initialized()
	if blob == null or not (blob is Dictionary):
		return
	var d: Dictionary = blob
	var loc = d.get("locals", {})
	_locals = loc if (loc is Dictionary) else {}
	var graphs_blob = d.get("graphs", {})
	if graphs_blob is Dictionary:
		for gid in graphs_blob.keys():
			var g := get_graph(str(gid))
			if g != null:
				g.load_from_save_blob((graphs_blob as Dictionary)[gid])
