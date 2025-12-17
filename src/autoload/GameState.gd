extends Node

# RPGGO-aware narrative state container.
# This does NOT own combat/physics or moment-to-moment simulation.
# Offline-first: all network operations are best-effort and time-bounded.

const DEFAULT_SYNC_TIMEOUT_SEC := 3.0

const RPGGO_CLIENT_SCRIPT := preload("res://services/rpggo/RpggoClient.gd")

var rpggo_world_state: Dictionary = {}
var rpggo_player_state: Dictionary = {}
var last_rpggo_sync_unix: int = 0

# Backing cache blob (will be persisted under SaveSys.rpggo_cache in a later step).
var rpggo_cache: Dictionary = {
	"world_state": {},
	"player_state": {},
	"npc_dialogue": {},
	"last_sync_unix": 0,
	"pending_events": []
}

var _client: Node
var _initialized := false

var _last_zone_sync_region: String = ""
var _last_zone_sync_unix: int = 0
const ZONE_SYNC_COOLDOWN_SEC := 10

func get_save_blob() -> Dictionary:
	# Persist only cache/state (never credentials). Backward compatible.
	ensure_initialized()
	return {
		"version": 1,
		"cache": rpggo_cache.duplicate(true)
	}

func load_from_save_blob(blob) -> void:
	ensure_initialized()
	if blob == null or not (blob is Dictionary):
		return
	var d: Dictionary = blob
	# Accept either {cache:{...}} or a raw cache dictionary.
	var cache_in = d.get("cache", d)
	if not (cache_in is Dictionary):
		return
	rpggo_cache = (cache_in as Dictionary).duplicate(true)
	# Restore convenience mirrors.
	rpggo_world_state = (rpggo_cache.get("world_state", {}) as Dictionary).duplicate(true)
	rpggo_player_state = (rpggo_cache.get("player_state", {}) as Dictionary).duplicate(true)
	last_rpggo_sync_unix = int(rpggo_cache.get("last_sync_unix", 0))
	# Ensure required cache keys exist.
	if not rpggo_cache.has("pending_events"):
		rpggo_cache["pending_events"] = []

func _ready() -> void:
	ensure_initialized()
	_wire_world_signals()

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_client = RPGGO_CLIENT_SCRIPT.new()
	add_child(_client)
	GameLog.info("GameState", "Ready")

func _wire_world_signals() -> void:
	var ws := get_node_or_null("/root/WorldSys")
	if ws == null:
		return
	if ws.has_signal("player_region_changed"):
		ws.connect("player_region_changed", Callable(self, "_on_player_region_changed"))

func _on_player_region_changed(new_region_id: String, _old_region_id: String) -> void:
	# Zone-based sync: best-effort, time-bounded, never blocks gameplay.
	if not rpggo_enabled():
		return
	var now := _now_unix()
	if new_region_id == _last_zone_sync_region and (now - _last_zone_sync_unix) < ZONE_SYNC_COOLDOWN_SEC:
		return
	_last_zone_sync_region = new_region_id
	_last_zone_sync_unix = now
	# World sync is also a good opportunity to flush any offline events.
	rpggo_world_sync("zone_enter:%s" % new_region_id, Callable(self, "_on_zone_sync_done"))

func _on_zone_sync_done(res: Dictionary) -> void:
	if bool(res.get("ok", false)):
		flush_pending_events()

# --- Narrative event API (canonical IDs only; see res://data/rpggo_events.gd) ---

func emit_narrative_event(event_id: String, local_context: Dictionary = {}) -> void:
	# Offline-first:
	# - Always apply local deterministic meaning (WorldFlags)
	# - Queue events while offline
	# - Best-effort flush when online
	var eid := event_id.strip_edges()
	if eid.is_empty():
		return
	WorldFlags.set_flag(eid, true)
	_enqueue_event(eid, local_context)
	flush_pending_events()

