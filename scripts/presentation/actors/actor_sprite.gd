class_name ActorSprite
extends Sprite2D

## Reproductor de animaciones para las hojas de sprites del pack (sección 25).
##
## Sustituye a los personajes dibujados a mano con rectángulos. No decide nada de
## juego: solo traduce un nombre de animación y una orientación a un fotograma de
## la hoja. Ni el estado, ni la vida, ni el daño se tocan aquí.
##
## ## Cómo es una hoja
##
## Las hojas del pack son rejillas de cuadros de `GameConfig.ACTOR_FRAME_SIZE`
## (16x16). `Sprite2D` hace el recorte con `hframes` y `vframes`, así que aquí no
## hay ni un solo `AtlasTexture` que mantener.
##
## Las hojas de caminar ocupan cuatro filas, una por orientación. La mayoría (las
## del pack) las tienen en el orden que fija `GameConfig.ACTOR_ROW_*`: abajo, un
## lateral, arriba y el otro lateral. Una hoja ajena (el humano de bit-era) puede
## ordenarlas distinto, y entonces la definición visual decide cada fila. Los
## fotogramas de una animación concreta son las **columnas**.
##
## ## Tres tipos de clip
##
## - `directional`: la fila sale de la orientación, así que el mismo clip se ve
##   mirando a las cuatro direcciones. Es lo que usa caminar.
## - fila fija: la animación solo existe mirando al frente, como el golpe. Se dibuja
##   siempre en su fila y se refleja en horizontal cuando el actor mira a un lado.
## - hoja por orientación (`sheets`): la definición trae un ARCHIVO distinto por
##   dirección con el arte ya dibujado para ella (sin espejos) y una línea de planta
##   por dirección. Entonces no hay filas que recortar: el fotograma es la celda
##   lineal de la hoja, el espejo nunca se usa y el desplazamiento vertical sale de
##   los pies del clip para que la línea de planta toque el origen del nodo. Así
##   funciona el pack Hormelz (`HormelzVisualData`).
##
## ## El pie del actor
##
## El origen del nodo está en los pies, no en el centro del cuadro: los cuerpos se
## dibujan hacia arriba desde ahí. Por eso el sprite va desplazado hacia arriba lo
## que mide medio cuadro (`GameConfig.ACTOR_SPRITE_OFFSET` en la rejilla clásica, o
## medio alto de celda menos la línea de planta en una hoja por orientación).
##
## Dependencias: presentation, infrastructure/configuration

## Fotogramas por ciclo de caminata.
const WALK := &"walk"
## Un único fotograma de la fila de la orientación: el actor parado.
const IDLE := &"idle"
## Golpe cuerpo a cuerpo. Se reproduce una vez y deja al actor en su último frame.
const ATTACK := &"attack"
## Lo que queda al morir.
const DEAD := &"dead"

## Nombres de animación que este reproductor conoce. Permite validar un nombre
## antes de reproducirlo y avisar en vez de quedarse en silencio.
const KNOWN_CLIPS: Array[StringName] = [WALK, IDLE, ATTACK, DEAD]


## ¿Este clip es un golpe?
##
## El genérico `ATTACK` o el de cualquier ataque del catálogo: la vista elige el
## del ataque concreto si la hoja lo trae, así que una comprobación que solo
## mirara `ATTACK` no vería un cuerpo clavado en `left_jab` — que es el fallo
## que se quiere cazar cuando se pregunta esto.
static func is_attack_clip(clip: StringName) -> bool:
	return clip == ATTACK or AttackCatalog.has_animation(clip)

## Hoja de la que se recortan los fotogramas.
var sheet_path: String = ""
## Clips definidos para esta hoja. Lo rellena `configure()`.
var clips: Dictionary = {}

