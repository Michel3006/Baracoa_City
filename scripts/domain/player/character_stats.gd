class_name CharacterStats
extends RefCounted

## Estadísticas base de un personaje (sección 9).
##
## Diseñado para crecer hacia hambre, sed, energía, fuerza, experiencia, nivel y
## habilidades sin reescribir los sistemas que lo consumen: los valores futuros
## se añaden como recursos opcionales, no como campos obligatorios.
##
## Dependencias: domain

signal changed()

const STAT_NAMES: PackedStringArray = [
	"max_health",
	"max_stamina",
	"move_speed",
	"base_damage",
	"defense",
]

var max_health: float = 100.0
var max_stamina: float = 100.0
var move_speed: float = 60.0
var base_damage: float = 5.0
var defense: float = 0.0


func _init(values: Dictionary = {}) -> void:
	for stat: String in STAT_NAMES:
		if values.has(stat):
			set_stat(stat, float(values[stat]))


func has_stat(stat: StringName) -> bool:
	return stat in STAT_NAMES


func stat_value(stat: StringName) -> float:
	if not has_stat(stat):
		GameLogger.warning("Estadística desconocida: %s" % stat, "CharacterStats")
		return 0.0
	return float(self[stat])


func set_stat(stat: StringName, value: float) -> void:
	if not has_stat(stat):
		GameLogger.warning("Estadística desconocida: %s" % stat, "CharacterStats")
		return
	if is_equal_approx(float(self[stat]), value):
		return
	set(stat, value)
	changed.emit()


func snapshot() -> Dictionary:
	var data := {}
	for stat: String in STAT_NAMES:
		data[stat] = self[stat]
	return data