# Implementación Fase 3 — Ropa y peinados a coste 0

Registro de lo que se construyó para la prueba mínima del
`docs/Plan_Ropa_Peinados_Baracoa_City.md` (1 camiseta + 1 peinado), **sin gastar
una sola generación de PixelLab** (ver `PIXELLAB_GENERATION_LOG.md`).

Decisiones que cerró el usuario antes de tocar código:

1. **Coste 0 primero** (recolor por región), y decidir la vía de IA después.
2. **Sí** se autorizó el cambio mínimo de `PlayerView` (añadir hijos de dibujo).
3. Peinado = **solo color** (coste 0).

## Qué se construyó

Cinco archivos nuevos, todos en `Presentation` (`RefCounted` puros salvo la capa),
más el cambio mínimo en `PlayerView`:

| archivo | qué es |
| --- | --- |
| `scripts/presentation/customization/garment_definition.gd` | Datos de una prenda: `id`, `part` (SHIRT/HAIR), `label`, `palette` (`Color` de la hoja -> `Color` de prenda) y la banda (`top_ratio`/`bottom_ratio`). |
| `scripts/presentation/customization/appearance_state.gd` | `RefCounted` con `shirt_id`, `hair_id` y señal `changed()`. Cosmético: no entra en el dominio. |
| `scripts/presentation/customization/garment_catalog.gd` | Catálogo estático: 7 camisetas y 6 peinados, cada uno con sus 4 tonos (base, sombra, luz, oscura). Añadir un color = añadir una fila. |
| `scripts/presentation/customization/garment_recolor.gd` | El núcleo: construye la superposición desde la propia hoja (por bytes, con caché del lado de la capa). |
| `scripts/presentation/customization/garment_layer.gd` | `Sprite2D` que **replica** el estado del `ActorSprite` cada fotograma (sin reloj propio) y dibuja la superposición. |

Cambios fuera de la carpeta nueva:

- `scripts/presentation/player/player_view.gd`: en `_build_actor()` se añaden dos
  `GarmentLayer` (`ShirtLayer`, `HairLayer`) tras el cuerpo y el brazo, con
  `z_index = 0`; y los métodos `set_shirt()`, `set_hair()`, `appearance_state()`.
  **No se toca** colisión, `Hitbox`, `combat_target`, señales ni tiempos.
- `scripts/infrastructure/configuration/game_config.gd`: constantes de las bandas
  (`GARMENT_SHIRT_TOP_RATIO`…), sin números mágicos.
- `ActorSprite` **no se tocó**: todo lo que la capa lee (`texture`, `frame`,
  `offset`, `flip_h`, `hframes`, `vframes`, `sheet_path`, `centered`) ya era
  público.

## Cómo funciona (y por qué por región)

El boxeador va **sin camiseta**, así que una camiseta es *pintar sobre los píxeles
de piel del torso*. En vez de dibujar 2.236 fotogramas, `GarmentRecolor` recorre la
hoja y, **por cada celda**:

1. Calcula el **rectángulo del cuerpo de ese fotograma** (saltando transparentes).
2. Se queda con la **banda** de la prenda, en fracciones de la altura del cuerpo
   (así sigue al fotograma: el torso de una patada no está donde el del reposo).
3. Sustituye los **colores clave** (los 4 tonos de piel) que caen dentro por los de
   la prenda; lo demás queda **transparente**.

La alineación es **exacta por construcción** (son los mismos píxeles, la misma
rejilla, el mismo anclaje) y la **oclusión es automática**: brazos, manos y botas
son de otro color, así que no se manchan.

### Geometría medida sobre el pack real (no razonada)

Medido con un volcado ASCII de la hoja real (`Idle1_dir8`, celda 42×44):

- Cabeza: `y` 10..16 (7 px). Ojos (blanco) en `y` 14.
- Banda de camiseta `0,26`–`0,56` de la altura: `y` 17..25 → cuello, torso y
  cintura. **No** toca la cabeza ni el pantalón rojo (`y` 26..28) ni los muslos
  (piel, `y` 29..31) ni las botas.
- Bandas de pelo `0,0`–`0,12`: `y` 10..13, **por encima de los ojos** (si se usa
  0,18 como al principio, pinta 6 de las 7 filas de la cabeza: la cara).

### Cuerpos tumbados (muerte)

