# AGENTS.md

Contexto para continuar el desarrollo. Leer esto antes de tocar código.

## Qué es este proyecto

Juego pixel-art 2D top-down, multijugador server-authoritative, que recrea
progresivamente el municipio del desarrollador. La especificación maestra, con 41
secciones, está en `VIDEOJUEGO_MUNDO_ABIERTO_ESPECIFICACION.md` y manda sobre
este archivo cuando los dos discrepen. La sección 37 marca los pasos 1 a 10 como
la primera tarea concreta.

## Dónde estamos

**Fase 1 (prototipo offline). Pasos 1 a 10 cerrados, combate, enemigos y sprites
hechos.**

Última verificación, todo en verde:

```bash
godot --headless --script res://tests/support/test_runner.gd
# RESULTADO: 110/110 pruebas correctas

godot --headless --script res://tests/integration/world_physics_runner.gd
# RESULTADO: 6/6 pruebas correctas

godot --headless --script res://tests/integration/combat_runner.gd
# RESULTADO: 11/11 pruebas correctas

godot --headless --script res://tests/integration/npc_combat_runner.gd
# RESULTADO: 18/18 pruebas correctas

godot --headless --script res://tests/integration/startup_runner.gd
# RESULTADO: 10/10 pruebas correctas
```

Los enemigos están **desactivados** (`GameConfig.NPC_ENABLED = false`): el juego
arranca con la zona despejada para poder probar el movimiento y el mapa sin que la IA
se meta en medio. Para volver a encenderlos, ese `false` a `true`.

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

**Regla que sale de esto:** si una suite da error por consola, no está verde.
Mirar el log, no solo el `RESULTADO`.

### El combate con enemigos estaba entero y no se veía

Mismo género de fallo, y conviene conocerlo. Cuando se acabó el combate con armas
había seis enemigos con IA, sprites, barras y golpe, todo con sus pruebas en verde.
En el juego no pasaba nada. Cuatro cosas distintas, todas invisibles para los tests:

1. El reparto de objetivo estaba atado a `move_performed`, así que un jugador quieto
   no lo perseguía nadie. Se reparte ahora con un reloj propio
   (`GameConfig.NPC_TARGET_REFRESH`) y también al reaparecer.
2. Los enemigos estaban a 126 px del punto de aparición, muy por fuera del radio de
   detección de 70 y fuera de lo que enseña la cámara (64 x 36 px). Se podía recorrer
   el mapa entero sin ver un enemigo.
3. Uno de los seis había nacido **dentro** de un edificio, en el tile (14, 25), y se
   quedaba encajonado sin poder salir.
4. El fotograma del efecto de golpe es de 16 x 32, no de 16 x 16. Recortado en
   cuadrados, el arco se recorría por la fila de arriba de la hoja, que está casi
   vacía: el golpe parpadeaba en blanco en vez de dibujarse.

El 4 no lo encontró ningún test: salió de contar píxeles con un script aparte, porque
una hoja mal recortada no da error, da el efecto equivocado. Los otros tres sí, pero
solo con casos que miran lo que el jugador ve y no lo que el código devuelve:

- `npc_combat_runner` comprueba que ningún enemigo nace encajonado, y que al aparecer
  hay alguno dentro del rectángulo de la cámara y dentro de su radio de detección.
- `test_actor_sprite` comprueba la rejilla de cada hoja y que el efecto de golpe tiene
  ocho fotogramas en horizontal.

**Regla que sale de esto:** una prueba que mira el valor que devuelve el código no
comprueba que se vea. Para lo que el jugador ve hay que medir la pantalla.

### La animación no actualizaba hasta que pasaba un ciclo entero

`ActorSprite._process()` envolvía el acumulador y solo refrescaba el recorte cuando
se cerraba un ciclo completo, así que los primeros 0,5 s de caminata salían con la
misma pose. Lo encontró `test_actor_sprite` al comprobar que el ciclo pasa por los
cuatro fotogramas.

### Había dos mundos y el que se veía no estaba conectado a nada

El más caro de todos, y el mismo género que los anteriores. Al darle a F5 no se movía
el jugador: se movía el arma.

La causa: `project.godot` carga `scenes/world/main.tscn` como escena principal, y esa
escena tenía el script `MainWorldView`. Pero el mundo lo monta el autoload `Game`, que
es el composition root. O sea que al arrancar se construían **dos mundos enteros**: el
del autoload, con el `MovementController` enchufado, y el de la escena principal,
montado encima y sin un solo caso de uso. De los dos se dibujaba el segundo, con el
jugador clavado, y como se montaba después le tocó a él el `make_current()` de la
cámara. El jugador que sí se movía quedaba tapado por los tiles del otro mundo, y solo
se veían las cosas con `z_index` por encima del terreno: el sprite del arma (z=1), los
enemigos (z=1) y los arcos de golpe (z=8). De ahí el "el arma sí se mueve".

