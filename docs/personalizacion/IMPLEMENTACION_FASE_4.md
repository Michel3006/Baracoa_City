# Implementación Fase 4 — La pantalla del vestuario (interfaz de selección)

Cierra lo que quedaba abierto de la Fase 3: el sistema de ropa y peinados
**funcionaba pero solo por código** (`player.set_shirt(...)`). Aquí se le pone la
pantalla que usa el jugador, con el mismo patrón que la mochila. Sigue **sin
gastar una generación de PixelLab** (ver `PIXELLAB_GENERATION_LOG.md`).

## Qué se construyó

Tres archivos nuevos y cuatro cambios mínimos:

| archivo | qué es |
| --- | --- |
| `scripts/presentation/customization/appearance_selection.gd` | **Modelo puro** (`RefCounted`, sin nodos ni entrada): qué fila está elegida y por qué opción va cada una. Aquí viven `options()`, `cycle()` (da la vuelta), `switch_part()` (no da la vuelta) y los rótulos. |
| `scripts/presentation/ui/appearance_panel.gd` | La pantalla: `Control` a pantalla completa en su propia `CanvasLayer`, dibujada con `draw_rect` + `PixelFont`. |
| `tests/unit/test_appearance_selection.gd` | 8 casos del modelo, sin montar escena. |

Cambios fuera:

- `project.godot`: acción nueva **`toggle_appearance`** atada a `C` con **código
  físico** (`"keycode":0,"physical_keycode":67`), como todas las demás acciones del
  proyecto.
- `scripts/infrastructure/configuration/game_config.gd`: bloque `APPEARANCE_*`
  (medidas, colores, rótulos y el velo). Cero números mágicos en la pantalla.
- `scripts/presentation/world/main_world_view.gd`: `appearance_panel` +
  `_build_appearance()`, en su `CanvasLayer` **encima** del de la mochila.
- `scripts/shared/game.gd`: `appearance_panel.bind(player)` al aparecer el jugador,
  como `hud` y `inventory_panel`.
- `scripts/presentation/ui/inventory_panel.gd`: una línea en `open()` para que los
  dos modales no puedan estar abiertos a la vez (abajo se explica por qué).
- `scripts/presentation/player/player_presenter.gd`: la muerte del jugador ahora
  llega a la vista (hallazgo, ver más abajo).

## Cómo se usa

| acción | tecla |
| --- | --- |
| Abrir / cerrar el vestuario | `C` (`toggle_appearance`) |
| Navegar | `WASD` o flechas: izquierda/derecha elige, arriba/abajo cambia de fila |
| Confirmar / cerrar | `E` (`interact`) |

**Elegir es ponerse.** No hay borrador ni confirmación: mover la selección **pone**
la prenda y se ve al instante en la vista previa. Cerrar deja lo último elegido,
que es lo que hace un vestuario. La fila **no da la vuelta** (dos filas: camiseta y
peinado); la opción **sí** (carrusel en los dos sentidos) y la opción 0 es
**"nada puesto"**, porque el boxeador del pack va con el torso desnudo y quitarse
la ropa tiene que estar en la lista como una opción más.

`Esc` no cierra el vestuario: sigue siendo la tecla de salir del juego, igual que
en la mochila.

## La vista previa: un espejo, no un muñeco

El panel **no dibuja un personaje aparte**. Monta un `Node2D` (`Preview`) con un
`Sprite2D` que **copia** del cuerpo real, cada fotograma, `texture`, `hframes`,
`vframes`, `frame`, `offset`, `flip_h` y `centered`, más dos `GarmentLayer` que
apuntan al cuerpo de verdad (`actor`) y al **mismo** `AppearanceState` del jugador.
No tiene estado propio: si el recuadro pudiera equivocarse, no tendría de dónde.

Está **a propósito sin tinte**: el cuerpo del mundo se tiñe al recibir daño, pero el
recuadro existe para leer el color de la prenda, así que no hereda ni el rojo ni el
gris de la muerte.

El `Preview` va en `PROCESS_MODE_DISABLED` mientras el panel está cerrado (no
cuesta nada) y en `PROCESS_MODE_ALWAYS` cuando está abierto: **el recuadro se
actualiza con el mundo pausado**, que es justo cuando hay que enseñar la elección.
Medido: con el árbol parado, cambiar la camiseta pasa sus píxeles en pantalla de
**0 a 62** sin que se reanude nada.

## Un solo modal a la vez (el velo que pausa dos veces)

Los dos paneles pausan el árbol al abrirse y lo reanudan al cerrarse. Si estuvieran
los dos abiertos, cerrar el primero **reanudaría el mundo por detrás del segundo**.
Por eso los dos `open()` empiezan rechazando si el árbol ya está pausado:

```gdscript
var tree := get_tree()
if tree != null and tree.paused:
	return false
```

Consecuencia buscada: el vestuario tampoco se abre cuando el mundo está parado por
otra cosa. Y es la razón por la que el panel **no se abre con el jugador muerto**:
pausar el mundo detrás de la pantalla de muerte rompería la reaparición. La
mochila ya lo hacía con el estado de dominio; el vestuario lo comprueba con
`PlayerView.is_dead()`.

## El hallazgo: la muerte del jugador no estaba cableada

Al escribir el guardián de "no abrir el vestuario con el jugador muerto" salió un
fallo de otro género, de los que este proyecto ya tiene un patrón:

