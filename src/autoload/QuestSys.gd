extends Node

# Quest runtime facade.
#
# We keep the public API stable (DebugConsole/tests/dialog effects call QuestSys),
# but the underlying implementation is now QuestDirector + QuestGraph + WorldFlags.

const GRAPH_ID := "authority_web"

const RPGGO_EVENTS_SCRIPT := preload("res://data/rpggo_events.gd")

var _initialized := false
var _graph: QuestGraph

func _ready() -> void:
	ensure_initialized()

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	if DB.quests.is_empty():
		DB.load_all()
	WorldFlags.ensure_initialized()
	QuestDirector.ensure_initialized()
	_graph = _compile_graph(DB.quests)
	if not QuestDirector.register_graph(_graph):
		GameLog.error("QuestSys", "Failed to register quest graph")
	GameLog.info("QuestSys", "Quest system ready (graph=%s quests=%d)" % [GRAPH_ID, DB.quests.size()])

func get_status(quest_id: int) -> String:
	ensure_initialized()
	var nid := _node_id(quest_id)
	if nid.is_empty():
		return "locked"
	if _graph != null and _graph.is_completed(nid):
		return "completed"
	if _graph != null and _graph.is_active(nid):
		return "active"
	return "available" if can_start(quest_id) else "locked"

func is_available(quest_id: int) -> bool:
	# Legacy name used by older code.
	return can_start(quest_id)

func can_start(quest_id: int) -> bool:
	ensure_initialized()
	var nid := _node_id(quest_id)
	return QuestDirector.can_activate(GRAPH_ID, nid)

func start_quest(quest_id: int) -> bool:
	ensure_initialized()
	var nid := _node_id(quest_id)
	if nid.is_empty():
		return false
	if not QuestDirector.activate(GRAPH_ID, nid):
		GameLog.warn("QuestSys", "Cannot start quest %d" % quest_id)
		return false
	WorldFlags.set_flag(_start_flag(quest_id), true)
	WorldFlags.set_flag(_active_flag(quest_id), true)
	WorldFlags.set_flag(_ready_flag(quest_id), false)
	GameLog.info("QuestSys", "Started quest %d" % quest_id)
	return true

func complete_quest(quest_id: int) -> bool:
	ensure_initialized()
	var nid := _node_id(quest_id)
	if nid.is_empty():
		return false
	if not WorldFlags.get_bool(_ready_flag(quest_id), false):
		GameLog.warn("QuestSys", "Cannot complete quest %d (requirements not satisfied)" % quest_id)
		return false
	if not QuestDirector.complete(GRAPH_ID, nid):
		GameLog.warn("QuestSys", "Cannot complete quest %d (not active or blocked)" % quest_id)
		return false
	WorldFlags.set_flag(_done_flag(quest_id), true)
	WorldFlags.set_flag(_active_flag(quest_id), false)
	WorldFlags.set_flag(_ready_flag(quest_id), false)
	QuestDirector.compute_boss_unlock()
	_emit_rpggo_quest_event_if_mapped(quest_id)
	GameLog.info("QuestSys", "Completed quest %d" % quest_id)
	return true

func _emit_rpggo_quest_event_if_mapped(quest_id: int) -> void:
	# IMPORTANT: do not generate event IDs dynamically.
	# For quest completion, emit the canonical quest_id string from data/quests.json.
	# (This is stable, content-authored, and avoids introducing new event schemas.)
	if GameState == null or not GameState.has_method("emit_narrative_event"):
		return
	var eid := _quest_completed_event_id(quest_id)
	if eid.is_empty():
		return
	GameState.emit_narrative_event(eid, {"source": "quest_complete", "quest_id": quest_id})

func _quest_completed_event_id(quest_id: int) -> String:
	# Use the quest_id string from data/quests.json for the given numeric quest index.
	# This keeps RPGGO event IDs aligned with authored quest IDs.
	if quest_id <= 0:
		return ""
	if DB == null:
		return ""
	var idx := quest_id - 1
	if idx < 0 or idx >= DB.quests.size():
		return ""
	var q_any = DB.quests[idx]
	if not (q_any is Dictionary):
		return ""
	var q: Dictionary = q_any
	var qid_str = q.get("quest_id", "")
	if qid_str is String:
		return str(qid_str)
	return ""

func list_active() -> Array:
	ensure_initialized()
	var out: Array = []
	var n := DB.quests.size() if DB != null else 100
	for i in range(1, n + 1):
		if get_status(i) == "active":
			out.append(i)
	out.sort()
	return out

func list_completed() -> Array:
	ensure_initialized()
	var out: Array = []
	var n := DB.quests.size() if DB != null else 100
	for i in range(1, n + 1):
		if get_status(i) == "completed":
			out.append(i)
	out.sort()
	return out

func list_available(limit: int = 20) -> Array:
	ensure_initialized()
	var out: Array = []
	var n := DB.quests.size() if DB != null else 100
	for i in range(1, n + 1):
		if can_start(i):
			out.append(i)
			if out.size() >= limit:
				break
	out.sort()
	return out

