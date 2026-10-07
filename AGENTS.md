# AGENTS.md

Contexto para continuar el desarrollo. Leer esto antes de tocar código.

## Qué es este proyecto

Juego pixel-art 2D top-down, multijugador server-authoritative, que recrea
progresivamente el municipio del desarrollador. La especificación maestra, con 41
secciones, está en `VIDEOJUEGO_MUNDO_ABIERTO_ESPECIFICACION.md` y manda sobre
este archivo cuando los dos discrepen. La sección 37 marca los pasos 1 a 10 como
la primera tarea concreta.

## Dónde estamos

**Fase 1 (prototipo offline) terminada: pasos 1 a 10, combate, enemigos, sprites,
HUD, feedback de golpe, inventario y los remates de UI (pantalla de la mochila,
aturdimiento con tinte propio, muerte con texto). Quedan dos remates que dependen
de cosas de fuera (texturas y play-test) y la Fase 2.**

Última verificación, todo en verde:

```bash
godot --headless --script res://tests/support/test_runner.gd
# RESULTADO: 151/151 pruebas correctas

godot --headless --script res://tests/integration/world_physics_runner.gd
# RESULTADO: 6/6 pruebas correctas

godot --headless --script res://tests/integration/combat_runner.gd
# RESULTADO: 11/11 pruebas correctas

godot --headless --script res://tests/integration/npc_combat_runner.gd
# RESULTADO: 21/21 pruebas correctas

godot --headless --script res://tests/integration/startup_runner.gd
# RESULTADO: 17/17 pruebas correctas

godot --headless --script res://tests/integration/inventory_runner.gd
# RESULTADO: 9/9 pruebas correctas
```

Los enemigos están **activados** (`GameConfig.NPC_ENABLED = true`) para poder
probar el combate contra la IA al jugar. Si se quiere la zona despejada (probar el
movimiento y el mapa sin que la IA se meta en medio), ese `true` a `false`.

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
4. El fotograma del efecto de golpe no es 16x16 ni 16x32: es un cuadrado de
   32x32, y la hoja son 128x32: **cuatro** fotogramas en una sola fila. Recortarla
   en 16x16 daba ocho celdas por dos filas y el efecto recorría la de arriba, que
   está casi vacía: el golpe parpadeaba en blanco en vez de dibujarse.

El 4 no lo encontró ningún test: salió de casar la hoja con el `Preview.gif` del
pack píxel a píxel (coincidencia exacta con la rejilla de 32x32), porque una hoja
mal recortada no da error, da el efecto equivocado. Los otros tres sí, pero solo
con casos que miran lo que el jugador ve y no lo que el código devuelve:

- `npc_combat_runner` comprueba que ningún enemigo nace encajonado, y que al aparecer
  hay alguno dentro del rectángulo de la cámara y dentro de su radio de detección.
- `test_actor_sprite` comprueba la rejilla de cada hoja, que el efecto de golpe
  tiene cuatro fotogramas cuadrados en una sola fila, y que el origen sale del
  centro del torso en las cuatro direcciones.

**Regla que sale de esto:** una prueba que mira el valor que devuelve el código no
comprueba que se vea. Para lo que el jugador ve hay que medir la pantalla.

### El arco salía en blanco y anclado en los pies

Dos fallos del mismo efecto, ambos invisibles para las suites mientras se trabajaba
en el feedback de golpe:

1. **La rejilla equivocada.** Recortada en 16x16, la hoja (128x32) se partía en dos
   filas y el arco recorría la de arriba, casi vacía: parpadeaba en blanco. Es un
   cuadrado de 32x32 y son cuatro fotogramas en una sola fila. No lo dijo ningún
   test: salió de casar la hoja con el `Preview.gif` del pack píxel a píxel
   (coincidencia exacta). La hoja de efecto es `slash.png`, y se recorta igual;
   la de las zarpas (`claw.png`) se borró el día que los enemigos dejaron de ser
   bestias.
