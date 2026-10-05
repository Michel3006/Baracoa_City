class_name NpcState
extends RefCounted

## Estados de un NPC (sección 18 de la especificación).
##
## Separado de `PlayerState` a propósito: el jugador tiene HURT y no tiene WANDER,
## y el NPC tiene WANDER y FLEE y no tiene HURT. Compartir un enum obligaría a
## inventar estados que no le sirven a ninguno de los dos.
##
## Las transiciones están centralizadas en `can_transition_to()` para que la IA no
## pueda saltarse el grafo escribiendo el estado directamente.
##
## Dependencias: domain

enum Kind {
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
	FLEE,
	DEAD,
}

const _NAMES := {
	Kind.IDLE: "IDLE",
	Kind.WANDER: "WANDER",
	Kind.CHASE: "CHASE",
	Kind.ATTACK: "ATTACK",
	Kind.FLEE: "FLEE",
	Kind.DEAD: "DEAD",
}

## Grafo de transiciones. DEAD no tiene salida, igual que en el jugador: la
## reaparición la decide el caso de uso, no la máquina de estados.
##
## Lo que se puede uno de verdad:
## - IDLE <-> WANDER: alternar entre quedarse quieto y pasearse.
## - IDLE/WANDER -> CHASE: el jugador ha entrado en el radio de aggro.
## - IDLE/WANDER/CHASE -> ATTACK: el objetivo está a distancia de golpe. Desde
##   IDLE y WANDER también, porque el jugador puede acercarse tanto que lo tenga
##   encima sin haber pasado antes por la persecución.
## - ATTACK -> CHASE: se ha retirado el objetivo.
## - cualquiera vivo -> FLEE: le queda poca vida.
## - FLEE -> IDLE/CHASE: ya no le queda poca vida, o se ha alejado.
## - cualquiera vivo -> DEAD: se ha quedado sin vida.
const _ALLOWED := {
	Kind.IDLE: [Kind.WANDER, Kind.CHASE, Kind.ATTACK, Kind.FLEE, Kind.DEAD],
	Kind.WANDER: [Kind.IDLE, Kind.CHASE, Kind.ATTACK, Kind.FLEE, Kind.DEAD],
	Kind.CHASE: [Kind.ATTACK, Kind.IDLE, Kind.FLEE, Kind.DEAD],
	Kind.ATTACK: [Kind.CHASE, Kind.IDLE, Kind.FLEE, Kind.DEAD],
	Kind.FLEE: [Kind.IDLE, Kind.CHASE, Kind.DEAD],
	Kind.DEAD: [],
}

## Estados en los que el NPC está vivo y puede actuar.
const ALIVE: Array[Kind] = [Kind.IDLE, Kind.WANDER, Kind.CHASE, Kind.ATTACK, Kind.FLEE]


static func name_of(kind: Kind) -> String:
	return _NAMES.get(kind, "UNKNOWN")


static func can_transition_to(from: Kind, to: Kind) -> bool:
	if from == to:
		return false
	return to in _ALLOWED.get(from, [])


static func is_alive(kind: Kind) -> bool:
	return kind in ALIVE
