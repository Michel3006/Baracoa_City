class_name CombatDebug
extends RefCounted

## Dibujado de depuración del combate (sección 35), conmutable con F2.
##
## Solo geometría y estado de presentación: dónde está la hurtbox del cuerpo,
## dónde la hitbox de su golpe, hacia dónde mira, qué área cubre el golpe y a
## quién ha alcanzado. Cada vista dibuja desde estos datos, y los tests
## comprueban los datos sin necesidad de capturas: contar píxeles es la red de
## seguridad, no la prueba.
##
## El interruptor es global y de ejecución: `GameConfig.SHOW_COMBAT_DEBUG` solo
## dice cómo arranca, y `toggle()` lo cambia en caliente sin reiniciar.
##
## Dependencias: presentation -> domain, infrastructure/configuration

## Interruptor de ejecución.
static var show: bool = GameConfig.SHOW_COMBAT_DEBUG


static func toggle() -> void:
	show = not show


## Círculo de la hurtbox del cuerpo: la zona que un golpe enemigo puede
## alcanzar. Cada vista conoce el radio de su propio cuerpo.
static func hurtbox_circle(view: Node2D) -> Dictionary:
	return {
		"center": view.global_position,
		"radius": float(view.call(&"hurtbox_radius")),
	}


## Círculo de la hitbox: desplazado hacia delante del cuerpo, con el radio y la
## distancia que ya usa la física del golpe (`HitboxSensor` + `GameConfig`).
## Es exactamente la geometría que decide si un golpe alcanza: lo que se dibuja
## es lo que pega.
static func hitbox_circle(view: Node2D) -> Dictionary:
	var hitbox := view.get("hitbox") as HitboxSensor
	if hitbox == null:
		return {"center": Vector2.ZERO, "radius": 0.0}
	return {
		"center": view.global_position
			+ hitbox.direction() * hitbox.reach * GameConfig.HITBOX_FORWARD_RATIO,
		"radius": hitbox.reach * GameConfig.HITBOX_RADIUS_RATIO,
	}


## Objetivos que la hitbox tiene encima ahora mismo (ya filtrados por
## `HitboxSensor`): lo que el golpe está a punto de alcanzar, o lo que ya ha
## alcanzado si la ventana está abierta.
static func reached_targets(view: Node2D) -> Array[Node2D]:
	var hitbox := view.get("hitbox") as HitboxSensor
	if hitbox == null:
		return []
	return hitbox.overlapping_bodies()