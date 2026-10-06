# Mapa: zone_001

Primera zona jugable. Sirve como banco de pruebas del mundo, no como contenido
final.

## Dimensiones

| dato | valor |
| --- | --- |
| id | `zone_001` |
| tamaño | 64x40 tiles |
| píxeles | 1024x640 |
| origen | (0, 0), esquina superior izquierda |
| tile | 16 px |
| resolución base | 384x216 (con `GameConfig.CAMERA_ZOOM` = 1.5 la cámara muestra 256x144 px) |

El mapa se dibuja entero en memoria: 1024x640 px es trivial para el hardware de
desarrollo. Cuando el municipio crezca, esto se sustituye por carga por zonas
(sección 14) sin cambiar el resto del sistema.

## Estructura de la escena

```text
world.tscn  (ZoneView)
├── Ground        TileMapLayer: arena, calles de tierra y losa empedrada
├── Bounds        StaticBody2D con 4 paredes fuera del área jugable
├── Tree x6       decor sólido dibujado a mano
├── Rock x3       decor sólido dibujado a mano
├── House x2      decor sólido dibujado a mano, colisión solo del volumen construido
└── Prop x22      sprite del atlas: 11 sólidos (barril, caja, cofre, caldero,
│                 estantería, mesa) y 11 de atrezo (antorcha, arbusto, huesos,
│                 poción, escudo)
```

`Bounds` se sitúa un tile fuera del rectángulo jugable por cada lado. El jugador
queda encerrado sin gastar tiles en borde y sin ver paredes fuera del mapa.

## Terreno

El suelo ya no son rectángulos dibujados: es un `TileMapLayer` con el atlas de
Tiny Dungeon de Kenney (CC0). `TileCatalog` es el único sitio que sabe qué celda
del atlas es cada cosa, así que cambiar el suelo es cambiar una tabla.

| elemento | `TileCatalog.Terrain` | calle |
| --- | --- | --- |
| arena | `SAND`, `SAND_DARK`, `SAND_PEBBLE` | 48, 50, 49 |
| calle de tierra | `DIRT`, `DIRT_PEBBLE` | 0, 24 |
| losa empedrada | `PAVED` | 6 |

El tono de arena se elige con el hash `(x*31 + y*17) % 3`, y el de la calle con
`salt % 3`: el mapa es idéntico en cada partida y en cada test.

La losa empedrada cubre un radio de 2 tiles alrededor de `GameConfig.PLAYER_SPAWN`:
donde aparece el jugador ya no hay arena.

## Distribución de prueba

Todo en coordenadas de tile, con origen en la esquina superior izquierda:

| elemento | tile | píxel |
| --- | --- | --- |
| árbol | (6, 8) | (96, 128) |
| árbol | (24, 4) | (384, 64) |
| árbol | (9, 24) | (144, 384) |
| árbol | (34, 20) | (544, 320) |
| árbol | (44, 30) | (704, 480) |
| árbol | (52, 22) | (832, 352) |
| piedra | (40, 11) | (640, 176) |
| piedra | (29, 27) | (464, 432) |
| piedra | (18, 18) | (288, 288) |
| casa | (14, 30) | (224, 480) |
| casa | (48, 8) | (768, 128) |

El jugador aparece en `GameConfig.PLAYER_SPAWN` = (200, 200), es decir el tile
(12, 12). Está en un claro: sin obstáculos a menos de 3 tiles.

Los props van en `_place_props()`. Los 11 sólidos están fuera de los pasillos que
recorren los tests de integración en línea recta (la fila y=20 y la columna x=20
alrededor del cruce), así que el tests de física no dependen del atrezo:

| prop | sólidos | tiles |
| --- | --- | --- |
| barril | sí | (2, 2), (61, 2), (2, 37), (61, 37) |
| caja | sí | (4, 4), (59, 5) |
| cofre | sí | (56, 34) |
| caldero | sí | (47, 30) |
| estantería | sí | (43, 33), (45, 33) |
| mesa | sí | (18, 16) |
| antorcha | no | (19, 14), (21, 18), (25, 23), (30, 19) |
| arbusto | no | (30, 10), (52, 25), (10, 35), (40, 30) |
| huesos | no | (16, 6) |
| poción | no | (17, 16) |
| escudo | no | (57, 33) |

`solid` decide si el prop lleva colisión. Un `PropView` con `solid = false` no
entra en la capa `world`, así que el jugador lo pisa sin cortarse.

## Zonas densas

`ZoneView.scattered_trees` activa una distribución de árboles cada 3 tiles,
saltando los que cumplen `(x*31 + y*17) % 5 == 0`. El patrón es determinista a
propósito, para que el mapa sea idéntico en cada partida y en los tests.

Para probarlo desde el código:

```gdscript
zone.size_in_tiles = Vector2i(64, 40)
zone.demo_layout = false
zone.scattered_trees = true
```

## Añadir una zona nueva

1. Duplicar `scenes/world/world.tscn`.
2. Cambiar `zone_id` y `size_in_tiles`.
3. Ajustar la distribución en `ZoneView.build_demo_layout()`.

Ningún cambio en el jugador ni en la cámara: los límites se recalculan al
cargar la zona.