2. **El origen en los pies.** El efecto se anclaba en el origen del nodo, que en
   los personajes está en los pies. Un arco "delante del personaje" puesto desde
   los pies queda bajo el cuerpo al mirar hacia abajo y mal en transversal hacia
   los lados. Ahora sale del centro del torso (`ACTOR_SPRITE_OFFSET` (0, -8)) más
   la dirección por `FX_ORIGIN_OFFSET` (14), vía `SlashEffect.origin_for()`.
   Medido sobre capturas reales en las cuatro direcciones, el bbox del arco
   coincide con el previsto con 1-2 px de error, y el efecto se borra solo al
   acabar el golpe.

**Reglas que salen de esto:**

- **Contar celdas no basta: hay que casar la hoja con una referencia.** Un
  `Preview.gif` del pack compara el recorte completo píxel a píxel y deshace
  cualquier duda de rejilla, número de fotogramas o filas.
- **"Delante del personaje" es delante del torso, no de la raíz del nodo.** Si el
  arma o el efecto cuelgan del nodo y el nodo está en los pies, lo dibujado se
  hunde o descuadra. Medir contra el cuerpo, no razonarlo.
- **Una captura sin efecto puede ser un ataque rechazado, no un fallo del
  efecto.** En la primera pasada, mirando abajo y arriba no salía el arco: el
  golpe era legalmente rechazado por cooldown. Bajo `xvfb` el render va sin límite
  de fps y `process_frame` no es tiempo de juego; para temporizar una secuencia
  hay que esperar `physics_frame`.

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

### El "anclaje por el mango" que no anclaba, y el golpe que nunca terminaba