Las cuatro suites que había estaban en verde, y cada una por su motivo:

- Los unitarios no montan escenas.
- Los tres runners de integración usan `--script`, que carga los autoload pero **no**
  la escena principal. Es decir: ninguno había visto nunca lo que sale al darle a F5.
- Los de integración miraban `Game.world_view`, que sí estaba bien montado. El problema
  era el otro, y no lo buscaban.

La defensa es `tests/integration/startup_runner.gd`: carga la escena de
`application/run/main_scene` encima del autoload, igual que hace F5, y comprueba que
el árbol tiene **un** `MainWorldView` y **un** jugador, que ese jugador tiene el
`MovementController` y el `MeleeCombat`, que la cámara activa sigue a ese mismo
jugador, y que pulsando `move_right` se mueve. Con el fallo puesto baja a 5/7
diciendo "hay 2 copias de MainWorldView".

**Reglas que salen de esto:**

- **Un runner con `--script` no ve la escena principal.** Para probar el arranque hay
  que cargarla a mano desde `ProjectSettings.get_setting("run/main_scene")`.
- **Nada que monte una segunda vez lo que ya monta el composition root.** Si dos nodos
  compiten por el mismo papel, el último que se monta se queda con la cámara
  (`make_current()`) y con el dibujo, y el primero queda debajo sin que nadie se entere.
- **`z_index` delata lo que está debajo.** Un sprite que se ve y el cuerpo que no, con
  el `z_index` del sprite por encima del terreno, es la firma de un nodo tapado por otro.

## El arma se quedaba clavada en el centro del cuerpo

Que "no se ve como camina, no se mueven los pies" y "al parar se pone de lado". Las dos
cosas eran el mismo fallo, y no estaba ni en el ciclo de caminar ni en la orientación:
el código de la caminata ya estaba bien (medido: cuatro fotogramas por fila, y al parar
el fotograma es la columna 0 de la fila de la orientación, o sea que el personaje sí se
quedaba mirando donde iba).

El culpable era `PlayerView._place_weapon()`, que se llamaba **solo al pasar a quieto** y
durante el golpe. Caminando no se llamaba nunca, así que:

1. Al arrancar, el sprite del arma se quedaba en el origen del nodo. El origen del
   cuerpo está en los pies, así que eso es el centro del personaje: un palo de 3x16 px
   dibujado encima, con `z_index = 1`. Los pies no se veían porque había un palo encima.
2. Al cambiar de orientación **sin parar**, el arma se quedaba en la mano de la
   dirección anterior durante toda la vuelta.
3. Al parar se colocaba de golpe, y como la inclinación salía de `_facing.angle()` el
   palo se tumbaba en horizontal y saltaba de sitio. De ahí el "se pone lateral": era el
   arma, no el personaje.

**Reglas que salen de esto:**

- **Lo que se dibuja en un estado hay que colocarlo en todos, no solo en ese estado.**
  Si la colocación va atada a una transición (`if not moving`), el resto del tiempo el
  sprite se queda en el último sitio conocido, que es el origen del nodo la primera vez.
- **Un sprite no se ancla por su centro si representa una mano.** Anclado por el mango,
  el nodo es la mano y el arco del golpe gira alrededor de ella.
- **La geometría hay que mirarla, no razonada.** Aquí se razonó que "la mano va donde
  mira el personaje" y sonó bien, y el resultado fue el arma encima de las piernas al
  caminar hacia abajo. Lo que faltaba era medir el rectángulo del sprite contra el del
  cuerpo, que es lo que hacen los tres casos de `startup_runner.gd` sobre el arma.

## Qué falta, en orden

Es la lista de trabajo real. No inventar alcance extra: la especificación ya
define el orden.

### 1. Inventario y objetos

Lo siguiente, y lo único que falta de la Fase 1. No existe nada de esto todavía: no
hay `scripts/domain/inventory/` ni `scripts/domain/item/`.

- `Inventory` con `add_item`, `remove_item`, `has_item`, `get_quantity`,
  `use_item`, `equip_item`, `unequip_item` y capacidad
  (`GameConfig.PLAYER_INVENTORY_CAPACITY = 20`).
- `Item` genérico con `type`, `stackable`, `max_stack`, `metadata` y la taxonomía
  WEAPON / CONSUMABLE / MATERIAL / QUEST / CURRENCY / CLOTHING / TOOL / MISC. No
  hace falta implementar todos los tipos.
