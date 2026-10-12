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
	DODGING,
	HURT,
	DEAD,
}

const _NAMES := {
	Kind.IDLE: "IDLE",
	Kind.MOVING: "MOVING",
	Kind.ATTACKING: "ATTACKING",
	Kind.DODGING: "DODGING",
	Kind.HURT: "HURT",
	Kind.DEAD: "DEAD",
}

## Transiciones permitidas. DEAD solo se alcanza desde HURT y no tiene salida
## (la reaparición la gestiona el caso de uso, no la máquina de estados).
##
## `DODGING` es del combate, no del movimiento: existe para que el reloj de la
## rodada (sección 30) no lo pise `_sync_motion_state()` con `MOVING`, que es
## justo lo que dejaría al jugador caminando con el cuerpo congelado en la
## rodada. Por eso el movimiento no lo escribe nunca y sí puede entrar y salir de
## él el combate.
const _ALLOWED := {
	Kind.IDLE: [Kind.MOVING, Kind.ATTACKING, Kind.DODGING, Kind.HURT, Kind.DEAD],
	Kind.MOVING: [Kind.IDLE, Kind.ATTACKING, Kind.DODGING, Kind.HURT, Kind.DEAD],
	Kind.ATTACKING: [Kind.IDLE, Kind.MOVING, Kind.DODGING, Kind.HURT, Kind.DEAD],
	Kind.DODGING: [Kind.IDLE, Kind.MOVING, Kind.ATTACKING, Kind.HURT, Kind.DEAD],
	Kind.HURT: [Kind.IDLE, Kind.MOVING, Kind.ATTACKING, Kind.DODGING, Kind.DEAD],
	Kind.DEAD: [],
}


static func name_of(kind: Kind) -> String:
	return _NAMES.get(kind, "UNKNOWN")


static func can_transition_to(from: Kind, to: Kind) -> bool:
	if from == to:
		return false
	return to in _ALLOWED.get(from, [])