## Lado de la celda actual: ancho y alto, porque las hojas horneadas no son
## cuadradas (42x44) y la rejilla clásica sí (16x16).
var _frame_width: int = GameConfig.ACTOR_FRAME_SIZE
var _frame_height: int = GameConfig.ACTOR_FRAME_SIZE
## Centro del torso que fija la definición aplicada (o el de la hoja clásica).
var _torso: Vector2 = GameConfig.ACTOR_SPRITE_OFFSET

var _clip: StringName = &""
var _elapsed: float = 0.0
var _facing: Vector2 = Vector2.DOWN
var _playing: bool = false

## Filas de las cuatro orientaciones para los clips direccionales, en coordenadas
## absolutas de la hoja. Las hojas del pack las traen en 0/1/2/3; la definición
## del humano de bit-era las tiene en 1 (frente), 2 (laterales) y 3 (espalda).
var _row_down: int = GameConfig.ACTOR_ROW_DOWN
var _row_side: int = GameConfig.ACTOR_ROW_SIDE
var _row_up: int = GameConfig.ACTOR_ROW_UP
var _row_side_mirrored: int = GameConfig.ACTOR_ROW_SIDE_MIRRORED
## La hoja solo camina hacia la derecha y la izquierda sale de reflejarla.
var _mirror_side: bool = false
## Golpe alterno: un puñetazo con un brazo y el siguiente con el otro.
var _alternate_attack: bool = false
var _attack_parity: bool = false


func _ready() -> void:
	centered = true
	offset = GameConfig.ACTOR_SPRITE_OFFSET
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if clips.is_empty():
		define_defaults()


## Carga la hoja y define los clips estandar de un actor que camina en cuatro
## direcciones.
##
## `walk_row` es la fila de la orientación de abajo y `attack_row` la del golpe; la
## del golpe puede ser otra fila (una hoja con una tira de ataque aparte) o la misma
## que la de abajo si la hoja no trae ataque dibujado. Es el camino clásico, sin
## definición: los actores del catálogo pasan por `apply_definition()`, que lee lo
## mismo pero hoja a hoja desde `ActorVisualCatalog`.
func configure(
	path: String,
	walk_row: int = GameConfig.ACTOR_ROW_DOWN,
	attack_row: int = -1
) -> void:
	sheet_path = path
	var sheet: Texture2D = load(path) as Texture2D
	if sheet == null:
		GameLogger.warning("No se pudo cargar la hoja %s" % path, "ActorSprite")
		return
	texture = sheet
	_frame_width = GameConfig.ACTOR_FRAME_SIZE
	_frame_height = GameConfig.ACTOR_FRAME_SIZE
	_apply_grid(sheet, _frame_width, _frame_height)
	define_defaults(walk_row, attack_row)


