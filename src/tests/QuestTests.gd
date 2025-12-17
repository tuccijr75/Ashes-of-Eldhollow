class_name QuestTests
extends RefCounted

static func run() -> Dictionary:
	var results := {"ok": true, "checks": []}
	var quests: Array = DB.quests

	# Quest data lives in data/quests.json which DB loads

	if quests.is_empty():
		return _fail(results, "quests_empty")
	var quest_count := quests.size()
	results.checks.append({"ok": true, "name": "quests_count", "detail": "%d" % quest_count})

	# Canonical quest_id in quests.json is a string (for RPGGO event alignment).
	# Runtime numeric IDs are list-index-based: qid = i + 1.
	var canonical_ids := {}
	for q in quests:
		var cid := str(q.get("quest_id", "")).strip_edges()
		if cid.is_empty():
			return _fail(results, "quest_id_invalid")
		if canonical_ids.has(cid):
			return _fail(results, "quest_id_duplicate:%s" % cid)
		canonical_ids[cid] = true
	results.checks.append({"ok": true, "name": "quest_ids", "detail": "canonical quest_id strings unique"})

	# Dependency validation: no missing ids
	for i in range(quest_count):
		var qid := i + 1
		var q: Dictionary = quests[i]
		var deps: Array = q.get("dependencies", [])
		for d in deps:
			var dep_id := int(d)
			if dep_id < 1 or dep_id > quest_count:
				return _fail(results, "missing_dependency:%d->%d" % [qid, dep_id])
	results.checks.append({"ok": true, "name": "deps_known", "detail": "all deps refer to existing quests"})

	# Acyclic check via DFS
	var graph := {}
	for i in range(quest_count):
		graph[i + 1] = (quests[i] as Dictionary).get("dependencies", [])
	var visiting := {}
	var visited := {}
	for qid in range(1, quest_count + 1):
		if _dfs_cycle(qid, graph, visiting, visited):
			return _fail(results, "dependency_cycle_detected")
	results.checks.append({"ok": true, "name": "deps_acyclic", "detail": "no cycles"})

	# Authority web sanity: domains are constrained to a known set.
	var allowed := {"": true, "META": true, "INK": true, "BLOOD": true, "SILENCE": true, "DEBT": true, "WITNESS": true}
	for q in quests:
		var dom := str(q.get("authority_domain", "")).to_upper()
		if not allowed.has(dom):
			return _fail(results, "invalid_authority_domain:%s" % dom)
	results.checks.append({"ok": true, "name": "authority_domain", "detail": "domains valid"})

	# Dialog presence + no-dead-end validation
	for i in range(1, quest_count + 1):
		var p := "res://data/dialogs/quest_%s.json" % str(i).pad_zeros(3)
		if not FileAccess.file_exists(p):
			return _fail(results, "missing_dialog:%s" % p)
		var txt := FileAccess.get_file_as_string(p)
		var parsed = JSON.parse_string(txt)
		if parsed == null or not (parsed is Dictionary):
			return _fail(results, "invalid_dialog_json:%s" % p)
		var start := str(parsed.get("start", ""))
		var nodes = parsed.get("nodes")
		if start.is_empty() or nodes == null or not (nodes is Dictionary):
			return _fail(results, "dialog_schema:%s" % p)
		if not (nodes as Dictionary).has(start):
			return _fail(results, "dialog_missing_start:%s" % p)
		var has_complete := false
		for node_id in (nodes as Dictionary).keys():
			var node: Dictionary = (nodes as Dictionary)[node_id]
			if bool(node.get("end", false)):
				continue
			var choices: Array = node.get("choices", [])
			if choices.is_empty():
				return _fail(results, "dialog_dead_end:%s node=%s" % [p, str(node_id)])
			for c in choices:
				if not (c is Dictionary) or str((c as Dictionary).get("next", "")).is_empty():
					return _fail(results, "dialog_choice_invalid:%s node=%s" % [p, str(node_id)])
				var nxt := str((c as Dictionary).get("next"))
				if not (nodes as Dictionary).has(nxt):
					return _fail(results, "dialog_choice_missing_target:%s node=%s next=%s" % [p, str(node_id), nxt])
				var effects: Array = (c as Dictionary).get("effects", [])
				for e in effects:
					if e is Dictionary and int((e as Dictionary).get("complete_quest", -1)) == i:
						has_complete = true
		if not has_complete:
			return _fail(results, "dialog_missing_complete_effect:%s" % p)
	results.checks.append({"ok": true, "name": "dialogs_valid", "detail": "%d dialogs present and valid" % quest_count})

	return results

static func _dfs_cycle(node_id: int, graph: Dictionary, visiting: Dictionary, visited: Dictionary) -> bool:
	if visited.has(node_id):
		return false
	if visiting.has(node_id):
		return true
	visiting[node_id] = true
	var deps: Array = graph.get(node_id, [])
	for d in deps:
		if _dfs_cycle(int(d), graph, visiting, visited):
			return true
	visiting.erase(node_id)
	visited[node_id] = true
	return false

static func _fail(results: Dictionary, reason: String) -> Dictionary:
	results.ok = false
	results.checks.append({"ok": false, "name": "fail", "detail": reason})
	return results
