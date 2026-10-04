class_name PlayerState
extends RefCounted

## Estados del jugador (sección 8 de la especificación).
##
## Las transiciones están centralizadas en `can_transition_to()` para que ningún
## sistema modifique el estado arbitrariamente.
##
## Dependencias: domain

enum Kind {
	IDLE,
	MOVING,
	ATTACKING,
	HURT,
	DEAD,
}

const _NAMES := {
	Kind.IDLE: "IDLE",
	Kind.MOVING: "MOVING",
	Kind.ATTACKING: "ATTACKING",
	Kind.HURT: "HURT",
	Kind.DEAD: "DEAD",
}

## Transiciones permitidas. DEAD solo se alcanza desde HURT y no tiene salida
## (la reaparición la gestiona el caso de uso, no la máquina de estados).
const _ALLOWED := {
	Kind.IDLE: [Kind.MOVING, Kind.ATTACKING, Kind.HURT, Kind.DEAD],
	Kind.MOVING: [Kind.IDLE, Kind.ATTACKING, Kind.HURT, Kind.DEAD],
	Kind.ATTACKING: [Kind.IDLE, Kind.MOVING, Kind.HURT, Kind.DEAD],
	Kind.HURT: [Kind.IDLE, Kind.MOVING, Kind.ATTACKING, Kind.DEAD],
	Kind.DEAD: [],
}


static func name_of(kind: Kind) -> String:
	return _NAMES.get(kind, "UNKNOWN")


static func can_transition_to(from: Kind, to: Kind) -> bool:
	if from == to:
		return false
	return to in _ALLOWED.get(from, [])