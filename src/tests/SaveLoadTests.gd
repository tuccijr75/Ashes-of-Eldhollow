class_name SaveLoadTests
extends RefCounted

static func run() -> Dictionary:
	var results := {"ok": true, "checks": []}

	# Save baseline
	Game.ensure_initialized()
	RNG.set_seed(777)
	Game.chapter = "II"
	Game.set_flag("CITY_ALERT", 2)
	QuestSys.start_quest(1)
	WorldFlags.set_flag("Q_READY_001", true)
	QuestSys.complete_quest(1)
	WorldSys.get_or_create_procedural("t_proc", "crypt", 123)
	WorldSys.mark_procedural_cleared("t_proc")

	var saved := SaveSys.save_game()
	if not saved:
		return _fail(results, "save_failed")
	results.checks.append({"ok": true, "name": "save", "detail": "ok"})

	# Mutate
	Game.chapter = "I"
	Game.set_flag("CITY_ALERT", 0)
	RNG.set_seed(1)
	WorldSys.force_regenerate_procedural("t_proc") # should refuse because cleared

	# Load
	var loaded := SaveSys.load_game()
	if not loaded:
		return _fail(results, "load_failed")

	# Validate restores
	if Game.chapter != "II":
		return _fail(results, "chapter_mismatch")
	if int(Game.get_flag("CITY_ALERT", -1)) != 2:
		return _fail(results, "flag_restore_failed")
	if RNG.get_seed() != 777:
		return _fail(results, "seed_restore_failed")
	if QuestSys.get_status(1) != "completed":
		return _fail(results, "quest_restore_failed")

	# Validate cleared procedural won't regenerate
	var ok_regen := WorldSys.force_regenerate_procedural("t_proc")
	if ok_regen:
		return _fail(results, "cleared_regenerated")

	results.checks.append({"ok": true, "name": "load", "detail": "restored chapter/flags/seed"})
	results.checks.append({"ok": true, "name": "quests", "detail": "quest state restored"})
	results.checks.append({"ok": true, "name": "procedural_cleared", "detail": "regen refused"})
	return results

static func _fail(results: Dictionary, reason: String) -> Dictionary:
	results.ok = false
	results.checks.append({"ok": false, "name": "fail", "detail": reason})
	return results
