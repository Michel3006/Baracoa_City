class_name NpcBehavior
extends RefCounted

## Cómo se comporta un tipo de enemigo (sección 18).
##
## Solo números: distancias, vida, daño y radios de detección. Ninguna decisión. La
## decisión se toma en `NpcBrain`; mover estos valores cambia cómo se comporta un
## enemigo sin tocar su lógica, que es justo lo que pide la especificación al pedir
## una "arquitectura preparada para distintos comportamientos".
##
## Todos los valores vienen de `GameConfig`: ni números mágicos (regla 5).
##
## Dependencias: domain, infrastructure/configuration

## Vida máxima y defensa: con qué aguanta un golpe del jugador.
var max_health: float = GameConfig.NPC_WEAK_HEALTH
var defense: float = GameConfig.NPC_WEAK_DEFENSE
## Potencia del golpe y hasta dónde llega.
var attack_damage: float = GameConfig.NPC_WEAK_DAMAGE
var attack_range: float = GameConfig.NPC_WEAK_RANGE
## Segundos entre dos golpes del mismo enemigo.
var attack_cooldown: float = GameConfig.NPC_WEAK_COOLDOWN
## Qué tan rápido persigue.
var move_speed: float = GameConfig.NPC_WEAK_SPEED

## Radio de detección: a partir de aquí el NPC se da cuenta del jugador.
var aggro_radius: float = GameConfig.NPC_AGGRO_RADIUS
## Radio de la correa: se aleja más de su puesto y deja de perseguir.
var leash_radius: float = GameConfig.NPC_LEASH_RADIUS
## Radio deambulación en reposo.
var wander_radius: float = GameConfig.NPC_WANDER_RADIUS
## Segundos que pasa quieto entre paseos.
var wander_interval: float = GameConfig.NPC_WANDER_INTERVAL
## Por debajo de esta proporción de vida huye en vez de seguir peleando.
var flee_health_ratio: float = GameConfig.NPC_FLEE_HEALTH_RATIO
## Ventana de invulnerabilidad tras recibir un golpe.
var invulnerability_time: float = GameConfig.NPC_INVULNERABILITY_TIME
## Aturdimiento al recibir daño.
var hurt_stun_time: float = GameConfig.NPC_HURT_STUN_TIME

## FACTORY de comportamientos, para no repetir los mismos números en cada sitio.

## Enemigo débil y lento: el que aparece más veces.
static func weak() -> NpcBehavior:
	return NpcBehavior.new()


## Enemigo más duro: más vida, más daño y más rápido, a cambio de más defensa.
static func strong() -> NpcBehavior:
	var behavior := NpcBehavior.new()
	behavior.max_health = GameConfig.NPC_STRONG_HEALTH
	behavior.defense = GameConfig.NPC_STRONG_DEFENSE
	behavior.attack_damage = GameConfig.NPC_STRONG_DAMAGE
	behavior.attack_range = GameConfig.NPC_STRONG_RANGE
	behavior.attack_cooldown = GameConfig.NPC_STRONG_COOLDOWN
	behavior.move_speed = GameConfig.NPC_STRONG_SPEED
	return behavior


func snapshot() -> Dictionary:
	return {
		"max_health": max_health,
		"defense": defense,
		"attack_damage": attack_damage,
		"attack_range": attack_range,
		"attack_cooldown": attack_cooldown,
		"move_speed": move_speed,
		"aggro_radius": aggro_radius,
		"leash_radius": leash_radius,
		"wander_radius": wander_radius,
		"flee_health_ratio": flee_health_ratio,
	}
