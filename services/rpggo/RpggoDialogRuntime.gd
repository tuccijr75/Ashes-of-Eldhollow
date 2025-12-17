class_name RpggoDialogRuntime
extends RefCounted

# Minimal runtime adapter to show RPGGO dialogue in the existing DialogOverlay.
# Offline-first: if the fetch fails, it falls back to a provided text.

var npc_id: String = ""
var speaker: String = ""
var _text: String = ""

var _requested := false
var _finished := false

var _on_updated: Callable = Callable()

func _init(_npc_id: String, _speaker: String, fallback_text: String) -> void:
	npc_id = _npc_id
	speaker = _speaker
	_text = fallback_text

func is_finished() -> bool:
	return _finished

func get_speaker() -> String:
	return speaker

func get_text() -> String:
	return _text

func get_choices() -> Array:
	return []

func choose(_choice_index_1_based: int) -> bool:
	return false

func advance() -> bool:
	# One-step dialog: advance closes.
	if _finished:
		return false
	_finished = true
	return true

func start_fetch(local_context: Dictionary = {}, on_updated: Callable = Callable()) -> void:
	# Fire-and-forget; updates text when the response arrives.
	if _requested:
		return
	_requested = true
	_on_updated = on_updated
	if GameState == null or not GameState.has_method("rpggo_get_npc_dialogue"):
		return
	GameState.call_deferred("rpggo_get_npc_dialogue", npc_id, local_context, Callable(self, "_on_dialogue"))

func _on_dialogue(res: Dictionary) -> void:
	if res.is_empty():
		return
	if bool(res.get("ok", false)):
		_text = str(res.get("text", _text))
		if _on_updated.is_valid():
			_on_updated.call()
