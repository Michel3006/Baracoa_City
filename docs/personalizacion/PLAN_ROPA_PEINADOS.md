# Plan de ropa y peinados — Estrategia, arte y arquitectura

Propuesta de Fases 1 a 4 para `docs/Plan_Ropa_Peinados_Baracoa_City.md`, sobre los
datos medidos en `INFORME_COMPATIBILIDAD.md`.

> **Estado (2026-10-14):** las tres preguntas del final están respondidas, la
> **Fase 3 (coste 0) y la interfaz de selección ya están implementadas y probadas**
> (`IMPLEMENTACION_FASE_3.md` y `IMPLEMENTACION_FASE_4.md`). Lo construido difiere
> de la propuesta en tres puntos, que manda la implementación: (1) no se usó
> `ShaderMaterial`, sino una **capa de superposición en CPU con caché** (no toca
> el `ActorSprite` ni su material, y así el combate no ve nada nuevo); (2) la UI no
> es una pestaña dentro de la mochila sino un **panel propio con su tecla (`C`)**
> que reutiliza el patrón de `InventoryPanel`; (3) los nombres de archivo reales
> están en esos dos documentos. Se usaron **0 generaciones** de PixelLab.
>
> Decisión abierta que ya tiene respuesta del usuario: el **peinado con forma** se
> **dibuja a mano y gratis** con `pixelart_workbench` (0 generaciones). Es el
> siguiente incremento.

## Fase 1 — Estrategia gráfica

### El problema, en números

Una prenda "dibujada" (una imagen superpuesta) necesita una imagen por cada
**clip × dirección × fotograma**. El personaje tiene 92 hojas y ~2.236 fotogramas.
Con IA a ≤15 frames por llamada y 10–25 gen/llamada:

| alcance | fotogramas | llamadas IA | generaciones | ¿cabe en 40? |
| --- | --- | --- | --- | --- |
| una prenda en **todo** el personaje | ~2.236 | ~150 | 1.500–3.700 | **no** |
| una prenda solo en **caminar** | 96 | ~7 | 70–175 | **no** |
| una prenda solo en **idle** (4 dir) | 4 | 1 | 10–25 | sí (25–62% del mes) |

Conclusión: **la vía "redibujar la prenda por IA" no es viable** ni con holgura.
La única forma de que la ropa quede **alineada en todas las direcciones y
animaciones** dentro del presupuesto es **derivar la prenda del propio dibujo**.

### Las tres estrategias del plan, evaluadas

- **Capas independientes (imágenes por frame):** viable técnicamente, **inviable
  en coste**. Descartada para cobertura completa.
- **Variantes completas de sprite:** peor (regenerar el personaje entero).
  Descartada.
- **Híbrido (recomendado):** la prenda se **calcula** desde el cuerpo para todo
  lo que se pueda (coste 0, cobertura total) y solo se usan **imágenes** para lo
  que de verdad necesita forma nueva (accesorios), en un conjunto acotado.

### Recomendación: máscara/región + capas para accesorios

Como el boxeador va **sin camiseta**, una camiseta es *pintar sobre los píxeles de
piel del torso*. Eso se puede hacer **por regla**, no por imagen, y entonces vale
para los 2.236 fotogramas a la vez:

- **Camiseta / pantalón / color de pelo → "recolor por región"** (coste 0):
  se define, por dirección, una **región del torso** y un **color clave** (la
  piel) y se sustituye por el color de la prenda. Al operar sobre los mismos
  píxeles, la alineación es **exacta por construcción** y la **oclusión es
  automática**: los brazos, manos y botas son de otro color y quedan intactos.
  Da colores ilimitados. Es literalmente lo que pide el plan: *"reutiliza
  píxeles, paletas, máscaras o herramientas de edición para evitar generar
  variantes duplicadas"*.
- **Peinado (forma) / gorra → "capa de superposición"** (requiere arte): hojas
  propias por (clip, dir) con la misma celda y `feet`. Se dibujan con
  **`pixelart_workbench` (gratis)** para un conjunto mínimo, o se encargan a IA
  (1 tanda de 10–25 gen) como **referencia** de una sola prenda de autor.

