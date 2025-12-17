class_name ProceduralProfiles
extends RefCounted

static func get_profile(profile_id: String) -> Dictionary:
	match profile_id:
		"crypt":
			return {
				"id": "crypt",
				"algorithm": "bsp",
				"width": 56,
				"height": 40,
				"room_min": Vector2i(5, 5),
				"room_max": Vector2i(11, 9),
				"max_depth": 4
			}
		"cave":
			return {
				"id": "cave",
				"algorithm": "cellular",
				"width": 60,
				"height": 44,
				"fill_prob": 0.45,
				"steps": 5
			}
		"ruin":
			return {
				"id": "ruin",
				"algorithm": "room_graph",
				"width": 64,
				"height": 48,
				"room_count": 10,
				"room_min": Vector2i(5, 5),
				"room_max": Vector2i(12, 10)
			}
		"arena":
			return {
				"id": "arena",
				"algorithm": "fixed",
				"width": 40,
				"height": 28
			}
		_:
			return {}
