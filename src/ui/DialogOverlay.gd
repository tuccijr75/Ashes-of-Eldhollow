extends CanvasLayer

@onready var _panel: Control = $Panel
@onready var _speaker: Label = $Panel/VBox/Speaker
@onready var _text: RichTextLabel = $Panel/VBox/Text
@onready var _choices: VBoxContainer = $Panel/VBox/Choices
@onready var _hint: Label = $Panel/VBox/Hint

var _active_runtime: RefCounted = null
var _active_kind: String = "" # "quest" | "location"
var _active_location_id: String = ""

func _ready() -> void:
	_panel.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Listen for region changes to auto-trigger a one-time location echo.
	var ws := get_node_or_null("/root/WorldSys")
	if ws != null and ws.has_signal("player_region_changed"):
		ws.connect("player_region_changed", Callable(self, "_on_player_region_changed"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if _panel.visible:
			if k == KEY_ESCAPE:
				_close()
				get_viewport().set_input_as_handled()
				return
			# Choice hotkeys 1..9
			if k >= KEY_1 and k <= KEY_9:
				var idx := int(k - KEY_0)
				_choose(idx)
				get_viewport().set_input_as_handled()
				return
			if k == KEY_ENTER:
				if _is_finished():
					_post_finish_action()
				else:
					var choices: Array = _active_runtime.call("get_choices")
					if choices.is_empty() and _active_runtime.has_method("advance"):
						var ok2 := bool(_active_runtime.call("advance"))
						if ok2:
							_refresh()
						else:
							_post_finish_action()
					else:
						_choose(1)
				get_viewport().set_input_as_handled()
				return
		else:
			# Manual trigger: E interacts if possible, otherwise opens the location dialog.
			if k == KEY_E:
				var interacted := false
				if InteractionSys != null and InteractionSys.has_method("try_interact"):
					interacted = bool(InteractionSys.call("try_interact", self))
				if not interacted:
					_open_current_location_dialog(true)
				get_viewport().set_input_as_handled()

func open_path(path: String, kind: String = "") -> bool:
	var ok := false
	_active_runtime = null
	_active_kind = kind
	_active_location_id = ""

	# Probe format: object-schema (Quest dialog) vs array-schema (Location dialog)
	if not FileAccess.file_exists(path):
		GameLog.warn("Dialog", "Dialog file missing: %s" % path)
		return false
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		var d: DialogRuntime = DialogRuntime.new()
		ok = d.load_from_path(path)
		if ok:
			_active_runtime = d
			if _active_kind.is_empty():
				_active_kind = "quest"
	elif parsed is Array:
		var s: SimpleDialogRuntime = SimpleDialogRuntime.new()
		ok = s.load_from_path(path)
		if ok:
			_active_runtime = s
			if _active_kind.is_empty():
				_active_kind = "location"

	if not ok or _active_runtime == null:
		return false
	_open()
	_refresh()
	return true

func open_runtime(runtime: RefCounted, kind: String = "") -> bool:
	if runtime == null:
		return false
	if not runtime.has_method("get_speaker"):
		return false
	if not runtime.has_method("get_text"):
		return false
	if not runtime.has_method("get_choices"):
		return false
	if not runtime.has_method("choose"):
		return false
	if not runtime.has_method("is_finished"):
		return false
	_active_runtime = runtime
	_active_kind = kind
	_active_location_id = ""
	_open()
	_refresh()
	return true

func refresh_active_dialog() -> void:
	# Public shim so async runtimes can request a redraw.
	if not _panel.visible:
		return
	if _active_runtime == null:
		return
	_refresh()

func open_quest(quest_id: int) -> bool:
	var p := "res://data/dialogs/quest_%s.json" % str(quest_id).pad_zeros(3)
	return open_path(p, "quest")

func open_location(location_id: String, forced: bool = false) -> bool:
	var lid := location_id.strip_edges().to_lower()
	if lid.is_empty():
		return false
	var seen_key := "LOC_SEEN_%s" % lid
	if not forced and WorldFlags.get_bool(seen_key, false):
		return false
	var p := "res://dialogs/dlg_%s.json" % lid
	if not FileAccess.file_exists(p):
		return false
	var ok := open_path(p, "location")
	if ok:
		_active_location_id = lid
		WorldFlags.set_flag(seen_key, true)
	return ok

func _open() -> void:
	_panel.visible = true
	get_tree().paused = true

func _close() -> void:
	_panel.visible = false
	_active_runtime = null
	_active_kind = ""
	_active_location_id = ""
	get_tree().paused = false

func _refresh() -> void:
	if _active_runtime == null:
		return
	_speaker.text = str(_active_runtime.call("get_speaker"))
	_text.text = str(_active_runtime.call("get_text"))
	_clear_choices()

	var choices: Array = _active_runtime.call("get_choices")
	if _is_finished():
		_hint.text = "Enter: close  |  Esc: close"
		return
	if choices.is_empty():
		_hint.text = "Enter: continue  |  Esc: close"
		return

	for i in range(choices.size()):
		var c = choices[i]
		var label := "(%d) %s" % [i + 1, str((c as Dictionary).get("text", ""))]
		var b := Button.new()
		b.text = label
		b.pressed.connect(func(): _choose(i + 1))
		_choices.add_child(b)
	_hint.text = "1-9: choose  |  Esc: close"

func _clear_choices() -> void:
	for ch in _choices.get_children():
		ch.queue_free()

func _choose(choice_index_1_based: int) -> void:
	if _active_runtime == null:
		return
	var ok := bool(_active_runtime.call("choose", choice_index_1_based))
	if not ok:
		return
	_refresh()

func _is_finished() -> bool:
	if _active_runtime == null:
		return true
	return bool(_active_runtime.call("is_finished"))

func _post_finish_action() -> void:
	# After a location dialog, offer to open the next available quest in this location.
	if _active_kind == "location" and not _active_location_id.is_empty():
		var next_q := _find_next_available_quest_for_location(_active_location_id)
		if next_q > 0:
			open_quest(next_q)
			return
	_close()

func _find_next_available_quest_for_location(location_id: String) -> int:
	var loc_key := _quest_location_for_region(location_id)
	var best := 0
	for i in range(DB.quests.size()):
		var q_any = DB.quests[i]
		if not (q_any is Dictionary):
			continue
		var q: Dictionary = q_any
		if str(q.get("location", "")).to_lower() != loc_key:
			continue
		var qid := i + 1
		if QuestSys.can_start(qid):
			if best == 0 or qid < best:
				best = qid
	return best

func _quest_location_for_region(region_id: String) -> String:
	var rid := region_id.strip_edges().to_lower()
	match rid:
		"fenmire_crossing", "fenmire_marsh", "forest", "fens_hut", "whispering_glen":
			return "fenmire"
		"ashpath", "stonebridge", "chapel", "village", "village_reborn":
			return "eldhollow"
		"graveyard", "vale_bones":
			return "vale_of_bones"
		"lava_chasm", "temple_choice", "temple_final":
			return "blightlands"
		"hollow_city", "herald_arena", "final_arena":
			return "hollow_city"
		_:
			return rid

func _on_player_region_changed(new_id: String, _old_id: String) -> void:
	# Auto-open once per region if a location dialog exists.
	_open_current_location_dialog(false)

func _open_current_location_dialog(forced: bool) -> void:
	if _panel.visible:
		return
	var rid := ""
	var ws := get_node_or_null("/root/WorldSys")
	if ws != null and ws.has_method("get_player_region_id"):
		rid = str(ws.call("get_player_region_id"))
	if rid.is_empty():
		return
	open_location(rid, forced)
