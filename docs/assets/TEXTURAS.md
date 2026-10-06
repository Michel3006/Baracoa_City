# Texturas del juego

Inventario de lo que ya hay, de lo que hace falta ahora y de lo que hará falta
después, con el formato exacto de cada hoja. Se usa como lista de encargo: si una
textura nueva no cumple el formato de aquí, el recorte o la animación saldrán mal
sin que ningún test lo diga (ver AGENTS.md: contar celdas no basta, y lo que no
encaje en la rejilla no da error, da un dibujo equivocado).

Cada textura nueva se deja en la carpeta `assets/` correspondiente y se cuelga del
código desde el catálogo que toque (`ActorVisualCatalog`, `TileCatalog`,
`WeaponCatalog`…) — nunca se referencia un archivo suelto desde la vista. Añadir
una textura nueva es: dejar el archivo, tocarlo en el catálogo, y un test de la
rejilla.

## 1. Lo que ya existe (no hace falta traer)

Todo esto está incluido y recortado a su rejilla, con tests que comprueban el
recorte:

| archivo | qué es | rejilla |
| --- | --- | --- |
| `assets/characters/ninja_blue.png` | jugador (64x112) | 16x16, 4 columnas x 7 filas: filas 0-3 caminar (abajo/lateral/arriba/lateral espejo), fila 4 golpe, filas 5-6 salto/objeto |
| `assets/characters/slime.png` | enemigo slime (64x64) | 16x16, 4 filas de caminar, sin fila de ataque |
| `assets/characters/owl.png` | enemigo búho (64x64) | ídem |
| `assets/characters/spider_red.png` | enemigo araña (64x64) | ídem |
| `assets/characters/lizard.png` | enemigo lagarto (64x64) | ídem |
| `assets/weapons/blade.png` | cuchillo (6x11) | el sprite es el icono y el arma en mano |
| `assets/weapons/rock.png` | piedra (3x16) | ídem |
| `assets/fx/slash.png` | arco de golpe del jugador (128x32) | **32x32**, 4 fotogramas en una sola fila — no es 16x32 |
| `assets/fx/claw.png` | zarpas de golpe de los enemigos (128x32) | ídem |
| `assets/environment/kenney_tiny_dungeon/Tilemap/tilemap.png` | atlas del terreno (203x186) | 16x16 con 1 px de separación, 12x11 celdas |

Casi todo el decorado del mundo (árboles, piedras, muros de casa) está dibujado
con rectángulos desde el código y no necesita textura.

## 2. Necesarias ahora (cierre de Fase 1)

Solo hay un hueco real, y es el único remate de Fase 1 que espera una textura:

### 2.1. Fila de ataque de los cuatro enemigos

Hoy el golpe de los enemigos reutiliza la pose de caminar de frente: el pack solo
trae filas de caminar, y al atacar de lado el fotograma no encaja (está anotado en
`ActorVisualCatalog.attack_row_of`).

**Qué traer:** para cada uno de los cuatro enemigos (slime, búho, araña, lagarto),
una **fila nueva de 4 fotogramas de 16x16** con la pose de ataque, añadida a su
hoja actual. La hoja pasa de 64x64 a **64x80** (5 filas): las cuatro de caminar
que ya tienen, y la quinta la del golpe — exactamente la misma disposición que ya
usa el jugador (cuatro filas de caminar y el golpe debajo, `PLAYER_ATTACK_ROW`).

Especificación de la fila:

- 4 columnas x 1 fila de 16x16, en una sola fila, pegadas (sin separación).
- La pose es la de golpe **de frente**, en el estilo de cada enemigo (misma
  paleta, mismo tamaño de cuerpo que sus filas de caminar).
- Los 4 fotogramas tienen que caber en la duración del golpe
  (`ACTOR_ATTACK_RECOVERY`), como los del jugador; el código los reproduce a
  `ACTOR_ATTACK_FPS` (20) y se queda en el último.