Lo que **no** se hará (lo prohíbe el plan): usar una sola imagen estática para
todas las poses, ni recortar el personaje para "convertirlo" en prenda.

## Fase 2 — Especificación de arte de la prueba mínima

Prueba mínima: **1 camiseta + 1 peinado**, sin ampliar catálogo.

### Camiseta (técnica de región; no necesita PNG nuevo)

- Región por dirección, en coordenadas de la celda 42×44 (origen del nodo en los
  pies, `feet` por dirección). Se define una **caja del torso** por dirección y se
  pinta la piel dentro de ella.
- Colores de la prenda derivados de la paleta base para que sombra y contorno
  casen: color principal + una sombra y un contorno a partir de los grises de la
  propia hoja.
- Validación: **captura + recuento de píxeles** (este modelo no ve imágenes; el
  proyecto ya trabaja así). Se compara el color de la prenda y se comprueba que
  brazos/manos/botas siguen con su color original.

### Peinado (dos niveles)

- Nivel 1, coste 0: **color de pelo** (región de la cabeza).
- Nivel 2, con forma (flequillo, gorra): **overlay** 42×44 por dirección. Si su
  forma cambia por fotograma (pelo al viento), se limita a los clips que se
  validen y se documenta qué queda fuera.

### Reglas de los recursos

- Carpeta nueva: `assets/characters/customization/` (nunca en `hormelz_melee/`).
- Nunca se sobrescribe, renombra, mueve ni borra un PNG original.
- Dimensiones 42×44, fondo transparente, filtro NEAREST, sin reescalado.
- Se valida **casando la hoja con el pack** (no contando celdas).

## Fase 3 — Arquitectura propuesta

Todo en `Presentation`. Nada en el dominio y nada de combate.

```
scripts/presentation/customization/
  appearance_state.gd      # RefCounted: shirt_id, hair_id, colores; señal changed()
  appearance_catalog.gd    # RefCounted estático: id -> GarmentDefinition
  garment_definition.gd    # RefCounted: qué se pinta y cómo (región u overlay)
  garment_layer.gd         # Node2D: lee el ActorSprite y dibuja la prenda
  palette_recolor.gd       # helper con caché (Image -> ImageTexture)
```

### Sincronización (obligatoria, sin relojes propios)

- El **dueño del estado sigue siendo `ActorSprite`**. `GarmentLayer` **no** tiene
  reloj: en su `_process` lee `texture`, `frame`, `offset`, `flip_h`,
  `current_clip()` y `facing()` del actor y **replica** ese estado. Si nada
  cambió desde el fotograma anterior, no hace nada.
- Para la técnica de **región**, el recoloreado se aplica **al propio cuerpo**:
  - **Opción preferida: `ShaderMaterial`** puesto en el `ActorSprite` con
    uniforms (color clave, color nuevo, rectángulo por dirección). Es puro
    material, cubre las 92 hojas sin código nuevo y no duplica texturas.
  - Alternativa: `palette_recolor` en CPU sobre una **copia** de la textura, con
    caché por (ruta de hoja, prenda). Más memoria, cero shader.
- Clips con `frames = 1` (idle, fight_idle) no dependen de ningún reloj; los
  animados ya los mueve el actor.

### Orden de dibujo y oclusión

| z | qué |
| --- | --- |
| 0 | cuerpo (`ActorSprite`) |
| 1 | `PunchArm` (ya existe) y capa de prenda frontal |
| 2 | pelo delantero (si hiciera falta) |
| 8 | FX de golpe (`Z_FX`, ya existe) |

- Con **región/recolor la oclusión es automática**: solo se tocan los píxeles del
  color clave. Manos, brazos, armas y botas (otros colores) no se manchan.
- El pelo puede necesitar **dos capas** (detrás y delante de la cabeza según
  dirección); solo si el arte lo pide.

### Integración (cambio mínimo, y por eso sujeto a aprobación)

- `PlayerView._build_actor()` añade la capa tras crear el actor. **`PlayerView` es
  compartido entre presentación y combate** (contiene la hitbox y `combat_target`),
  así que este cambio se explica aquí y **espera aprobación** antes de aplicarse.
- `ActorSprite` **no necesita cambios**: todo lo que la capa lee ya es público.
  (Si se opta por el shader, se le asigna `material` desde fuera, sin tocarlo.)
