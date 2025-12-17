class_name TestRunner
extends RefCounted

func run_all() -> Dictionary:
	var out := {"ok": true, "suites": []}
	for suite in [
		{"name": "procedural", "fn": func(): return run_procedural_tests()},
		{"name": "quests", "fn": func(): return run_quest_tests()},
		{"name": "save_load", "fn": func(): return run_save_load_tests()},
		{"name": "stream", "fn": func(): return run_stream_tests()},
	]:
		var res: Dictionary = (suite.fn as Callable).call()
		out.suites.append({"name": suite.name, "ok": res.get("ok", false), "detail": res})
		if not bool(res.get("ok", false)):
			out.ok = false
	return out

func run_procedural_tests() -> Dictionary:
	var res := ProceduralTests.run()
	if bool(res.get("ok", false)):
		GameLog.info("Tests", "Procedural tests OK")
	else:
		GameLog.error("Tests", "Procedural tests FAILED")
		for c in res.get("cases", []):
			if not bool(c.get("ok", false)):
				GameLog.error("Tests", "Case failed: %s" % JSON.stringify(c))
	return res

func run_quest_tests() -> Dictionary:
	var res := QuestTests.run()
	if bool(res.get("ok", false)):
		GameLog.info("Tests", "Quest tests OK")
	else:
		GameLog.error("Tests", "Quest tests FAILED")
		GameLog.error("Tests", JSON.stringify(res))
	return res

func run_save_load_tests() -> Dictionary:
	var res := SaveLoadTests.run()
	if bool(res.get("ok", false)):
		GameLog.info("Tests", "Save/load tests OK")
	else:
		GameLog.error("Tests", "Save/load tests FAILED")
		GameLog.error("Tests", JSON.stringify(res))
	return res

func run_stream_tests() -> Dictionary:
	var res := StreamTests.run()
	if bool(res.get("ok", false)):
		GameLog.info("Tests", "Stream tests OK")
	else:
		GameLog.error("Tests", "Stream tests FAILED")
		GameLog.error("Tests", JSON.stringify(res))
	return res
