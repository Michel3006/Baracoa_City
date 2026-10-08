class_name GameConfig
extends RefCounted

## Configuración centralizada del juego.
##
## Sección 28 de la especificación: ningún sistema debe leer números mágicos
## directamente. Todos los valores ajustables se concentran aquí y se pueden
## sobrescribir desde un archivo externo (`user://config.cfg`) sin recompilar.
##
## Dependencias: infrastructure/configuration

const CONFIG_PATH := "user://config.cfg"

# --- Presentación / coordenadas (sección 16) ---
const BASE_RESOLUTION := Vector2i(384, 216)
const WINDOW_SCALE := 3
const TILE_SIZE := 16
## Zoom de la cámara del mundo (sección 17). La ventana escala el viewport x3
## (`window/stretch/mode="viewport"`), así que en pantalla cada píxel de mundo ocupa
## 3 x CAMERA_ZOOM píxeles: solo los zooms enteros (3, 2, 1) dejan todos los píxeles
## con el mismo tamaño. Con 1 la cámara enseña los 384x216 px de la resolución base
## con escala 3x; bajar de 1 enseñaría más mapa, pero con píxeles de tamaños
## desiguales y un personaje más pequeño de lo que ya es.
const CAMERA_ZOOM := 1.0

# --- Jugador ---
## Velocidad de caminar, en píxeles de mundo por segundo. Es el valor con el que se
## juega: el `PlayerView` lo toma de aquí y el presentador se lo pasa al
## `MovementController`. Antes la vista traía el suyo (110) y ganaba, así que este
## 60 no era el que movía al jugador.
const PLAYER_SPEED := 110.0
const PLAYER_MAX_HEALTH := 100
const PLAYER_MAX_STAMINA := 100
const PLAYER_START_STAMINA := 100.0
const PLAYER_MAX_DEFENSE := 0
const PLAYER_BASE_DAMAGE := 5
## Nº de casillas del inventario: una por objeto distinto, con las pilas hasta el
## `max_stack` de cada objeto.
const PLAYER_INVENTORY_CAPACITY := 20

# --- Objetos (secciones 12 y 13) ---
## Nombres visibles de los objetos del MVP. Los valores de las armas (daño,
## alcance, cooldown) no se repiten aquí: el objeto de arma apunta al `Weapon`
## correspondiente y solo el catálogo de armas decide cuánto pega.
const ITEM_STONE_NAME := "Piedra"
const ITEM_KNIFE_NAME := "Cuchillo"
const ITEM_BERRY_NAME := "Baya"

# --- Combate ---
const DEFAULT_ATTACK_COOLDOWN := 0.45
const INVULNERABILITY_TIME := 0.6
## Duración del estado ATTACKING: el jugador queda comprometido durante la Recuperacion.
##
## 0.23 s no es un número redondo: es el puñetazo izquierdo del pack Hormelz
## (15 fotogramas a 68 fps = 0.2206 s) con un pizco de margen, y la prueba de
## arranque exige que el estado dure 13/60 = 0.2167 s sin llegar a 0.2467 s.
## Si cambia el clip de `ATTACK`, cambia este número: `tests/unit/test_actor_sprite`
## compara los dos contra la misma fórmula.
const ATTACK_RECOVERY := 0.23
## Fracción del cooldown durante la que la hitbox está activa. El golpe se registra
## en un instante concreto, no durante todo el cooldown.
const HITBOX_ACTIVE_RATIO := 0.35
## Aturdimiento al recibir daño.
const HURT_STUN_TIME := 0.25
## Geometría de la hitbox: círculo desplazado hacia delante, para que el golpe
## alcance lo que tiene delante y no lo que tiene detrás.
const HITBOX_RADIUS_RATIO := 0.45
const HITBOX_FORWARD_RATIO := 0.55
## Stamina recuperada por segundo y espera tras el último gasto.
const PLAYER_STAMINA_REGEN := 18.0
const STAMINA_REGEN_DELAY := 0.4

