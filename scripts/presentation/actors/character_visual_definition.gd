class_name CharacterVisualDefinition
extends RefCounted

## Definición visual de un personaje: qué hoja se recorta y qué filas y fotogramas
## usa cada animación (sección 8 de la especificación de personas).
##
## Solo datos, sin nodos ni lógica de juego: ni el estado, ni la vida, ni el daño
## se tocan aquí. Es el punto donde un personaje deja de ser "la hoja del pack"
## para ser "lo que el reproductor necesita saber de esa hoja". El ninja, el
## humano y (en las fases de ciudadanos) cualquier persona real son instancias de
## este mismo dato con valores distintos.
##
## Los valores por defecto son los que ya usaban las hojas antiguas, así que una
## definición mínima replica el comportamiento de siempre y solo hay que escribir
## lo que cambia.
##
## Dependencias: presentation -> infrastructure/configuration

## Nombre con el que el catálogo identifica a esta definición.
var id: StringName = &""
## Hoja de sprites de la que se recorta.
var sheet: String = ""
## Lado de un frame. El pack usa 16x16; se deja aquí porque una hoja futura
## (personas reales) podría traer otra rejilla.
var frame_size: int = GameConfig.ACTOR_FRAME_SIZE
## Fila de la orientación de abajo (las otras tres salen sumando `ACTOR_ROW_*`).
var walk_row: int = GameConfig.ACTOR_ROW_DOWN
## Fotogramas por ciclo de caminata y segundos entre cada uno.
var walk_frames: int = GameConfig.ACTOR_WALK_FRAMES
var walk_fps: float = GameConfig.ACTOR_WALK_FPS
## Fila del golpe y cuántos fotogramas la recorren.
##
## No tiene por qué ser `walk_row + 4`: el humano ataca en la fila 5 con tres
## fotogramas, el ninja en la 4 con cuatro. La fila se escribe aquí, no se deduce.
var attack_row: int = 0
var attack_frames: int = GameConfig.ACTOR_ATTACK_FRAMES
var attack_fps: float = GameConfig.ACTOR_ATTACK_FPS
## Fila y columna del frame de DEAD, y si la muerte respeta la orientación.
##
## El ninja no tiene muerte dibujada: cae en la pose quieta de la fila en la que
## mira (`dead_directional = true`). El humano tiene una muerte real (fila 4,
## columna 2, yacente) que es fija: no cambia con la orientación.
var dead_row: int = 0
var dead_column: int = 0
var dead_directional: bool = true