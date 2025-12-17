extends Node

signal flag_changed(key: String, value, old_value)
signal flags_loaded
signal flags_reset

# Lightweight typed flag registry + storage.
# Keep it small and data-driven; do not hard-couple systems.

enum FlagType { ANY, BOOL, INT, FLOAT, STRING }

var _initialized := false
var _flags: Dictionary = {}
var _schema: Dictionary = {} # key -> {type:int, default:Variant}

func _ready() -> void:
	ensure_initialized()

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_register_defaults()
	_reset_missing_to_defaults()

func _register_defaults() -> void:
	# Authority Ladder / Contracts core schema (extend as needed).
	_define("CHAPTER", "I", FlagType.STRING)
	_define("CENSURE", 0, FlagType.INT)
	_define("CENSURE_MODE", "unresolved", FlagType.STRING) # unresolved|reduced|defied

	_define("DOMAIN_INK_SCORE", 0, FlagType.INT)
	_define("DOMAIN_BLOOD_SCORE", 0, FlagType.INT)
	_define("DOMAIN_SILENCE_SCORE", 0, FlagType.INT)
	_define("DOMAIN_DEBT_SCORE", 0, FlagType.INT)
	_define("DOMAIN_WITNESS_SCORE", 0, FlagType.INT)

	_define("SEAL_INK", false, FlagType.BOOL)
	_define("SEAL_BLOOD", false, FlagType.BOOL)
	_define("SEAL_SILENCE", false, FlagType.BOOL)
	_define("SEAL_DEBT", false, FlagType.BOOL)
	_define("SEAL_WITNESS", false, FlagType.BOOL)
	_define("KEYSTONE_TRIAL_DONE", false, FlagType.BOOL)
	_define("BOSS_UNLOCKED", false, FlagType.BOOL)

	_define("CLAUSE_SET", "", FlagType.STRING) # mutually exclusive contract path; empty=unset
	_define("ENDING_ID", "", FlagType.STRING)

	# Party / companion constraints (schema only; runtime systems come later).
	_define("PARTY_SIZE_MAX", 3, FlagType.INT)
	_define("ACTIVE_COMPANION_ID", "", FlagType.STRING)
	_define("COMPANION_SWAP_RULE", "out_of_combat_only", FlagType.STRING)

	# Example world flags already referenced in content.
	_define("CITY_ALERT", 0, FlagType.INT)
	_define("WARDEN_TRUST", 0, FlagType.INT)
	_define("HOLLOW_MARK_LEVEL", 0, FlagType.INT)

func _define(key: String, default_value, t: int) -> void:
	_schema[key] = {"type": t, "default": default_value}
	if not _flags.has(key):
		_flags[key] = default_value

func reset_all() -> void:
	ensure_initialized()
	_flags = {}
	_register_defaults()
	emit_signal("flags_reset")

func set_flag(key: String, value) -> void:
	ensure_initialized()
	var old_value = _flags.get(key)
	var coerced = _coerce_value(key, value)
	_flags[key] = coerced
	if old_value != coerced:
		emit_signal("flag_changed", key, coerced, old_value)

func get_flag(key: String, default_value = null):
	ensure_initialized()
	if _flags.has(key):
		return _flags[key]
	return default_value

func get_bool(key: String, default_value: bool = false) -> bool:
	return bool(get_flag(key, default_value))

func get_int(key: String, default_value: int = 0) -> int:
	return int(get_flag(key, default_value))

func get_string(key: String, default_value: String = "") -> String:
	return str(get_flag(key, default_value))

func export_flags() -> Dictionary:
	ensure_initialized()
	return _flags.duplicate(true)

func get_flags_ref() -> Dictionary:
	# Returns the live flags Dictionary (do not mutate directly unless you
	# intentionally want to bypass schema coercion/events).
	ensure_initialized()
	return _flags

func import_flags(raw: Dictionary, emit_events: bool = false) -> void:
	ensure_initialized()
	if raw == null:
		return
	if not emit_events:
		_flags = raw.duplicate(true)
		_reset_missing_to_defaults()
		emit_signal("flags_loaded")
		return
	for k in raw.keys():
		set_flag(str(k), raw[k])
	_reset_missing_to_defaults()
	emit_signal("flags_loaded")

func get_save_blob() -> Dictionary:
	ensure_initialized()
	return {"version": 1, "flags": export_flags()}

func load_from_save_blob(blob) -> void:
	ensure_initialized()
	if blob == null or not (blob is Dictionary):
		return
	var d: Dictionary = blob
	var v := int(d.get("version", 1))
	var f = d.get("flags", {})
	if not (f is Dictionary):
		f = {}
	var migrated: Dictionary = _migrate_flags(v, f)
	import_flags(migrated, false)

func _migrate_flags(_version: int, flags_in: Dictionary) -> Dictionary:
	# v1 is current. Keep hook for future.
	return flags_in.duplicate(true)

func _reset_missing_to_defaults() -> void:
	for k in _schema.keys():
		if not _flags.has(k):
			_flags[k] = _schema[k].get("default")

func _coerce_value(key: String, value):
	if not _schema.has(key):
		return value
	var t := int((_schema[key] as Dictionary).get("type", FlagType.ANY))
	match t:
		FlagType.BOOL:
			return bool(value)
		FlagType.INT:
			return int(value)
		FlagType.FLOAT:
			return float(value)
		FlagType.STRING:
			return str(value)
		_:
			return value
