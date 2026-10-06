# Gameplay

Estado: **Fase 1 — prototipo offline**

Este documento describe lo que el jugador puede hacer hoy. Lo que todavía no
existe está marcado como pendiente de fase, para no confundir intención con
realidad.

## 1. Controles

| Acción | Teclas |
| --- | --- |
| Mover | `WASD` o flechas |
| Golpear con el arma | `Espacio` o clic izquierdo |
| Golpear a puños | `F` o clic derecho |
| Reaparecer | `E` (solo tras morir, pasado el retraso) |
| Cerrar el juego | `Esc` |

Las acciones de entrada están declaradas en `project.godot` con nombres estables
(`move_up`, `move_down`, `move_left`, `move_right`, `attack`, `attack_unarmed`,
`interact`) para que reasignarlas no afecte al código.

Las dos formas de golpear son independientes a propósito. Se puede pegar a puños
con algo en la mano: el golpe desarmado **no des-equipa** el arma, usa su propio
alcance, daño, cooldown y stamina, y no gasta durabilidad. Lo único que cambia al
mirar la pantalla es que a puños no se dibuja ni el arma ni el arco del golpe.

## 2. Movimiento

- Velocidad: 110 px/s (`GameConfig.PLAYER_SPEED`, que `PlayerView.move_speed`
  inyecta en `MovementController.move_speed`). La constante decía 60 y no era el valor
  con el que se jugaba: la vista traía el suyo y ganaba al copiearlo.
- Movimiento libre en 8 direcciones, con el eje dominante mandando.
- El movimiento no se acelera ni se frena: es directo. El suavizado solo en la
  cámara, para que el jugador sienta el control inmediato.
- Colisiona contra escenario, decor y borde de zona.

### Orientación

El jugador mira en una de cuatro direcciones: arriba, abajo, izquierda o
derecha. La decide el eje dominante de la intención de movimiento y se comunica
por señal, de modo que las animaciones futures la consuman sin conocer el
movimiento.

Cada orientación tiene su fila en la hoja de sprites, y el golpe no cambia de
fila: la animación de golpe solo existe mirando al frente y se refleja en
horizontal cuando el actor va de lado. Ver la sección 9 de `ARCHITECTURE.md`,
que explica también el caso de las dos filas laterales especulares.

`MovementController.block_for(segundos)` inmoviliza al jugador. Lo llama el
presentador cuando `MeleeCombat` avisa de un aturdimiento, así que el jugador no
puede moverse mientras está HURT.

### El arma en la mano

El arma equipada es un sprite hijo del jugador que va **al costado del cuerpo**,
nunca en su eje: la mano está a `HAND_REACH` a un lado y a la altura del pecho, y
hacia arriba o abajo solo se adelanta un poco (`HAND_VERTICAL_REACH`). El sprite se
ancla por el mango, así que el nodo es la mano y el arco del golpe gira alrededor de
ella en vez de despegar el arma de la mano a mitad de swing.

Para que el nodo sea de verdad el mango el sprite va con `centered = false`. Con
`centered = true` el rectángulo que se dibuja es `posicion + offset - tamaño / 2`, así
que un `offset.y = -altura` pensado para anclar por el mango deja el borde inferior del
arma **media altura por encima de la mano** y el palo se ve flotando por encima de la
cabeza en las cuatro orientaciones. La comprobación es sobre el rectángulo dibujado y
no sobre la posición del nodo: el nodo estaba bien colocado y lo que flotaba era el
dibujo.

Fuera del golpe el arma descansa recta, con una inclinación pequeña hacia donde mira
el jugador (`HAND_TILT`), y el arco (`HAND_SWING`) solo suma mientras dura el swing.
Se coloca en **todos** los fotogramas, no solo al parar: si se coloca solo en un
estado, mientras se camina se queda donde se dejó la última vez, y al parar salta de
golpe a la posición y a la inclinación nuevas.

