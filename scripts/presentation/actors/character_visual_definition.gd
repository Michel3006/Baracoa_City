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
## Alto de la celda. `0` = celda cuadrada (= `frame_size`). Las hojas horneadas
## miden 44 de alto con 42 de ancho y hay que dividir cada eje por su medida.
var frame_height: int = 0
## Fila de la orientación de abajo (el frente). Es la base de la que salen las
## otras tres en el pack clásico (`walk_row + ACTOR_ROW_*`); una hoja ajena puede
## ordenar sus filas distinto y entonces se escriben aquí las otras tres.
var walk_row: int = GameConfig.ACTOR_ROW_DOWN
## Filas de las otras tres orientaciones, en coordenadas absolutas de la hoja.
## El pack clásico las tiene en 1, 2 y 3; la persona de bit-era ordena sus filas
## [lateral de pie, frente, lateral derecho, espalda] = [0, 1, 2, 3], así que
## escribe aquí la 1, la 2 y la 3 (la 0 queda sin usar: es la pose lateral de pie).
var row_side: int = GameConfig.ACTOR_ROW_SIDE
var row_up: int = GameConfig.ACTOR_ROW_UP
var row_side_mirrored: int = GameConfig.ACTOR_ROW_SIDE_MIRRORED
## Si la hoja no trae el lateral de la izquierda dibujado: el lado izquierdo sale
## de reflejar en horizontal el lateral. La persona solo camina hacia la derecha
## (`Walk Right` del pack de bit-era); el pack clásico trae los dos laterales
## dibujados y esto va en `false`.
var mirror_side: bool = false
## Si el clip del golpe se refleja en golpes alternos para que el puñetazo salga
## unas veces con una mano y otras con la otra, siempre hacia donde se mira. De
## lado la hoja solo guarda un puño, así que ahí no se refleja en golpes alternos:
## el puño sale siempre hacia la orientación (izquierda reflejada, derecha tal
## cual) y la dirección del golpe la llevan la hitbox y el arco de efecto. Es
## visual: no toca daño, alcance, cooldown ni ningún valor de juego.
var alternate_attack: bool = false
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
## Punto del que arranca el brazo del puñetazo: los dos guantes de la pose
## quieta, en coordenadas del nodo (los pies en el origen) y en el cuadro sin
## reflejar.
##
## Es lo que necesita `PunchArm` para dibujar el brazo: el brazo arranca en el
## guante para taparlo, así que si estos valores no coinciden con lo que la hoja
## tiene dibujado asoman píxeles de guante por debajo. Medidos píxel a píxel sobre
## cada hoja: el humano los tiene en (-2, -6) y (1, -6) — las dos manchas blancas
## de la cintura — y el ninja en (-6, -5) y (4, -5), que son sus manos azules a
## los costados.
var guard_hands: Array[Vector2] = [Vector2(-2.0, -6.0), Vector2(1.0, -6.0)]
## Cabeza del cuadro, en coordenadas del nodo: la región que el cuerpo dibuja en
## las filas de arriba.
##
## Sirve para que el brazo del puñetazo se esconda detrás de la cabeza cuando el
## golpe va hacia arriba, que es hacia donde la cámara no ve: en esa orientación
## el brazo se aleja de la cámara y la cabeza tapa lo que pasa por detrás, igual
## que taparía el arma. Solo se recorta el brazo si el golpe va hacia arriba; en
## las otras tres orientaciones va hacia la cámara o de lado y se dibuja encima.
## Medido: la cabeza del humano ocupa y = -16..-10 (el pelo, que es negro) y la
## del ninja y = -14..-8. Ocupa el ancho del cuadro entero, que es lo único que
## el recorte usa.
var head_rect: Rect2 = Rect2(-8.0, -16.0, 16.0, 7.0)
## Paleta del brazo dibujado del puñetazo: brazo, puño y contorno.
##
## Salen de la propia hoja, porque el brazo se dibuja encima del cuerpo y tiene
## que confundirse con lo que la hoja ya pinta. El humano tiene la piel pálida
## (233, 240, 146) y los guantes blancos; el ninja tiene los brazos azules de la
## armadura (121, 184, 206), las manos en verde apagado (95, 113, 96) y el
## contorno casi negro (20, 27, 27).
var punch_skin: Color = Color("e9f092")
var punch_glove: Color = Color.WHITE
var punch_outline: Color = Color.BLACK
## Fila y columna del frame de DEAD, y si la muerte respeta la orientación.
##
## El ninja no tiene muerte dibujada: cae en la pose quieta de la fila en la que
## mira (`dead_directional = true`). El humano tiene una muerte real (fila 4,
## columna 2, yacente) que es fija: no cambia con la orientación.
var dead_row: int = 0
var dead_column: int = 0
var dead_directional: bool = true
## Clips con hoja propia por orientación (packs horneados, como el Hormelz).
##
## Cuando este diccionario viene vacío, la hoja es una rejilla clásica y el
## reproductor recorta filas y columnas como siempre. Cuando trae datos, cada
## clip no recorta nada: la orientación decide QUÉ ARCHIVO se carga (el arte ya
## viene dibujado para esa dirección, sin espejos) y el fotograma es la celda
## lineal de esa hoja. La estructura de cada clip es la de
## `HormelzVisualData.sheet_clips()`: `sheets` (dir -> ruta), `feet`
## (dir -> línea de planta en píxeles de celda), `frames`, `fps` y `loop`.
##
## El resto de campos de esta definición siguen mandando para lo que son
## datos de la hoja (tamaño de celda, fila del golpe para el catálogo), pero
## las filas y el espejo solo los usa la rama de rejilla clásica.
var sheet_clips: Dictionary = {}
## Centro del torso, en coordenadas del nodo (los pies en el origen).
##
## Es el punto del que sale el arco de golpe (`SlashEffect.origin_for`): el
## brazo se articula desde el hombro, no desde los pies. Las hojas clásicas de
## 16 px tienen el torso en (-8); la persona horneada mide 26 px de alto, así
## que su centro está en -14 (medido: el contenido ocupa y = -26..-1). Si el
## arco sale desplazado en el eje transversal es porque este valor no coincide
## con el cuerpo real, no porque falle el efecto.
var torso_offset: Vector2 = GameConfig.ACTOR_SPRITE_OFFSET

## Alto de la celda de la hoja. `0` significa celda cuadrada (= `frame_size`):
## las hojas clásicas miden 16x16, pero las horneadas del Hormelz son de 42x44
## (el original es de 126x132 y 132/3 = 44) y dividir el alto por el ancho
## redondeado a veces daría una fila de más.
func cell_height() -> int:
	return frame_height if frame_height > 0 else frame_size