# --- Combate sin arma (puños) ---
## El jugador siempre puede golpear a puños, tenga o no arma en la mano. Es un
## "arma" degenerada: sin textura, sin durabilidad y con el alcance de un brazo.
const WEAPON_UNARMED_NAME := "Puños"
const WEAPON_UNARMED_DAMAGE := 3.0
const WEAPON_UNARMED_RANGE := 12.0
const WEAPON_UNARMED_COOLDOWN := 0.3
const WEAPON_UNARMED_STAMINA := 2.0
## Los puños no se rompen: `max_durability` a 0 desactiva el desgaste.
const WEAPON_UNARMED_DURABILITY := 0

# --- Armas (sección 7: solo piedra y cuchillo en el MVP) ---
const WEAPON_STONE_NAME := "Piedra"
const WEAPON_STONE_DAMAGE := 5.0
const WEAPON_STONE_RANGE := 20.0
const WEAPON_STONE_COOLDOWN := DEFAULT_ATTACK_COOLDOWN
const WEAPON_STONE_STAMINA := 4.0
const WEAPON_STONE_DURABILITY := 40

const WEAPON_KNIFE_NAME := "Cuchillo"
const WEAPON_KNIFE_DAMAGE := 9.0
const WEAPON_KNIFE_RANGE := 15.0
const WEAPON_KNIFE_COOLDOWN := 0.28
const WEAPON_KNIFE_STAMINA := 6.0
const WEAPON_KNIFE_DURABILITY := 60

# --- Mundo ---
const WORLD_ZONE_SIZE := Vector2i(64, 64)
const PLAYER_SPAWN := Vector2(200, 200)