Las dos cosas son medidas, no supuestas: el arma del pack es un palo de 3x16 px, y
centrado en el eje del cuerpo tapaba las piernas al caminar hacia abajo.

## 3. Cámara

- Sigue al jugador con suavizado exponencial (`FOLLOW_SMOOTHING = 8`).
- Zoom configurable por `GameConfig.CAMERA_ZOOM`, hoy 1 sobre la resolución base
  de 384x216, así que la cámara muestra los 384x216 px del mundo (eran 256x144 con
  el 1,5 anterior y 128x72 con el zoom 3 inicial). La ventana escala el viewport x3,
  así que con el 1 la escala es 3x y todos los píxeles de mundo quedan iguales en
  pantalla; bajar de 1 enseñaría más mapa con píxeles desiguales.
- Límites derivados del rectángulo de la zona: nunca se ve fuera del mapa.

Los límites se recalculan al cargar la zona, así que un mapa mayor no requiere
cambios en la cámara.

## 4. Vida y daño

Modelo actual (`Health`, dentro del dominio):

```text
Health
├── current
├── maximum
├── is_dead
├── apply_damage(cantidad) -> daño real
├── heal(cantidad) -> cantidad real curada
├── refill()
└── señales: changed, depleted
```

Reglas:

- `apply_damage` nunca devuelve negativo y nunca deja la vida bajo 0.
- Un muerto no recibe daño ni curación.
- `depleted` se emite una sola vez, en la transición a 0.
- `Player` escucha `depleted`, pasa su estado a `DEAD` y emite `died`.

Vida inicial: 100 (`GameConfig.PLAYER_MAX_HEALTH`).

### Reaparición

`Player.respawn_at(posicion)` devuelve al jugador a IDLE con la vida y la stamina
llenas. El caso de uso es `GameSession.respawn()`, que además elige el punto de
reaparición, y el botón está cableado: `RespawnInput` lee `E` (`interact`), pide la
reaparición y `GameSession` decide si puede. Hay un retraso de
`GameConfig.RESPAWN_DELAY` (1 s) entre morir y poder volver, para que no sea pulsar y
aparecer.

Mismo botón que `interact` a propósito: en la pantalla de muerte no hay nada con lo
que interactuar, así que no obliga a aprender dos teclas.

## 5. Estados del jugador

```text
IDLE  ->  MOVING / ATTACKING / HURT / DEAD
MOVING -> IDLE / ATTACKING / HURT / DEAD
ATTACKING -> IDLE / MOVING / HURT / DEAD
HURT -> IDLE / MOVING / ATTACKING / DEAD
DEAD -> (terminal; la reaparición la decide GameSession, no la máquina)
```

`Player.transition_to()` es el único camino: si la transición no está en la
tabla, se rechaza y se registra en el log. El combate usa ya `ATTACKING` (al
golpear y mientras dura la recuperación) y `HURT` (al recibir daño).

**Cada estado tiene un dueño, y solo uno.** El movimiento es dueño de `IDLE` y
`MOVING` y no toca nada más; el combate abre y cierra `ATTACKING` con su propio
reloj; el daño pone `HURT`; la reaparición pone `DEAD`. Antes el movimiento
sincronizaba `IDLE`/`MOVING` en cada fotograma sin mirar qué había antes, así que
ponía `MOVING` encima de `ATTACKING` en el fotograma siguiente al golpe: el estado
duró un fotograma y, como `MeleeCombat` solo emitía `attack_finished` desde
`ATTACKING`, la señal no salía nunca. El jugador se quedaba con el cuerpo congelado
en la pose de golpe para siempre, y como andaba y giraba durante la recuperación el
clip se reiniciaba en cada giro: de ahí el "va dando vueltas".

De ahí la regla: **una señal de fin de evento no puede depender del estado que otro
sistema escribe cada fotograma.** `MeleeCombat` emite cuando su reloj vence, y solo
la transición de estado es condicional, porque ahí sí puede haberse metido otro
sistema (por ejemplo `HURT` al recibir daño a mitad de golpe).

