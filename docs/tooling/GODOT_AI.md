# godot-ai: construir dentro del editor

El segundo puente. `docs/tooling/GODOT_MCP.md` es el que **juega** el juego (reloj
congelado, input inyectado, estado en vivo). Éste es el que **construye**: escenas,
nodos, scripts, recursos, UI, temas, materiales, animaciones, partículas, cámaras,
tilemaps, autoloads, input map y settings.

| | godot-mcp (`satelliteoflove`) | godot-ai (`hi-godot`) |
| --- | --- | --- |
| para qué | jugar y observar | construir y editar |
| herramienta estrella | `step` con input y reloj de juego congelado | `batch_execute`, `script_patch`, `ui_manage` |
| transporte | websocket `127.0.0.1:6550` dentro del propio editor | `attach` por stdio → servidor Python → websocket `9500` |
| version | addon/server 4.1.11 | addon/server 4.3.0 |
| herramientas | 21 | 47 |

Los dos conviven y ven **el mismo juego en marcha** (medido: con el juego lanzado,
godot-mcp contesta `godot_mcp_bridge=true godot_ai_helper=true` y godot-ai reporta
`is_playing=true, helper_live=true`).

## Las piezas

| pieza | dónde | qué es |
| --- | --- | --- |
| addon | `addons/godot_ai/` (313 ficheros, 3,2 MB) | plugin del editor + helper del juego |
| plugin activado | `project.godot` → `[editor_plugins]` | junto al de godot-mcp |
| autoload del juego | `project.godot` → `_mcp_game_helper` | servidor de capturas del juego por el depurador |
| servidor Python | lo arranca el plugin (`uvx`) | MCP por `http://127.0.0.1:8000` + WS `9500` |
| cliente | `.opencode/opencode.json` | entrada `godot-ai` por stdio con `attach` |

Requisitos: Godot **4.7+** (usamos 4.7.2) y **`uv`** (`uv`/`uvx` 0.13.1, en
`~/.local/bin`).

## Instalarlo desde cero (verificado)

El release trae dos zips y **el nombre engaña**: `godot-ai-plugin.zip` es el
**migrador** v3→v4 (lleva dentro el plugin bueno y el viejo). Para una instalación
nueva el archivo es `godot-ai-v4-plugin.zip`, firmado con
`godot-ai-v4-plugin.manifest.json` + `.manifest.sig`.

```bash
V=4.3.0
BASE=https://github.com/hi-godot/godot-ai/releases/download/v$V
mkdir -p /tmp/opencode/godot-ai && cd /tmp/opencode/godot-ai
for f in godot-ai-v4-plugin.zip godot-ai-v4-plugin.manifest.json godot-ai-v4-plugin.manifest.sig; do
  curl -sSLO "$BASE/$f"
done
unzip -qo godot-ai-v4-plugin.zip -d v4

# 1. el manifest contra el zip: sha256 del archivo y huella de los 313 ficheros
python3 - <<'PY'
import json, hashlib, zipfile
m = json.load(open('godot-ai-v4-plugin.manifest.json'))
z = zipfile.ZipFile('godot-ai-v4-plugin.zip')
data = open('godot-ai-v4-plugin.zip','rb').read()
assert hashlib.sha256(data).hexdigest() == m['asset']['sha256']
assert z.namelist() == [r['path'] for r in m['inventory']]
for r in m['inventory']:
    b = z.read(r['path'])
    assert len(b) == r['size'] and hashlib.sha256(b).hexdigest() == r['sha256']
print('arbol y hashes: OK', len(m['inventory']), 'ficheros')
PY

# 2. la firma RSA del manifest, con la clave publica que trae el addon
python3 - <<'PY'
import re
src = open('v4/addons/godot_ai/utils/update_manager.gd').read()
pem = re.search(r'RELEASE_SIGNING_PUBLIC_KEY_PEM := """(.*?)"""', src, re.S).group(1)
open('relkey.pem', 'w').write(pem)
PY
openssl dgst -sha256 -verify relkey.pem \
  -signature godot-ai-v4-plugin.manifest.sig godot-ai-v4-plugin.manifest.json
# -> Verified OK

# 3. instalar
cp -r /tmp/opencode/godot-ai/v4/addons/godot_ai /workspaces/Baracoa_City/addons/
```

Resultado de esta instalación: sha256 OK, **313 ficheros coincidiendo uno a uno con
el inventario firmado**, y **firma RSA `Verified OK`** con la clave pública
`RELEASE_SIGNING_PUBLIC_KEY_PEM` de `addons/godot_ai/utils/update_manager.gd`.

Después: activar el plugin en `[editor_plugins]` y arrancar el editor (ver
`GODOT_MCP.md` para el `xvfb`). El plugin arranca el servidor Python solo.

## El comando del cliente (argv exacto)

