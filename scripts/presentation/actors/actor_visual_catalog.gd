class_name ActorVisualCatalog
extends RefCounted

## Qué hoja y cómo se recorta cada actor (sección 25; el jugador humano viene de
## la especificación de personas, secciones 14 a 21).
##
## Un solo sitio donde se decide de qué archivo sale el sprite de cada personaje y
## qué filas son qué animación. Añadir un enemigo nuevo es una línea aquí y una en
## `NpcKind`; ni la vista ni el caso de uso saben nombres de archivo.
##
## El jugador tiene dos definiciones visuales: el humano (`PLAYER_HUMAN`, el que
## se ve al jugar) y el ninja (`PLAYER_NINJA`, el clásico, que se conserva como
## fallback). Cuál de las dos usa el juego lo decide `GameConfig.PLAYER_VISUAL`;
## el id `PLAYER` es un alias que resuelve al visual activo, para que las vistas
## no tengan que saber cuál es.
##
## Solo datos, sin nodos ni estado. Vive en Presentation porque una ruta de textura
## es cosa de esa capa: el dominio no sabe que existen hojas de sprites.
##
## Dependencias: presentation -> domain, infrastructure/configuration

## Jugador: alias al visual activo que fija `GameConfig.PLAYER_VISUAL`.
const PLAYER := &"player"
## Persona (hoja de bit-era, CC0): por defecto desde la especificación de personas.
const PLAYER_HUMAN := &"player_human"
## Ninja del pack clásico: se conserva como fallback y para comparar.
const PLAYER_NINJA := &"player_ninja"


## Resuelve el alias del jugador al visual activo que fija la configuración.
static func active_player() -> StringName:
	var visual: StringName = GameConfig.PLAYER_VISUAL
	if visual in [PLAYER_HUMAN, PLAYER_NINJA]:
		return visual
	GameLogger.warning(
		"Visual de jugador desconocido: %s; se usa el humano" % visual,
		"ActorVisualCatalog"
	)
	return PLAYER_HUMAN


static func ids() -> Array[StringName]:
	return [
		PLAYER, PLAYER_NINJA,
		NpcKind.SLIME, NpcKind.OWL, NpcKind.SPIDER, NpcKind.LIZARD,
	]


static func exists(id: StringName) -> bool:
	return id in ids() or id in [PLAYER_HUMAN, PLAYER_NINJA]


## Ruta de la hoja de un actor, o cadena vacía si no se conoce.
static func sheet_of(id: StringName) -> String:
	var def := definition_of(id)
	if def != null:
		return def.sheet
	match id:
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
##
## El jugador usa la fila que diga su definición visual: la 5 para el humano, la 4
## para el ninja. No es `walk_row + 4` por convención: es la fila de cada hoja.
static func attack_row_of(id: StringName) -> int:
	var def := definition_of(id)
	if def != null:
		return def.attack_row
	return GameConfig.ACTOR_ROW_DOWN


## Definición visual de un actor del catálogo, o `null` si no tiene.
##
## Los enemigos no tienen definición: usan la ruta clásica de `configure()`. Las
## personas (jugador hoy, ciudadanos en fases futuras) sí, y la definición es lo
## único que el reproductor necesita saber de su hoja.
static func definition_of(id: StringName) -> CharacterVisualDefinition:
	match id:
		PLAYER:
			return definition_of(active_player())
		PLAYER_HUMAN:
			return _human_definition()
		PLAYER_NINJA:
			return _ninja_definition()
	return null


## La persona: hoja de bit-era (CC0), 64x128 = 4x8 de 16 px.
##
## OJO al orden de filas: NO es el del pack (abajo, izquierda, arriba, derecha).
## El autor dibuja [lateral de pie, frente, derecha, espalda] = filas [0, 1, 2, 3]:
## la 0 es la pose lateral de pie (sin usar), la 1 el frente (abajo), la 2 el
## lateral caminando a la derecha (`Walk Right`, único lateral) y la 3 la espalda
## (arriba). Por eso el mapeo escribe la 1, la 2 y la 3, la izquierda refleja la 2,
## y la fila 4 trae salto/caída/muerte (muerte en la columna 2, yacente, fija) y la
## 5 el golpe con tres fotogramas (la columna 3 queda vacía).
static func _human_definition() -> CharacterVisualDefinition:
	var def := CharacterVisualDefinition.new()
	def.id = PLAYER_HUMAN
	def.sheet = "res://assets/characters/human_player.png"
	def.walk_row = 1
	def.row_side = 2
	def.row_up = 3
	def.row_side_mirrored = 2
	def.mirror_side = true
	def.alternate_attack = true
	def.attack_row = GameConfig.ACTOR_ROW_DOWN + 5
	def.attack_frames = 3
	def.dead_row = 4
	def.dead_column = 2
	def.dead_directional = false
	return def


## El ninja clásico, exactamente como estaba antes de las personas: 64x112 = 4x7
## de 16 px, golpe en la fila 4 y muerte en la fila de la orientación.
static func _ninja_definition() -> CharacterVisualDefinition:
	var def := CharacterVisualDefinition.new()
	def.id = PLAYER_NINJA
	def.sheet = "res://assets/characters/ninja_blue.png"
	def.attack_row = GameConfig.ACTOR_ROW_DOWN + 4
	def.dead_row = GameConfig.ACTOR_ROW_DOWN
	def.dead_column = 0
	def.dead_directional = true
	return def


## Prepara un `ActorSprite` para un actor del catálogo.
##
## Devuelve `false` si la hoja no existe o no se pudo cargar, para que quien llame
## pueda dejar al actor sin sprite en vez de quedarse con un nodo en blanco.
static func apply_to(id: StringName, sprite: ActorSprite) -> bool:
	if sprite == null:
		return false
	var def := definition_of(id)
	if def != null:
		return sprite.apply_definition(def)
	var path := sheet_of(id)
	if path.is_empty() or not ResourceLoader.exists(path):
		GameLogger.warning("Falta la hoja de %s (%s)" % [id, path], "ActorVisualCatalog")
		return false
	sprite.configure(path, walk_row_of(id), attack_row_of(id))
	return sprite.texture != null