## 6. Estadísticas

`CharacterStats` expone cinco valores, todos ajustables:

| estadística | valor inicial |
| --- | --- |
| `max_health` | 100 |
| `max_stamina` | 100 |
| `move_speed` | 60 (el jugador usa `GameConfig.PLAYER_SPEED` = 110; la estadística queda reservada para los NPC) |
| `base_damage` | 5 |
| `defense` | 0 |

El sistema acepta nombres como `"hambre"` o `"experiencia"` sin fallar: se
registra el aviso y se devuelven 0. Esa es la vía prevista para añadir sistemas
de vida en la Fase 5 sin reescribir lo existente.

## 7. Mundo

`zone_001`: 64x40 tiles (1024x640 px), origen en (0,0).

Contenido de la distribución de prueba:

| elemento | cantidad | colisión |
| --- | --- | --- |
| árboles | 6 | sí |
| piedras | 3 | sí |
| casas | 2 | sí, solo el volumen construido |
| caminos de tierra | 2 | no |
| muro de límites | 4 paredes | sí |

`ZoneView.scattered_trees` rellena la zona con árboles según un patrón
determinista (`(x*31 + y*17) % 5`). Se mantiene determinista a propósito: el
mismo mapa en cada partida y en los tests.

### Qué es decor y qué no

Un árbol, una piedra o una casa son `WorldDecor`: dibujo más una caja de
colisión. No tienen reglas. Cuando se pueda talar un árbol, la regla vivirá en
el dominio y el decor solo mostrará el estado resultante.

## 8. Pendiente para completar el MVP

- [x] **Animaciones**: el jugador se dibuja con la hoja de sprites del pack, en
      cuatro orientaciones, con ciclo de paso, pose de golpe y parpadeo al aturdirse.
- [x] **Combate**: golpe con distancia, cooldown, daño `max(1, ataque - defensa)`,
      detección de objetivo por hitbox e invulnerabilidad temporal.
- [x] **Armas**: piedra y cuchillo, con durabilidad. La fórmula del daño vive en
      `DamageRules`, en el dominio, no en el arma.
- [x] **Combate sin arma**: se puede pegar a puños en cualquier momento, con reglas
      propias y sin des-equipar lo que se lleva en la mano.
- [x] **NPC**: seis enemigos con `stats`, `state`, `position` y `behavior`, y los
      estados IDLE / WANDER / CHASE / ATTACK / FLEE / DEAD. Ver §8bis.
- [x] **HUD**: vida, stamina, barra de golpe e icono del arma, todo dibujado. El
      inventario no tiene pantalla todavía (los datos sí existen, ver §8quinquies).
- [x] **Muerte y reaparición jugables**: morir bloquea el movimiento, tiñe la
      pantalla y `E` reaparece tras el retraso.
- [x] **Inventario**: `add_item`, `remove_item`, `has_item`, `get_quantity`,
      `use_item`, `equip_item`, `unequip_item`, con capacidad inicial de 20.
      Equipar va del inventario hasta el arma en mano; falta solo la pantalla.
- [x] **Objetos**: definición genérica con `type`, `stackable` y `max_stack`,
      y la taxonomía WEAPON / CONSUMABLE / MATERIAL / QUEST / CURRENCY /
      CLOTHING / TOOL / MISC.

## 8bis. Combate cuerpo a cuerpo

El golpe sale de `MeleeCombat` (Application) y la física solo dice a quién ha
tocado la `HitboxSensor` (Presentation).

| pieza | responsabilidad |
| --- | --- |
| `DamageRules` | la fórmula `max(1, ataque - defensa)`, en el dominio |
| `Weapon` / `WeaponCatalog` | cuánto pega, hasta dónde llega, cuánto espera |
| `MeleeCombat` | cooldown, ventana de golpe, aturdimiento, invulnerabilidad |
| `HitboxSensor` | un círculo que se enciende solo durante la ventana |

