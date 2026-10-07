# Arquitectura

Estado: **MVP_OFFLINE (Fase 1 en curso)**

## 1. Capas

El proyecto sigue cuatro capas con dependencias en un solo sentido:

```text
Presentation  ->  Application  ->  Domain
                                  ^
                                  |
                            Infrastructure
```

| Capa | Carpeta | Puede depender de | Nunca debe |
| --- | --- | --- | --- |
| Presentation | `scripts/presentation` | Application, Domain (lectura), Infrastructure | contener reglas de juego |
| Application | `scripts/application` | Domain, Infrastructure | dibujar ni conocer nodos visuales |
| Domain | `scripts/domain` | nada (ni siquiera Godot) | usar `Node`, `Input`, escenas o red |
| Infrastructure | `scripts/infrastructure` | nada del dominio | filtrar reglas |

`scripts/shared` contiene lo transversal y sin reglas: el reloj de la aplicación
(`game.gd`) y los nombres de capas de física (`collision_layers.gd`).

## 2. Regla de dependencia

Una dependencia entre capas solo es legal si apunta hacia la derecha en el
diagrama. En la práctica:

- **Domain** no hace `extends Node` ni toca singletons. `Player`, `Health`,
  `CharacterStats` y `PlayerState` son `RefCounted` puros y se prueban sin
  cargar ninguna escena.
- **Application** coordina casos de uso. `MovementController` decide la
  velocidad; recibe un `CharacterBody2D` ya construido, no lo busca en el árbol.
- **Presentation**Lee el estado y lo dibuja. `PlayerView` no calcula daño ni
  vida; `PlayerPresenter` traduce la entrada del teclado a una intención de
  movimiento y se la entrega al caso de uso.
- **Infrastructure** abstrae el exterior. `GameConfig` centraliza los valores
  ajustables (sección 28 de la especificación) y admite overrides externos.

## 3. Composition root

`scenes/shared/game.tscn` es el autoload `Game`. Es el único punto que conoce
las piezas a la vez:

```text
Game._ready()
  -> GameLogger.configure()
  -> GameEvents (bus de eventos)
  -> GameSession (crea el Player del dominio)
  -> GameSession.setup_npcs() (crea el NpcDirector y sus agentes)
  -> MainWorldView (crea zona + jugador + cámara + HUD + capa de efectos)
  -> MainWorldView.setup_npcs(director) (da cuerpo a los agentes)
  -> MovementController.bind(player)
  -> RespawnInput.bind(session)
  -> Timer de reparto de objetivo (NPC_TARGET_REFRESH)
```

El resto del código recibe sus colaboradores por setter (`bind`, `setup`,
`connect_cases`) o por signals. No hay singletons adicionales ni
localizadores de servicios.

### La escena principal no monta el mundo

`scenes/world/main.tscn` es la escena de `application/run/main_scene` y **no lleva
ningún script**: es un `Node2D` vacío. Godot necesita una escena principal para
arrancar, y el juego ya está montado antes de que esa escena entre en el árbol,
porque los autoload se cargan antes que la escena principal.

Que esa escena sea un `MainWorldView` fue un bug de lo más caro del proyecto, así que
conviene escribir por qué no puede volver a serlo. Con el script puesto, al darle a F5
se acababan con **dos mundos**: el del autoload, con el `MovementController` enchufado, y
el de la escena principal, montado encima y sin un solo caso de uso. El que se
dibujaba era el segundo, con el jugador clavado, y como se montaba después le tocó a
él el `make_current()` de la cámara. El jugador que sí se movía quedaba tapado por los
tiles del otro mundo, y solo se veían las cosas con `z_index` por encima del terreno:
el sprite del arma (z=1), los enemigos (z=1) y los arcos de golpe (z=8). El síntoma era
"el jugador no se mueve pero el arma sí", y las cuatro suites que había estaban en verde
porque cada una miraba un solo mundo. Un runner con `--script` carga los autoload pero
no la escena principal, así que ninguna podía verlo: de ahí
`tests/integration/startup_runner.gd`, que reproduce el arranque real y comprueba que
**lo que se ve es lo que se mueve**.