# --- Presentacion de actores (seccion 25: los placeholders dan paso a sprites) ---
## Qué visual usa el jugador (especificación de personas, sección 18): el pack
## Hormelz por defecto, con hoja propia por orientación y los doce golpes del
## combate dibujados. Son los ids de `ActorVisualCatalog`; el catálogo resuelve
## el alias `PLAYER` con este valor. Cambiarlo a `&"player_human"` o
## `&"player_ninja"` vuelve a las hojas clásicas de rejilla sin tocar nada más.
const PLAYER_VISUAL: StringName = &"player_hormelz"
## Lado de un frame de personaje. El pack de sprites usa 16x16, el mismo tamano
## que el tile del mapa, asi que un personaje ocupa exactamente un tile de ancho.
const ACTOR_FRAME_SIZE := 16
## Filas de una hoja de caminar del pack: abajo, izquierda, arriba, derecha.
##
## OJO: es la unica convencion del pack que no se puede deducir de los pixeles, y
## las hojas laterales son imagenes especulares la una de la otra. Si al jugar el
## personaje lateral del pack mira al reves, basta con intercambiar
## `ACTOR_ROW_SIDE` y `ACTOR_ROW_SIDE_MIRRORED`. El humano de bit-era no usa estas
## filas: su hoja las ordena distinto ([lateral de pie, frente, derecha, espalda])
## y el mapeo vive en su `CharacterVisualDefinition` (`walk_row`, `row_side`,
## `row_up`, `row_side_mirrored`, `mirror_side`) en `ActorVisualCatalog`.
const ACTOR_ROW_DOWN := 0
const ACTOR_ROW_SIDE := 1
const ACTOR_ROW_UP := 2
const ACTOR_ROW_SIDE_MIRRORED := 3
## Fotogramas por ciclo de caminata, y segundos entre cada uno.
const ACTOR_WALK_FRAMES := 4
const ACTOR_WALK_FPS := 8.0
## Fotogramas por ciclo de golpe y segundos entre cada uno.
##
## Los cuatro fotogramas tienen que caber dentro de `ATTACK_RECOVERY`, que es lo que
## el actor está bloqueado después de pegar. A 14 fps el arco duraba 0.29 s contra los
## 0.22 s de recuperación de entonces, así que el último fotograma nunca se veía. Hoy
## la recuperación es 0.23 y esta ruta clásica sigue cabiendo (4/20 = 0.20 s); hay un
## test que lo comprueba contra `ATTACK_RECOVERY`.
const ACTOR_ATTACK_FRAMES := 4
const ACTOR_ATTACK_FPS := 20.0
## Desplazamiento en vertical del sprite respecto a los pies, en pixeles. El
## origen del nodo esta en los pies: el cuerpo se dibuja hacia arriba.
const ACTOR_SPRITE_OFFSET := Vector2(0.0, -8.0)
## Hojas de efecto de golpe: cuatro fotogramas CUADRADOS de 32x32 en una sola fila.
##
## OJO: el fotograma mide 32x32, no 16x32. La hoja del pack es de 128x32 y el pack
## trae su `Preview.gif` jugando las cuatro celdas de 32 px de izquierda a derecha:
## comprobado fotograma a fotograma, coincide al 100 %. Recortada en celdas de 16 px
## cada fotograma real se parte por la mitad, y la animacion sale como un arco, una
## cola suelta, la mitad de otro arco y asi: un parpadeo que no da ningun error porque
## ningun numero esta mal, solo el dibujo. Hay un test que comprueba la rejilla y que
## ningun fotograma se queda vacio.
const FX_FRAME_WIDTH := 32
const FX_FRAME_HEIGHT := 32
const FX_FRAMES := 4
## Fotogramas por segundo del arco. Con cuatro fotogramas salen 0.222 s, que es
## prácticamente lo que dura la pose de golpe (`ATTACK_RECOVERY`): la barre mientras
## el cuerpo barre y se va al terminar. Si se toca `ATTACK_RECOVERY` o `FX_FPS` hay
## que revisarlo, que hay un test que compara las dos cosas (margen: 0.222 contra
## 0.23 de recuperación, ratio 0.97).
const FX_FPS := 18.0
## Punto de anclaje del efecto, medido desde el centro del cuerpo y por delante, en la
## dirección del golpe.
##
## El arco gira alrededor de su centro, así que lo que decide la animación es dónde
## cae ese centro. Está sobre el centro del torso, que esta `ACTOR_SPRITE_OFFSET` por
## encima de los pies, y `FX_ORIGIN_OFFSET` px por delante: media altura del cuerpo
## (8) más 6 px de holgura. Con el centro en los pies el arco lateral salía a media
## altura de las piernas y el de arriba se metía encima de la cabeza; con esta regla
## el arco queda centrado en el torso en las cuatro direcciones y sin pisar el
## cuerpo, medido contra el sprite real. Hay un test.
const FX_ORIGIN_OFFSET := 14.0
## Z del efecto de golpe: por encima del mundo y del NPC, por debajo del HUD.
const FX_Z_INDEX := 8

