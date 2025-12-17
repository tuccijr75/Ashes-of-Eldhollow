class_name ProceduralTests
extends RefCounted

static func run() -> Dictionary:
	var results := {"ok": true, "cases": []}
	var profiles := ["crypt", "cave", "ruin", "arena"]
	for p in profiles:
		for s in [1, 2, 3, 42, 1337, 9999]:
			var gen := ProceduralDungeon.generate(p, s)
			var grid: Array = gen.get("grid", [])
			var entrance: Vector2i = gen.get("entrance", Vector2i.ZERO)
			var exit: Vector2i = gen.get("exit", Vector2i.ZERO)
			var v := MapValidator.validate(grid, entrance, exit)
			var ok := bool(v.get("ok", false))
			results.cases.append({"profile": p, "seed": s, "ok": ok, "reason": v.get("reason", "")})
			if not ok:
				results.ok = false
	return results
