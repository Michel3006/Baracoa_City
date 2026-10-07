class_name NpcKind
extends RefCounted

## Tipos de enemigo (secciones 9 y 18).
##
## Identificadores de dominio, no rutas de archivo. El sprite de cada tipo lo elige
## `ActorVisualCatalog`, en Presentation, leyendo este identificador: el dominio no
## sabe que existe una hoja de sprites ni de dónde sale.
##
## Los cuatro son personas. Antes eran bichos (Limo, Búho, Araña y Lagarto) y no
## tenían fila de ataque en su hoja, así que mueren de pie; desde que los enemigos
## comparten la hoja de la persona caminan, golpean y mueren igual que el jugador.
## Lo que distingue a un tipo de otro es el nombre de aquí y el tinte de paleta
## (`ActorVisualCatalog.tint_of`).
##
## Dependencias: domain

## Vándalo: lento, poca vida, el enemigo de relleno.
const VANDAL := &"vandal"
## Atracador: rápido y débil.
const ROBBER := &"robber"
## Matón: rápido y duro.
const BRUTE := &"brute"
## Pandillero: rápido y duro.
const GANGSTER := &"gangster"


static func ids() -> Array[StringName]:
	return [VANDAL, ROBBER, BRUTE, GANGSTER]


static func exists(id: StringName) -> bool:
	return id in ids()


## Nombre que se muestra al jugador para un tipo de enemigo.
static func display_name(id: StringName) -> String:
	match id:
		VANDAL:
			return "Vándalo"
		ROBBER:
			return "Atracador"
		BRUTE:
			return "Matón"
		GANGSTER:
			return "Pandillero"
		_:
			return "Individuo"


## Tipo con el que arranca un NPC que no trae uno asignado.
static func default_kind() -> StringName:
	return VANDAL