Dos mosquitos reports ("camino y el player va dando vueltas" y "ataco y vuelve el bug
anterior") que son uno solo debajo, más un tercero que salió al mirar.

**El arma flotaba por encima de la cabeza.** El código ponía `centered = true` y
`offset = (-w/2, -h)` para "anclar por el mango". Con `centered = true` el rectángulo
que se dibuja es `posicion + offset - tamaño / 2`, así que ese offset deja el borde
inferior del arma **media altura por encima del nodo**: el palo se veía flotando 13 px
sobre la cabeza en las cuatro orientaciones, sin tocar el cuerpo. El comentario del
código y el nombre del test decían "mango en la mano" y era verdad solo para la posición
del nodo, que sí estaba bien. Medido con `Sprite2D.get_rect()` en un script aparte:
`centered=true, offset.y=-16` da `y` de -24 a -8, y hace falta `centered=false` para
que el borde inferior caiga en el nodo.

**El golpe no terminaba nunca.** `MeleeCombat.advance()` emitía `attack_finished` solo
si el jugador seguía en `ATTACKING` al cumplirse la recuperación. Pero
`GameSession._sync_motion_state()` sincronizaba el estado en cada fotograma y ponía
`MOVING` encima de `ATTACKING` en el fotograma siguiente al golpe, así que la condición
era falsa siempre. Medido: tras una pulsación de espacio, `_swing` llegaba a 2.33 y no
paraba, el clip se quedaba en `attack`, y al andar y girar se reiniciaba cinco veces
por vuelta (el clip no se repite, así que `play()` lo arranca de cero). El jugador se
movía de verdad por encima, con el cuerpo congelado en la pose de golpe.

Los dos symptoms que el jugador describió ("da vueltas", "vuelve el bug anterior") eran
el mismo reloj que no cerraba. La fila lateral especular no tenía nada que ver, por
mucho que los píxeles parecieran contradecirse.

**Reglas que salen de esto:**

- **Una señal de fin de evento no puede depender del estado que otro sistema escribe cada
  fotograma.** El reloj del evento es su autoridad. La transición de estado sí puede ser
  condicional, porque ahí puede haberse metido otro sistema a mitad de evento.
- **Cada estado tiene un dueño.** `IDLE`/`MOVING` son del movimiento y el movimiento no
  toca nada más; `ATTACKING` del combate; `HURT` del daño; `DEAD` de la reaparición.
  Un dueño que escribe su estado en cada fotograma es un dueño que no es dueño de nada.
- **Un test que mira la posición del nodo no dice nada del dibujo.** Con `centered`
  صحيح el nodo está en el sitio y el sprite flota. Lo que hay que medir es
  `get_rect()` trasladado por la posición y la rotación, y el punto sobre el que gira el
  arco (el centro del borde inferior del rectángulo local).
- **Un clip que no se repite se queda clavado en su último fotograma.** Comparar con `<=`
  cuenta cada fotograma repetido como un reinicio y hace fallar el caso siempre. Solo
  retroceder es reiniciar.
- **La defensa que tapa el fallo hace que el test no lo vea.** Con el reloj de la vista
  arreglado, la suite daba verde aunque se revirtiera el arreglo del reloj del combate.
  Por eso el caso de la señal es unitario, en `test_melee_combat.gd`: donde vive el
  fallo. Y la segunda red (el auto-cierre de la vista) tiene su propio caso, que abre la
  pose a mano para apartar el camino de la señal.
- **Medir antes de arreglar, también para un test que escribe mal.** Los tres casos
  nuevos fallaron dos veces por culpa del test: comparando el rectángulo antes de girar,
  contando fotogramas repetidos como reinicios, y mirando el clip en un fotograma suelto
  con el jugador contra una pared. Contra una pared el clip es `idle` porque no camina.
  Los que dependan del movimiento tienen que mirar solo los fotogramas en los que la
  posición cambia de verdad.

### Los enemigos eran monstruos y no podían usar el golpe del jugador

La fila de ataque de los enemigos quedó pendiente al cerrar Fase 1: sus hojas
(64x64) solo traían filas de caminar, el golpe reutilizaba la pose de frente, la
muerte era la pose quieta (los bichos mueren de pie) y hacerlo bien exigía cuatro
hojas nuevas. Se resolvió sin pedir ninguna textura: los cuatro tipos pasaron a
ser personas que usan `human_player.png` con la definición entera del jugador
(`ActorVisualCatalog._npc_human_definition()`), y lo único que los distingue es el
nombre (`NpcKind`: Vándalo, Atracador, Matón, Pandillero) y un tinte de paleta por
tipo (`ActorVisualCatalog.tint_of`, con los cuatro colores en
`GameConfig.NPC_TINT_*`).

Al compartir hoja comparten de regalo el puñetazo de tres fotogramas con mano
alternada, la caminata en las cuatro orientaciones y la muerte yacente: "los NPC
tienen que poder hacer lo mismo que el jugador" salió de reutilizar su definición,
no de duplicar animaciones. Se borraron `slime.png`, `owl.png`, `spider_red.png`,
`lizard.png` y `claw.png`, y `SlashEffect.NPC_SHEET` dejó de existir: el arco del
enemigo es ahora el del jugador.

Dos cosas que las suites no cuentan y conviene saber:

- **El tinte multiplica, no repinta.** `modulate` sobre la paleta real de la hoja
  (negro de contorno, verde pálido de ropa, blanco de piel) solo puede oscurecer
  canales que la hoja ya tiene: no hay azul posible en la ropa y el contorno sigue
  siendo negro. Por eso los cuatro colores se eligieron **sobre esa paleta** y se
  comprobaron contando píxeles en una captura, no razonándolos: con el jugador en
  (192, 192) la imagen traía exactos los cuatro colores de ropa previstos
  — (233,145,35), (82,158,146), (116,211,61) y (233,212,44) — más los cuatro de
  piel teñida y los del jugador sin teñir.
- **El color propio deja de mandar en cuanto hay un estado.** El reposo es el
  tinte del tipo; encima manda `HURT_TINT` (rojo), `STUN_TINT` (violeta) y la
  muerte (gris). De ahí que los cuatro colores sean naranja, azul, verde y
  amarillo: ninguno se acerca al rojo ni al violeta, que significan otra cosa.

**Reglas que salen de esto:**

- **Cuando un encargo de textura sirve para parchear una hoja mala, mirar antes si
  se puede reutilizar la hoja buena.** "Cinco filas por bicho" habría dado cuatro
  hojas nuevas que mantener, y seguiría sin dar la muerte que sí tiene la persona.
- **Una hoja compartida solo puede diferenciarse por el color**, y ese color tiene
  que dejar libres los colores de estado. Un enemigo que se distingue por su
  matiz no puede confundirse con el rojo de un golpe recibido.
- **El recuento de píxeles de una captura es la comprobación del color propio.**
  Un `modulate` no se ve en el test que compara `modulate == tint`: eso solo dice
  que se aplicó, no qué sale dibujado.

## Qué falta, en orden

Es la lista de trabajo real. No inventar alcance extra: la especificación ya
define el orden.

### 1. Inventario y objetos — hecho, incluida la pantalla

`Inventory` (add/remove/has/get_quantity, use/equip/unequip, capacidad de **20
pilas** = 20 objetos distintos) en `scripts/domain/inventory/`; `Item` genérico
con `type`, `stackable`, `max_stack` y `metadata` y la taxonomía completa en
`scripts/domain/item/`; `ItemCatalog` con piedra, cuchillo y baya. El inventario
es dominio puro: la UI lo consulta (`get_entries()`, señales) y no sabe nada de
gráficos. El cableado inventario -> arma vive en `GameSession._on_inventory_equipped`,
que traduce `equipped_changed` al `MeleeCombat.equip()` que ya existía (no se
tocó su API). El jugador arranca con la piedra en la mano vía la semilla del
inventario, la misma piedra con la que el combate ya empezaba.

La pantalla es `InventoryPanel` (`scripts/presentation/ui/inventory_panel.gd`):
una `Control` a pantalla completa en su propia `CanvasLayer` sobre el HUD, dibujada
con `draw_rect` y `PixelFont`. Abre y cierra con `Tab` (`toggle_inventory`),
**pausa el árbol** mientras está abierta (va en `PROCESS_MODE_ALWAYS` para seguir
oyendo la entrada), navega con los ejes de movimiento, y `E` confirma: equipa si
es WEAPON, consume si es CONSUMABLE. `Esc` no la cierra ni la abre: es la tecla
de salir del juego. Puede que el panel deba cerrarse solo si algo más pausa el
mundo — el cierre explícito está en `game.gd` (freno del teletransporte/cierre).

### 2. Remates de lo que ya funciona

Hechos en el cierre de Fase 1: pantalla de la mochila (§1 de esta lista), tinte
propio de aturdimiento (`STUN_TINT`, violeta, distinto del rojo de la
invulnerabilidad, vía señal `stun_changed` de los cuerpos de combate) y muerte
con texto ("CAIDO / E PARA REVIVIR" con `PixelFont`).

Queda uno, y necesita jugar para ajustarlo:

- **El enemigo fuerte mata a un jugador quieto en unos 15 s.** Dentro de lo
  razonable, pero no se ha ajustado jugando. Se ajusta con feedback real (basta
  un número en `GameConfig`).

El otro que quedaba — **la fila de golpe lateral de los enemigos** — se cerró sin
texturas nuevas: los cuatro tipos (`NpcKind`: Vándalo, Atracador, Matón,
Pandillero) usan ahora la hoja de la persona (`human_player.png`) con un tinte de
paleta por tipo, así que golpean, caminan y mueren igual que el jugador, y las
hojas de los bichos y la de las zarpas se borraron. Detalle y comprobación en la
lección "Los enemigos eran monstruos y no podían usar el golpe del jugador" (más
arriba) y en `docs/assets/TEXTURAS.md` (§2.1).

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

Tres casos de este cierre conviene recordarlos como patrón:

- `test_pixel_font.gd` prueba el núcleo de datos de la fuente (`lit_pixels`,
  `measure`) sin tocar ningún `CanvasItem`: la lista de píxeles es el dibujo.
- Los casos del panel en `inventory_runner.gd` corren sobre el **mismo mundo**:
  unos dejan la mochila con el cuchillo equipado y otros sin vida; cada caso que
  asuma un estado (por ejemplo "la primera casilla es la piedra") tiene que
  dejarlo preparado él mismo, no fiarse de lo que dejen los demás.
- Los casos de tinte de `npc_combat_runner.gd` miden la secuencia completa
  violeta -> rojo -> normal avanzando los relojes a mano, porque con los
  presentadores apagados nada avanza el stun.

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
# tests unitarios (151)
godot --headless --script res://tests/support/test_runner.gd

# tests de integracion con fisica (6)
godot --headless --script res://tests/integration/world_physics_runner.gd

# tests de integracion de combate (11)
godot --headless --script res://tests/integration/combat_runner.gd

# tests de integracion de NPC (21)
godot --headless --script res://tests/integration/npc_combat_runner.gd

# tests de integracion de arranque (17)
godot --headless --script res://tests/integration/startup_runner.gd

# tests de integracion de inventario (9)
godot --headless --script res://tests/integration/inventory_runner.gd

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
  matarlo: no deja fichero ni mensaje. Para capturar hace falta pantalla; en esta
  máquina se usa `xvfb`:

  ```bash
  export LC_ALL=C LANG=C
  xvfb-run -a godot --rendering-driver opengl3 --script res://tests/support/screenshot.gd -- /tmp/shot.png 60 216 380 1
  ```

  Dos avisos: bajo `xvfb` el render va sin límite de fps, así que `process_frame`
  no es tiempo de juego (para temporizar una secuencia hay que esperar
  `physics_frame`); y una captura se revisa contando píxeles, no mirándola: un
  `SCRIPT ERROR` y un efecto mal recortado se ven igual de bien en pantalla.

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
- **Las hojas de efecto también son cuadradas, pero de 32x32.** La hoja son 128x32:
  **cuatro** fotogramas en una sola fila, no ocho. Recortarla en 16x16 la parte en
  dos filas y el efecto recorre la de arriba, que está casi vacía. La rejilla se
  confirmó casando la hoja con el `Preview.gif` del pack píxel a píxel, no contando
  celdas. `GameConfig` tiene `FX_FRAME_WIDTH` / `FX_FRAME_HEIGHT` = 32 y
  `FX_ORIGIN_OFFSET` (14) para sacar el origen desde el centro del torso.
- **La orientación de las hojas laterales no se puede deducir.** Ver la nota del
  sprite lateral más arriba.
- **`Sprite2D.centered` mueve el origen del rectángulo dibujado.** Con `centered = true`
  (el valor por defecto) el rectángulo se dibuja en `posicion + offset - tamaño / 2`, no
  en `posicion + offset`. Medido con `get_rect()`: para una textura de 3x16,
  `centered = true` con `offset.y = -16` da el rectángulo de `y = -24` a `-8`, y
  `centered = false` con el mismo offset lo da de `-16` a `0`. Media altura de diferencia,
  que es justo lo que hace flotar un sprite "anclado por el mango". Para anclar por un
  extremo del dibujo: `centered = false`. No razonar la fórmula, imprimir `get_rect()`.
- **Resolución 384x216**: 16:9 exacto, escala de ventana x3, tile de 16 px. Ojo:
  216 **no** es múltiplo de 16. No escribir tests que asuman lo contrario.
- **Zoom de cámara (`GameConfig.CAMERA_ZOOM`, hoy 1)**: la imagen guardada por
  `screenshot.gd` es de 384x216 (el viewport), y en ella cada píxel de mundo ocupa
  `zoom` píxeles de imagen: con el 1 actual es 1 a 1, con el 1.5 anterior eran 1,5 y
  con el zoom 3 original 3. Para medir sobre una captura hay que tener esto en
  cuenta; con zooms no enteros un píxel de mundo se reparte en distinta cantidad de
  píxeles de imagen según caiga y la medida descuadra por eso, no por el sprite.
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
- **La entrada de daño es única: el cuerpo de combate** (`NpcCombat` para el
  enemigo, `MeleeCombat` para el jugador). Las vistas exponen ese cuerpo en
  `combat_target`, y el daño se pide con `take_damage(amount)` sobre él — nunca
  sobre el `Player` o el `Npc` pelados. De ahí la **ley del tinte rojo**: todo ser
  que recibe daño se tiñe (`HURT_TINT`) durante su invulnerabilidad, y el tinte es
  la lectura de `invulnerability_changed` en la vista. Estuvo rota para los NPC:
  `MeleeCombat.strike` llamaba a `take_damage` sobre el `Npc` directo, sin pasar
  por `NpcCombat`, y el enemigo bajaba de vida sin tinte ni aturdimiento. Ojo con
  `take_damage`: la cantidad ya viene calculada por el atacante (defensa incluida),
  así que **no** se vuelve a aplicar la fórmula; `receive_damage` es la entrada de
  daño bruto, y la usa quien ataca con un número sin calcular.
- **Golpear a un enemigo lo deja aturdido e invulnerable en su `NpcCombat`**, y ese
  reloj solo avanza con `advance(delta)` de su presentador. Los tests de
  integración que apagan los presentadores y luego atacan con el combate del
  enemigo tienen que limpiar el reloj primero (`combat.advance(...)`): si no, el
  `try_attack` del propio enemigo se rechaza por stun.
- **`set_anchors_preset(PRESET_FULL_RECT)` no da tamaño a un `Control` cuyo padre
  es una `CanvasLayer`**: se queda en 0x0 (medido en el árbol real). Todo lo que
  se dibuje con `size` —overlays a pantalla completa, texto centrado— no sale.
  De hecho el velo rojo de la muerte **nunca llegó a dibujarse** por esto, y un
  overlay `Rect2(Vector2.ZERO, size)` con tamaño 0 no pinta nada ni avisa. Tanto
  `Hud` como `InventoryPanel` fijan `size = get_viewport_rect().size` en el
  `_ready()`; el proyecto es de resolución fija (384x216), así que no hay que
  reaccionar a redimensionamientos.
- **Los textos del juego van con `PixelFont`** (`scripts/presentation/ui/pixel_font.gd`),
  una mini fuente de glifos 3x5 dibujada con `draw_rect` de 1x1. La del sistema
  sale borrosa a 384x216. Cubre A-Z, 0-9 y `! ? . - : ( )`; lo desconocido cae en
  `?`. El núcleo comprobable es `lit_pixels(text)`, que devuelve la lista de
  píxeles sin tocar ningún `CanvasItem`; `draw()` solo recorre esa lista. El
  espacio ocupa una celda entera (3 px + separación), igual que una letra, para
  que `measure()` no tenga casos raros: la segunda letra de "A A" arranca en x=8.
- **La mochila pausa el mundo mientras está abierta** (`get_tree().paused`), y el
  panel va en `PROCESS_MODE_ALWAYS` para seguir oyendo la entrada. Abre y cierra
  con `toggle_inventory` (Tab), navega con los ejes de movimiento y confirma con
  `interact` (E): equipa si WEAPON, consume si CONSUMABLE. Se come las
  pulsaciones (`set_input_as_handled`) para que el jugador no avance ni ataque
  mientras gestiona el equipo, y **`Esc` no la cierra**: `ui_cancel` sigue
  cerrando el juego desde el autoload, que recibe el evento antes. No se abre con
  el jugador muerto.
- **La señal de aturdimiento sube al aturdir y baja al expirar**
  (`stun_changed(active)` en `MeleeCombat` y `NpcCombat`), y solo avisa del cruce:
  un segundo `apply_stun()` mientras ya está aturdido no repite el `true`. La
  vista pinta con prioridad **muerto > aturdido (`STUN_TINT` violeta) > herido
  (`HURT_TINT` rojo) > normal**: el aturdimiento dura menos que la
  invulnerabilidad, así que el rojo gana cuando el stun expira sin perder la
  lectura del golpe.
- **Una señal con argumentos no se conecta a un método de 0 argumentos**:
  `equipped_changed(item_id)` conectado a `queue_redraw` fallaba en caliente con
  "Method expected 0 argument(s), but called with 1" en cada señal, y el
  resultado seguía verde. Cualquier conexión con firma distinta necesita un
  wrapper; y un error por consola no es una suite verde (la regla de siempre).

## Documentación relacionada

| archivo | contenido |
| --- | --- |
| `docs/CHARACTER_VISUAL_SYSTEM.md` | sistema de definiciones visuales: humano por defecto, ninja como fallback, filas/fotogramas de cada animación |
| `docs/architecture/ARCHITECTURE.md` | capas, flujo, coordenadas, colisiones, testing |
| `docs/gameplay/GAMEPLAY.md` | controles, movimiento, vida, estados, qué falta del MVP |
| `docs/networking/NETWORKING.md` | diseño server-authoritative de la Fase 2 |
| `docs/ROADMAP.md` | fases y checklist |
| `docs/maps/ZONE_001.md` | dimensiones y distribución del mapa de prueba |
| `docs/assets/TEXTURAS.md` | inventario de texturas: lo que hay, lo que se encarga y su formato exacto |

## Git

El repositorio vive en `main`. El commit inicial (`2ee61e0`) incluye la
especificación, la estructura, los scripts, las escenas, los tests y la
documentación; el cierre de Fase 1 (remates de UI) le sigue en los commits con
mensaje referente al "cierre de Fase 1 (remates de UI)". Cada incremento se
commitea y se empuja a `main` con los tests en verde.