El orden importa: los enemigos se crean **antes** que la escena del mundo, porque
`MainWorldView` avisa de que el jugador está listo mientras se construye y para ese
aviso ya tiene que saber cuántos enemigos hay en la zona. Con
`GameConfig.NPC_ENABLED` en `false` no se crean, y todo lo que consulta al director ya
está preparado para `null`.

Dos relojes, y ninguno toca los casos de uso de otro:

- El de cada enemigo lo mueve su propio `NpcPresenter._physics_process()`.
- El reparto de objetivo lo mueve un `Timer` del composition root. `distribute_target()`
  solo asigna a quién persigue cada uno; no avanza ningún caso de uso. Por eso puede
  ir a su aire sin tocar el ritmo de la IA, y por eso está atado a un reloj y no al
  movimiento del jugador: si dependiera de `move_performed`, un jugador quieto no lo
  perseguiría nadie.

Al terminar, `_exit_tree()` suelta en **orden inverso**: primero el director de NPC,
porque sus señales apuntan al presentador, que a su vez apunta al dominio.

## 4. Flujo de una entrada de movimiento

```text
Tecla W
  -> PlayerPresenter._physics_process        (Presentation: lee el teclado)
  -> MovementController.intent_from_input()  (Application: normaliza)
  -> MovementController.move()               (Application: decide velocidad)
  -> CharacterBody2D.move_and_slide()        (Godot: resuelve colisiones)
  -> PlayerView.apply_motion()               (Presentation: dibuja)
```

Si mañana el servidor es autoritativo, solo cambia `MovementController.move()`:
seguirá aplicando la posición que le llegue, sin que la vista se entere.

## 5. Mapa de módulos

```text
scripts/
├── shared/
│   ├── game.gd                     autoload Game: composition root + relojes
│   └── collision_layers.gd         bits de las capas 2d_physics
├── domain/
│   ├── events/game_events.gd       bus de señales
│   ├── player/player.gd            entidad y sus invariantes
│   ├── player/player_state.gd      máquina de estados
│   ├── player/health.gd            vida, daño, muerte
│   ├── player/character_stats.gd   estadísticas base
│   ├── combat/weapon.gd            arma con daño, alcance y durabilidad
│   ├── combat/weapon_catalog.gd    catálogo de armas, incluido el puñetazo
│   ├── combat/damage_rules.gd      fórmula de daño compartida por ambos lados
│   ├── item/item_kind.gd           taxonomía de objetos (sección 12)
│   ├── item/item.gd                definición de objeto (id, tipo, pila, metadata)
│   ├── item/item_catalog.gd        objetos concretos del MVP
│   ├── inventory/inventory.gd      mochila: pilas, capacidad y mano (sección 13)
│   └── npc/
│       ├── npc_kind.gd             tipos de enemigo (identificadores de dominio)
│       ├── npc_state.gd            máquina de estados y grafo de transiciones
│       ├── npc.gd                  entidad del enemigo
│       └── npc_behavior.gd         estadísticas de combate y detección
├── application/
│   ├── game_session.gd             caso de uso: sesión, reaparición, avance
│   ├── player/movement_controller.gd  caso de uso: movimiento
│   ├── combat/melee_combat.gd      caso de uso: golpe del jugador, con o sin arma
│   └── npc/
│       ├── npc_brain.gd            caso de uso: qué hace el enemigo ahora
│       ├── npc_combat.gd           caso de uso: golpe del enemigo
│       ├── npc_spawn_table.gd      qué enemigos hay y dónde
│       └── npc_director.gd         caso de uso: dirige a los enemigos de la zona
├── presentation/
│   ├── world/main_world_view.gd    raíz del mundo
│   ├── world/zone_view.gd          una zona con terreno, decor y límites
│   ├── world/world_decor.gd        base de obstáculos sólidos
│   ├── world/decor/                árbol, piedra
│   ├── world/structures/           casa
│   ├── player/player_view.gd       sprite, colisión, hitbox y mano del jugador
│   ├── player/player_presenter.gd  entrada -> caso de uso
│   ├── player/hitbox_sensor.gd     área de golpe del jugador
│   ├── player/respawn_input.gd     botón de revivir
│   ├── actors/actor_sprite.gd      reproductor de animaciones de las hojas del pack
│   ├── actors/actor_visual_catalog.gd  tipo de actor -> hoja y filas
│   ├── npc/                        cuerpo, presentador y aparición de enemigos
│   ├── fx/slash_effect.gd          arco del golpe
│   ├── hud/hud.gd                  barras de vida, stamina y golpe, e icono de arma
│   └── camera/world_camera.gd      seguimiento y límites
├── infrastructure/
│   ├── configuration/game_config.gd
│   └── logging/game_logger.gd
└── (tests viven fuera de scripts, en tests/)

tests/
├── support/test_runner.gd          runner unitario
├── support/screenshot.gd           captura de frame
├── support/script_test_context.gd  aserciones
├── unit/                           15 archivos, 135 pruebas
└── integration/
    ├── world_physics_runner.gd     6 pruebas
    ├── combat_runner.gd            11 pruebas
    ├── npc_combat_runner.gd        20 pruebas
    ├── startup_runner.gd           17 pruebas
    └── inventory_runner.gd         5 pruebas
```

