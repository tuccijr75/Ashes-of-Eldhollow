extends Node2D

@onready var _debug_label: Label = $DebugOverlay/Label

func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	var want_run_tests := user_args.has("--run-tests")
	var want_smoke := user_args.has("--smoke")
	if want_run_tests:
		Config.run_tests_on_boot = true
		Config.debug_overlay_enabled = false
	elif want_smoke:
		Config.debug_overlay_enabled = false

	GameLog.info("Boot", "Main scene ready")
	Game.ensure_initialized()
	var ws := get_node_or_null("/root/WorldSys")
	if ws != null and ws.has_method("ensure_initialized"):
		ws.call("ensure_initialized")
	else:
		GameLog.error("Boot", "WorldSys autoload missing or failed to load")
	if Config.run_tests_on_boot:
		var runner := TestRunner.new()
		var res := runner.run_all()
		if bool(res.get("ok", false)):
			GameLog.info("Tests", "All boot tests OK")
			if want_run_tests:
				get_tree().quit(0)
				return
		else:
			GameLog.error("Tests", "Boot tests FAILED")
			GameLog.error("Tests", JSON.stringify(res))
			if want_run_tests:
				get_tree().quit(1)
				return
	if want_smoke:
		get_tree().quit(0)
		return
	_update_overlay()

func _process(_delta: float) -> void:
	if Config.debug_overlay_enabled:
		_update_overlay()

func _update_overlay() -> void:
	if _debug_label == null:
		return
	if not Config.debug_overlay_enabled:
		_debug_label.visible = false
		return
	_debug_label.visible = true
	var loaded: Array = []
	var ws := get_node_or_null("/root/WorldSys")
	if ws != null and ws.has_method("get_loaded_region_ids"):
		loaded = ws.call("get_loaded_region_ids")
	var mem_mb := int(Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0))
	_debug_label.text = "Regions loaded: %s\nStatic mem: %d MB\nSeed: %s\nChapter: %s" % [str(loaded), mem_mb, str(RNG.get_seed()), str(Game.chapter)]
