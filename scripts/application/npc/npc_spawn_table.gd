class_name NpcSpawnTable
extends RefCounted

## Qué enemigos aparecen en la zona de prueba y dónde (secciones 18 y 38).
##
## Un solo sitio con la lista. La capa Application la lee para saber qué
## estadísticas darle a cada uno y la capa Presentation para saber qué hoja de
## sprites usar, así que el mismo `kind` significa lo mismo en las dos capas y no
## hay dos listas que se desincronicen.
##
## Las posiciones están en tiles, que es como se coloca el resto del mapa: se
## multiplica por el tamaño de tile en vez de escribir píxeles sueltos.
##
## Dependencias: application -> domain, infrastructure/configuration

## Una entrada de la tabla. `behavior` decide sus estadísticas, `kind` su sprite.
class Entry extends RefCounted:
	var kind: StringName
	var display_name: String
	var behavior: NpcBehavior
	var tile: Vector2i

	func _init(p_kind: StringName, p_name: String, p_behavior: NpcBehavior, p_tile: Vector2i) -> void:
		kind = p_kind
		display_name = p_name
		behavior = p_behavior
		tile = p_tile


## Los enemigos de la primera demostración, con la mezcla deropolis.
##
## Tres débiles y tres duros: los débiles se matan de dos golpes de piedra, los
## duros exigen de verdad. Están los dos porque si solo hay débiles el combate no
## tiene nada que demostrar.
##
## ## Por qué están colocados alrededor del jugador y no en el centro del mapa
##
## Porque de lo contrario el combate era invisible. El jugador aparece en
## `PLAYER_SPAWN`, en el tile (12, 12), y los enemigos estaban en el tile (23, 22):
## a más de 120 píxeles, muy por fuera del radio de detección. Se podía recorrer el
## mapa entero sin ver un enemigo y sin enterarse de que el combate existía. Ahora hay
## dos a la vista al aparecer y los otros cuatro convergen conforme el jugador se
## mueve.
##
## ## Por qué lo verifica un test y no basta con mirar el mapa
##
## Un tile puede estar ocupado por una pared en cualquier momento sin que se note al
## escribir la lista: el único enemy que estaba en el tile (14, 25) había nacido
## dentro de un edificio y se quedaba encajonado allí sin poder salir. La capa
## Application no sabe qué hay dibujado en el mapa, así que no puede comprobarlo; lo
## comprueba `npc_combat_runner`, que sí tiene la escena montada.
static func demo() -> Array[Entry]:
	return [
		Entry.new(NpcKind.SLIME, NpcKind.display_name(NpcKind.SLIME), NpcBehavior.weak(), Vector2i(15, 12)),
		Entry.new(NpcKind.SLIME, NpcKind.display_name(NpcKind.SLIME), NpcBehavior.weak(), Vector2i(10, 13)),
		Entry.new(NpcKind.SPIDER, NpcKind.display_name(NpcKind.SPIDER), NpcBehavior.weak(), Vector2i(8, 11)),
		Entry.new(NpcKind.OWL, NpcKind.display_name(NpcKind.OWL), NpcBehavior.strong(), Vector2i(12, 16)),
		Entry.new(NpcKind.LIZARD, NpcKind.display_name(NpcKind.LIZARD), NpcBehavior.strong(), Vector2i(17, 8)),
		Entry.new(NpcKind.LIZARD, NpcKind.display_name(NpcKind.LIZARD), NpcBehavior.strong(), Vector2i(19, 16)),
	]


## Convierte la posición en tiles a coordenadas de mundo.
static func to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile) * float(GameConfig.tile_size())


## Los enemigos que hay que colocar, sin pasarse del máximo configurado.
static func count() -> int:
	return mini(demo().size(), GameConfig.NPC_SPAWN_COUNT)