**No vale un `http://127.0.0.1:8000/mcp` a pelo.** v4 usa `godot-ai attach` por
stdio con credenciales rotatorias; el README lo dice explícitamente: "a bare
`http://127.0.0.1:8000/mcp` entry cannot authenticate or follow capability
rotation". El argv lo construye `client_configurator.gd`
(`_resolve_attach_launch_uncached` + `UvResolution.args()`), y el que hay en
`.opencode/opencode.json` es ese mismo, con la versión fijada:

```jsonc
"godot-ai": {
  "type": "local",
  "command": [
    "uvx",
    "--isolated", "--no-config", "--no-env-file", "--no-sources", "--no-build",
    "--index-strategy", "first-index", "--keyring-provider", "disabled",
    "--index", "https://pypi.org/simple",
    "--default-index", "https://pypi.org/simple",
    "--find-links", "https://pypi.org/simple/godot-ai/",
    "--link-mode", "copy",
    "--from", "godot-ai==4.3.0",
    "godot-ai", "attach", "--port", "8000", "--ws-port", "9500",
    "--disable-telemetry"
  ],
  "enabled": true
}
```

Las banderas `--isolated --no-config --no-env-file --no-sources --no-build
--index*` no son adorno: impiden que un `UV_*` heredado o un fichero de
configuración de uv cambien **de dónde se descarga el paquete que luego se
ejecuta**. Se copian tal cual las escribe el plugin.

Aviso: el dock del plugin escribe su configuración en
`~/.config/opencode/opencode.json` (global). Aquí vive en el repo
(`.opencode/opencode.json`) para que sea reproducible, así que **el dock dirá que
no está configurado** aunque funcione. Es cosmético.

## Cómo se usa

```text
session_manage   {op: "list"}                 # qué editores hay conectados
editor_state     {}                           # escena abierta, ¿jugando?, ¿helper vivo?
scene_get_hierarchy / node_find / logs_read   # leer antes de tocar
script_patch / node_create / ui_manage / batch_execute
test_run                                      # lanza los tests del proyecto
```

Preferir las lecturas (`session_manage`, `editor_state`, `node_get_properties`,
`logs_read`) para orientarse y `batch_execute` para varios cambios de una vez.

## Tres detalles medidos

### El autoload va con `*`, y aquí sí es la forma correcta

`plugin.gd` escribe `autoload/_mcp_game_helper = "*res://addons/godot_ai/runtime/game_helper.gd"`
(línea 1287, con el comentario `"*" prefix = singleton`) y lo borra al desactivar
el plugin. **No choca** con su `class_name` porque `game_helper.gd` **no tiene
`class_name` a propósito** (lo dice su cabecera: "path, not class_name: this
autoload runs in the game process"). Es exactamente la trampa que nos costó cara
con `MCPGameBridge`, resuelta al revés. Si algún día se le añade un `class_name`,
vuelve el fallo silencioso.

Y no lo escribe cuando el editor va headless: `_mcp_disabled_for_headless_launch()`
mira `--headless` y `DisplayServer.get_name()`. Por eso `godot --headless --import`
no lo toca ni arranca el servidor.

### La telemetría se apaga por entorno, no por proyecto

`godot_ai/telemetry_enabled` es un **EditorSetting**, no un ajuste de proyecto, así
que no se puede fijar desde `project.godot`. Se apaga con
`GODOT_AI_DISABLE_TELEMETRY=true` en el proceso del editor **y**
`--disable-telemetry` en el argv del cliente, que es lo que el plugin espera
entonces. Comprobación en el log:

```
godot-ai-telemetry | Telemetry disabled
```

Si se toca después de configurar el cliente, hay que reconfigurarlo: el argv
generado cambia.

### `MCPDebuggerPlugin` y `McpDebuggerPlugin` sólo difieren en mayúsculas

godot-mcp nombra sus clases `MCP*` y godot-ai las suyas `Mcp*`. Hay **una**
coincidencia si se ignoran mayúsculas: `MCPDebuggerPlugin` / `McpDebuggerPlugin`.
Medido: Godot no avisa, los dos plugins cargan y las seis suites siguen en verde.
Es inocuo mientras ningún script escriba el nombre ambiguo; si algún día hace
falta referirse a uno, escribirlo con su mayúscula exacta.

## Límites

- **El editor tiene que estar vivo** (el servidor Python lo arranca y lo vigila él;
  `Orphan reaper armed for owner editor pid …`).
- Es **un proceso más** (Python/uvicorn) sobre 2 CPUs con render por software.
- **El primer comando tras lanzar el juego se agota** (medido dos veces: `exec` y
  `game_time step`); el segundo funciona. No es un fallo, es el arranque en frío
  bajo `llvmpipe`.
- El addon son **313 ficheros** en el repo; el autoload se referencia desde
  `project.godot`, así que tiene que estar versionado.
- `[NOT_AVAILABLE]`/avisos de `fastmcp 4.1.0` en el log los imprime el entorno de
  `uvx` del propio servidor, no el proyecto.