## Carga la hoja y los clips de una definición visual (sección 8 de la
## especificación de personas).
##
## La definición decide filas, fotogramas y velocidad por personaje: el humano
## ataca en la fila 5 con tres fotogramas y muere en una pose fija de la fila 4,
## el ninja ataca en la 4 con cuatro y cae en la fila de la orientación. Los
## enemigos usan la definición del humano, así que comparten todo esto con el
## jugador: la hoja es la que obliga, y aquí no se decide nada más.
func apply_definition(def: CharacterVisualDefinition) -> bool:
	if def == null or def.sheet.is_empty():
		GameLogger.warning("Definición visual vacía", "ActorSprite")
		return false
	sheet_path = def.sheet
	var sheet: Texture2D = load(def.sheet) as Texture2D
	if sheet == null:
		GameLogger.warning("No se pudo cargar la hoja %s" % def.sheet, "ActorSprite")
		return false
	texture = sheet
	_frame_width = def.frame_size
	_frame_height = def.cell_height()
	_apply_grid(sheet, _frame_width, _frame_height)
	_row_down = def.walk_row
	_row_side = def.row_side
	_row_up = def.row_up
	_row_side_mirrored = def.row_side_mirrored
	_mirror_side = def.mirror_side
	_alternate_attack = def.alternate_attack
	_attack_parity = false
	_torso = def.torso_offset
	if def.sheet_clips.is_empty():
		# Rejilla clásica: filas y columnas del recorte de siempre.
		offset = GameConfig.ACTOR_SPRITE_OFFSET
		clips = {
			WALK: {
				"row": def.walk_row,
				"frames": def.walk_frames,
				"fps": def.walk_fps,
				"loop": true,
				"directional": true,
			},
			IDLE: {
				"row": def.walk_row,
				"frames": 1,
				"fps": 1.0,
				"loop": true,
				"directional": true,
			},
			ATTACK: {
				"row": def.attack_row,
				"frames": def.attack_frames,
				"fps": def.attack_fps,
				"loop": false,
				"directional": false,
			},
			DEAD: {
				"row": def.dead_row,
				"column": def.dead_column,
				"frames": 1,
				"fps": 1.0,
				"loop": true,
				"directional": def.dead_directional,
			},
		}
		_refresh()
		return true
	# Hoja por orientación: cada clip trae sus cuatro archivos, sus fotogramas
	# y su línea de planta. La definición sigue poniendo el resto de datos
	# (fila del golpe, muerte) por si algo los consulta, pero el dibujo de
	# estos clips no pasa por filas.
	clips = def.sheet_clips.duplicate(true)
	# Estado inicial: el clip de reposo de la orientación con la que arranca el
	# actor (abajo), que es además la hoja representativa de la definición.
	var initial := clips.get(IDLE, clips.get(ATTACK, {})) as Dictionary
	if not initial.is_empty():
		_sync_sheet(initial)
	_refresh()
	return true


## ¿Este nombre de clip se puede reproducir en la hoja actual?
##
## Los clips de hoja por orientación amplían el vocabulario más allá de los
## cuatro estándar (`KNOWN_CLIPS`), y quien lanza un ataque quiere saber si su
## animación existe antes de pedirla.
func has_clip(name: StringName) -> bool:
	return clips.has(name)


## Centro del torso de esta definición, en coordenadas del nodo. Lo usan los
## presentadores para situar el arco de golpe a la altura del hombro del actor
## que se dibuja de verdad, no de una hoja genérica.
func torso_offset() -> Vector2:
	return _torso


## Recorta la hoja en una rejilla de cuadros del tamaño que diga la hoja.
## Los personajes del pack usan `GameConfig.ACTOR_FRAME_SIZE`; una hoja futura
## (personas reales) puede traer otra rejilla y la trae en su definición. `frame_height`
## es 0 cuando la celda es cuadrada; las hojas horneadas miden 44 de alto con 42
## de ancho y hay que dividir cada eje por su medida, no redondear la división
## cruzada (con celdas suficientemente altas daría una fila de más).
func _apply_grid(
	sheet: Texture2D,
	frame_size: int = GameConfig.ACTOR_FRAME_SIZE,
	frame_height: int = 0
) -> void:
	var w := float(maxi(1, frame_size))
	var h := float(maxi(1, frame_height if frame_height > 0 else frame_size))
	var size := sheet.get_size()
	hframes = maxi(1, int(round(size.x / w)))
	vframes = maxi(1, int(round(size.y / h)))


## Clips que espera una hoja de actor con caminar en cuatro direcciones.
##
## El golpe son cuatro fotogramas en su propia fila. La hoja del jugador tiene
## exactamente esa disposicion: cuatro filas de caminar, despues el golpe.
func define_defaults(walk_row: int = GameConfig.ACTOR_ROW_DOWN, attack_row: int = -1) -> void:
	_row_down = walk_row
	_row_side = GameConfig.ACTOR_ROW_SIDE
	_row_up = GameConfig.ACTOR_ROW_UP
	_row_side_mirrored = GameConfig.ACTOR_ROW_SIDE_MIRRORED
	_mirror_side = false
	_alternate_attack = false
	_attack_parity = false
	var strike := attack_row if attack_row >= 0 else walk_row + 4
	clips = {
		WALK: {
			"row": walk_row,
			"frames": GameConfig.ACTOR_WALK_FRAMES,
			"fps": GameConfig.ACTOR_WALK_FPS,
			"loop": true,
			"directional": true,
		},
		IDLE: {
			"row": walk_row,
			"frames": 1,
			"fps": 1.0,
			"loop": true,
			"directional": true,
		},
		ATTACK: {
			"row": strike,
			"frames": GameConfig.ACTOR_ATTACK_FRAMES,
			"fps": GameConfig.ACTOR_ATTACK_FPS,
			"loop": false,
			"directional": false,
		},
		DEAD: {
			"row": walk_row,
			"frames": 1,
			"fps": 1.0,
			"loop": true,
			"directional": true,
		},
	}
	_refresh()