### El inventario y la mano

`Inventory` vive en `scripts/domain/inventory/` y no sabe nada de gráficos:
guarda pilas de `Item` con su cantidad, una casilla por objeto distinto
(capacidad `GameConfig.PLAYER_INVENTORY_CAPACITY = 20`). "La mano" es estado del
propio inventario (`equipped()`), y `Player.equipped_item` se lee de ahí. Cuando
`equipped_changed` emite, `GameSession` traduce el id al arma (`item.metadata.weapon`
-> `WeaponCatalog.create`) y llama al `MeleeCombat.equip()` que ya existía; la
señal `weapon_changed` del combate hace que la vista cambie el sprite de la mano.
El jugador arranca con la piedra equipada, la misma piedra con la que el combate
ya empezaba antes de que existiera el inventario.

### Qué NO hereda el combate del enemigo

`NpcCombat` **no** hereda de `MeleeCombat`, a propósito. Los dos son casos de uso y
el enemigo no tiene inventario, ni armas intercambiables, ni stamina: si heredara,
arrastraría un `Player` y un `Weapon` que no le sirven. Lo que sí comparten son las
reglas de daño, y eso vive en `DamageRules`, que recibe un objetivo con la forma
`take_damage` / `is_dead` / `stats` sin saber de qué clase es.

### La entrada de daño es única: el cuerpo de combate

Los dos casos de uso exponen un `take_damage(amount)` con el mismo contrato: la
cantidad ya viene calculada por el atacante (`DamageRules.compute` contra la
defensa de este cuerpo), y este método lo que hace es respetar la ventana de
invulnerabilidad, aturdir y emitir `invulnerability_changed`. Las vistas exponen
ese cuerpo de combate en `combat_target` (el jugador su `MeleeCombat`, el NPC su
`NpcCombat`), así que ningún golpe puede saltarse la ventana llamando a
`take_damage` sobre el `Player` o el `Npc` pelado.

De ahí sale la **ley del tinte rojo**: al recibir daño, todo ser se tiñe de rojo
(`HURT_TINT`) mientras dura su invulnerabilidad. El tinte es la lectura de la señal
`invulnerability_changed` en la vista, y por eso solo existe si el daño entra por
esta vía única. Estuvo rota para los NPC: `MeleeCombat.strike` golpeaba el `Npc`
directo, sin pasar por `NpcCombat`, y el enemigo bajaba de vida sin tinte. Hay un
caso en `npc_combat_runner` que mide la cadena entera (golpe -> hitbox ->
`NpcCombat` -> señal -> `modulate`).

## 6. Sistema de coordenadas (sección 16)

Decisiones fijas. No cambiar a mitad de proyecto.

| Concepto | Valor | Motivo |
| --- | --- | --- |
| Resolución base | 384x216 | 16:9 exacto, escala de ventana entera x3 |
| Tile | 16 px | cabe exacto en la resolución base |
| Escala de ventana | x3 | 1152x648 exacto, sin interpolar |
| Origen | (0, 0) en la esquina superior izquierda de la zona | |
| Unidades | 1 unidad = 1 px | sin conversión |
| Ejes | X derecha, Y abajo | convención de Godot 2D |
| Gravedad | 0 | el movimiento es libre en 8 direcciones |
| Movimiento | `MOTION_MODE_FLOATING` | nada de suelo en vista cenital |
| Filtro de textura | nearest | pixel art sin blur |