func _enqueue_event(event_id: String, local_context: Dictionary) -> void:
	var q: Array = rpggo_cache.get("pending_events", [])
	if not (q is Array):
		q = []
	# De-dupe: if already pending, keep earliest.
	for e in q:
		if e is Dictionary and str((e as Dictionary).get("id", "")) == event_id:
			return
	q.append({"id": event_id, "ts": _now_unix(), "ctx": local_context.duplicate(true)})
	rpggo_cache["pending_events"] = q

func flush_pending_events(timeout_sec: float = DEFAULT_SYNC_TIMEOUT_SEC) -> void:
	# Non-blocking: send pending events sequentially, stop on first failure.
	if not rpggo_enabled():
		return
	call_deferred("_flush_pending_events_async", timeout_sec)

func _flush_pending_events_async(timeout_sec: float) -> void:
	var q: Array = rpggo_cache.get("pending_events", [])
	if not (q is Array) or q.is_empty():
		return
	var next_q: Array = []
	for e in q:
		if not (e is Dictionary):
			continue
		var eid := str((e as Dictionary).get("id", "")).strip_edges()
		if eid.is_empty():
			continue
		var res: Dictionary = await _client.call("submit_event", eid, rpggo_player_state, rpggo_world_state, timeout_sec)
		if not bool(res.get("ok", false)):
			# Keep the failed event (and the remainder) for later.
			next_q.append(e)
			var idx := q.find(e)
			if idx >= 0:
				for j in range(idx + 1, q.size()):
					next_q.append(q[j])
			break
		# Successful mutation should update our cached state.
		var data = res.get("data", {})
		if data is Dictionary:
			if (data as Dictionary).has("world_state"):
				rpggo_world_state = (data as Dictionary).get("world_state", {})
			if (data as Dictionary).has("player_state"):
				rpggo_player_state = (data as Dictionary).get("player_state", {})
		rpggo_cache["world_state"] = rpggo_world_state.duplicate(true)
		rpggo_cache["player_state"] = rpggo_player_state.duplicate(true)
		rpggo_cache["last_sync_unix"] = _now_unix()

	rpggo_cache["pending_events"] = next_q

func rpggo_enabled() -> bool:
	ensure_initialized()
	return _client != null and _client.has_method("is_configured") and bool(_client.call("is_configured"))

func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())

func _hash_state(d: Dictionary) -> int:
	# Used for cheap cache invalidation.
	return hash(JSON.stringify(d))

# --- Canon flows (non-blocking wrappers) ---

func rpggo_world_sync(context: String, callback: Callable = Callable(), timeout_sec: float = DEFAULT_SYNC_TIMEOUT_SEC) -> void:
	# Fire-and-forget; invokes callback with {ok,status,world_state?,raw?,error?}
	ensure_initialized()
	call_deferred("_rpggo_world_sync_async", context, callback, timeout_sec)

func _rpggo_world_sync_async(context: String, callback: Callable, timeout_sec: float) -> void:
	if not rpggo_enabled():
		if callback.is_valid():
			callback.call({"ok": false, "error": "not_configured"})
		return
	var res: Dictionary = await _client.call("world_sync", context, timeout_sec)
	var out := {"ok": bool(res.get("ok", false)), "status": int(res.get("status", 0)), "raw": res}
	if bool(res.get("ok", false)):
		var data = res.get("data", {})
		if data is Dictionary and (data as Dictionary).has("world_state"):
			rpggo_world_state = (data as Dictionary).get("world_state", {})
		else:
			# Some APIs may return the blob directly.
			rpggo_world_state = data if (data is Dictionary) else {}
		last_rpggo_sync_unix = _now_unix()
		rpggo_cache["world_state"] = rpggo_world_state.duplicate(true)
		rpggo_cache["last_sync_unix"] = last_rpggo_sync_unix
		out["world_state"] = rpggo_world_state
	else:
		GameLog.warn("RPGGO", "World sync failed: %s" % str(res.get("error", "")))
	if callback.is_valid():
		callback.call(out)

func rpggo_submit_event(event_id: String, callback: Callable = Callable(), timeout_sec: float = DEFAULT_SYNC_TIMEOUT_SEC) -> void:
	ensure_initialized()
	call_deferred("_rpggo_submit_event_async", event_id, callback, timeout_sec)

