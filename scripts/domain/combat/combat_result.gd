class_name CombatResult
extends RefCounted

## Resultado de un intercambio de golpes (sección 19).
##
## No es el daño ni la vida: es lo que pasó con el golpe, y lo usan las dos puntas
## de la cadena. El atacante sabe si su ataque conectó (`HIT`), y el defensor avisa
## de si lo aguantó (`BLOCKED`), lo esquivó (`DODGED`) o se lo comió a media faena
## (`INTERRUPTED`). El HUD de depuración y los tests leen de aquí en vez de
## adivinar por la vida que falta.
##
## `MISS` no se emite como señal: la hitbox que no toca a nadie simplemente no
## genera `target_hit`, así que el silencio ya es el resultado. La constante existe
## para que el vocabulario de la sección 19 esté entero y no haya que inventarlo
## cuando haya HUD.
##
## Es `RefCounted` puro: sin `Node`, sin `Input`, sin escenas.
##
## Dependencias: domain

## El golpe no tocó a nadie.
const MISS := &"miss"
## El golpe entró y quitó vida.
const HIT := &"hit"
## El golpe entró en la guardia: no quitó vida (o la guardia se rompió).
const BLOCKED := &"blocked"
## El defensor estaba en su ventana de esquive: el golpe pasó de largo.
const DODGED := &"dodged"
## El defensor estaba atacando y el golpe le cortó el ataque.
const INTERRUPTED := &"interrupted"

const _NAMES := {
	MISS: "MISS",
	HIT: "HIT",
	BLOCKED: "BLOCKED",
	DODGED: "DODGED",
	INTERRUPTED: "INTERRUPTED",
}


## Nombre legible del resultado, para logs y HUD.
static func name_of(result: StringName) -> String:
	return _NAMES.get(result, "UNKNOWN")
