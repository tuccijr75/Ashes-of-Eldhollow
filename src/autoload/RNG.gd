extends Node

var _seed: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_seed(Config.default_seed if Config.deterministic_seed_enabled else int(Time.get_unix_time_from_system()))
	GameLog.info("RNG", "RNG ready seed=%s" % str(_seed))

func set_seed(new_seed: int) -> void:
	_seed = new_seed
	_rng.seed = new_seed

func get_seed() -> int:
	return _seed

func randi_range(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)

func randf() -> float:
	return _rng.randf()