- El estado de apariencia no entra en `GameSession` salvo para persistir, si se
  quiere más adelante.

### Interfaz de selección — **hecha** (`IMPLEMENTACION_FASE_4.md`)

- Se reutiliza el patrón de `InventoryPanel` (mochila), que ya pausa el mundo y
  navega con los ejes. `Tab` está ocupado por la mochila, así que el vestuario usa
  **`C`** (`toggle_appearance`) en un **panel propio**, no una pestaña dentro de la
  mochila: así cada modal tiene una tecla y los dos son excluyentes.
- **Elegir es ponerse** (sin borrador), la fila no da la vuelta, la opción sí, y la
  opción 0 es "nada puesto".
- La **vista previa** es un espejo del cuerpo real (copia `texture`/`frame`/`flip_h`
  cada fotograma y apunta al **mismo** `AppearanceState`), sin reloj propio y sin
  tinte: en el recuadro se lee la prenda, no el estado de combate.

### Pruebas que se añadirán

- Unitarios (datos puros): `garment_definition`, `appearance_catalog`,
  `appearance_state`, `palette_recolor` (mapa de color → color).
- Integración (nodos, con `teardown()`): la capa existe, lee el estado del actor
  y no crea reloj propio; cambiar de prenda no desincroniza el clip ni el
  fotograma.
- Visual: captura con `xvfb` y recuento de píxeles (color de prenda presente,
  colores de mano/bota intactos).

## Fase 4 — Protección del combate

- No se toca ningún archivo de la tabla de la sección 4 del informe.
- `PlayerView` es lo único compartido que se tocaría; el cambio es **añadir un
  hijo** (una capa de dibujo) y no altera colisiones, hitbox, `combat_target`,
  tiempos ni señales.
- **Prueba de que el combate no cambió:** la suite de combate
  (`combat_runner` 16/16, `npc_combat_runner` 22/22) y el `git diff` de los
  archivos de combate, que deben salir **vacíos**.

## Fase 5 — Validación de la prueba

1. Godot sin errores de importación, recursos ni GDScript (`--headless --import`
   limpio y ninguna suite con `SCRIPT ERROR`).
2. Las 4 direcciones.
3. idle, caminar, atacar, recibir daño y muerte.
4. Varios fotogramas por animación (no solo el primero).
5. Buscar desfases, bordes opacos, píxeles flotantes y saltos de escala.
6. Oclusión mirando arriba y abajo.
7. Suites de combate antes y después (mismos números).
8. Cambiar de prenda no desincroniza la animación.
9. Registrar lo probado y lo no verificable.

## Fase 6 — Ampliar catálogo (solo con autorización)

Más colores (coste 0, son máscaras), luego más formas. Antes de cada lote, coste
conocido y saldo restante.

## Lo que necesito que decidas

> **Respondido (2026-10-13):** 1) **a coste 0 primero** (`true` → se implementó la
> Fase 3); 2) **sí** se autorizó el cambio mínimo de `PlayerView`; 3) peinado =
> **solo color** (coste 0). El resultado medido de las tres está en
> `IMPLEMENTACION_FASE_3.md`; el peinado por color tiene una limitación conocida
> (el personaje va rapado) que ese documento explica.
>
> **Respondido (2026-10-14):** para el **peinado con forma** el usuario eligió
> **dibujarlo a mano, gratis**, con `pixelart_workbench` (0 generaciones), en vez de
> una tanda de IA. La UI de selección ya está hecha (`IMPLEMENTACION_FASE_4.md`).

1. **¿Apruebas la estrategia de coste 0** (camiseta por región/recolor) como
   prueba mínima, o prefieres **gastar 10–25 generaciones** en una camiseta de
   autor por IA (cobertura parcial: solo los fotogramas que se generen)?
2. **¿Autorizas tocar `PlayerView`** (añadir un hijo de dibujo) para integrar la
   capa? Es el único archivo compartido que se modificaría.
3. **Peinado:** ¿te vale **color de pelo** (coste 0) en la prueba, o quieres
   **forma** (overlay dibujado gratis con `pixelart_workbench`, o 1 tanda de IA)?