Cuando el cuerpo es más ancho que alto (muerto/rodando) la banda pasa a ser
**horizontal y centrada**, donde cae el torso. El **pelo no se pinta** en ese caso:
en un cuerpo tumbado la cabeza está en un extremo, pero no se sabe en cuál (el mismo
fotograma sirve para las dos direcciones espejadas), y pintarlo "en el centro" se lo
pondría en el torso. Es una **aproximación documentada**: la pose de muerte es
transitoria (2 s) y no merece una regla por fotograma.

## Validación (medida, no mirada)

### Suites

| suite | antes | después |
| --- | --- | --- |
| unitarios | 213/213 | **225/225** (+12: 5 de catálogo, 7 de recolor) |
| world_physics | 6/6 | 6/6 |
| combat | 16/16 | 16/16 |
| npc_combat | 22/22 | 22/22 |
| startup | 25/25 | **29/29** (+4 de integración de la prenda) |
| inventory | 9/9 | 9/9 |

Ninguna suite con `SCRIPT ERROR`. Los casos de integración viven en
`startup_runner.gd` (es "lo que se ve") y comprueban: que la capa se pone y se
quita, que **replica** fotograma y espejo del cuerpo en las 4 direcciones sin
desincronizarse, que va encima del cuerpo sin añadir física, y que **pelo y
camiseta no comparten un solo píxel** (bandas disjuntas).

Los unitarios no montan escena: construyen hojas **sintéticas** y comprueban dónde
pinta (torso sí, cabeza/pantalón no), que no toca lo que no es piel, el cuerpo
tumbado y la rejilla de varias celdas. Se usan hojas sintéticas y no reales para que
retocar el pack no rompa un test que no tiene nada roto.

### Captura real (`xvfb`, recuento de píxeles)

`godot --rendering-driver opengl3` bajo `xvfb`, captura a zoom 1 y recuento de
píxeles exactos:

| | sin prenda | con prenda |
| --- | --- | --- |
| píxeles del color de la camiseta | **0** | **62** |
| píxeles del color del pelo | **0** | **12** |
| píxeles de piel | 102 | 28 |
| píxeles de ojo/blanco | 5 | 5 |

Y la posición: con el jugador centrado (~192, 108), la camiseta cae en `y` 88..96
(torso) y el pelo en `y` 82..84 (cabeza), las dos centradas en `x ≈ 191`. O sea: la
prenda **se dibuja de verdad**, en el cuerpo, y **la cara no se tapa** (los ojos
siguen ahí).

Demostración visual en `prueba_ropa_vs_base.png`: a la izquierda el boxeador base,
a la derecha con camiseta roja y pelo rubio (recorte ampliado 6×). El recuento de
ese montaje da 0 píxeles de camiseta en la mitad izquierda y 2.232 en la derecha
(62 píxeles escalados 6×6), que es lo que confirma que el cambio es la prenda y no
otra cosa.

## El combate quedó intacto (diff vacío)

```
$ git diff --stat -- scripts/application/combat scripts/application/npc \
      scripts/presentation/player/hitbox_sensor.gd scripts/domain/combat \
      scripts/presentation/player/player_presenter.gd
(vacío)
```

Los archivos de combate salen **sin cambios**. Lo único compartido que se tocó es
`PlayerView`, y solo para **añadir hijos de dibujo** (`ShirtLayer`, `HairLayer`) y
tres métodos de conveniencia: no se cambió ninguna colisión, hitbox,
`combat_target`, señal ni tiempo.

## Limitación conocida: el personaje va rapado

El pack *MeleeCharacter* dibuja al boxeador **sin pelo**: la cabeza es piel y ojos,
no hay mechón que recolorear. Por eso el "color de pelo" **no puede** dar un
peinado: pinta la coronilla (por encima de los ojos), que es lo máximo que se puede
hacer sin forma nueva. Un peinado de verdad necesita una **capa con forma** (un
overlay 42×44 por dirección), que se puede **dibujar gratis** con
`pixelart_workbench`, o encargar a IA (1 tanda de 10–25 generaciones). Esa decisión
queda abierta.

## Qué NO se hizo

- **Ninguna generación de PixelLab** (0 de 40).
- Ningún PNG nuevo: no se creó `assets/characters/customization/` porque la vía de
  coste 0 no lo necesita (el "recurso" es una tabla de colores + una regla).
- No se tocó ningún archivo de la lista de combate del informe.
- No se añadió interfaz de selección: primero se valida el sistema visual (Fase 3).
