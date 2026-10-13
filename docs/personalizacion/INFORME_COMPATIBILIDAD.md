# Informe de compatibilidad — Ropa y peinados (Fase 0)

Auditoría de la Fase 0 del `docs/Plan_Ropa_Peinados_Baracoa_City.md`: qué hay
realmente en el proyecto, qué se puede tocar y qué no, y qué cuesta de verdad
hacer ropa y peinados con el presupuesto de PixelLab.

Esta fase **no ha consumido ninguna generación**. Las únicas llamadas a PixelLab
han sido `get_balance` y `search_help` (documentación); ver el
`PIXELLAB_GENERATION_LOG.md`.

## Resumen ejecutivo (lo que decide el diseño)

1. **No hay camiseta que recolorear.** El personaje del jugador es un boxeador
   del pack *MeleeCharacter* **sin camiseta**: torso de piel, pantalón rojo en la
   cadera y botas azules. Poner una camiseta es **pintar encima**, no cambiar un
   color existente.
2. **La cobertura completa por IA es imposible con este presupuesto.** El
   personaje son **92 hojas** (23 clips × 4 direcciones) y **~2.236 fotogramas**
   (~559 por dirección). `transfer_outfit` / `edit_image` aceptan ≤15 frames de
   42×44 por llamada y cuestan **10–25 generaciones** cada una. Cubrir una prenda
   exigiría ~150 llamadas = **1.500–3.700 generaciones**. El presupuesto es **40**.
   Solo la animación de caminar (24 frames × 4) ya costaría 4–12 llamadas.
3. **La cobertura total solo sale a coste cero** si la prenda se **deriva del
   propio dibujo** (región/recolor por máscara) en vez de redibujarse fotograma a
   fotograma. Es la única vía compatible con "alineado en todas las direcciones y
   animaciones".

## 1. Entorno

- Godot **4.7.2-stable** (`4.7.2.stable.official.ed1daf0bf`). El binario no
  sobrevive a un reinicio: se reinstaló en `/tmp/opencode/godot/` como avisa
  `AGENTS.md`.
- Viewport 384×216, zoom de cámara 1, tile 16 px, `stretch/mode="viewport"`.
- Escena principal: `res://scenes/world/main.tscn` (la que monta F5). El mundo lo
  construye el autoload `Game` (`scenes/shared/game.tscn` → `GameSession`), que
  es el composition root.

## 2. Dónde vive el jugador y su controlador visual

- `MainWorldView` (`scripts/presentation/world/main_world_view.gd`) instancia
  `scenes/player/player.tscn` (`PlayerView`).
- `PlayerView` (`scripts/presentation/player/player_view.gd`, `CharacterBody2D`)
  construye sus hijos por código en `_ready()`:
  - `Actor` — **`ActorSprite`** (`Sprite2D`): el cuerpo dibujado.
  - `Hitbox` — `HitboxSensor` (`Area2D`): hitbox del golpe. **Es combate.**
  - `PunchArm` — `punch_arm.gd` (`Node2D`, `z_index = 1`): brazo dibujado para el
    puñetazo. Con la hoja Hormelz no pinta nada (el cuerpo trae su propio puño).
- Origen del nodo **en los pies**. Todo lo que se dibuja encima se coloca respecto
  a ese punto.

## 3. Cómo se controlan animación, dirección, fotograma, textura y anclaje

El reproductor es **`ActorSprite`** (`scripts/presentation/actors/actor_sprite.gd`,
`extends Sprite2D`) y es el **dueño único del estado visual**:

- `_clip`, `_elapsed`, `_facing`, `_playing` son suyos; `_process(delta)` avanza
  el fotograma y `_refresh()` vuelca el estado en las propiedades de `Sprite2D`
  (`texture`, `frame`, `offset`, `flip_h`).
