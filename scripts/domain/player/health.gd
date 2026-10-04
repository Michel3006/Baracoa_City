class_name Health
extends RefCounted

## Vitalidad de una entidad (secciones 8 y 9).
##
## No depende de nodos visuales. El `Health` de un NPC y el de un jugador se
## comportan igual; la presentación se suscribe a las señales.
##
## Dependencias: domain

signal changed(current: float, maximum: float)
signal depleted()

var current: float
var maximum: float


func _init(max_value: float = 0.0, initial: float = -1.0) -> void:
	maximum = maxf(0.0, max_value)
	current = maximum if initial < 0.0 else clampf(initial, 0.0, maximum)


var is_dead: bool:
	get:
		return current <= 0.0


var ratio: float:
	get:
		return 0.0 if maximum <= 0.0 else current / maximum


## Aplica daño y devuelve el daño realmente infligido (nunca negativo).
func apply_damage(amount: float) -> float:
	if amount <= 0.0 or is_dead:
		return 0.0
	var before := current
	_write(maxf(0.0, current - amount))
	return before - current


## Restaura vida sin superar el máximo. Devuelve la cantidad realmente curada.
func heal(amount: float) -> float:
	if amount <= 0.0 or is_dead:
		return 0.0
	var before := current
	_write(minf(maximum, current + amount))
	return current - before


func refill() -> void:
	_write(maximum)


## Cambia el máximo y recorta la vida actual si excedía el nuevo máximo.
func set_maximum(value: float) -> void:
	maximum = maxf(0.0, value)
	_write(minf(current, maximum))


func _write(value: float) -> void:
	var clamped := clampf(value, 0.0, maximum)
	if is_equal_approx(clamped, current):
		return
	var was_dead := is_dead
	current = clamped
	changed.emit(current, maximum)
	if is_dead and not was_dead:
		depleted.emit()