## Reproduce una animación. Devuelve `true` si ha cambiado algo.
##
## Volver a pedir la animación que ya suena no reinicia el ciclo: si el codigo de
## arriba llama a `play(WALK)` en cada fotograma de física, la caminata no
## reiniciaria el paso a cada frame.
func play(name: StringName, restart: bool = false) -> bool:
	if not clips.has(name):
		GameLogger.warning("Clip desconocido: %s" % name, "ActorSprite")
		return false
	if _clip == name and _playing and not restart:
		return false
	if name == ATTACK and _alternate_attack:
		# Un golpe nuevo alterna de mano. Solo cambia el dibujo: ni daño, ni
		# alcance, ni reloj. El puño sale siempre hacia donde se mira (de lado no
		# se refleja en golpes alternos: la hoja solo tiene un puño).
		_attack_parity = not _attack_parity
	_clip = name
	_elapsed = 0.0
	_playing = true
	_refresh()
	return true


func stop() -> void:
	_playing = false


func is_playing(name: StringName) -> bool:
	return _playing and _clip == name


func current_clip() -> StringName:
	return _clip


## Orientacion del actor. Solo afecta a los clips direccionales.
func set_facing(facing: Vector2) -> void:
	if facing.is_zero_approx() or facing.is_equal_approx(_facing):
		return
	_facing = facing
	_refresh()


func facing() -> Vector2:
	return _facing


func _process(delta: float) -> void:
	if not _playing or delta <= 0.0:
		return
	var clip := clips.get(_clip, {}) as Dictionary
	var frames := int(clip.get("frames", 1))
	var fps := float(clip.get("fps", 1.0))
	if frames <= 1 or fps <= 0.0:
		return
	_elapsed += delta * fps
	# El recorte se actualiza en cada fotograma, no solo cuando se cierra un ciclo
	# entero. Convolver primero y decidir despues si toca refrescar dejaba el primer
	# medio segundo de caminata con la misma pose, porque hasta entonces no hay
	# ningun cambio de fotograma que dibujar.
	if _elapsed >= float(frames):
		if bool(clip.get("loop", false)):
			# `fposmod` guarda el sobrante en vez de tirarlo, asi que un `delta` grande
			# no hace que el ciclo se salte fotogramas.
			_elapsed = fposmod(_elapsed, float(frames))
		else:
			# Una animacion que no se repite se queda en su ultimo fotograma: es lo
			# que hace que el golpe se vea entero en vez de parpadear.
			_elapsed = float(frames) - 1.0
			_playing = false
	_refresh()


## Vuelca el estado actual en el `frame` del `Sprite2D`.
func _refresh() -> void:
	if texture == null or not clips.has(_clip):
		return
	var clip := clips[_clip] as Dictionary
	if clip.has("sheets"):
		# Hoja por orientación: el recorte es la celda lineal de la hoja que
		# toca, y el archivo lo decide la orientación.
		_sync_sheet(clip)
		var cells := maxi(1, hframes * vframes)
		var sheet_frames := clampi(maxi(1, int(clip.get("frames", 1))), 1, cells)
		frame = clampi(int(_elapsed), 0, sheet_frames - 1)
		flip_h = false
		return
	var row := int(clip.get("row", 0))
	if bool(clip.get("directional", false)):
		row = _direction_row()
	var frames := maxi(1, int(clip.get("frames", 1)))
	var column := int(clip.get("column", 0))
	if frames > 1:
		column += clampi(int(_elapsed), 0, frames - 1)
	column = mini(column, maxi(0, hframes - 1))
	frame = clampi(row * maxi(1, hframes) + column, 0, maxi(0, hframes * vframes - 1))
	_apply_flip(clip)


