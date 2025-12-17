class_name SimpleDialogRuntime
extends RefCounted

# Supports legacy/simple dialog schema used under res://dialogs/dlg_*.json:
# [
#   { speaker, line, choices:[ {text, flags:[...], outcome, toggle_flag, set_flag, value, start_quest, complete_quest, checkpoint }, ... ] },
#   ...
# ]
#
# This runtime is intentionally small and only implements effects we can support
# in the current Godot build (flags + quests).

var dialog_id: String = ""
var nodes: Array = []
var index: int = 0

var _warned: Dictionary = {} # key -> true
var _applied_nodes: Dictionary = {} # index -> true

func load_from_path(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		GameLog.error("Dialog", "Missing dialog file: %s" % path)
		return false
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed == null or not (parsed is Array):
		GameLog.error("Dialog", "Invalid simple dialog JSON (expected Array): %s" % path)
		return false
	nodes = parsed as Array
	index = 0
	dialog_id = path
	_applied_nodes = {}
	_normalize_index_to_visible()
	return nodes.size() > 0

func is_finished() -> bool:
	_normalize_index_to_visible()
	return index < 0 or index >= nodes.size()

func _cur_node() -> Dictionary:
	_normalize_index_to_visible()
	if is_finished():
		return {}
	var n = nodes[index]
	return n if (n is Dictionary) else {}

func _normalize_index_to_visible() -> void:
	# Skip conditional nodes that shouldn't be shown.
	while index >= 0 and index < nodes.size():
		var n = nodes[index]
		if not (n is Dictionary):
			break
		var nd := n as Dictionary
		var conds: Array = nd.get("conditions", [])
		if conds.is_empty() or _eval_conditions(conds):
			if not _applied_nodes.has(index):
				_applied_nodes[index] = true
				var nf: Array = nd.get("flags", [])
				for f in nf:
					var fid := str(f)
					if not fid.is_empty():
						Game.set_flag(fid, true)
			break
		index += 1

func get_speaker() -> String:
	return str(_cur_node().get("speaker", ""))

func get_text() -> String:
	# Legacy schema uses "line".
	return str(_cur_node().get("line", ""))

func get_choices() -> Array:
	var n := _cur_node()
	var ch: Array = n.get("choices", [])
	if ch.is_empty():
		return []
	var out: Array = []
	for c in ch:
		if not (c is Dictionary):
			continue
		var cd := c as Dictionary
		if str(cd.get("text", "")).length() <= 0:
			continue
		var conds: Array = cd.get("conditions", [])
		if _eval_conditions(conds):
			out.append(cd)
	return out

func advance() -> bool:
	# Move forward for nodes that have no choices.
	if is_finished():
		return false
	index += 1
	_normalize_index_to_visible()
	return not is_finished()

func choose(choice_index_1_based: int) -> bool:
	_normalize_index_to_visible()
	var choices := get_choices()
	if choices.is_empty():
		return false
	var i := choice_index_1_based - 1
	if i < 0 or i >= choices.size():
		return false
	var c = choices[i]
	if not (c is Dictionary):
		return false
	_apply_choice_effects(c as Dictionary)
	# Optional explicit next index.
	if (c as Dictionary).has("next"):
		index = int((c as Dictionary).get("next", index + 1))
	else:
		# Default behavior: continue to the next node.
		index += 1
	_normalize_index_to_visible()
	return true

func _eval_conditions(conditions: Array) -> bool:
	if conditions.is_empty():
		return true
	for cond in conditions:
		if not _eval_condition(cond):
			return false
	return true

func _eval_condition(cond) -> bool:
	# Mirrors DialogRuntime condition support.
	if cond == null:
		return false
	if cond is bool:
		return bool(cond)
	if not (cond is Dictionary):
		_warn_once("cond_type", "Unsupported condition type")
		return false
	var d: Dictionary = cond

	if d.has("not"):
		return not _eval_condition(d.get("not"))
	if d.has("any"):
		var arr: Array = d.get("any", [])
		for c in arr:
			if _eval_condition(c):
				return true
		return false
	if d.has("all"):
		var arr2: Array = d.get("all", [])
		for c2 in arr2:
			if not _eval_condition(c2):
				return false
		return true

	if d.has("has_flag"):
		var fid := str(d.get("has_flag", ""))
		if fid.is_empty():
			return false
		return bool(Game.get_flag(fid, false))

	if d.has("flag"):
		var flag_id := str(d.get("flag", ""))
		var op := str(d.get("op", "=="))
		var target = d.get("value")
		var actual = Game.get_flag(flag_id, null)
		return _compare(actual, op, target)

	_warn_once("cond_unknown", "Unknown condition keys")
	return false

func _compare(actual, op: String, target) -> bool:
	match op:
		"==":
			return actual == target
		"!=":
			return actual != target
		">":
			return float(actual) > float(target)
		">=":
			return float(actual) >= float(target)
		"<":
			return float(actual) < float(target)
		"<=":
			return float(actual) <= float(target)
		_:
			_warn_once("op:%s" % op, "Unknown compare op")
			return false

func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	GameLog.warn("Dialog", "%s (key=%s)" % [msg, key])

func _apply_choice_effects(c: Dictionary) -> void:
	# flags: ["a","b"] => set true
	var flags_arr: Array = c.get("flags", [])
	for f in flags_arr:
		var fid := str(f)
		if not fid.is_empty():
			Game.set_flag(fid, true)

	if c.has("set_flag"):
		var k := str(c.get("set_flag", ""))
		if not k.is_empty():
			Game.set_flag(k, c.get("value"))

	if c.has("toggle_flag"):
		var t := str(c.get("toggle_flag", ""))
		if not t.is_empty():
			var cur := bool(Game.get_flag(t, false))
			Game.set_flag(t, not cur)

	if c.has("start_quest"):
		var qid := int(c.get("start_quest", 0))
		if qid > 0:
			QuestSys.start_quest(qid)

	if c.has("start_next_available_quest"):
		var loc := str(c.get("start_next_available_quest", "")).strip_edges().to_lower()
		if not loc.is_empty():
			_start_next_available_quest(loc)

	if c.has("complete_quest"):
		var qid2 := int(c.get("complete_quest", 0))
		if qid2 > 0:
			Game.set_flag("Q_READY_%s" % str(qid2).pad_zeros(3), true)
			QuestSys.complete_quest(qid2)

	var outcome := str(c.get("outcome", ""))
	match outcome:
		"set_checkpoint":
			# Store a lightweight checkpoint marker.
			var cp := str(c.get("checkpoint", ""))
			if cp.is_empty():
				cp = dialog_id
			Game.set_flag("CHECKPOINT", cp)
			return
		"toggle_flag":
			# Support legacy outcome form.
			var tf := str(c.get("toggle_flag", ""))
			if not tf.is_empty():
				var cur2 := bool(Game.get_flag(tf, false))
				Game.set_flag(tf, not cur2)
			return
		"start_quest":
			var qid3 := int(c.get("start_quest", 0))
			if qid3 > 0:
				QuestSys.start_quest(qid3)
			return
		"complete_quest":
			var qid4 := int(c.get("complete_quest", 0))
			if qid4 > 0:
				Game.set_flag("Q_READY_%s" % str(qid4).pad_zeros(3), true)
				QuestSys.complete_quest(qid4)
			return
		_:
			return

func _start_next_available_quest(location_key: String) -> void:
	var best := 0
	for i in range(DB.quests.size()):
		var q_any = DB.quests[i]
		if not (q_any is Dictionary):
			continue
		var q: Dictionary = q_any
		if str(q.get("location", "")).to_lower() != location_key:
			continue
		var qid := i + 1
		if QuestSys.can_start(qid):
			if best == 0 or qid < best:
				best = qid
	if best > 0:
		QuestSys.start_quest(best)