`zone_001` mide 64x40 tiles = 1024x640 px, con origen en (0,0).

## 7. Colisiones

| Capa | Bit | Contenido |
| --- | --- | --- |
| world | 1 | decor, estructuras, muro de límites |
| player | 2 | jugador |
| npc | 4 | NPC (Fase 1) |
| item | 8 | objetos en el suelo |
| hitbox | 16 | áreas de ataque (Fase 1, combate) |

El jugador es `collision_layer = PLAYER`, `collision_mask = WORLD`: colisiona
solo con el escenario. Los decor son estáticos con `mask = 0`, así que el mundo
no se empuja a sí mismo.

El borde de la zona es un `StaticBody2D` con cuatro paredes finas situadas fuera
del rectángulo jugable: mantiene al jugador dentro sin gastar tiles de borde.

## 8. Testing

```bash
# 111 pruebas de dominio, combate, enemigos, sprites y configuracion
godot --headless --script res://tests/support/test_runner.gd

# 6 pruebas con fisica real: colisiones y sincronía dominio/vista
godot --headless --script res://tests/integration/world_physics_runner.gd

# 11 pruebas del golpe del jugador: hitbox, dano, cooldown, arco
godot --headless --script res://tests/integration/combat_runner.gd

# 18 pruebas del enemigo: IA, golpe de ida y vuelta, muerte y reaparición
godot --headless --script res://tests/integration/npc_combat_runner.gd

# 7 pruebas de arranque: un solo mundo, cámara y jugador reales, WASD de verdad
godot --headless --script res://tests/integration/startup_runner.gd

# Captura un frame para inspeccion visual
godot --script res://tests/support/screenshot.gd -- /tmp/shot.png 60 216 432 1
```

El runner unitario carga cada archivo de `tests/unit/`, invoca `register()` y
ejecuta cada caso con un `ScriptTestContext`. Termina con código 1 si algo falla. Si
el archivo declara `teardown()`, lo llama tras cada caso: lo necesitan los casos que
crean nodos, porque un `Sprite2D` sin liberar deja la textura viva y Godot avisa de
fugas al salir.

Los tests unitarios no necesitan `SceneTree`: `Player`, `Health` y
`CharacterStats` son `RefCounted`. Eso es una consecuencia directa de la regla de
dependencias, y es la razón por la que el dominio se prueba tan rápido. Los sprites
también se pueden probar así: `Sprite2D` se configura y se consulta fuera del árbol, y
`_process` se llama a mano para no depender de la tasa de fotogramas.

Los tests de integración sí lo necesitan, porque `move_and_slide()` solo resuelve
colisiones cuando el servidor de física ha avanzado. Por eso viven en un runner
propio. Hay cuatro y no uno: cada suite tiene que **bajar de forma distinta** cuando se
le rompe su cadena. En el runner de combate se desconecta el presentador y bajan tres
casos; en el de enemigos, sin cuerpos `CharacterBody2D` o sin reparto de objetivo,
bajan las de la IA; en el de arranque, con un `MainWorldView` de más en
`run/main_scene`, bajan el recuento de mundos, la cámara activa y el movimiento.

El runner de enemigos monta su propia zona (`_ensure_npcs()`) en vez de fiarse de que
el autoload la haya poblado, porque `GameConfig.NPC_ENABLED` puede dejarla vacía. Atar
la suite al contenido por defecto del juego es atarla a una bandera, y así los 20
casos siguen significando lo mismo se enciendan o apaguen los enemigos.

`screenshot.gd` acepta `x`, `y` y `zoom`: teletransporta al jugador y ajusta el
aumento de la camara, lo que permite inspeccionar una zona entera o un elemento
concreto sin abrir el editor. **No funciona en `--headless`**: el driver de render
headless no emite `frame_post_draw` y el script se queda esperando ahí. Para
capturar hay que darle pantalla (`xvfb-run -a godot --rendering-driver opengl3 --script res://tests/support/screenshot.gd -- ...`), y las capturas se revisan
contando píxeles de las hojas y de la imagen, no mirándolas.

## 9. Sprites: cómo se lee una hoja del pack

