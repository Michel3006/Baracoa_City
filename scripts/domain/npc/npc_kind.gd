class_name NpcKind
extends RefCounted

## Tipos de enemigo del MVP (secciones 9 y 18).
##
## Identificadores de dominio, no rutas de archivo. ElSprite de cada tipo lo elige
## `ActorVisualCatalog`, en Presentation, leyendo este identificador: el dominio no
## sabe que existe una hoja de sprites ni de dónde sale.
##
## Dependencias: domain

## Limo: lento, poca vida, el enemigo de relleno.
const SLIME := &"slime"
## Búho: rápido y duro.
const OWL := &"owl"
## Araña: rápida y débil.
const SPIDER := &"spider"
## Lagarto: rápido y duro.
const LIZARD := &"lizard"


static func ids() -> Array[StringName]:
	return [SLIME, OWL, SPIDER, LIZARD]


static func exists(id: StringName) -> bool:
	return id in ids()


## Nombre que se muestra al jugador para un tipo de enemigo.
static func display_name(id: StringName) -> String:
	match id:
		SLIME:
			return "Limo"
		OWL:
			return "Búho"
		SPIDER:
			return "Araña"
		LIZARD:
			return "Lagarto"
		_:
			return "Criatura"