Reglas vigentes:

- La hitbox permanece **apagada** y se enciende con `attack_started`: un sensor
  siempre activo detectaría cuerpos a la espalda.
- El círculo se coloca **desplazado hacia delante** (`HITBOX_FORWARD_RATIO` del
  alcance), no centrado en el jugador.
- Cada objetivo solo recibe daño **una vez por golpe**, aunque la hitbox siga
  encendida.
- Al recibir daño el jugador queda **aturdido** (`HURT_STUN_TIME`), lo que llama a
  `MovementController.block_for()`.
- Tras un golpe hay **invulnerabilidad** (`INVULNERABILITY_TIME`) para que un
  enemigo no repita daño cada frame.

| arma | daño | alcance | cooldown | stamina | durabilidad |
| --- | --- | --- | --- | --- | --- |
| Puños | 3 | 12 px | 0.30 s | 2 | no se rompe |
| Piedra | 5 | 20 px | 0.45 s | 4 | 40 |
| Cuchillo | 9 | 15 px | 0.28 s | 6 | 60 |

El cuchillo pega más y más rápido, pero llega menos lejos y cansa más: es el
arma de combate cercano, la piedra el arma de confianza. Los puños son siempre la
peor opción en daño, así que hay motivo para llevar algo en la mano.

Un arma sin `max_durability` no se rompe nunca. Cuando la durabilidad llega a 0
el arma `is_broken` y `can_attack()` es `false`.

Los puños son un "arma" degenerada (`WeaponCatalog.UNARMED`): sin textura, sin
durabilidad. Así las reglas del combate están en un solo sitio y el caso de "pegar
sin arma" es otro valor de los mismos parámetros, no una ruta aparte con sus propias
condiciones.

## 8ter. Los enemigos

**Ahora el juego arranca con enemigos.** `GameConfig.NPC_ENABLED = true` crea el
director, los agentes y sus cuerpos en pantalla al arrancar. Fue deliberado tenerlos
apagados para probar el movimiento y el mapa sin que la IA se meta en medio: con la
bandera en `true` se juega lo que se describe abajo, y en `false` la zona queda
despejada.

Seis enemigos de cuatro tipos del pack, con tres débiles y tres duros:

| tipo | vida | daño | alcance | velocidad |
| --- | --- | --- | --- | --- |
| Limo, araña | 24 | 4 | 13 px | lenta |
| Búho, lagarto | 40 | 8 | 16 px | rápida |

Cómo se comportan:

- **Solo uno persigue a la vez**, el más cercano y solo si el jugador ha entrado en
  su radio de detección (70 px). Con seis persiguiendo a la vez el combate deja de
  ser legible.
- El perseguidor se va a su casa cuando el jugador se aleja más de 130 px (la
  correa), para que la zona siga teniendo enemigos y no se vacíe.
- Por debajo del 25 % de vida **huyen** en vez de seguir peleando.
- Al recibir daño se stun 0,2 s y ganan 0,35 s de invulnerabilidad, para que dos
  enemigos no peguen en el mismo frame.
- Pasean por su zona cuando están en reposo, más despacio de lo que persiguen:
  correr sin motivo delata que es un enemigo.

Los estados están en un grafo explícito (`NpcState._ALLOWED`) y solo se transiciona
con `NpcState.transition_to()`. Ojo: el grafo inicialmente no permitía pasar de IDLE o
WANDER a ATTACK, así que un enemigo en reposo nunca podía pegar. Está arreglado, y
hay un caso que lo fija (`_attack_from_rest`).

Dos cosas que no están y conviene saber:

- Los enemigos del pack **no tienen fila de golpe propia**: reutilizan la pose de
  frente, así que de lado el fotograma no encaja del todo.
