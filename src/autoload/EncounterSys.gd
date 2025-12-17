extends Node

# Picks weighted random encounters from DB.encounters.
# Data source: res://data/encounters.json

func _ready() -> void:
	GameLog.info("EncounterSys", "Ready")

func _act_from_chapter(ch: String) -> String:
	var c := ch.strip_edges().to_upper()
	if c == "I" or c == "II" or c == "III":
		return c
	return "I"

func pick_spawn(region_name: String, chapter: String) -> Dictionary:
	# Returns {name, id, rare, prob, tier}
	var target_region := region_name.strip_edges()
	var act := _act_from_chapter(chapter)
	var buckets: Array = []
	for e_any in DB.encounters:
		if not (e_any is Dictionary):
			continue
		var e: Dictionary = e_any
		if str(e.get("region", "")) != target_region:
			continue
		if str(e.get("act", "")) != act:
			continue
		buckets = e.get("spawns", [])
		break
	if buckets.is_empty():
		return {}
	var total := 0.0
	for b in buckets:
		if b is Dictionary:
			total += float((b as Dictionary).get("prob", 0.0))
	if total <= 0.0:
		return {}
	var r := RNG.randf() * total
	var acc := 0.0
	for b2 in buckets:
		if not (b2 is Dictionary):
			continue
		var d: Dictionary = b2
		acc += float(d.get("prob", 0.0))
		if r <= acc:
			var tier := 1
			if bool(d.get("rare", false)):
				tier = 4
			elif act == "III":
				tier = 3
			elif act == "II":
				tier = 2
			return {
				"id": str(d.get("id", "")),
				"name": str(d.get("name", "Unknown")),
				"rare": bool(d.get("rare", false)),
				"prob": float(d.get("prob", 0.0)),
				"tier": tier
			}
	return {}