La mayoría de los gráficos vienen del **Ninja Adventure Asset Pack** de Pixel-boy
(CC0). El jugador humano viene del pack **Bit Era Game Character - Extended** de
ImogiaGames (CC0), elegido tras inspeccionar las hojas candidatas píxel a píxel
(ver `docs/CHARACTER_VISUAL_SYSTEM.md`). Solo se copiaron las hojas que el juego
usa, no los packs enteros: `assets/` pesa unos 1,4 MB de los ~26 MB de los
paquetes originales.

| hoja | tamaño | rejilla |
| --- | --- | --- |
| `assets/characters/human_player.png` | 64x128 | 4 x 8 de 16x16 (jugador, por defecto) |
| `assets/characters/ninja_blue.png` | 64x112 | 4 x 7 de 16x16 (jugador, fallback) |
| `assets/characters/{slime,owl,spider_red,lizard}.png` | 64x64 | 4 x 4 de 16x16 |
| `assets/fx/slash.png` | 128x32 | 4 de 32x32 (arco del jugador) |
| `assets/fx/claw.png` | 128x32 | 4 de 32x32 (zarpazo de los enemigos) |
| `assets/weapons/{blade,rock}.png` | 6x11 y 3x16 | sin rejilla |

Dos cosas que no se deducen mirando los píxeles y que por eso están en
`GameConfig`:

**Las filas del personaje son las cuatro orientaciones**, en el orden que fija
`ACTOR_ROW_DOWN`, `ACTOR_ROW_SIDE`, `ACTOR_ROW_UP`, `ACTOR_ROW_SIDE_MIRRORED`. Las
dos filas laterales son imágenes especulares la una de la otra, así que **no hay forma
de saber cuál es izquierda y cuál derecha**. Está en la configuración y no en el
código a propósito: si al jugar el personaje lateral va del revés, se intercambian esos
dos números y no hay que tocar ningún otro archivo.

**El fotograma del efecto de golpe es un cuadrado de 32x32**: la hoja es de 128x32
y contiene **cuatro** fotogramas en una sola fila. Recortarla en 16x16 la parte en
dos filas y el efecto recorre la de arriba, que está casi vacía: el golpe parpadea
en blanco en vez de dibujarse, sin ningún error. La rejilla se confirmó casando la
hoja con el `Preview.gif` del pack píxel a píxel, no contando celdas. El origen del
efecto lo calcula `SlashEffect.origin_for()` desde el centro del torso
(`ACTOR_SPRITE_OFFSET` (0, -8)) más la dirección por `FX_ORIGIN_OFFSET`: un arco
anclado en la raíz del personaje, que está en los pies, queda mal en transversal y
al mirar hacia abajo.

`ActorSprite` hace el recorte con `hframes` y `vframes` de `Sprite2D`: no hay ningún
`AtlasTexture` que mantener. Dos tipos de clip:

- **direccional**: la fila sale de la orientación, así que el mismo clip se ve hacia
  las cuatro. Es lo que usa caminar.
- **fila fija**: la animación solo existe mirando al frente, como el golpe. Se dibuja
  siempre en su fila y se refleja en horizontal cuando el actor mira a un lado.

Los enemigos del pack no traen fila de golpe propia, así que reutilizan la pose de
frente, que es lo que dice `ActorVisualCatalog.attack_row_of`.

Cambiar el visual del jugador es cambiar `GameConfig.PLAYER_VISUAL` (el humano
`player_human` por defecto, el ninja `player_ninja` como fallback). El catálogo
resuelve el alias `PLAYER` a la definición activa; cada definición trae su hoja,
sus filas y sus fotogramas. Los tipos de enemigo (`NpcKind`) viven en el dominio;
el catálogo visual los traduce a hoja. La regla de capas manda sobre lo que
resulte más cómodo.

## 10. Extender el mapa

Añadir una zona nueva:

1. duplicar `scenes/world/world.tscn` y cambiar `zone_id` y `size_in_tiles`;
2. asignar `zone_scene` en `MainWorldView` o cargarla bajo demanda.

Añadir un tipo de decor nuevo:

1. crear el script en `scripts/presentation/world/decor/` extendiendo
   `WorldDecor`;
2. registrar la clave en `ZoneView._create_decor()`.

Ninguno de los dos casos obliga a tocar el mapa existente ni el jugador.