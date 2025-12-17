extends CanvasLayer

@onready var _panel: Control = $Panel
@onready var _out: RichTextLabel = $Panel/VBox/Output
@onready var _in: LineEdit = $Panel/VBox/Input

var _visible := false

var _active_dialog: DialogRuntime = null

func _ready() -> void:
	_panel.visible = false
	_in.text_submitted.connect(_on_submit)
	_print_line("Debug console ready. Press F2 to toggle.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			_toggle()
			get_viewport().set_input_as_handled()

func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_in.grab_focus()

func _on_submit(text: String) -> void:
	_in.text = ""
	var cmd := text.strip_edges()
	if cmd.is_empty():
		return
	_print_line("> " + cmd)
	_execute(cmd)

func _execute(cmd: String) -> void:
	var parts := cmd.split(" ", false)
	var head := parts[0].to_lower()
	match head:
		"help":
			_print_line("Commands: help | regions | tp x y | region <id> | seed <n> | save | load | flag <id> [value] | flags | quest <id> | quest_start <id> (auto dlg) | quest_complete <id> | quest_available | quest_active | quest_done | proc <profile> <id> [seed] | proc_regen <id> | proc_clear <id> | dlg <quest_id> | dlg_choose <n> | dlg_state | test_proc | test_quests | test_save | test_stream | test_all")
		"regions":
			_print_line("Loaded: %s" % str(WorldSys.get_loaded_region_ids()))
		"proc":
			# proc <profile> <dungeon_id> [seed]
			if parts.size() < 3:
				_print_line("Usage: proc <profile> <dungeon_id> [seed]")
				return
			var profile := str(parts[1])
			var did := str(parts[2])
			var dungeon_seed := int(parts[3]) if parts.size() >= 4 else 0
			var ok := WorldSys.enter_procedural_dungeon(did, profile, dungeon_seed)
			_print_line("Procedural: %s" % ("ok" if ok else "failed"))
		"proc_regen":
			# proc_regen <dungeon_id>
			if parts.size() < 2:
				_print_line("Usage: proc_regen <dungeon_id>")
				return
			var ok := WorldSys.force_regenerate_procedural(str(parts[1]))
			_print_line("Regen: %s" % ("ok" if ok else "failed"))
		"proc_clear":
			# proc_clear <dungeon_id>
			if parts.size() < 2:
				_print_line("Usage: proc_clear <dungeon_id>")
				return
			WorldSys.mark_procedural_cleared(str(parts[1]))
			_print_line("Cleared: ok")
		"test_proc":
			var runner := TestRunner.new()
			var res := runner.run_procedural_tests()
			_print_line("Tests ok=%s cases=%d" % [str(res.get("ok", false)), int((res.get("cases", []) as Array).size())])
		"test_quests":
			var runner := TestRunner.new()
			var res := runner.run_quest_tests()
			_print_line("Quest tests ok=%s" % str(res.get("ok", false)))
		"test_save":
			var runner := TestRunner.new()
			var res := runner.run_save_load_tests()
			_print_line("Save/load tests ok=%s" % str(res.get("ok", false)))
		"test_stream":
			var runner := TestRunner.new()
			var res := runner.run_stream_tests()
			_print_line("Stream tests ok=%s" % str(res.get("ok", false)))
		"test_all":
			var runner := TestRunner.new()
			var res := runner.run_all()
			_print_line("All tests ok=%s suites=%d" % [str(res.get("ok", false)), int((res.get("suites", []) as Array).size())])
		"tp":
			if parts.size() < 3:
				_print_line("Usage: tp x y")
				return
			var p := _player()
			if p == null:
				_print_line("No player")
				return
			p.global_position = Vector2(float(parts[1]), float(parts[2]))
			_print_line("Teleported")
		"region":
			if parts.size() < 2:
				_print_line("Usage: region <id>")
				return
			var ok := WorldSys.teleport_player_to_region(str(parts[1]))
			_print_line("Teleport region: %s" % ("ok" if ok else "failed"))
		"seed":
			if parts.size() < 2:
				_print_line("Usage: seed <n>")
				return
			RNG.set_seed(int(parts[1]))
			_print_line("Seed set to %s" % str(RNG.get_seed()))
		"save":
			_print_line("Save: %s" % ("ok" if SaveSys.save_game() else "failed"))
		"load":
			_print_line("Load: %s" % ("ok" if SaveSys.load_game() else "failed"))
		"flag":
			if parts.size() < 2:
				_print_line("Usage: flag <id> [value]")
				return
			var fid := str(parts[1])
			if parts.size() == 2:
				_print_line("%s=%s" % [fid, str(Game.get_flag(fid, null))])
				return
			var raw := str(parts[2])
			var v
			if raw.to_lower() == "true":
				v = true
			elif raw.to_lower() == "false":
				v = false
			elif raw.is_valid_int():
				v = int(raw)
			else:
				v = raw
			Game.set_flag(fid, v)
			_print_line("Set %s=%s" % [fid, str(v)])
		"flags":
			_print_line(JSON.stringify(Game.flags))
		"quest":
			if parts.size() < 2:
				_print_line("Usage: quest <id>")
				return
			var qid := int(parts[1])
			_print_line("quest %d status=%s" % [qid, QuestSys.get_status(qid)])
		"quest_start":
			if parts.size() < 2:
				_print_line("Usage: quest_start <id>")
				return
			var qid2 := int(parts[1])
			var ok := QuestSys.start_quest(qid2)
			_print_line("quest_start %d: %s" % [qid2, "ok" if ok else "failed"])
			if ok:
				_open_dialog(qid2)
		"quest_complete":
			if parts.size() < 2:
				_print_line("Usage: quest_complete <id>")
				return
			var qid3 := int(parts[1])
			Game.set_flag("Q_READY_%s" % str(qid3).pad_zeros(3), true)
			var ok2 := QuestSys.complete_quest(qid3)
			_print_line("quest_complete %d: %s" % [qid3, "ok" if ok2 else "failed"])
		"quest_available":
			_print_line("available: %s" % str(QuestSys.list_available(20)))
		"quest_active":
			_print_line("active: %s" % str(QuestSys.list_active()))
		"quest_done":
			_print_line("done: %s" % str(QuestSys.list_completed()))
		"dlg":
			if parts.size() < 2:
				_print_line("Usage: dlg <quest_id>")
				return
			var qid := int(parts[1])
			_open_dialog(qid)
		"dlg_choose":
			if _active_dialog == null:
				_print_line("No active dialog. Use: dlg <quest_id>")
				return
			if parts.size() < 2:
				_print_line("Usage: dlg_choose <n>")
				return
			var n := int(parts[1])
			if not _active_dialog.choose(n):
				_print_line("Invalid choice")
				return
			_print_dialog_state()
		"dlg_state":
			if _active_dialog == null:
				_print_line("No active dialog")
				return
			_print_dialog_state()
		_:
			_print_line("Unknown command. Type 'help'.")

func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func _print_line(line: String) -> void:
	if _out == null:
		return
	_out.append_text(line + "\n")
	_out.scroll_to_line(_out.get_line_count())

func _open_dialog(quest_id: int) -> void:
	var p := "res://data/dialogs/quest_%s.json" % str(quest_id).pad_zeros(3)
	if not FileAccess.file_exists(p):
		_print_line("No dialog: %s" % p)
		return
	var d: DialogRuntime = DialogRuntime.new()
	if not d.load_from_path(p):
		_print_line("Dialog load failed")
		return
	_active_dialog = d
	_print_dialog_state()

func _print_dialog_state() -> void:
	if _active_dialog == null:
		return
	_print_line("[%s] %s" % [_active_dialog.get_speaker(), _active_dialog.get_text()])
	if _active_dialog.is_finished():
		_print_line("(End)")
		return
	var choices: Array = _active_dialog.get_choices()
	for i in range(choices.size()):
		var c = choices[i]
		if c is Dictionary:
			_print_line("%d) %s" % [i + 1, str((c as Dictionary).get("text", ""))])