- Cuando un enemigo golpea **sale un zarpazo** en pantalla: el mismo efecto que el
  arco del jugador, con la hoja de zarpas del pack (`assets/fx/claw.png`), mismo
  recorte y mismo origen. Al recibir daño, el jugador se tiñe de rojo
  (`HURT_TINT`) mientras dura la invulnerabilidad.

## 8quater. El HUD

El HUD es todo dibujo, **sin una sola letra**. La fuente del sistema sale borrosa a
384x216 y rompería el pixel art, así que las barras se pintan con `draw_rect` y el
icono del arma es el propio sprite del arma. El pack trae temas de madera, no el
`ThemeRed` del que salen los nueve-patch de Godot, así que tampoco hay panel.

| elemento | qué muestra |
| --- | --- |
| barra de vida | rojo sobre fondo oscuro, se vacía hacia la derecha |
| barra de stamina | azul, y se vacía mientras más rápido se recupera |
| barra de golpe | cooldown del arma: **llena = se puede pegar**, vacía = recién golpeado; se llena sola al pasar el cooldown |
| icono del arma | el sprite del arma equipada; desaparece a puños |
| pantalla de muerte | tinte rojo sobre todo |

La barra de golpe es la última en llegar. Se pinta invertida respecto a
`cooldown_ratio` de `MeleeCombat` (llena cuando el ratio llega a 0) y el HUD la
lee por fotograma porque el cooldown no emite señal: es un reloj que corre. Cuando
vuelve a estar listo, `attack_ready()` la da llena. El HUD consume el caso de uso
por señales y estado consultado; no decide reglas.

El HUD va en un `CanvasLayer` propio, así que no le afecta ni la cámara ni el zoom.
Consume el caso de uso por señales: no lee `Health` directamente ni sabe qué es un
jugador.

## 8quinquies. El inventario

El inventario es dominio puro (`scripts/domain/inventory/`): no sabe nada de
gráficos, la UI lo consulta. Guarda pilas de `Item` con su cantidad — una casilla
por objeto distinto (20 casillas, `GameConfig.PLAYER_INVENTORY_CAPACITY`) — y
"la mano" es estado suyo: `equipped()` dice qué se lleva, `&""` a puños.

| operación | qué hace |
| --- | --- |
| `add_item(item, n)` | recoge; apila hasta `max_stack` o abre casilla; devuelve lo que entró |
| `remove_item(id, n)` | quita; al vaciar la pila libera la casilla (y des-equipa si era la mano) |
| `has_item` / `get_quantity` | consultas |
| `use_item(id)` | consume una unidad de los consumibles y emite `used` (el efecto es de quien escuche) |
| `equip_item(id)` / `unequip_item()` | pone o quita el objeto de la mano; solo los WEAPON se equipan |

Los objetos son definiciones (`scripts/domain/item/`): `id`, `name`, `type`
(WEAPON / CONSUMABLE / MATERIAL / QUEST / CURRENCY / CLOTHING / TOOL / MISC),
`stackable`, `max_stack` y `metadata`. `ItemCatalog` concreta la piedra, el
cuchillo y una baya de ejemplo; las armas llevan en `metadata.weapon` el id del
`WeaponCatalog` que representan.

El cableado inventario -> arma vive en `GameSession`: `equipped_changed` se
traduce a `MeleeCombat.equip()` (que no se tocó: era el gancho) y la señal
`weapon_changed` del combate cambia el sprite de la mano. El jugador arranca con
la piedra equipada por esta vía. El jugador lo lleva al revés:
`player.equipped_item` se lee del inventario, no al contrario.

Lo que falta es la pantalla: el HUD sigue siendo barras y no dibuja la mochila.
La consulta para el panel ya existe (`get_entries()` y las señales `changed`,
`quantity_changed`, `equipped_changed`, `used`).

## 9. Qué NO debe colarse en el MVP

Las armas de fuego quedan fuera de forma explícita. Tampoco entran todavía
hambre, sed, energía, dinero, propiedades, misiones, vehículos ni persistencia.
Ver `docs/ROADMAP.md` para el orden.