- **Dos modos de recorte** (`CharacterVisualDefinition`):
  - **Rejilla clásica** (humano bit-era, ninja): `hframes`/`vframes`, filas por
    orientación y columnas = fotogramas.
  - **Hoja por orientación** (el jugador: Hormelz): cada clip trae **un PNG por
    dirección** en `sheet_clips[clip]["sheets"]`. La orientación decide **qué
    archivo** se carga (`_sync_sheet`), no se espeja, y `frame` es la **celda
    lineal** de esa hoja (row-major sobre `hframes × vframes`).
- **Dirección**: `_dir_number()` traduce `_facing` a `2` (izquierda), `4`
  (arriba), `6` (derecha), `8` (abajo). **Cuatro direcciones, no ocho.**
- **Anclaje**: en modo hoja-por-orientación, `offset = (0, alto/2 − feet[dir])`,
  con `feet` = línea de planta medida por dirección. Es lo que deja los pies en
  el origen.
- **Tinte de estado**: `PlayerView._apply_tint()` y `NpcView._apply_tint()` ponen
  `modulate` en el nodo de la vista (propaga a los hijos). Prioridad
  muerto > aturdido > herido > normal.

**Consecuencia para la personalización:** el estado autoritativo (clip,
orientación, fotograma, textura, offset, flip) es leíble desde fuera
(`current_clip()`, `facing()`, y las propiedades públicas de `Sprite2D`). Una capa
de ropa puede **leer** ese estado sin duplicar ningún reloj — que es justo lo que
exige el plan (`Sincronización obligatoria`).

## 4. Frontera de combate (archivos que NO se tocan)

Reglas del proyecto (`AGENTS.md`): la entrada de daño es única y vive en el
cuerpo de combate; el combate no depende de los sprites.

**No se modifica** sin autorización separada y justificación documentada:

| archivo | papel |
| --- | --- |
| `scripts/application/combat/melee_combat.gd` | reglas, fases, ventana de impacto, reloj del golpe |
| `scripts/application/npc/npc_combat.gd` | cuerpo de combate del enemigo (daño, stun, invulnerabilidad) |
| `scripts/presentation/player/hitbox_sensor.gd` | hitbox (solo física) |
| `scripts/domain/combat/*` | daño, ataques, reacciones, resultados |
| `scripts/presentation/player/player_presenter.gd` | puente entrada ↔ casos de uso (lee teclado, enciende hitbox) |
| `scripts/application/npc/*` | IA, director, mesa de aparición |

**Archivos de presentación compartidos** (se pueden tocar, pero son
compartidos y por eso el plan pide explicar el cambio mínimo y esperar
aprobación): `player_view.gd`, `npc_view.gd`, `actor_sprite.gd`,
`actor_visual_catalog.gd`, `character_visual_definition.gd`.

> El plan es explícito: *"La personalización solo debe cambiar los gráficos
> mostrados. No alteres colisiones, áreas, nodos de combate ni tiempos."*

## 5. Formato real de las hojas (medido, no supuesto)

- Raíz: `assets/characters/humans/hormelz_melee/<Clip>/Boxer__<Clip>_dirN.png`.
- **Celda 42×44 px** (`HormelzVisualData.CELL_WIDTH/HEIGHT`). Comprobado: `Idle1`
  = 252×264 = 6×6 celdas; `WalkFoward` = 210×220 = 5×5 (24 con dibujo); `Die1` =
  378×352 = 9×8 (65 con dibujo).
- **Rejilla**, no tira: `frame` es índice lineal sobre `hframes × vframes`.
- Fondo **transparente** (RGBA). Filtro **NEAREST**. Sin reescalado (el pack
  original de 126×132 está horneado a 1/3 con NEAREST).
- **Paleta medida** (idle dir8, primera celda): piel `(247,165,102)` y sombra
  `(239,125,87)`; rojo de pantalón `(177,62,83)` y `(135,50,88)`; azul de botas
  `(86,108,134)` y `(117,142,164)`; contornos `(26,28,44)` y `(59,33,68)`; luz
  `(244,244,244)` y `(255,205,117)`.
- Silueta del idle frontal (dir8): ocupa aprox. y = 10..36, x = 14..27 de la
  celda; la cabeza y el pelo van arriba, el torso de piel en medio, el rojo del
  pantalón en la cadera y el azul de las botas abajo.

