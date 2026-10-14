# godot-mcp: ojos y manos dentro del juego

El agente ya no adivina lo que sale en pantalla ni cuenta píxeles de una captura
para saber si algo se movió: habla con el editor vivo, lanza el juego, lo maneja
como un jugador y lee el estado como datos.

Esto existe por los tres fallos que AGENTS.md documenta como **invisibles para
las suites**:

| fallo documentado | qué lo habría cazado |
| --- | --- |
| "el arco no salía: el golpe era legalmente rechazado por cooldown" y "bajo `xvfb` `process_frame` no es tiempo de juego" | congelar el reloj de juego y avanzar tramos exactos con el input dentro de la ventana |
| "había dos mundos y el que se veía no estaba conectado a nada" | árbol de escena del juego **en marcha**, no del que monta un runner |
| "el arma flotaba 13 px sobre la cabeza" | captura real del juego y rectángulos medidos en vivo |

## Las piezas

| pieza | dónde | qué es |
| --- | --- | --- |
| addon del editor | `addons/godot_mcp/` (74 ficheros, 600 KB, MIT) | servidor websocket `127.0.0.1:6550` dentro del editor + plugin de depurador |
| plugin activado | `project.godot` → `[editor_plugins]` | sin esto el addon no arranca |
| autoload del puente | `project.godot` → `autoload/MCPGameBridge` | el lado del juego; se comunica por el protocolo del depurador |
| servidor MCP local | `.opencode/opencode.json` | `npx -y @satelliteoflove/godot-mcp`; expone las 21 herramientas `godot_*` |

Versión del addon instalada: **4.1.11** (`godot_version_min="4.5"`). Requisitos:
Godot 4.5+ (usamos 4.7.2), Node 20+ (usamos 24).

## Arrancarlo

El servidor MCP lo levanta OpenCode solo al leer `.opencode/opencode.json`. Lo que
hay que levantar a mano es **el editor**, que es quien sirve el puente:

```bash
export LC_ALL=C LANG=C

# 1. Pantalla virtual: el editor necesita una. Una vez por sesión de trabajo.
Xvfb :99 -screen 0 1280x1024x24 &
export DISPLAY=:99

# 2. El editor, que abre el puente.
godot --editor --path /workspaces/Baracoa_City --rendering-driver opengl3 \
  >/tmp/opencode/godot-editor.log 2>&1 &

# 3. Comprobar que escucha (tarda ~20 s en arrancar).
ss -ltn | grep 6550
tail -2 /tmp/opencode/godot-editor.log
#   [godot-mcp] Plugin initialized
#   [godot-mcp] Server listening on 127.0.0.1:6550 [Localhost]
```

En una máquina con pantalla de verdad los pasos 1 y 2 sobran: se abre Godot y ya.

Si algo no conecta, `godot_project {action: "addon_status"}` dice si el addon y el
servidor están sincronizados, y `godot_project {action: "check_stale"}` avisa si
`project.godot` cambió en disco después de que el editor lo leyera (el editor nunca
lo relee solo: hace falta `godot_editor_edit {action: "restart"}`).

## Usarlo

Las herramientas leen (`godot_*_read`, `godot_project`, `godot_resource`) o
escriben. El bucle que importa es congelar → preparar → avanzar → observar:

```text
godot_editor_edit {action: "run", frozen: true}      # arranca con el reloj parado en el fotograma 0
godot_exec        {action: "run", source: "..."}     # escenario: dar el arma, mover al jugador…
godot_game_time   {action: "step", duration_ms: 300, inputs: [{action_name: "move_right", duration_ms: 300}]}
godot_runtime_state {action: "digest"}               # estado como datos, sin gastar visión
godot_editor_read {action: "screenshot_game"}        # solo cuando haya que juzgar ASPECTO
```

Medido en la comprobación de esta instalación: un `step` de 300 ms dio **30
fotogramas y 19 ticks de física** (≈96 fps y ≈61 Hz de tiempo de juego), inyectó
`move_right` y movió al jugador de `(200, 200)` a `(225.06, 200.43)`. O sea: el
tiempo de juego va desacoplado de los fps reales, que es justo lo que `xvfb` no
daba.