## Golpe a puños: el brazo y el puño se dibujan por código sobre la pose
## direccional del cuerpo (`PunchArm`).
##
## Por qué existe: la fila de ataque de la hoja del humano es un puñetazo de
## perfil dibujado hacia la derecha, así que al golpear mirando abajo o arriba el
## cuerpo se giraba a perfil y el puño salía hacia los lados mientras la hitbox
## iba al frente. A puños el cuerpo se queda en su pose de la orientación y el
## brazo sale hacia donde se mira, con las dos manos alternadas (jab y cruz).
##
## Las fases son fracciones de `ATTACK_RECOVERY` (0.23 s ≈ 14 fotogramas de
## física) y reparten los fotogramas así: guardia 1, carga 2, extensión 3,
## impacto sostenido 3 y retorno 4. El orden es el de un puñetazo real.
##
## La extensión termina en `PUNCH_THRUST_END` = 0.45, antes de que cierre la
## ventana de hitbox (0.3 s de cooldown sin arma x 0.35 de `HITBOX_ACTIVE_RATIO`
## sobre 0.23 s = 0.497): el puño está salido cuando se registra el golpe, nunca
## al revés.
const PUNCH_GUARD_END := 0.08
const PUNCH_WINDUP_END := 0.22
const PUNCH_THRUST_END := 0.45
const PUNCH_IMPACT_END := 0.68
## Alcance visual del puño, en píxeles, medido desde el centro del torso en la
## dirección del golpe. Es la misma referencia que usa el arco
## (`FX_ORIGIN_OFFSET`, que sale del centro del torso) y el mismo número que
## `WEAPON_UNARMED_RANGE`: la punta del puño llega hasta donde llegan los puños.
##
## Como el centro del torso está 8 px sobre los pies, la fórmula reparte lo que
## toca en cada orientación sin que nadie lo decida a mano: 12 px por arriba (el
## puño acaba por encima de la cabeza, que llega hasta y = -16), 4 px por abajo
## (por debajo de los pies) y 12 px a los lados. Medido contra el sprite.
const PUNCH_REACH := 12.0
## Ancho de la banda del brazo y lado del puño, en píxeles. Los dos valen 4
## porque la hoja dibuja los guantes de 3 px: un brazo más estrecho deja ver el
## guante de la pose quieta por debajo.
const PUNCH_LIMB_WIDTH := 4.0
const PUNCH_FIST_SIZE := 4.0
## Avance del cuerpo durante la extensión y el impacto, en píxeles. Un paso de
## plantón al pegar: solo en esas dos fases, para que el retroceso del retorno
## también se note.
const PUNCH_BODY_SHIFT := 1.0