`PlayerView.set_dead()` existía entero (apaga la hitbox, corta el puñetazo en
curso, reproduce el clip `DEAD` y pone el tinte gris) **y no lo llamaba nadie**.
El `PlayerPresenter` no lo sincronizaba, así que el jugador moría **de pie** con su
última animación, y `PlayerView.is_dead()` era **siempre** `false` — el guardián
habría sido código muerto. Los NPC y el muñeco de pruebas sí lo hacían
(`npc_presenter.gd`), o sea que eran **el jugador el único que no**.

Se sincroniza donde vive el reloj del combate, antes de los cortes de
`_physics_process` (para que la muerte se dibuje también durante el hit stop y
aunque no haya combate enganchado):

```gdscript
if _view != null:
	_view.set_dead(_combat != null and _combat.is_dead)
```

`MeleeCombat.is_dead` lee del dominio (`player.is_dead`), así que la reaparición lo
devuelve solo. Comprobado **en vivo** (el jugador murió de verdad, matado por la IA
mientras se hacían las medidas):

| | valor |
| --- | --- |
| clip del cuerpo | `dead` |
| tinte | `(0.45, 0.45, 0.5, 0.85)` |
| `PlayerView.is_dead()` | `true` |
| `C` con el jugador muerto | **no abre** el vestuario, y no pausa el mundo |

## Validación (medida, no mirada)

### Suites

| suite | antes | después |
| --- | --- | --- |
| unitarios | 225/225 | **237/237** (+12: 8 del modelo + 4 del espejo por clip y dirección) |
| world_physics | 6/6 | 6/6 |
| combat | 16/16 | 16/16 |
| npc_combat | 22/22 | 22/22 |
| startup | 29/29 | **36/36** (+6 de la pantalla) |
| inventory | 9/9 | 9/9 |

Ninguna suite con `SCRIPT ERROR` ni fuga de nodos. Los seis casos nuevos de
`startup_runner.gd` son:

1. **Abre con C, navega y viste.** Se empuja la tecla **al viewport** (pulsación y
   suelta, con código físico) y no se llama al método a mano: así se mide de paso
   que la entrada **llega de verdad**, que es lo que se rompe si alguien olvida el
   `PROCESS_MODE_ALWAYS`. Comprueba además la geometría del panel (cabe en la
   pantalla, la vista previa no pisa las filas, las filas no se solapan) y que el
   carrusel da la vuelta por los dos lados.
2. **Con el mundo parado el panel sigue oyendo la entrada.** Con un **testigo**:
   una sonda `Node` corriente en el árbol no recibe nada con el mundo pausado y el
   panel sí. Las dos mitades: la primera demuestra que el reparto respeta la pausa.
3. **Mochila y vestuario son excluyentes**, por los dos lados, y el mundo sigue
   pausado una sola vez.
4. **No se abre con el jugador muerto**, y al reaparecer sí.
5. **La vista previa es un espejo del cuerpo**: campo a campo, dentro del recuadro,
   sigue un cambio de orientación con el mundo parado, y lo que enseña el recuadro
   son **los mismos bytes** que acaban en el mundo.
6. **Con ropa el cuerpo camina, golpea y muere igual**: recorrer el menú entero de
   camisetas y peinados **no cambia** vida, stamina, posición, `combat_target` ni
   hitbox; y con ropa puesta el cuerpo camina en las cuatro direcciones, golpea y
   muere sin que la prenda se separe del cuerpo ni un fotograma.

### En vivo, con el puente del editor

Además de las suites, con el juego de verdad bajo el puente (`docs/tooling/GODOT_MCP.md`):

| medida | resultado |
| --- | --- |
| abrir con `C` físico | panel abierto, `tree.paused = true` |
| geometría | panel `(228,4) 152×208` dentro de `384×216`; recuadro `(234,22) 140×56` |
| navegar con `move_right`/`move_down` inyectados | `shirt_red` puesto, `hair_black` puesto, rótulos `SHIRT RED`/`HAIR BLACK` |
| **píxeles de la prenda en el recuadro** | **62 de 62** píxeles opacos de la superposición (exacto, 1 a 1) |
| quitar la prenda (A/B) | **62 → 0 → 62** |
| píxeles de la prenda **en el mundo**, sobre el cuerpo | **57 de 62**, contra la paleta **prevista** con el tinte (`paleta × modulate`); los 5 que faltan los tapan el pelo y el brazo |
| `C` con el jugador muerto | no abre; el mundo no se pausa |

El recuento en el recuadro es exacto porque el espejo dibuja a 1:1: cada píxel
opaco de la superposición tiene que aparecer una vez en pantalla. Que el número
salga **igual** es la prueba de que lo que se ve es la prenda y no otra cosa.

## El combate quedó intacto

```
$ git diff --stat -- scripts/domain scripts/application
(vacío)
```

Lo único compartido que se tocó es `PlayerView` (fase anterior) y
`player_presenter.gd`, y este último solo **añade** el volcado de la muerte a la
vista leyendo `MeleeCombat.is_dead`: no se cambió ninguna colisión, hitbox ni
`combat_target`, ni un tiempo.

## Qué NO se hizo (y por qué)

- **Ninguna generación de PixelLab** (0 de 40).
- **Ningún PNG nuevo.** Sigue sin existir `assets/characters/customization/`: la
  vía de coste 0 no necesita imágenes.
- **Nada de persistencia.** La apariencia no se guarda en `GameSession`; se pierde
  al cerrar el juego. Es una decisión aparte.
- **Nada de peinado con forma.** El usuario decidió **dibujarlo a mano y gratis**
  con `pixelart_workbench`; es el siguiente incremento, no este.