func get_save_blob() -> Dictionary:
	ensure_initialized()
	# Keep the save key name stable (SaveSys stores this under "quests").
	return {
		"version": 2,
		"director": QuestDirector.get_save_blob(),
		"flags": WorldFlags.get_save_blob()
	}

func load_from_save_blob(blob) -> void:
	ensure_initialized()
	if blob == null or not (blob is Dictionary):
		return
	var d: Dictionary = blob
	# Legacy v1: {states:{qid->{status,...}}}
	if d.has("states"):
		_import_legacy_states(d.get("states", {}))
		return
	# v2+: {director:{...}, flags:{...}}
	if d.has("flags"):
		WorldFlags.load_from_save_blob(d.get("flags"))
	if d.has("director"):
		QuestDirector.load_from_save_blob(d.get("director"))

func _import_legacy_states(states_in) -> void:
	if states_in == null or not (states_in is Dictionary):
		return
	var st: Dictionary = states_in
	# Force-apply legacy statuses into the graph/flags.
	for k in st.keys():
		var qid := int(k)
		var s: Dictionary = st[k] if (st[k] is Dictionary) else {}
		var status := str(s.get("status", ""))
		var nid := _node_id(qid)
		if nid.is_empty():
			continue
		if status == "completed":
			_graph.completed_nodes[nid] = {"completed_at": int(s.get("completed_at", 0))}
			WorldFlags.set_flag(_done_flag(qid), true)
			WorldFlags.set_flag(_active_flag(qid), false)
			WorldFlags.set_flag(_start_flag(qid), true)
		elif status == "active":
			_graph.active_nodes[nid] = true
			WorldFlags.set_flag(_start_flag(qid), true)
			WorldFlags.set_flag(_active_flag(qid), true)
	QuestDirector.compute_boss_unlock()
	GameLog.info("QuestSys", "Migrated legacy quest states: %d" % st.size())

func _compile_graph(quests: Array) -> QuestGraph:
	var g := QuestGraph.new()
	g.graph_id = GRAPH_ID
	g.title = "Authority Web"
	g.nodes = []
	for i in range(quests.size()):
		var q_any = quests[i]
		if not (q_any is Dictionary):
			continue
		var q: Dictionary = q_any
		# Quests are indexed 1..N across the game (quest dialogs, debug console, saves).
		# data/quests.json stores a canonical string id under "quest_id", so we derive
		# the numeric id from position to keep runtime stable and deterministic.
		var qid := i + 1
		var n := QuestNode.new()
		n.node_id = _node_id(qid)
		n.title = str(q.get("name", "Quest %d" % qid))
		n.mode = str(q.get("authority_domain", ""))
		n.description = str(q.get("_meta", {}).get("narrative_premise", ""))

		# Availability conditions
		var avail: Array = []
		# Always respect dependencies as baseline gating.
		var deps = q.get("dependencies", [])
		if deps is Array and not (deps as Array).is_empty():
			var reqs: Array = []
			for d in (deps as Array):
				reqs.append({"flag": _done_flag(int(d)), "op": "==", "value": true})
			avail.append({"all": reqs})
		# Add any additional custom availability conditions.
		var custom_avail = q.get("availability_conditions", null)
		if custom_avail is Array:
			for c in (custom_avail as Array):
				avail.append(c)
		n.availability_conditions = avail

		# Completion conditions
		var compl: Array = []
		var custom_comp = q.get("completion_conditions", null)
		if custom_comp is Array:
			compl = custom_comp
		else:
			compl = [{"flag": _ready_flag(qid), "op": "==", "value": true}]
		n.completion_conditions = compl

		# Outcomes
		var outcomes: Array = []
		outcomes.append({"set_flag": _done_flag(qid), "value": true})
		outcomes.append({"set_flag": _active_flag(qid), "value": false})
		outcomes.append({"set_flag": _ready_flag(qid), "value": false})
		var extra = q.get("outcomes", [])
		if extra is Array:
			for eff in (extra as Array):
				outcomes.append(eff)
		n.outcomes = outcomes

		n.is_terminal = bool(q.get("is_terminal", false))
		g.nodes.append(n)
	g.ensure_initialized()
	return g

func _node_id(quest_id: int) -> String:
	if quest_id <= 0:
		return ""
	return "Q%s" % str(quest_id).pad_zeros(3)

func _start_flag(quest_id: int) -> String:
	return "Q_START_%s" % str(quest_id).pad_zeros(3)

func _active_flag(quest_id: int) -> String:
	return "Q_ACTIVE_%s" % str(quest_id).pad_zeros(3)

func _ready_flag(quest_id: int) -> String:
	return "Q_READY_%s" % str(quest_id).pad_zeros(3)

func _done_flag(quest_id: int) -> String:
	return "Q_DONE_%s" % str(quest_id).pad_zeros(3)