func _rpggo_submit_event_async(event_id: String, callback: Callable, timeout_sec: float) -> void:
	if not rpggo_enabled():
		if callback.is_valid():
			callback.call({"ok": false, "error": "not_configured"})
		return
	var res: Dictionary = await _client.call("submit_event", event_id, rpggo_player_state, rpggo_world_state, timeout_sec)
	var out := {"ok": bool(res.get("ok", false)), "status": int(res.get("status", 0)), "raw": res}
	if bool(res.get("ok", false)):
		var data = res.get("data", {})
		if data is Dictionary:
			if (data as Dictionary).has("world_state"):
				rpggo_world_state = (data as Dictionary).get("world_state", {})
			if (data as Dictionary).has("player_state"):
				rpggo_player_state = (data as Dictionary).get("player_state", {})
		last_rpggo_sync_unix = _now_unix()
		rpggo_cache["world_state"] = rpggo_world_state.duplicate(true)
		rpggo_cache["player_state"] = rpggo_player_state.duplicate(true)
		rpggo_cache["last_sync_unix"] = last_rpggo_sync_unix
		out["world_state"] = rpggo_world_state
		out["player_state"] = rpggo_player_state
	else:
		GameLog.warn("RPGGO", "Event submit failed: %s" % str(res.get("error", "")))
	if callback.is_valid():
		callback.call(out)

func rpggo_get_npc_dialogue(npc_id: String, local_context: Dictionary, callback: Callable, timeout_sec: float = DEFAULT_SYNC_TIMEOUT_SEC) -> void:
	# Uses cache aggressively; callback receives {ok,text,tone,raw?,cached?}
	ensure_initialized()
	call_deferred("_rpggo_get_npc_dialogue_async", npc_id, local_context, callback, timeout_sec)

func _rpggo_get_npc_dialogue_async(npc_id: String, local_context: Dictionary, callback: Callable, timeout_sec: float) -> void:
	var npc_key := npc_id.strip_edges()
	if npc_key.is_empty():
		if callback.is_valid():
			callback.call({"ok": false, "error": "missing_npc_id"})
		return

	var world_hash := _hash_state(rpggo_world_state)
	var cache: Dictionary = rpggo_cache.get("npc_dialogue", {})
	if cache.has(npc_key):
		var entry: Dictionary = cache[npc_key]
		if int(entry.get("world_hash", -1)) == world_hash:
			if callback.is_valid():
				callback.call({
					"ok": true,
					"text": str(entry.get("text", "")),
					"tone": str(entry.get("tone", "")),
					"cached": true
				})
			return

	if not rpggo_enabled():
		if callback.is_valid():
			callback.call({"ok": false, "error": "not_configured"})
		return

	var ctx := local_context.duplicate(true)
	if not ctx.has("recent_events"):
		ctx["recent_events"] = []
	var res: Dictionary = await _client.call("npc_dialogue", npc_key, rpggo_player_state, rpggo_world_state, ctx, timeout_sec)
	if not bool(res.get("ok", false)):
		GameLog.warn("RPGGO", "NPC dialogue failed (%s): %s" % [npc_key, str(res.get("error", ""))])
		if callback.is_valid():
			callback.call({"ok": false, "raw": res, "error": str(res.get("error", ""))})
		return

	var data = res.get("data", {})
	var text := ""
	var tone := ""
	if data is Dictionary:
		text = str((data as Dictionary).get("dialogue", (data as Dictionary).get("text", "")))
		tone = str((data as Dictionary).get("tone", ""))
	else:
		text = str(data)

	# Update cache
	var entry := {
		"text": text,
		"tone": tone,
		"world_hash": world_hash,
		"ts": _now_unix()
	}
	cache[npc_key] = entry
	rpggo_cache["npc_dialogue"] = cache

	if callback.is_valid():
		callback.call({"ok": true, "text": text, "tone": tone, "raw": res, "cached": false})
