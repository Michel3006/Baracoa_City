class_name CombatDummy
extends Npc

## Muñeco de entrenamiento (sección 33).
##
## Es un `Npc` que no pelea. La sección 33 pide un `CombatDummy` con salud,
## hitbox de daño, visual, reacción al golpe, aturdimiento, retroceso y muerte:
## todo eso ya lo dan `Npc` + `NpcCombat`, que son el mismo sistema que usan los
## enemigos, así que el muñeco no inventa nada nuevo — es el caso "recibe el golpe
## y no responde". La diferencia con un enemigo es solo de configuración: un
## comportamiento pasivo (cero de todo lo que mueve o ataca) y un aspecto propio
## (`KIND`), que el catálogo visual resuelve como la persona de piedra.
##
## La reaparición (opcional según la sección 33; aquí se eligió `respawn = 2 s`,
## ver `GameConfig.DUMMY_RESPAWN_TIME`) vive en el generador de la presentación,
## no aquí: el dominio solo sabe morir y volver a la vida con `respawn_at()`.
##
## Dependencias: domain

## Identificador visual del muñeco. No es un `NpcKind`: los cuatro tipos de esa
## clase son enemigos que se reparten en la tabla de aparición, y el muñeco no se
## reparte. Es su propio id, que `ActorVisualCatalog` resuelve a la hoja de la
## persona con el tinte de piedra.
const KIND := &"dummy"


func _init(
	npc_id: int = 0,
	display_name: String = "MUÑECO",
	behavior: NpcBehavior = null
) -> void:
	super(npc_id, display_name, behavior if behavior != null else NpcBehavior.dummy())
	kind = KIND