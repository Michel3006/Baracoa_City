# Sistema Visual de Personajes

Documentación del sistema que decide cómo se dibuja a cada personaje
(especificación de personas, secciones 7 a 21). Complementa el §9 de
`docs/architecture/ARCHITECTURE.md`, que describe la lectura de hojas; aquí se
cuenta la capa de definiciones que se añadió al migrar al jugador humano.

## 23.1 Propósito

El sistema visual responde a una sola pregunta: **dado un personaje del juego,
¿qué hoja se recorta y qué filas y fotogramas usa cada animación?** Antes de esta
tarea la respuesta estaba acoplada al ninja: `ActorVisualCatalog` tenía
`PLAYER_SHEET = ninja_blue.png` y una convención fija de filas (`walk_row + 4`
para el golpe, muerte en la fila de la orientación). Ese acoplamiento impedía
darle al jugador un personaje humano sin tocar la vista, y hacía imposible pensar
en ciudadanos futuros.

Ahora el gameplay (dominio) no sabe qué hoja se dibuja: `Player` y su estado no
mencionan sprites. La apariencia es una preocupación exclusiva de la capa
`Presentation`, y un personaje se describe con una **definición visual** de
datos puros. Cambiar el visual del jugador es cambiar un valor de configuración,
no reescribir la vista.

## 23.2 Arquitectura

La cadena real, de arriba a abajo:

    Player (dominio)
      ↓  (no sabe nada de sprites)
    PlayerView
      ↓  _build_actor(): ActorVisualCatalog.apply_to(PLAYER, actor)
    ActorVisualCatalog
      ↓  resuelve PLAYER → active_player() → GameConfig.PLAYER_VISUAL
    CharacterVisualDefinition  (datos: hoja, filas, fotogramas, fps)
      ↓
    ActorSprite.apply_definition(def)  →  Sprite2D (hframes/vframes, clips)
      ↓
    SpriteSheet (textura)

El flujo inverso del prompt (`GAMEPLAY → PLAYER → VISUAL DEFINITION →
SPRITESHEET`) se cumple: el gameplay no conoce el nombre del ninja ni del humano.

Piezas:

- **`CharacterVisualDefinition`** (`scripts/presentation/actors/character_visual_definition.gd`):
  `RefCounted` de datos puros. Campos: `id`, `sheet`, `frame_size`, `walk_row`,
  `walk_frames`, `walk_fps`, `attack_row`, `attack_frames`, `attack_fps`,
  `dead_row`, `dead_column`, `dead_directional`, y desde el arreglo de las
  direcciones: `row_side`, `row_up`, `row_side_mirrored` (filas absolutas de las
  otras tres orientaciones), `mirror_side` (el lateral izquierdo sale de reflejar
  el derecho) y `alternate_attack` (el golpe alterna de brazo en golpes seguidos,
  solo visual). Los valores por defecto son los de la convención antigua, así que
  una definición mínima replica el comportamiento de siempre y solo hay que
  escribir lo que cambia.
- **`ActorVisualCatalog`**: catálogo de actores. Para el jugador expone los ids
  `PLAYER` (alias), `PLAYER_HUMAN` y `PLAYER_NINJA`, y `active_player()` resuelve
  el alias según `GameConfig.PLAYER_VISUAL`. `definition_of(id)` devuelve la
  definición del jugador (y de futuras personas) y `null` para los enemigos, que
  conservan la ruta clásica `configure()`.
- **`ActorSprite`**: `apply_definition(def)` carga la hoja, la recorta con el
  `frame_size` de la definición y monta los clips IDLE / WALK / ATTACK / DEAD. El
  clip DEAD admite ahora una columna base: un frame fijo (la muerte yacente del
  humano) en vez de solo «fila de la orientación, columna 0» (la muerte del ninja).
- **`GameConfig.PLAYER_VISUAL`**: `&"player_human"` por defecto. Es el único knob
  para elegir visual del jugador; las vistas no conocen nombres de hoja.

## 23.3 Assets

El jugador usa `res://assets/characters/human_player.png`, la variante **00
(paleta canónica: negro + verde claro + blanco)** del pack *Bit Era Game
Character - Extended* de ImogiaGames (CC0, publicado en OpenGameArt; derivado de
*a cute little game character from bit era* de pavcreations). Se eligió tras
inspeccionar las hojas candidatas píxel a píxel (ver el informe final de la
tarea): los descartados fueron el `roguelikeChar_transparent.png` de Kenney
(tiles con margen de 1 px y disposición irregular) y las hojas de
`docs/sheet-pixelchar-01.png` / `02.png` (solo frontal, sin direcciones ni
ataque).

Dimensiones: **64x128 px, frame 16x16 → rejilla 4 columnas x 8 filas**. Es la
misma rejilla de 16 px que el resto del proyecto (mismo tamaño que el tile del
mapa), así que no hace falta tocar resolución, renderer ni estilo gráfico.

## 23.4 Animaciones

Mapping real de la hoja (confirmado casando fotogramas píxel a píxel y contra el
README del autor, no contando celdas):

