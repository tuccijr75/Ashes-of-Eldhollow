extends Node

var debug_overlay_enabled: bool = true
var deterministic_seed_enabled: bool = true
var default_seed: int = 123456

var run_tests_on_boot: bool = false

var max_simultaneous_regions: int = 2

func _ready() -> void:
	GameLog.info("Config", "Config ready")
