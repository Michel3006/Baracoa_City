class_name GameLogger
extends RefCounted

## Logging con niveles (sección 27 de la especificación).
##
## Dependencias: infrastructure/configuration

enum Level { DEBUG = 0, INFO = 1, WARNING = 2, ERROR = 3, OFF = 4 }

const _LEVEL_NAMES := {
	Level.DEBUG: "DEBUG",
	Level.INFO: "INFO",
	Level.WARNING: "WARNING",
	Level.ERROR: "ERROR",
}

static var _min_level: int = Level.INFO


static func configure(min_level: int = -1) -> void:
	_min_level = GameConfig.log_level() if min_level < 0 else min_level


static func set_level(level: int) -> void:
	_min_level = level


static func level_name(level: int) -> String:
	return _LEVEL_NAMES.get(level, "?")


static func debug(message: String, context: String = "") -> void:
	_log(Level.DEBUG, message, context)


static func info(message: String, context: String = "") -> void:
	_log(Level.INFO, message, context)


static func warning(message: String, context: String = "") -> void:
	_log(Level.WARNING, message, context)


static func error(message: String, context: String = "") -> void:
	_log(Level.ERROR, message, context)


static func _log(level: int, message: String, context: String) -> void:
	if level < _min_level:
		return
	var tag := level_name(level)
	if context != "":
		tag += "[%s]" % context
	var line := "[%s] %s" % [tag, message]
	match level:
		Level.ERROR, Level.WARNING:
			printerr(line)
		_:
			print(line)