class_name CombatState
extends RefCounted

## Estados de combate (sección 7 de la especificación).
##
## Es la máquina de fases del golpe, aparte de `PlayerState`. Van en paralelo y
## dicen cosas distintas: mientras el jugador está en `ATTACKING` ("está
## pegando"), el combate recorre `WINDUP -> ACTIVE -> RECOVERY` y eso es lo que
## decide si la hitbox está encendida (sección 16: apagada normalmente,
## activada durante ACTIVE).
##
## En F4 solo se recorren las cuatro primeras. Las demás existen desde ya con
## el nombre literal de la sección 7 para que F5 (esquive, bloqueo, reacciones)
## no tenga que reescribir la enum ni los `match`.
##
## Dependencias: domain

enum Kind {
	FREE,
	WINDUP,
	ACTIVE,
	RECOVERY,
	HIT_REACTION,
	STAGGERED,
	DODGING,
	BLOCKING,
	DEAD,
}

const _NAMES := {
	Kind.FREE: "FREE",
	Kind.WINDUP: "WINDUP",
	Kind.ACTIVE: "ACTIVE",
	Kind.RECOVERY: "RECOVERY",
	Kind.HIT_REACTION: "HIT_REACTION",
	Kind.STAGGERED: "STAGGERED",
	Kind.DODGING: "DODGING",
	Kind.BLOCKING: "BLOCKING",
	Kind.DEAD: "DEAD",
}


## Nombre legible de un estado, para mensajes de prueba y de depuración.
static func name_of(kind: int) -> String:
	return String(_NAMES.get(kind, "?"))


## ¿Está encendida la hitbox en este estado? (sección 16)
static func is_window_open(kind: int) -> bool:
	return kind == Kind.ACTIVE