| animación | clips en `ActorSprite` | fila | fotogramas | velocidad | detalle |
| --- | --- | --- | --- | --- | --- |
| IDLE | `IDLE` (direccional) | la de la orientación (§23.5) | 1 | — | la pose de pie de cada fila |
| WALK | `WALK` (direccional) | la de la orientación (§23.5) | 4 | 8 fps | frente=1, laterales=2 (derecha tal cual, izquierda reflejada), espalda=3 |
| ATTACK | `ATTACK` (fila fija) | **5** | **3** | 20 fps | 3 fotogramas; la columna 3 está vacía y no se lee; 0,15 s ≤ recuperación (0,22 s); alterna de brazo en golpes seguidos |
| DEAD | `DEAD` (fila fija) | **4**, columna **2** | 1 | — | pose yacente real del asset; no cambia con la orientación |

El golpe del humano tiene 3 fotogramas, no 4: la fila 5 es
`fotograma-idle → arco → impacto` y la cuarta celda está vacía. Es un puñetazo
con un solo brazo (el frame de impacto es asimétrico), así que en golpes
seguidos el reproductor lo refleja (`alternate_attack` en la definición) para
que salga con un brazo y el siguiente con el otro. Es puramente visual: daño,
alcance, cooldown y reloj del golpe son idénticos en cada golpe (no se tocan los
§13-14). La velocidad sale del clip, no de una constante global, así que cada
personaje lleva su ritmo.

## 23.5 Direcciones

El sistema sigue usando **4 direcciones** (Sur, Este, Norte, Oeste), como pedía
la especificación: no se añadieron 8. **OJO: el orden de filas de la hoja humana
NO es el del pack clásico.** Casar la hoja píxel a píxel con el README del autor
(`Idle side, Walk front, Walk Right, Walk back, ...`) da:

    fila 0 = pose lateral de pie / idle lateral   (sin usar para caminar)
    fila 1 = frente  → SUR     (walk_row, sin reflejo)
    fila 2 = derecha → ESTE    (row_side_mirrored, sin reflejo)
                        OESTE  (row_side, la misma fila REFLEJADA)
    fila 3 = espalda → NORTE   (row_up, sin reflejo)

O sea: el frente es la fila 1, la espalda la 3, y la hoja solo trae **un**
lateral (el de la derecha, `Walk Right`); la izquierda sale de reflejar esa misma
fila (`mirror_side = true` en la definición del humano). Por eso izquierda y
derecha comparten fila y se distinguen por el espejo, y por eso antes del arreglo
el jugador «caminaba abajo» al ir a la izquierda (la fila 1 es el frente), «hacia
arriba» al ir a la derecha (la fila 3 es la espalda) y «de lado» al ir arriba o
abajo (las filas 2 y 0 son los laterales).

Todo este mapeo vive **en la definición del humano** (`walk_row`, `row_side`,
`row_up`, `row_side_mirrored`, `mirror_side` en `ActorVisualCatalog`), no en
constantes globales: `ActorSprite` lee las filas de la definición. Los valores
por defecto de `CharacterVisualDefinition` siguen siendo las filas del pack
(0/1/2/3), así que el ninja y los enemigos no cambian.

La advertencia clásica sigue valiendo: las filas laterales de una hoja son
especulares la una de la otra, así que **no se puede deducir cuál es izquierda y
cuál derecha mirando los píxeles**. Aquí se resolvió con el README del autor
(`Walk Right`) y con el informe de jugador; la prueba definitiva es jugar. Si el
lateral saliera espejado, se intercambian `row_side`/`row_side_mirrored` (o el
`mirror_side`) en la definición del humano y no se toca nada más.

## 23.6 Frame size

**16x16**, medido en la hoja: 64 px de ancho / 4 columnas = 16, y 128 px de alto
/ 8 filas = 16. Coincide con `GameConfig.ACTOR_FRAME_SIZE` y con el tamaño del
tile del mapa. La definición lo lleva como campo (`frame_size`) por si una hoja
futura trae otra rejilla, pero hoy ninguna lo cambia.

## 23.7 Fallback

El ninja **no se borró**: `assets/characters/ninja_blue.png` sigue en el repo y
`ActorVisualCatalog.PLAYER_NINJA` conserva su definición exacta (golpe en la fila
4 con 4 fotogramas, muerte en la fila de la orientación). Para volver a él solo
hay que poner `GameConfig.PLAYER_VISUAL = &"player_ninja"`; nada más cambia.
Los tests comprueban ambas definiciones, de modo que el fallback no puede
romperse en silencio.

## 23.8 Extensión futura

Añadir otro personaje humano (un ciudadano, un policía, un médico, un enemigo
humano) **sin tocar gameplay** es: 1) copiar su hoja a `assets/characters/`,
2) crear una `CharacterVisualDefinition` con su fila de golpe, sus fotogramas y
su muerte, y 3) registrarla en `ActorVisualCatalog`. La vista (`ActorSprite`) no
se reescribe: ya lee filas, fotogramas, fps y columna de la definición. Los NPCs
pueden seguir usando enemigos lógicos + visual humano más adelante porque la
apariencia quedó separada de `NpcKind` (§20 de la especificación).