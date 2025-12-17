class_name StreamTests
extends RefCounted

static func run() -> Dictionary:
	var results := {"ok": true, "checks": []}

	WorldSys.ensure_initialized()
	var ids: Array = WorldSys.get_all_region_ids()
	if ids.is_empty():
		return _fail(results, "no_regions_indexed")

	# Stress: teleport around region centers; ensure <= max_simultaneous loaded.
	var max_regions: int = max(1, Config.max_simultaneous_regions)
	for rid in ids:
		var center := WorldSys.get_region_center_px(str(rid))
		WorldSys.debug_stream_tick_at(center)
		var loaded: Array = WorldSys.get_loaded_region_ids()
		if loaded.size() > max_regions:
			return _fail(results, "loaded_exceeds_limit")

	results.checks.append({"ok": true, "name": "stream_limit", "detail": "<=%d" % max_regions})
	return results

static func _fail(results: Dictionary, reason: String) -> Dictionary:
	results.ok = false
	results.checks.append({"ok": false, "name": "fail", "detail": reason})
	return results
