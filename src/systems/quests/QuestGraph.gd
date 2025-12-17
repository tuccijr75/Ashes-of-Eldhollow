class_name QuestGraph
extends Resource

# Stateful, reactive quest graph container.
# This is a framework: content can come from .tres Resources or compiled JSON.

@export var graph_id: String = ""
@export var title: String = ""

@export var nodes: Array = [] # QuestNode

# Runtime state (kept inside resource instance; save via get_save_blob()).
var _initialized := false
var _node_by_id: Dictionary = {}

var active_nodes: Dictionary = {} # node_id -> true
var completed_nodes: Dictionary = {} # node_id -> {completed_at:int}

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_node_by_id = {}
	for n in nodes:
		if n is QuestNode and (n as QuestNode).is_valid():
			_node_by_id[(n as QuestNode).node_id] = n

func get_node(node_id: String) -> QuestNode:
	ensure_initialized()
	var n = _node_by_id.get(node_id)
	return n as QuestNode

func list_node_ids() -> Array:
	ensure_initialized()
	return _node_by_id.keys()

func validate() -> Dictionary:
	ensure_initialized()
	if graph_id.is_empty():
		return {"ok": false, "reason": "graph_id_empty"}
	if _node_by_id.is_empty():
		return {"ok": false, "reason": "no_nodes"}
	for nid in _node_by_id.keys():
		var node: QuestNode = _node_by_id[nid]
		if node == null:
			return {"ok": false, "reason": "null_node:%s" % str(nid)}
		for e in (node.edges as Array):
			if not (e is Dictionary):
				return {"ok": false, "reason": "edge_not_dict:%s" % str(nid)}
			var to_id := str((e as Dictionary).get("to", ""))
			if to_id.is_empty() or not _node_by_id.has(to_id):
				return {"ok": false, "reason": "edge_target_missing:%s->%s" % [str(nid), to_id]}
	return {"ok": true}

func is_completed(node_id: String) -> bool:
	return completed_nodes.has(node_id)

func is_active(node_id: String) -> bool:
	return active_nodes.has(node_id)

func can_activate(node_id: String, flags: Node, local_vars: Dictionary = {}) -> bool:
	var node := get_node(node_id)
	if node == null:
		return false
	if is_completed(node_id) or is_active(node_id):
		return false
	for c in (node.availability_conditions as Array):
		if not ConditionEvaluator.eval_condition(c, flags, local_vars):
			return false
	return true

func activate(node_id: String) -> bool:
	ensure_initialized()
	if node_id.is_empty() or not _node_by_id.has(node_id):
		return false
	if is_completed(node_id) or is_active(node_id):
		return false
	active_nodes[node_id] = true
	return true

func can_complete(node_id: String, flags: Node, local_vars: Dictionary = {}) -> bool:
	var node := get_node(node_id)
	if node == null:
		return false
	if not is_active(node_id):
		return false
	for c in (node.completion_conditions as Array):
		if not ConditionEvaluator.eval_condition(c, flags, local_vars):
			return false
	return true

func complete(node_id: String) -> Dictionary:
	# Returns {ok, node:QuestNode}
	ensure_initialized()
	var node := get_node(node_id)
	if node == null:
		return {"ok": false}
	if not is_active(node_id):
		return {"ok": false}
	active_nodes.erase(node_id)
	completed_nodes[node_id] = {"completed_at": Time.get_unix_time_from_system()}
	return {"ok": true, "node": node}

func get_save_blob() -> Dictionary:
	ensure_initialized()
	return {
		"version": 1,
		"graph_id": graph_id,
		"active_nodes": active_nodes,
		"completed_nodes": completed_nodes
	}

func load_from_save_blob(blob) -> void:
	ensure_initialized()
	active_nodes = {}
	completed_nodes = {}
	if blob == null or not (blob is Dictionary):
		return
	var d: Dictionary = blob
	var a = d.get("active_nodes", {})
	var c = d.get("completed_nodes", {})
	active_nodes = a if (a is Dictionary) else {}
	completed_nodes = c if (c is Dictionary) else {}
