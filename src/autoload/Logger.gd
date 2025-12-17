extends Node

enum Level { INFO, WARN, ERROR, CRITICAL }

var _file: FileAccess
var _enabled_console := true

func _ready() -> void:
	_init_logfile()
	info("Logger", "Logger ready")

func _init_logfile() -> void:
	var dir_path := "user://logs"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path := dir_path + "/game.log"
	_file = FileAccess.open(file_path, FileAccess.WRITE_READ)
	if _file == null:
		push_warning("Logger failed to open log file at %s" % file_path)
		return
	_file.seek_end()

func set_console_enabled(enabled: bool) -> void:
	_enabled_console = enabled

func _log(level: int, category: String, message: String) -> void:
	var level_name := _level_name(level)
	var ts := Time.get_datetime_string_from_system(true)
	var line := "%s [%s] %s: %s" % [ts, level_name, category, message]
	if _enabled_console:
		match level:
			Level.INFO:
				print(line)
			Level.WARN:
				push_warning(line)
			Level.ERROR, Level.CRITICAL:
				push_error(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()

func _level_name(level: int) -> String:
	match level:
		Level.INFO:
			return "INFO"
		Level.WARN:
			return "WARN"
		Level.ERROR:
			return "ERROR"
		Level.CRITICAL:
			return "CRITICAL"
		_:
			return "INFO"

func info(category: String, message: String) -> void:
	_log(Level.INFO, category, message)

func warn(category: String, message: String) -> void:
	_log(Level.WARN, category, message)

func error(category: String, message: String) -> void:
	_log(Level.ERROR, category, message)

func critical(category: String, message: String) -> void:
	_log(Level.CRITICAL, category, message)