- El inventario no debe saber nada de gráficos; la UI lo consulta.
- `MeleeCombat.equip()` ya existe y es el gancho: no tocarlo para añadir inventario.
  `WeaponCatalog.UNARMED` ya permite combatir sin nada en la mano.

### 2. Remates de lo que ya funciona

No bloquean nada, pero se notan al jugar:

- **Los enemigos no dan feedback al pegar.** Cuando un NPC golpea al jugador no sale
  arco ni destello: solo baja la barra de vida. El arco del jugador ya sale y se
  borra solo, y hay un caso que lo comprueba.
- **El aturdimiento no tiene lectura visual.** Se aplica (`_on_stun_applied`) pero no
  se ve.
- **La muerte no avisa con texto.** El HUD son barras dibujadas, sin letras, porque la
  fuente del sistema sale borrosa a 384x216. Al morir solo se tiñe la pantalla de rojo.
- **Los enemigos del pack no tienen fila de golpe propia**: reutilizan la pose de
  frente, así que al atacar de lado el fotograma no encaja del todo. Está anotado en
  `ActorVisualCatalog.attack_row_of`.
- **La orientación del sprite lateral es una constante, no un hecho.** Las dos filas
  laterales de las hojas son imágenes especulares la una de la otra, así que no se
  puede deducir de los píxeles cuál es mirar a la izquierda y cuál a la derecha. Está
  en `GameConfig.ACTOR_ROW_SIDE` y `ACTOR_ROW_SIDE_MIRRORED`: si al jugar el
  personaje lateral va del revés, se intercambian esos dos números y no hay que tocar
  ningún otro archivo.
- **Un enemigo fuerte mata a un jugador quieto** en unos 15 s. Dentro de lo
  razonable, pero no se ha ajustado jugando.

### 3. Tests de lo que se añada

Los runners ya existen. Los unitarios no necesitan `SceneTree`; los que sí, van a
`tests/integration/` con su propio runner. Si un caso crea nodos, que tenga
`teardown()`: el runner lo llama tras cada caso, y sin él Godot avisa de fugas al
salir, que es un error por consola como cualquier otro.

Si lo que se toca es el arranque, lo que se mueve o lo que se ve, el sitio es
`startup_runner.gd`, y **no** hay que añadir casos a los otros: los otros tres miran un
solo mundo y por eso los cuatro suites possono estar en verde con el juego roto. Y si
un runner necesita enemigos, que los monte él (`npc_combat_runner._ensure_npcs()`):
depender de `GameConfig.NPC_ENABLED` ataría la suite a una bandera.

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
# tests unitarios (110)
godot --headless --script res://tests/support/test_runner.gd

# tests de integracion con fisica (6)
godot --headless --script res://tests/integration/world_physics_runner.gd

# tests de integracion de combate (11)
godot --headless --script res://tests/integration/combat_runner.gd

# tests de integracion de NPC (18)
godot --headless --script res://tests/integration/npc_combat_runner.gd

# tests de integracion de arranque (10)
godot --headless --script res://tests/integration/startup_runner.gd

# captura un frame: <salida> [frames] [x] [y] [zoom]
godot --script res://tests/support/screenshot.gd -- /tmp/shot.png 60 216 380 1

# reimportar tras cambiar project.godot
godot --headless --import
```

Tres avisos sobre estos comandos:

- Tras clonar o cambiar `project.godot`, correr `--headless --import` **antes** de
  los tests. Sin el caché de clases globales, `class_name` no resuelve y el runner
  no compila.
- El resultado se lee en el `RESULTADO` **y** en el log. Un `SCRIPT ERROR` por
  consola significa que algo está mal aunque el resultado sea verde.
- **`screenshot.gd` no funciona en `--headless`.** El driver de render headless no
  emite `frame_post_draw`, así que el script se queda esperando ahí y hay que
  matarlo: no deja fichero ni mensaje. Sin `Xvfb` instalado en esta máquina no hay
  forma de capturar la pantalla. Para revisar los sprites hay que leer las hojas
  contando píxeles, no mirando una captura.

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
- **Los sprites del pack no son cuadrados.** Los personajes son de 16x16, pero el
  efecto de golpe es de 16 de ancho por 32 de alto, y la hoja son 128x32: ocho
  fotogramas en una fila. Recortarla en 16x16 da ocho celdas por dos filas y el
  efecto recorre la fila de arriba, que está casi vacía. `GameConfig` tiene
  `ACTOR_FRAME_SIZE` y, aparte, `FX_FRAME_WIDTH` / `FX_FRAME_HEIGHT` por eso.
- **La orientación de las hojas laterales no se puede deducir.** Ver la nota del
  sprite lateral más arriba.
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