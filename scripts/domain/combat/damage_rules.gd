class_name DamageRules
extends RefCounted

## Reglas de daño (secciones 9 y 10 de la especificación).
##
## La fórmula vive aquí y no en el arma ni en el personaje: cambiar cómo se calcula
## un golpe no debe obligar a reescribir armas, enemigos ni animaciones. Todo lo que
## consulte el sistema de combate pregunta a esta clase.
##
## Dependencias: domain

## Un golpe siempre quita al menos esto, aunque la defensa lo supere.
const MINIMUM_DAMAGE := 1.0


## Daño final de un golpe: `max(1, ataque - defensa)` (sección 10).
##
## Devuelve 0 si no hay ataque válido: un arma rota no golpea.
static func compute(attack_damage: float, defense: float) -> float:
	if attack_damage <= 0.0:
		return 0.0
	return maxf(MINIMUM_DAMAGE, attack_damage - maxf(0.0, defense))


## ¿El ataque puede llegar a inflictir daño?
static func is_valid_attack(attack_damage: float) -> bool:
	return attack_damage > 0.0


## Lectura de la defensa de cualquier objetivo.
##
## Acepta dos formas para no atar el sistema de combate a una sola clase: un
## `CharacterStats` en la propiedad `stats` (jugador y NPC) o un método
## `get_defense()` (cualquier otro objetivo). Así un enemigo puede tener su
## defensa en un script propio sin cambiar las reglas.
static func defense_of(target: Variant) -> float:
	if not (target is Object):
		return 0.0
	var body := target as Object
	if "stats" in body:
		var stats: Variant = body.get(&"stats")
		if stats is CharacterStats:
			return maxf(0.0, (stats as CharacterStats).defense)
		return 0.0
	if body.has_method(&"get_defense"):
		return maxf(0.0, float(body.call(&"get_defense")))
	return 0.0


## Un objetivo es dañable si sabe recibir daño y no está muerto.
static func is_damageable(target: Variant) -> bool:
	if not (target is Object):
		return false
	var body := target as Object
	if not body.has_method(&"take_damage"):
		return false
	if "is_dead" in body and bool(body.get(&"is_dead")):
		return false
	return true
