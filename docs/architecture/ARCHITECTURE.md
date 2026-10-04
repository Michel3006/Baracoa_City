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
  -> MainWorldView (crea zona + jugador + cámara)
  -> MovementController.bind(player)
```

El resto del código recibe sus colaboradores por setter (`bind`, `setup`,
`connect_movement`) o por signals. No hay singletons adicionales ni
localizadores de servicios.

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
│   ├── game.gd                     autoload Game: composition root + reloj
│   └── collision_layers.gd         bits de las capas 2d_physics
├── domain/
│   ├── events/game_events.gd       bus de señales
│   ├── player/player.gd            entidad y sus invariantes
│   ├── player/player_state.gd      máquina de estados
│   ├── player/health.gd            vida, daño, muerte
│   └── player/character_stats.gd   estadísticas base
├── application/
│   ├── game_session.gd             caso de uso: inicio de sesión y reaparición
│   └── player/movement_controller.gd  caso de uso: movimiento
├── presentation/
│   ├── world/main_world_view.gd    raíz del mundo
│   ├── world/zone_view.gd          una zona con terreno, decor y límites
│   ├── world/world_decor.gd        base de obstáculos sólidos
│   ├── world/decor/                árbol, piedra
│   ├── world/structures/           casa
│   ├── player/player_view.gd       sprite y colisión del jugador
│   ├── player/player_presenter.gd  entrada -> caso de uso
│   └── camera/world_camera.gd      seguimiento y límites
├── infrastructure/
│   ├── configuration/game_config.gd
│   └── logging/game_logger.gd
└── (tests viven fuera de scripts, en tests/)

tests/
├── support/test_runner.gd          runner unitario
├── support/screenshot.gd           captura de frame
├── support/script_test_context.gd  aserciones
├── unit/                           6 archivos, 30 pruebas
└── integration/                    mundo y fisica, 6 pruebas
```

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
# 30 pruebas de dominio, movimiento, limites y configuracion
godot --headless --script res://tests/support/test_runner.gd

# 6 pruebas con fisica real: colisiones y sincronía dominio/vista
godot --headless --script res://tests/integration/world_physics_runner.gd

# Captura un frame para inspeccion visual
godot --script res://tests/support/screenshot.gd -- /tmp/shot.png 60 216 432 1
```

El runner unitario carga cada archivo de `tests/unit/`, invoca `register()` y
ejecuta cada caso con un `ScriptTestContext`. Termina con código 1 si algo falla.

Los tests unitarios no necesitan `SceneTree`: `Player`, `Health` y
`CharacterStats` son `RefCounted`. Eso es una consecuencia directa de la regla de
dependencias, y es la razón por la que el dominio se prueba tan rápido.

Los tests de integración sí lo necesitan, porque `move_and_slide()` solo resuelve
colisiones cuando el servidor de física ha avanzado. Por eso viven en un runner
propio.

`screenshot.gd` acepta `x`, `y` y `zoom`: teletransporta al jugador y ajusta el
aumento de la camara, lo que permite inspeccionar una zona entera o un elemento
concreto sin abrir el editor.

## 9. Extender el mapa

Añadir una zona nueva:

1. duplicar `scenes/world/world.tscn` y cambiar `zone_id` y `size_in_tiles`;
2. asignar `zone_scene` en `MainWorldView` o cargarla bajo demanda.

Añadir un tipo de decor nuevo:

1. crear el script en `scripts/presentation/world/decor/` extendiendo
   `WorldDecor`;
2. registrar la clave en `ZoneView._create_decor()`.

Ninguno de los dos casos obliga a tocar el mapa existente ni el jugador.