**Regla del proyecto que aplica aquí:** contar celdas no basta; lo que no encaje
en la rejilla no da error, da un dibujo equivocado. Cualquier recurso nuevo se
valida **casiendo la hoja con el pack**, no contando.

## 6. Direcciones y animaciones reales

- **4 direcciones**: 2 izquierda, 4 arriba, 6 derecha, 8 abajo.
- **24 clips** (`HormelzVisualData.sheet_clips()`), 23 carpetas de hoja (los clips
  `attack` y `left_jab` comparten hojas) → **92 PNG**.

| clip | frames/dir | clip | frames/dir |
| --- | --- | --- | --- |
| idle | 1 | roll_forward | 16 |
| fight_idle | 1 | roll_stand | 33 |
| walk | 24 | hit_light | 12 |
| walk_back | 23 | hit_body | 21 |
| attack / left_jab | 15 | hit_head | 18 |
| right_jab | 11 | straight | 25 |
| left_hook | 16 | elbow | 23 |
| right_hook | 14 | front_kick | 29 |
| front_kick2 | 25 | high_kick | 33 |
| side_kick | 20 | stomp_kick | 29 |
| combo | 27 | dead | 65 |
| dead_alt | 63 | | |

Total ≈ **559 fotogramas por dirección × 4 = 2.236 fotogramas**.

## 7. Herramientas de PixelLab y coste real

Saldo comprobado: **`generations_remaining: 40`**, `generations_used: 0`,
`subscription: trial` (+5 diarias cuando se agota). Confirmado por `get_balance`.

Coste por `search_help` (no inventado):

| herramienta | coste | límite |
| --- | --- | --- |
| `transfer_outfit` | **10–25 gen** por rejilla | ≤15 frames de 42×44 por llamada |
| `edit_image` (varios frames) | **10–25 gen** por rejilla | ≤16 frames en modo texto |
| `inpaint_image` | **10–25 gen** | según tamaño |
| `create_character_state` | **10–25 gen** | según canvas |
| `animate_character` | 1–8 gen por dirección según tamaño/modo | — |
| **`pixelart_workbench`** | **gratis, exacto** | "tú eres el artista"; edita/dibuja/describe |

PixelLab no garantiza alineación píxel a píxel ni anclaje exacto en
`transfer_outfit`/`edit_image`, según la documentación consultada.

## 8. Línea base de pruebas (antes de tocar nada)

Todas en verde, **sin `SCRIPT ERROR`** (solo WARNINGs de casos de camino negativo,
intencionados):

| suite | resultado |
| --- | --- |
| `tests/support/test_runner.gd` (unitarios) | **213/213** |
| `tests/integration/world_physics_runner.gd` | **6/6** |
| `tests/integration/combat_runner.gd` | **16/16** |
| `tests/integration/npc_combat_runner.gd` | **22/22** |
| `tests/integration/startup_runner.gd` | **25/25** |
| `tests/integration/inventory_runner.gd` | **9/9** |

> Los recuentos de `AGENTS.md` (151/6/11/21/17/9) están **desactualizados**: el
> proyecto ha crecido. La línea base a batir es la de esta tabla.

## 9. Conclusión de compatibilidad

El sistema actual **es compatible** con una capa de personalización de
presentación:

- El estado visual es **leíble desde fuera** y tiene un dueño único
  (`ActorSprite`), así que las capas pueden sincronizarse sin relojes propios.
- Existe ya un precedente exacto de "capa dibujada sobre el cuerpo": `PunchArm`.
- El tinte de estado (`modulate`) propaga a los hijos, así que una capa hija
  hereda herido/aturdido/muerte sin trabajo extra (a decidir si conviene).

Pero **el coste de la vía IA es incompatible con el presupuesto** para cobertura
completa (punto 2 del resumen). La estrategia viable está en
`PLAN_ROPA_PEINADOS.md` (Fase 1): derivar la prenda del propio dibujo (máscara /
recolor, coste 0) y reservar la IA para, como mucho, **una** prenda de autor como
referencia.
