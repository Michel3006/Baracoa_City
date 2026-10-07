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
| `assets/characters/human_player.png` | persona (bit-era, CC0): el jugador por defecto y los cuatro tipos de enemigo (64x128) | 16x16, 4 columnas x 8 filas: filas 0-3 caminar (abajo/lateral/arriba/lateral espejo), fila 4 salto/caída/muerte (muerte en columna 2, yacente), fila 5 golpe (3 fotogramas, la columna 3 queda vacía), filas 6-7 vacías |
| `assets/characters/ninja_blue.png` | ninja clásico del pack: fallback del jugador (64x112) | 16x16, 4 columnas x 7 filas: filas 0-3 caminar, fila 4 golpe, filas 5-6 salto/objeto |
| `assets/weapons/blade.png` | cuchillo (6x11) | el sprite es el icono y el arma en mano |
| `assets/weapons/rock.png` | piedra (3x16) | ídem |
| `assets/fx/slash.png` | arco de golpe del jugador y de los enemigos (128x32) | **32x32**, 4 fotogramas en una sola fila — no es 16x32 |
| `assets/environment/kenney_tiny_dungeon/Tilemap/tilemap.png` | atlas del terreno (203x186) | 16x16 con 1 px de separación, 12x11 celdas |

Los enemigos no tienen hoja propia: comparten la de la persona y se diferencian por
el nombre (`NpcKind`) y por un tinte de paleta (`ActorVisualCatalog.tint_of`, con
los cuatro colores en `GameConfig.NPC_TINT_*`). Así el golpe, la caminata y la
muerte de un enemigo son literalmente los del jugador, sin una segunda hoja que
mantener. Las hojas de los antiguos bichos (`slime`, `owl`, `spider_red`,
`lizard`) y `assets/fx/claw.png` (las zarpas) se borraron el día que los
enemigos pasaron a ser personas.

Casi todo el decorado del mundo (árboles, piedras, muros de casa) está dibujado
con rectángulos desde el código y no necesita textura.

## 2. Necesarias ahora (cierre de Fase 1)

### 2.1. Por qué ya no hace falta una fila de ataque para los enemigos

Se había pedido, para cada uno de los cuatro enemigos, una fila nueva de ataque
añadida a su hoja (64x64 -> 64x80): sus hojas solo traían filas de caminar, y al
atacar de lado el fotograma no encajaba. **Quedó resuelto de otra manera y ya no
hay textura que traer.**

Los enemigos pasaron a ser personas: los cuatro tipos usan `human_player.png`,
la misma hoja que el jugador (`ActorVisualCatalog._npc_human_definition()`), y se
distinguen por el nombre y por un tinte de paleta (`tint_of`, con los colores en
`GameConfig.NPC_TINT_*`). El golpe es ya el puñetazo de tres fotogramas de la
fila 5, la caminata es la del jugador en las cuatro orientaciones y la muerte es
la pose yacente de la fila 4, igual en las cuatro direcciones: no solo se ganó la
fila de ataque, también se ganó la muerte de pie, que era el otro defecto de las
hojas viejas.

Las hojas de los bichos (`slime.png`, `owl.png`, `spider_red.png`, `lizard.png`)
y `assets/fx/claw.png` (las zarpas) se borraron. Si algún día vuelve a existir un
enemigo con hoja propia, el encargo vuelve a estar en pie con este mismo formato:

- 4 columnas x 1 fila de 16x16, en una sola fila, pegadas (sin separación), con la
  pose de ataque de frente.
- Los 4 fotogramas tienen que caber en la duración del golpe
  (`ACTOR_ATTACK_RECOVERY`); el código los reproduce a `ACTOR_ATTACK_FPS` y se
  queda en el último.
- Para casar la fila con la hoja, comparar con el `Preview.gif` del pack píxel a
  píxel: contar celdas no basta.

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
edificios con fachadas, interiores, puertas), más NPC con sus hojas (el mismo
formato que el jugador: 64x128, cuatro filas de caminar, muerte y golpe de tres
fotogramas — o la propia `human_player.png` con otro tinte, que es lo que hoy
hacen los enemigos), y más objetos colocables (con icono para la mochila).

**Fase 5 — sistemas de vida:** sprites de dinero/moneda, comida y bebida
(consumibles con icono), objetos de trabajo y propiedades.

**Fase 2 — multijugador:** no necesita texturas nuevas por sí sola; si se quiere
distinguir al segundo jugador, una variante de color del `ninja_blue.png` con la
misma rejilla (64x112).