## Carga la hoja de la orientación actual de un clip con `sheets` si no es la que
## ya está puesta, y recoloca el desplazamiento para que la línea de planta del
## clip quede en el origen del nodo.
##
## Sin espejos que calcular: cada dirección tiene su arte, así que `flip_h` no
## entra aquí (lo pone `_refresh`, que siempre lo deja en `false` para esta
## rama).
func _sync_sheet(clip: Dictionary) -> void:
	var sheets := clip.get("sheets", {}) as Dictionary
	if sheets.is_empty():
		return
	var direction := _dir_number()
	var path := str(sheets.get(direction, sheets.get(8, "")))
	if path.is_empty():
		return
	if path != sheet_path:
		var loaded := load(path) as Texture2D
		if loaded == null:
			GameLogger.warning("No se pudo cargar la hoja %s" % path, "ActorSprite")
			return
		texture = loaded
		sheet_path = path
		_apply_grid(loaded, _frame_width, _frame_height)
	var feet := clip.get("feet", {}) as Dictionary
	var ground := int(feet.get(direction, feet.get(8, _frame_height)))
	offset = Vector2(0.0, float(_frame_height) * 0.5 - float(ground))


## Número de dirección del pack para la orientación actual: el mismo esquema que
## los nombres de archivo (`dir2` izquierda, `dir4` arriba, `dir6` derecha,
## `dir8` abajo), el de las ocho direcciones clásicas sin los diagonales.
func _dir_number() -> int:
	if _facing.y > 0.0:
		return 8
	if _facing.y < 0.0:
		return 4
	if _facing.x < 0.0:
		return 2
	return 6


## Un clip direccional ya trae las cuatro orientaciones en sus propias filas, así
## que solo se refleja cuando la hoja no trae el lateral de la izquierda dibujado
## (el humano de bit-era camina solo hacia la derecha y la izquierda es el espejo).
## Uno de fila fija (el golpe) solo existe mirando al frente. De frente o de
## espaldas el puñetazo se ve con las dos manos, así que cada golpe nuevo se
## refleja (alterna de mano) y los dos salen hacia donde se mira. De lado la hoja
## solo guarda UN puño (el frame de impacto es asimétrico): reflejarlo en golpes
## alternos mandaría medio golpe hacia atrás, así que el puño sale siempre hacia
## donde se mira — izquierda reflejada, derecha tal cual — y es lo único que se
## dibuja; la dirección del golpe la llevan la hitbox y el arco de efecto, que van
## hacia la orientación.
func _apply_flip(clip: Dictionary) -> void:
	if bool(clip.get("directional", false)):
		flip_h = _mirror_side and _facing == Vector2.LEFT
		return
	if _alternate_attack and _clip == ATTACK and is_zero_approx(_facing.x):
		# De frente (o de espaldas, misma fila fija) se ven las dos manos: alterna.
		flip_h = _attack_parity
		return
	# De lado (o un actor que no alterna) el puño va hacia la orientación, y la
	# muerte fija del humano también se refleja solo mirando a la izquierda.
	flip_h = _facing.x < 0.0


## Fila absoluta de la hoja en la que se dibuja la orientación actual.
func _direction_row() -> int:
	if _facing.y < 0.0:
		return _row_up
	if _facing.y > 0.0:
		return _row_down
	if _facing.x < 0.0:
		return _row_side
	return _row_side_mirrored