- El código refleja la fila en horizontal cuando el enemigo mira a la izquierda,
  igual que hace con el jugador, así que no hay que dibujar el golpe lateral ni el
  de espaldas: con la pose frontal basta para que las cuatro orientaciones se lean.

Para casar la fila con la hoja, comparar el resultado con el `Preview.gif` del
pack (si el enemigo lo trae) píxel a píxel, como se hizo con las hojas de efecto:
contar celdas no basta.

**Cableado cuando lleguen:** `ActorVisualCatalog.attack_row_of()` devuelve la fila
4 (`GameConfig.ACTOR_ROW_DOWN + 4`) para los cuatro enemigos, igual que el
jugador, y se añade un caso a `test_actor_sprite` que compruebe la rejilla de las
cuatro hojas (64x80, golpe en la fila 4). Hasta que no estén, el golpe sigue
reutilizando la pose frontal sin que nada se rompa.

### 2.2. Icono de la baya (opcional, pero cómodo)

La mochila dibuja la baya procedural (círculo rojo + hoja con `draw_rect`): funciona,
pero no tiene el acabado del resto. Un `assets/items/berry.png` de **16x16** con
fondo transparente la sustituiría. Las armas ya enseñan su propio sprite como icono,
así que solo hacen falta iconos para los objetos que no son armas.

## 3. Reglas de formato que se aplican a cualquier textura que se traiga

1. **PNG con transparencia (RGBA)**; fondo transparente, sin bordes de fondo.
2. **Rejilla de 16x16** para personajes y objetos de suelo (los efectos y el atlas
   tienen la suya propia, ver arriba). Fuera de una rejilla conocida no se
   recorta: se parte la animación.
3. **Un archivo por hoja**, con la animación completa dentro. No filetes sueltos de
   un fotograma por archivo.
4. **Nearest, no suavizado**: pixel-art sin sombreado ni interpolación; el juego
   dibuja con `TEXTURE_FILTER_NEAREST`.
5. **Estilo del pack Ninja Adventure / Tiny Dungeon (CC0)** si se quiere que
   empaste con lo que ya hay; paleta y tamaño de cuerpo parecidos.
6. **El origen del personaje está en los pies, no en el centro del recorte**: el
   cuerpo se dibuja hacia arriba desde la raíz del nodo (`ACTOR_SPRITE_OFFSET`).
   Un sprite centrado en su recorte se verá flotando o hundido en el suelo según
   como caiga el cuadro.
7. **La orientación de las hojas laterales no se puede deducir de los píxeles**:
   si una fila lateral sale espejada al jugar, se intercambian dos constantes de
   `GameConfig` (`ACTOR_ROW_SIDE` / `ACTOR_ROW_SIDE_MIRRORED`) y no se toca nada
   más.
8. **Acompañar toda hoja de un `Preview.gif` jugando los fotogramas** si es
   posible: es la referencia que deshace dudas de rejilla, número de fotogramas o
   filas (la lección de las hojas de efecto).

## 4. Futuras (fases 4-6, no urgentes)

Para que la lista esté completa de cara al roadmap, lo que hará falta cuando se
amplíe el juego. No traer nada de esto todavía: el juego no lo consume y los
catálogos no lo referencian.

**Fase 4 — mundo ampliado:** tiles y props de la municipalidad (calles/aceras,
edificios con fachadas, interiores, puertas), más NPC con sus hojas (mismo formato
que los enemigos: 64x64, cuatro filas de caminar + fila de golpe), y más objetos
colocables (con icono para la mochila).

**Fase 5 — sistemas de vida:** sprites de dinero/moneda, comida y bebida
(consumibles con icono), objetos de trabajo y propiedades.

**Fase 2 — multijugador:** no necesita texturas nuevas por sí sola; si se quiere
distinguir al segundo jugador, una variante de color del `ninja_blue.png` con la
misma rejilla (64x112).