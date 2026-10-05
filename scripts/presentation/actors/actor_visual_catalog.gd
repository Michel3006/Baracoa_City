class_name ActorVisualCatalog
extends RefCounted

## Qué hoja y cómo se recorta cada actor (sección 25).
##
## Un solo sitio donde se decide de qué archivo sale el sprite de cada personaje y
## qué filas son qué animación. Añadir un enemigo nuevo es una línea aquí y una en
## `NpcKind`; ni la vista ni el caso de uso saben nombres de archivo.
##
## Solo datos, sin nodos ni estado. Vive en Presentation porque una ruta de textura
## es cosa de esa capa: el dominio no sabe que existen hojas de sprites.
##
## Dependencias: presentation -> domain, infrastructure/configuration

## Jugador. Su hoja es de 4x7: cuatro filas de caminar en las cuatro
## orientaciones, y después el golpe (fila 4), el salto (5) y el de objeto (6).
const PLAYER := &"player"
const PLAYER_SHEET := "res://assets/characters/ninja_blue.png"
const PLAYER_WALK_ROW := GameConfig.ACTOR_ROW_DOWN
const PLAYER_ATTACK_ROW := PLAYER_WALK_ROW + 4


static func ids() -> Array[StringName]:
	return [PLAYER, NpcKind.SLIME, NpcKind.OWL, NpcKind.SPIDER, NpcKind.LIZARD]


static func exists(id: StringName) -> bool:
	return id in ids()


## Ruta de la hoja de un actor, o cadena vacía si no se conoce.
static func sheet_of(id: StringName) -> String:
	match id:
		PLAYER:
			return PLAYER_SHEET
		NpcKind.SLIME:
			return "res://assets/characters/slime.png"
		NpcKind.OWL:
			return "res://assets/characters/owl.png"
		NpcKind.SPIDER:
			return "res://assets/characters/spider_red.png"
		NpcKind.LIZARD:
			return "res://assets/characters/lizard.png"
		_:
			GameLogger.warning("Actor sin hoja: %s" % id, "ActorVisualCatalog")
			return ""


## Fila donde empieza a caminar el actor dentro de su hoja.
static func walk_row_of(id: StringName) -> int:
	return GameConfig.ACTOR_ROW_DOWN


## Fila del golpe.
##
## Los enemigos del pack solo traen las cuatro filas de caminar: no tienen fila de
## ataque. Para ellos el golpe reutiliza la pose de frente, que es justo la que
## necesita un ataque de frente. Es lo que hace el pack, no un apaño nuestro.
static func attack_row_of(id: StringName) -> int:
	if id == PLAYER:
		return PLAYER_ATTACK_ROW
	return GameConfig.ACTOR_ROW_DOWN


## Prepara un `ActorSprite` para un actor del catálogo.
##
## Devuelve `false` si la hoja no existe o no se pudo cargar, para que quien llame
## pueda dejar al actor sin sprite en vez de quedarse con un nodo en blanco.
static func apply_to(id: StringName, sprite: ActorSprite) -> bool:
	if sprite == null:
		return false
	var path := sheet_of(id)
	if path.is_empty() or not ResourceLoader.exists(path):
		GameLogger.warning("Falta la hoja de %s (%s)" % [id, path], "ActorVisualCatalog")
		return false
	sprite.configure(path, walk_row_of(id), attack_row_of(id))
	return sprite.texture != null