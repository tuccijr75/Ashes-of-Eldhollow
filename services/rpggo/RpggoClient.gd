class_name RpggoClient
extends Node

const ENV_API_KEY := "RPGGO_API_KEY"
const ENV_GAME_ID := "RPGGO_GAME_ID"
const ENV_BASE_URL := "RPGGO_BASE_URL"

# Offline-first defaults: keep these small and never block gameplay.
const DEFAULT_TIMEOUT_SEC := 3.0

func is_configured() -> bool:
	return (not _api_key().is_empty()) and (not _game_id().is_empty()) and (not _base_url().is_empty())

func _api_key() -> String:
	return str(OS.get_environment(ENV_API_KEY)).strip_edges()

func _game_id() -> String:
	return str(OS.get_environment(ENV_GAME_ID)).strip_edges()

func _base_url() -> String:
	return str(OS.get_environment(ENV_BASE_URL)).strip_edges().trim_suffix("/")

func _headers() -> PackedStringArray:
	# Never log the api key.
	return PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"Authorization: Bearer %s" % _api_key(),
	])

func _endpoint(path: String) -> String:
	var p := path
	if not p.begins_with("/"):
		p = "/" + p
	return _base_url() + p

func _make_request_node(timeout_sec: float) -> HTTPRequest:
	var req := HTTPRequest.new()
	req.timeout = maxf(0.1, timeout_sec)
	add_child(req)
	return req

func request_json(path: String, payload: Dictionary, timeout_sec: float = DEFAULT_TIMEOUT_SEC) -> Dictionary:
	# Returns: { ok:bool, status:int, data:Variant, error:String }
	if not is_configured():
		return {"ok": false, "status": 0, "data": null, "error": "not_configured"}

	var url := _endpoint(path)
	var body := JSON.stringify(payload)
	var req := _make_request_node(timeout_sec)
	var err := req.request(url, _headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "status": 0, "data": null, "error": "request_failed_%s" % str(err)}

	var completed := await req.request_completed
	req.queue_free()

	var result_code := int(completed[0])
	var status := int(completed[1])
	var response_body: PackedByteArray = completed[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": status, "data": null, "error": "http_result_%s" % str(result_code)}

	var text := response_body.get_string_from_utf8()
	if text.is_empty():
		return {"ok": (status >= 200 and status < 300), "status": status, "data": {}, "error": ""}

	var parsed := JSON.parse_string(text)
	if parsed == null:
		return {"ok": false, "status": status, "data": null, "error": "invalid_json"}

	return {"ok": (status >= 200 and status < 300), "status": status, "data": parsed, "error": ""}

# Canon flows (doc-aligned)
func world_sync(context: String, timeout_sec: float = DEFAULT_TIMEOUT_SEC) -> Dictionary:
	var payload := {
		"game_id": _game_id(),
		"context": context
	}
	return await request_json("/world/state", payload, timeout_sec)

func submit_event(event_id: String, player_state: Dictionary, world_state: Dictionary, timeout_sec: float = DEFAULT_TIMEOUT_SEC) -> Dictionary:
	var payload := {
		"game_id": _game_id(),
		"event": event_id,
		"player_state": player_state,
		"world_state": world_state
	}
	return await request_json("/world/event", payload, timeout_sec)

func npc_dialogue(npc_id: String, player_state: Dictionary, world_state: Dictionary, context: Dictionary, timeout_sec: float = DEFAULT_TIMEOUT_SEC) -> Dictionary:
	var payload := {
		"game_id": _game_id(),
		"npc_id": npc_id,
		"player_state": player_state,
		"world_state": world_state,
		"context": context
	}
	return await request_json("/npc/dialogue", payload, timeout_sec)
