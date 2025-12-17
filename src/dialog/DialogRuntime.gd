class_name DialogRuntime
extends RefCounted

var quest_id: int = 0
var start_node: String = ""
var nodes: Dictionary = {}
var current_node_id: String = ""

var _warned: Dictionary = {} # key -> true

func load_from_path(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		GameLog.error("Dialog", "Missing dialog file: %s" % path)
		return false
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed == null or not (parsed is Dictionary):
		GameLog.error("Dialog", "Invalid dialog JSON: %s" % path)
		return false
	quest_id = int((parsed as Dictionary).get("quest_id", 0))
	start_node = str((parsed as Dictionary).get("start", ""))
	nodes = (parsed as Dictionary).get("nodes", {})
	if start_node.is_empty() or nodes.is_empty() or not nodes.has(start_node):
		GameLog.error("Dialog", "Dialog schema missing start/nodes: %s" % path)
		return false
	current_node_id = start_node
	return true

func is_finished() -> bool:
	var node := get_current_node()
	return bool(node.get("end", false))

func get_current_node() -> Dictionary:
	if current_node_id.is_empty() or not nodes.has(current_node_id):
		return {}
	var n = nodes[current_node_id]
	return n if (n is Dictionary) else {}

func get_speaker() -> String:
	return str(get_current_node().get("speaker", ""))

func get_text() -> String:
	return str(get_current_node().get("text", ""))

func get_choices() -> Array:
	var node := get_current_node()
	var choices: Array = node.get("choices", [])
	if choices.is_empty():
		return []
	var out: Array = []
	for c in choices:
		if not (c is Dictionary):
			continue
		var conds: Array = (c as Dictionary).get("conditions", [])
		if _eval_conditions(conds):
			out.append(c)
	return out

func choose(choice_index_1_based: int) -> bool:
	var choices := get_choices()
	if choices.is_empty():
		return false
	var i := choice_index_1_based - 1
	if i < 0 or i >= choices.size():
		return false
	var c = choices[i]
	if not (c is Dictionary):
		return false
	_apply_effects((c as Dictionary).get("effects", []))
	var next_id := str((c as Dictionary).get("next", ""))
	if next_id.is_empty() or not nodes.has(next_id):
		return false
	current_node_id = next_id
	return true

func _eval_conditions(conditions: Array) -> bool:
	# Empty means "always available".
	if conditions.is_empty():
		return true
	for cond in conditions:
		if not _eval_condition(cond):
			return false
	return true

func _eval_condition(cond) -> bool:
	# Supported forms (best-effort):
	# - { flag, op, value }
	# - { has_flag }
	# - { not: {..} }
	# - { any: [..] } / { all: [..] }
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
		return Game.flags.has(fid)

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

func _apply_effects(effects) -> void:
	if effects == null:
		return
	if not (effects is Array):
		_warn_once("effects_type", "Unsupported effects type")
		return
	for eff in (effects as Array):
		_apply_effect(eff)

func _apply_effect(eff) -> void:
	# Supported forms (best-effort):
	# - { set_flag, value }
	# - { inc_flag, delta }
	# - { clear_flag }
	# - { start_quest }
	# - { complete_quest }
	# - { set_chapter }
	# - { set_seed }
	# - { set_clause }
	# - { grant_seal }
	# - { set_censure_mode }
	# - { compute_boss_unlock }
	if eff == null:
		return
	if not (eff is Dictionary):
		_warn_once("eff_type", "Unsupported effect type")
		return
	var d: Dictionary = eff
	if d.has("set_flag"):
		var fid := str(d.get("set_flag", ""))
		if fid.is_empty():
			return
		Game.set_flag(fid, d.get("value"))
		return
	if d.has("inc_flag"):
		var fid2 := str(d.get("inc_flag", ""))
		if fid2.is_empty():
			return
		var delta := int(d.get("delta", 1))
		var cur := int(Game.get_flag(fid2, 0))
		Game.set_flag(fid2, cur + delta)
		return
	if d.has("clear_flag"):
		var fid3 := str(d.get("clear_flag", ""))
		if fid3.is_empty():
			return
		Game.flags.erase(fid3)
		return
	if d.has("set_chapter"):
		Game.chapter = str(d.get("set_chapter", Game.chapter))
		return
	if d.has("set_seed"):
		RNG.set_seed(int(d.get("set_seed", RNG.get_seed())))
		return
	if d.has("start_quest"):
		var qid := int(d.get("start_quest", 0))
		if qid > 0:
			QuestSys.start_quest(qid)
		return
	if d.has("complete_quest"):
		var qid2 := int(d.get("complete_quest", 0))
		if qid2 > 0:
			# Mark requirements satisfied for the console/dialog-driven completion model.
			Game.set_flag("Q_READY_%s" % str(qid2).pad_zeros(3), true)
			QuestSys.complete_quest(qid2)
		return
	if d.has("set_clause"):
		var clause := str(d.get("set_clause", ""))
		if not clause.is_empty():
			# Set once; ignored if already set.
			var cur := WorldFlags.get_string("CLAUSE_SET", "")
			if cur.is_empty():
				WorldFlags.set_flag("CLAUSE_SET", clause)
		return
	if d.has("grant_seal"):
		var seal := str(d.get("grant_seal", ""))
		if not seal.is_empty():
			WorldFlags.set_flag("SEAL_%s" % seal.to_upper(), true)
		return
	if d.has("set_censure_mode"):
		WorldFlags.set_flag("CENSURE_MODE", str(d.get("set_censure_mode")))
		return
	if d.has("compute_boss_unlock"):
		QuestDirector.compute_boss_unlock()
		return
	_warn_once("eff_unknown", "Unknown effect keys")

func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	GameLog.warn("Dialog", "%s (key=%s)" % [msg, key])
