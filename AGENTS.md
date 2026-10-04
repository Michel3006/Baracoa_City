# AGENTS.md

Contexto para continuar el desarrollo. Leer esto antes de tocar código.

## Qué es este proyecto

Juego pixel-art 2D top-down, multijugador server-authoritative, que recrea
progresivamente el municipio del desarrollador. La especificación maestra, con 41
secciones, está en `VIDEOJUEGO_MUNDO_ABIERTO_ESPECIFICACION.md` y manda sobre
este archivo cuando los dos discrepen. La sección 37 marca los pasos 1 a 10 como
la primera tarea concreta.

## Dónde estamos

**Fase 1 (prototipo offline). Pasos 1 a 10 cerrados, combate y armas hechos.**

Última verificación, todo en verde:

```bash
godot --headless --script res://tests/support/test_runner.gd
# RESULTADO: 61/61 pruebas correctas

godot --headless --script res://tests/integration/world_physics_runner.gd
# RESULTADO: 6/6 pruebas correctas

godot --headless --script res://tests/integration/combat_runner.gd
# RESULTADO: 9/9 pruebas correctas
```

Los pasos 1 a 10 de la sección 37:

| paso | estado |
| --- | --- |
| 1. Inspeccionar entorno | hecho |
| 2. Proyecto Godot 2D | hecho |
| 3. Estructura de carpetas | hecho |
| 4. Documentación | hecho |
| 5. Mapa de prueba | hecho |
| 6. Jugador provisional | hecho |
| 7. Movimiento | hecho |
| 8. Cámara | hecho |
| 9. Colisiones | hecho y probado |
| 10. Ejecutar y verificar | hecho |

La sección 37 dice explícitamente: no avanzar al combate hasta que esto funcione.
Ya funciona, y el combate también.

### El combate estuvo roto y las pruebas no lo dijeron

Conviene saberlo, porque es la clase de fallo que se repite. `HitboxSensor`
llamaba a `add_excluded_object()`, que es API de `CollisionObject3D`. Dos
consecuencias:

1. El script no compilaba, así que arrastraba a los ocho scripts que lo
   referenciaban. El error no paraba el juego: Godot lo escribía en consola y
   seguía. `HitboxSensor.new()` fallaba en `_ready()` y la hitbox **nunca
   existía**.
2. Los tests seguían en verde. Los unitarios de `MeleeCombat` no dependen de la
   física, y los de integración comprobaban colisiones, no golpes. El combate
   "funcionaba" en las pruebas y no en el juego.

De ahí las dos defensas que hay ahora:

- `tests/unit/test_script_integrity.gd` recorre `scripts/` y obliga a que todo
  cargue y compile. Se comprobó reintroduciendo el fallo: la suite baja a 60/61
  diciendo qué script no compila.
- `tests/integration/combat_runner.gd` prueba la cadena real (presentador ->
  hitbox -> daño). Desconectar el combate del presentador lo baja a 6/9.

**Regla que sale de esto:** si unaSuite da error por consola, no está verde.
Mirar el log, no solo el `RESULTADO`.

## Qué falta, en orden

Es la lista de trabajo real. No inventar alcance extra: la especificación ya
define el orden.

### 1. Inventario y objetos

Lo siguiente. No existe nada de esto todavía: no hay `scripts/domain/inventory/`
ni `scripts/domain/item/`.

- `Inventory` con `add_item`, `remove_item`, `has_item`, `get_quantity`,
  `use_item`, `equip_item`, `unequip_item` y capacidad
  (`GameConfig.PLAYER_INVENTORY_CAPACITY = 20`).
- `Item` genérico con `type`, `stackable`, `max_stack`, `metadata` y la taxonomía
  WEAPON / CONSUMABLE / MATERIAL / QUEST / CURRENCY / CLOTHING / TOOL / MISC. No
  hace falta implementar todos los tipos.
- El inventario no debe saber nada de gráficos; la UI lo consulta.
- `MeleeCombat.equip()` ya existe y es el gancho: no tocarlo para añadir
  inventario.

### 2. NPC

Al menos uno, con `stats`, `state`, `position`, `behavior` y los estados IDLE /
WANDER / CHASE / ATTACK / FLEE / DEAD. Sin IA avanzada. La capa de física `npc`
ya está declarada.

`Player` y `Health` ya son reutilizables por un NPC: `Health` no depende de nada
de jugador.

El NPC tiene que ser un `CharacterBody2D`, ver la nota de `Area2D` más abajo.

### 3. HUD y muerte jugable

`GameSession.respawn()` existe pero no hay forma de invocarla desde el juego.
Falta HUD (vida, stamina, inventario) y el ciclo morir y reaparecer.

### 4. Tests de lo que se añada

Los runners ya existen. Los unitarios no necesitan `SceneTree`; los que sí, van a
`tests/integration/` con su propio runner.

## Reglas que no se negocian

1. **El dominio no depende de Godot.** `Player`, `Health`, `CharacterStats` y
   `PlayerState` son `RefCounted` puros, sin `Node`, sin `Input`, sin escenas. Es
   lo que permite probarlos sin arrancar nada.
2. **Las dependencias van en un sentido:**
   `Presentation -> Application -> Domain`, e `Infrastructure` debajo.
3. **Nada de `GameManager` monolítico.** `scripts/shared/game.gd` solo ensambla
   piezas en `_ready()` y suelta referencias en `_exit_tree()`.