Aviso de coste: **una captura no se borra nunca** del contexto; cada fotograma
sigue ahí en los turnos siguientes. Para estructura y estado, leer texto
(`godot_node_read`, `godot_runtime_state`) sale casi gratis y una imagen no.

## Dos trampas medidas

### 1. El autoload va SIN `*`, y equivocarse deja las suites en verde

El addon registra `autoload/MCPGameBridge="res://addons/godot_mcp/game_bridge/mcp_game_bridge.gd"`
**sin** el `*` que llevan los demás autoloads del proyecto. No es un descuido. Con
`*`, Godot registra un singleton global llamado `MCPGameBridge`, y el script declara
`class_name MCPGameBridge`: el choque hace que el script no compile y el autoload no
se instancie.

Lo grave es cómo se veía. Con el `*` puesto:

```
SCRIPT ERROR: Parse Error: Class "MCPGameBridge" hides an autoload singleton.
ERROR: Failed to instantiate an autoload, script ... does not inherit from 'Node'.
```

y **las seis suites en verde** (6/6, 16/16, 22/22, 29/29, 9/9) con el puente
completamente muerto. Es la regla de siempre: un `SCRIPT ERROR` por consola no es
una suite verde. La comprobación de que el puente vive de verdad es preguntárselo
al juego en marcha:

```text
godot_exec {action: "run", source: 'return str(tree.root.get_node_or_null("MCPGameBridge") != null)'}
# -> bridge=true process_mode=3
```

Y en el log del editor, `[godot-mcp] Game bridge initialized` seguido de
`[godot-mcp] Game bridge: ready to drive`.

### 2. El plugin reescribe `project.godot` al arrancar

`plugin.gd`, en `_enter_tree()`, llama a `ProjectSettings.save()` (y añade el
autoload si falta). Es una escritura que ocurre en **cada** arranque del editor y
que no se puede evitar desde fuera. Consecuencias reales sobre el fichero:

- **Los comentarios se pierden.** Se fueron `; Proyecto: Baracoa — Mundo Abierto
  Pixelado Online` y `; Fase 0 (FOUNDATION). Ver docs/architecture/ARCHITECTURE.md`;
  Godot escribe su cabecera canónica. Volver a ponerlos no sirve: se borran otra vez
  en el arranque siguiente. La documentación vive en `AGENTS.md`, no en
  `project.godot`.
- **Desaparecen las líneas que igualan el valor por defecto**, porque `save()`
  escribe solo lo que difiere de Godot: se fueron
  `physics/common/physics_ticks_per_second=60`,
  `rendering/anti_aliasing/quality/msaa_2d=0` y
  `display/window/stretch/aspect="keep"`. Comprobado leyendo los valores efectivos
  tras el cambio: siguen siendo **60**, **0** y **"keep"**. Ninguna cambia el
  comportamiento; el fichero queda en su forma canónica y ya no vuelve a moverse.

Lo que **no** cambia: no es un fichero en `scripts/`, así que
`test_script_integrity.gd` no lo mira, y sus 30 `class_name MCP*` no chocan con
nada del proyecto. El puente es inerte cuando el juego no lo lanza el editor
(`if not EngineDebugger.is_active(): return`), así que los runners headless
siguen igual.

## Límites

- **El editor tiene que estar vivo.** El puente vive en el editor; si se cierra,
  las herramientas dejan de responder.
- **Un cliente a la vez.** Un editor sirve a un solo cliente MCP; un subagente que
  herede la configuración hace cola en vez de robar la sesión.
- **Bajo `xvfb` el render es `llvmpipe`** (software, 2 CPUs en esta máquina): va
  lento y el audio cae al driver dummy. Los avisos `libasound`/`libpulse` y el
  `V-Sync mode` no son nuestros.
- **El puente no sustituye a las suites.** Sigue haciendo falta la red de
  `tests/`, sobre todo `startup_runner`; esto añade la comprobación de lo que se ve
  y de lo que pasa en el tiempo, que es donde estaban los fallos.