# --- NPC (seccion 18) ---
## Interruptor de enemigos. En `false` el juego arranca con la zona despejada: no se
## crea el director, ni los agentes, ni sus cuerpos en pantalla.
##
## Es lo que se usa para probar el movimiento y el mapa sin que seis enemigos
## persiguiendo al jugador se confundan con que el jugador no se mueve: el aturdimiento
## al recibir un golpe congela el movimiento, y con el mapa lleno parece un fallo de
## los WASD cuando en realidad es la IA. Ponerlo en `true` devuelve los enemigos.
##
## Vive aquí y no en `Game` porque es contenido del juego, no cableado: cualquier
## ajuste del MVP va en `GameConfig` (sección 28). Los tests de NPC no lo consultan:
## ellos montan su propia zona (ver `npc_combat_runner._ensure_npcs()`), así que esta
## bandera puede estar apagada sin que la suite pierda nada.
const NPC_ENABLED := true
## Cada cuanto se reparte el objetivo entre los enemigos. Solo reparta, no mueve ningun
## reloj, asi que puede ir a su aire sin tocar el ritmo de la IA.
##
## No puede depender solo de que el jugador se mueva: quieto en mitad de un nido de
## enemigos se quedaba sin que nadie lo persiguiera, porque el reparto era una
## consecuencia del movimiento. Diez veces por segundo basta: la IA vuelve a mirar su
## radio de deteccion en cada fotograma de fisica.
const NPC_TARGET_REFRESH := 0.1
## Numero de enemigos que aparecen en la zona de prueba.
const NPC_SPAWN_COUNT := 6
## Distancia a la que un NPC se da cuenta del jugador.
const NPC_AGGRO_RADIUS := 70.0
## Distancia a la que un NPC deja de perseguirlo (vuelve a lo que hacía).
const NPC_LEASH_RADIUS := 130.0
## Radio deambulacion en reposo, y segundos entre cambios de destino.
const NPC_WANDER_RADIUS := 28.0
const NPC_WANDER_INTERVAL := 2.5
## Los NPC pasean mas despacio de lo que persiguen: correr sin motivo delata que
## es un enemigo y rompe la lectura de la escena.
const NPC_WANDER_SPEED_RATIO := 0.45
## Angulo que gira el destino de paseo en cada salto. El numero dorado reparte los
## puntos mejor que un aleatorio, y al ser fijo da siempre el mismo mapa.
const NPC_WANDER_GOLDEN_ANGLE := 2.39996
## Por debajo de esta proporcion de vida el NPC huye en vez de seguir peleando.
const NPC_FLEE_HEALTH_RATIO := 0.25
## Invulnerabilidad tras recibir un golpe: evita que dos NPCs peguen en el mismo
## frame y que el jugador muera de un solo golpe.
const NPC_INVULNERABILITY_TIME := 0.35
## Aturdimiento del NPC al recibir dano.
const NPC_HURT_STUN_TIME := 0.2
## Estatico de danio y alcance del golpe cuerpo a cuerpo de un NPC debil.
const NPC_WEAK_DAMAGE := 4.0
const NPC_WEAK_HEALTH := 24.0
const NPC_WEAK_RANGE := 13.0
const NPC_WEAK_COOLDOWN := 0.9
const NPC_WEAK_SPEED := 26.0
const NPC_WEAK_DEFENSE := 0.0
## Lo mismo, para un enemigo tougher.
const NPC_STRONG_DAMAGE := 8.0
const NPC_STRONG_HEALTH := 48.0
const NPC_STRONG_RANGE := 15.0
const NPC_STRONG_COOLDOWN := 1.2
const NPC_STRONG_SPEED := 34.0
const NPC_STRONG_DEFENSE := 2.0
## Tinte propio de cada tipo de enemigo.
##
## Los cuatro enemigos son personas: la misma hoja que el jugador, la misma
## animacion de golpe y la misma muerte. Lo que los distingue en pantalla, ademas
## del nombre, es el color de la ropa, y ese color sale de multiplicar aqui el
## `modulate` del cuerpo. El tinte es el de reposo: encima manda el rojo de la
## invulnerabilidad, el violeta del aturdimiento y el gris de la muerte.
##
## Ninguno de los cuatro es el rojo de `HURT_TINT` ni el violeta de `STUN_TINT`:
## un enemigo de color propio no puede confundirse con "acabo de recibir un golpe"
## ni con "estoy aturdido". Se eligieron los cuatro sobre la paleta real de la
## hoja (negro de contorno, verde palido de ropa, blanco de piel): el `modulate`
## multiplica, así que nunca enciende un canal que la hoja no tiene y el contorno
## sigue siendo negro.
const NPC_TINT_VANDAL := Color("ff9a3d")
const NPC_TINT_ROBBER := Color("5aa8ff")
const NPC_TINT_BRUTE := Color("7fe06b")
const NPC_TINT_GANGSTER := Color("ffe14d")

# --- HUD (seccion 8) ---
## Tamano de las barras de vida y stamina, y margenes respecto a la pantalla.
const HUD_BAR_SIZE := Vector2(48, 4)
const HUD_BAR_MARGIN := Vector2(4, 4)
const HUD_BAR_GAP := 2
## Alto del icono del arma y tinte de pantalla mientras el jugador esta sin vida.
const HUD_WEAPON_SIZE := Vector2(6, 11)
const HUD_DOWN_TINT := 0.28
## Tinte del cuerpo mientras dura la invulnerabilidad: el sprite entero se tiñe de
## este rojo al recibir un golpe. Es la mitad visible del feedback de daño junto al
## arco del atacante: sin él, que te peguen solo se nota en la barra de vida, que a
## 384x216 es mover cuatro píxeles. Lo comparten el jugador y los enemigos, así que
## va aquí y no dentro de ninguna de las dos vistas.
const HURT_TINT := Color("ff6b6b")
## Tinte del cuerpo mientras dura el aturdimiento, distinto del rojo de la
## invulnerabilidad. Un golpe deja al ser aturdido (unos decimas) y luego rojo
## (lo que quede de la ventana): los dos estados se leen al instante sin confundirse.
## Si se apagara el rojo mientras dura el aturdimiento, un golpe aturdidor pasaría
## sin tinte hasta el final de la ventana.
const STUN_TINT := Color("a78bfa")

