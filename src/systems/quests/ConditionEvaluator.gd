class_name ConditionEvaluator
extends RefCounted

# Evaluates simple condition DSL.
# Supported:
# - true/false
# - { flag: "KEY", op: "==|!=|<|<=|>|>=", value: X }
# - { has_flag: "KEY" }
# - { not: <cond> }
# - { any: [<cond>...] }
# - { all: [<cond>...] }
# - { var: "local_key", op: ..., value: ... }  (quest-local variables)

static func eval_condition(cond, flags: Node, local_vars: Dictionary = {}) -> bool:
	if cond == null:
		return false
	if cond is bool:
		return bool(cond)
	if cond is Dictionary:
		var d: Dictionary = cond
		if d.has("not"):
			return not eval_condition(d.get("not"), flags, local_vars)
		if d.has("any"):
			var arr: Array = d.get("any", [])
			for c in arr:
				if eval_condition(c, flags, local_vars):
					return true
			return false
		if d.has("all"):
			var arr2: Array = d.get("all", [])
			for c2 in arr2:
				if not eval_condition(c2, flags, local_vars):
					return false
			return true

		if d.has("count_true"):
			# { count_true: ["FLAG_A", "FLAG_B"], op: ">=", value: 2 }
			var keys: Array = d.get("count_true", [])
			var op_ct := str(d.get("op", ">="))
			var target_ct := int(d.get("value", 0))
			var ct := 0
			for k_any in keys:
				var k := str(k_any)
				if k.is_empty():
					continue
				if bool(_get_flag(flags, k)):
					ct += 1
			return _compare(ct, op_ct, target_ct)

		if d.has("has_flag"):
			var k := str(d.get("has_flag", ""))
			if k.is_empty():
				return false
			return _has_flag(flags, k)

		if d.has("var"):
			var lk := str(d.get("var", ""))
			var op := str(d.get("op", "=="))
			var target = d.get("value")
			var actual = local_vars.get(lk, null)
			return _compare(actual, op, target)

		if d.has("flag"):
			var fk := str(d.get("flag", ""))
			var op2 := str(d.get("op", "=="))
			var target2 = d.get("value")
			var actual2 = _get_flag(flags, fk)
			return _compare(actual2, op2, target2)

	return false

static func _get_flag(flags: Node, key: String):
	if flags == null:
		return null
	if flags.has_method("get_flag"):
		return flags.call("get_flag", key, null)
	return null

static func _has_flag(flags: Node, key: String) -> bool:
	if flags == null:
		return false
	if flags.has_method("export_flags"):
		var d = flags.call("export_flags")
		return (d is Dictionary) and (d as Dictionary).has(key)
	return false

static func _compare(actual, op: String, target) -> bool:
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
			return false
