# Gameplay

Estado: **Fase 1 — prototipo offline**

Este documento describe lo que el jugador puede hacer hoy. Lo que todavía no
existe está marcado como pendiente de fase, para no confundir intención con
realidad.

## 1. Controles

| Acción | Teclas |
| --- | --- |
| Mover | `WASD` o flechas |
| Cerrar el juego | `Esc` |

Las acciones de entrada están declaradas en `project.godot` con nombres estables
(`move_up`, `move_down`, `move_left`, `move_right`) para que reasignarlas no
afecte al código.

## 2. Movimiento

- Velocidad: 110 px/s (`PlayerView.move_speed`, se inyecta en
  `MovementController.move_speed`).
- Movimiento libre en 8 direcciones, con el eje dominante mandando.
- El movimiento no se acelera ni se frena: es directo. El suavizado solo en la
  cámara, para que el jugador sienta el control inmediato.
- Colisiona contra escenario, decor y borde de zona.

### Orientación

El jugador mira en una de cuatro direcciones: arriba, abajo, izquierda o
derecha. La decide el eje dominante de la intención de movimiento y se comunica
por señal, de modo que las animaciones futures la consuman sin conocer el
movimiento.

`MovementController.block_for(segundos)` inmoviliza al jugador. Existe para el
aturdimiento del combate; todavía ningún sistema lo llama.

## 3. Cámara

- Sigue al jugador con suavizado exponencial (`FOLLOW_SMOOTHING = 8`).
- Zoom x3 sobre la resolución base de 384x216, así que la cámara muestra
  128x72 px del mundo.
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
reaparición. Aún no hay interfaz para invocarla: falta HUD y detección de
"caíste fuera del mundo". Ver §8.

## 5. Estados del jugador

```text
IDLE  ->  MOVING / ATTACKING / HURT / DEAD
MOVING -> IDLE / ATTACKING / HURT / DEAD
ATTACKING -> IDLE / MOVING / HURT / DEAD
HURT -> IDLE / MOVING / ATTACKING / DEAD
DEAD -> (terminal; la reaparición la decide GameSession, no la máquina)
```

`Player.transition_to()` es el único camino: si la transición no está en la
tabla, se rechaza y se registra en el log. En Fase 1 solo se usan `IDLE`,
`MOVING` y `DEAD`; `ATTACKING` y `HURT` ya están reservados y conectados.

## 6. Estadísticas

`CharacterStats` expone cinco valores, todos ajustables:

| estadística | valor inicial |
| --- | --- |
| `max_health` | 100 |
| `max_stamina` | 100 |
| `move_speed` | 60 (el jugador usa 110; la estadística queda reservada para los NPC) |
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

Nada de esto existe todavía. Es el trabajo restante de la Fase 1.

- [ ] **Animaciones**: ahora el jugador es un rectángulo con un triángulo de
      orientación. Necesita cuatro estados de caminar.
- [ ] **Combate**: ataque cuerpo a cuerpo con distancia, cooldown, daño
      (`max(1, attack_damage - defense)`), detección de objetivo e
      invulnerabilidad temporal (`GameConfig.INVULNERABILITY_TIME = 0.6`).
      Requiere la capa `hitbox` y conectar `ATTACKING` / `HURT`.
- [ ] **Armas**: piedra y cuchillo. La fórmula del daño debe vivir en el dominio
      para que cambiarla no obligue a tocar las armas.
- [ ] **Inventario**: `add_item`, `remove_item`, `has_item`, `get_quantity`,
      `use_item`, `equip_item`, `unequip_item`, con capacidad inicial de 20.
- [ ] **Objetos**: definición genérica con `type`, `stackable` y `max_stack`,
      y la taxonomía WEAPON / CONSUMABLE / MATERIAL / QUEST / CURRENCY /
      CLOTHING / TOOL / MISC.
- [ ] **NPC**: al menos uno, con `stats`, `state`, `position` y `behavior`, y
      estados IDLE / WANDER / CHASE / ATTACK / FLEE / DEAD.
- [ ] **HUD**: vida, stamina, inventario.
- [ ] **Muerte y reaparición jugables**: hoy la reaparición existe como caso de
      uso pero no hay forma de invocarla desde el juego.

## 9. Qué NO debe colarse en el MVP

Las armas de fuego quedan fuera de forma explícita. Tampoco entran todavía
hambre, sed, energía, dinero, propiedades, misiones, vehículos ni persistencia.
Ver `docs/ROADMAP.md` para el orden.