4. **Los sistemas se comunican con señales**, no con referencias cruzadas.
5. **Nada de números mágicos**: todo valor ajustable pasa por `GameConfig`.
6. **El mundo se divide en zonas.** Nunca un mapa gigante.
7. **El cliente no es confiable** desde el primer día: daño, vida, inventario,
   dinero y posición final los decide el servidor.
8. **Cada incremento deja el proyecto ejecutable** y con los tests en verde.

## Comandos

```bash
# tests unitarios (61)
godot --headless --script res://tests/support/test_runner.gd

# tests de integracion con fisica (6)
godot --headless --script res://tests/integration/world_physics_runner.gd

# tests de integracion de combate (9)
godot --headless --script res://tests/integration/combat_runner.gd

# captura un frame: <salida> [frames] [x] [y] [zoom]
godot --script res://tests/support/screenshot.gd -- /tmp/shot.png 60 216 380 1

# reimportar tras cambiar project.godot
godot --headless --import
```

Dos avisos sobre estos comandos:

- Tras clonar o cambiar `project.godot`, correr `--headless --import` **antes** de
  los tests. Sin el caché de clases globales, `class_name` no resuelve y el runner
  no compila.
- El resultado se lee en el `RESULTADO` **y** en el log. Un `SCRIPT ERROR` por
  consola significa que algo está mal aunque el resultado sea verde.

## Entorno

- Godot **4.7.2-stable**, necesario para `config/features` de `project.godot`.
- El binario está en `/tmp/opencode/godot/`, que **no sobrevive a un reinicio**.
  Si `godot` no está en el PATH, reinstalarlo:

```bash
mkdir -p /tmp/opencode/godot && cd /tmp/opencode/godot
curl -L -o godot.zip "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"
unzip -o godot.zip && chmod +x Godot_v4.7.2-stable_linux.x86_64
ln -sf /tmp/opencode/godot/Godot_v4.7.2-stable_linux.x86_64 ~/.local/bin/godot
```

- Descarga lenta: ~78 MB, dejar tiempo.
- `export LC_ALL=C LANG=C` para quitar el ruido `xkbcommon` en consola.
- `~/.local/bin` puede no existir en una máquina nueva: crearlo antes del
  `ln -sf`, o el enlace falla.

## Detalles del diseño que conviene no redescubrir

- **`Area2D` no tiene lista de excepciones en Godot 4.** Ni `add_exception()` ni
  `add_excluded_object()` existen ahí: las excepciones son de `PhysicsBody2D`
  (`add_collision_exception_with()`). Un `Area2D` hijo del jugador, en la misma
  capa, detecta al propio jugador, así que `HitboxSensor` lo filtra en
  `overlapping_bodies()` con su propia lista `_ignored`. No volver a intentar
  delegarlo en el motor: no existe.
- **`Area2D.get_overlapping_bodies()` no ve `StaticBody2D`.** Comprobado: un
  `StaticBody2D` añadido en tiempo de ejecución, en la posición exacta y con la
  capa correcta, no aparece nunca, ni tras 200 frames ni reactivando
  `monitoring`. Un `CharacterBody2D` en el mismo sitio se detecta a la primera.
  Los objetivos de golpeo (NPC) tienen que ser `CharacterBody2D`, que además es lo
  natural porque se mueven. `intersect_shape()` sí encuentra los estáticos: no
  fiarse de esa vía para diagnosticar hitboxes.
- **Resolución 384x216**: 16:9 exacto, escala de ventana x3, tile de 16 px. Ojo:
  216 **no** es múltiplo de 16. No escribir tests que asuman lo contrario.
- **Zoom de cámara 3**: la imagen guardada por `screenshot.gd` es de 384x216, y
  cada píxel de imagen son 3 píxeles de mundo. Para medir sobre una captura hay
  tener esto en cuenta.
- **`move_and_slide()` no expulsa al instante**: con velocidad cero no deshace el
  solapamiento en el primer frame. Por eso los tests esperan varios
  `physics_frame`.
- **Lambdas de GDScript capturan locales por valor**: una lambda no puede
  modificar una variable local del ámbito exterior. Usar `Array` o variables de
  miembro para contadores.
- **Conectar señales entre dos `RefCounted` crea un ciclo** que Godot no
  recolecta. `GameSession.shutdown()` los rompe a mano; si añades una conexión
  nueva, añádela a `_links`.
- **El teleportaje pasa por `GameSession.teleport_to()`**, no por
  `MainWorldView.move_player_to()`: si no, dominio y vista quedan desalineados.
- **Los tests de integración desactivan el presentador**
  (`presenter.set_physics_process(false)`) porque el presentador lee el teclado y
  pisaría al controlador que el test maneja.

## Documentación relacionada

| archivo | contenido |
| --- | --- |
| `docs/architecture/ARCHITECTURE.md` | capas, flujo, coordenadas, colisiones, testing |
| `docs/gameplay/GAMEPLAY.md` | controles, movimiento, vida, estados, qué falta del MVP |
| `docs/networking/NETWORKING.md` | diseño server-authoritative de la Fase 2 |
| `docs/ROADMAP.md` | fases y checklist |
| `docs/maps/ZONE_001.md` | dimensiones y distribución del mapa de prueba |

## Git

El repositorio **no tenía ningún commit** al escribir este archivo. Si sigue así,
el commit inicial incluye la especificación, la estructura, los scripts, las
escenas, los tests y la documentación.