# --- Inventario (UI, seccion 13) ---
## Rejilla de la mochila. Las casillas son cuadradas; el numero de filas sale de la
## capacidad (`INVENTORY_COLS` por capacidad), asi que cambiar la capacidad no deja
## la rejilla descuadrada.
const INVENTORY_COLS := 5
const INVENTORY_SLOT := 14
const INVENTORY_GAP := 2
const INVENTORY_PAD := 4
## Altura de la zona del titulo del panel, sobre la rejilla.
const INVENTORY_HEADER := 10
## Textos del panel. Son contenido, no cableado: viven aqui como los nombres de los
## objetos.
const INVENTORY_TITLE := "MOCHILA"
## Colores del panel: fondo y borde, casilla, y los dos anillos de estado.
const INVENTORY_BG := Color(0.07, 0.1, 0.09, 0.96)
const INVENTORY_BORDER := Color(0.35, 0.45, 0.4, 1.0)
const INVENTORY_SLOT_BG := Color(0.12, 0.16, 0.14, 1.0)
const INVENTORY_SELECTED := Color("f0c05a")
const INVENTORY_EQUIPPED := Color("7cf0a8")
const INVENTORY_TEXT := Color("d9e6df")
const INVENTORY_OVERLAY := Color(0.0, 0.0, 0.0, 0.5)

# --- Muerte y reaparición (sección 8) ---
## Tiempo tras morir hasta que el botón de revivir hace algo. Sin espera, un botón
## mantenido devolvería la vida al instante y se perdería la lectura de qué pasó.
const RESPAWN_DELAY := 1.0
## Texto de la pantalla de muerte. Se dibuja con la mini fuente de píxeles del
## proyecto, no con la del sistema: la del sistema sale borrosa a 384x216.
const HUD_DEATH_TEXT := "CAIDO"
const HUD_DEATH_HINT := "E PARA REVIVIR"

# --- Networking (Fase 2) ---
const SERVER_PORT := 27015
const MAX_PLAYERS := 16
const SERVER_BIND_ADDRESS := "127.0.0.1"

# --- Logging ---
const DEFAULT_LOG_LEVEL := 1 # 0=DEBUG 1=INFO 2=WARNING 3=ERROR

static var _overrides: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = ConfigFile.new().parse(file.get_as_text())
	file.close()
	if parsed is ConfigFile:
		var config := parsed as ConfigFile
		for section in config.get_sections():
			for key in config.get_section_keys(section):
				_overrides["%s/%s" % [section, key]] = config.get_value(section, key)


## Devuelve el valor de configuración, priorizando el override externo.
static func get_value(key: String, default: Variant) -> Variant:
	_ensure_loaded()
	return _overrides.get(key, default)


static func get_int(key: String, default: int) -> int:
	return int(get_value(key, default))


static func get_float(key: String, default: float) -> float:
	return float(get_value(key, default))


static func get_vector2(key: String, default: Vector2) -> Vector2:
	return get_value(key, default)


## Sobrescribe un valor en memoria. No persiste en disco.
static func set_override(key: String, value: Variant) -> void:
	_ensure_loaded()
	_overrides[key] = value


## Descarta todos los overrides. Usado por los tests.
static func clear_overrides() -> void:
	_ensure_loaded()
	_overrides.clear()


# --- Accesos tipados de uso frecuente ---

static func player_speed() -> float:
	return get_float("gameplay/player_speed", PLAYER_SPEED)


static func tile_size() -> int:
	return get_int("world/tile_size", TILE_SIZE)


static func log_level() -> int:
	return get_int("logging/level", DEFAULT_LOG_LEVEL)