extends RefCounted

## Pruebas del reproductor de animaciones y del catálogo de hojas (sección 25).
##
## Aquí se prueba la parte que más se rompe en silencio: el recorte. Una hoja mal
## dividida no da ningún error, da un personaje que camina con las piernas de la fila
## de arriba, y eso solo se ve jugando. Por eso se comprueba número a número qué
## fotograma de la rejilla toca cada orientación y cada animación.
##
## No hace falta escena: `Sprite2D` se puede configurar y consultar fuera del árbol, y
## `_process` se llama a mano para no depender de la tasa de fotogramas.

## Hojas del pack con su rejilla esperada, para detectar de un vistazo si un archivo
## se sustituye por otro de tamaño distinto.
const SHEETS := {
	# El jugador activo es la persona del Hormelz horneada: la hoja de reposo
	# mirando abajo mide 252x264, que en celdas de 42x44 son 6x6. Las celdas no
	# son cuadradas, por eso esta entrada trae ancho y alto; las clásicas siguen
	# siendo de 16 px y no los traen. Los enemigos no tienen hoja propia: usan la
	# del Hormelz, y eso lo comprueba `_enemy_attack_row` en vez de repetir aquí
	# la misma entrada.
	"jugador": [
		"res://assets/characters/humans/hormelz_melee/Idle1/Boxer__Idle1_dir8.png",
		6, 6, 42, 44,
	],
	"humano": ["res://assets/characters/human_player.png", 4, 8],
	"ninja": ["res://assets/characters/ninja_blue.png", 4, 7],
	# La hoja del efecto mide 128x32, que en celdas de 16 px son 8x2. Ojo: esa no es
	# su rejilla de dibujo (son cuatro fotogramas de 32x32, que lo comprueba
	# `_fx_grid`), aquí solo se fija que el archivo siga midiendo lo que mide.
	"golpe": ["res://assets/fx/slash.png", 8, 2],
}

## Los cuatro tipos de enemigo, que comparten hoja y definición con la persona.
const NPC_KINDS: Array[StringName] = [
	NpcKind.VANDAL, NpcKind.ROBBER, NpcKind.BRUTE, NpcKind.GANGSTER,
]

## Fotograma de física con el que se avanza el tiempo en las pruebas de animación.
## Se usa uno real y no un múltiplo exacto de la duración de un fotograma, porque en
## el juego el `delta` nunca lo es, y una animación que solo funciona con deltas
## justos es una animación que se ve a saltos.
const STEP := 1.0 / 60.0

## Las cuatro direcciones de golpe, que son las que el juego usa.
const FX_DIRECTIONS := {
	"derecha": Vector2.RIGHT,
	"izquierda": Vector2.LEFT,
	"arriba": Vector2.UP,
	"abajo": Vector2.DOWN,
}

## Reproductores creados en el caso que se está ejecutando.
var _alive: Array[ActorSprite] = []


## Un reproductor configurado con la hoja del jugador, sin meterlo en el árbol.
func _sprite() -> ActorSprite:
	return _prepared(ActorVisualCatalog.PLAYER)


## Un reproductor con la hoja de un actor del catálogo.
func _prepared(kind: StringName) -> ActorSprite:
	var sprite := ActorSprite.new()
	_alive.append(sprite)
	ActorVisualCatalog.apply_to(kind, sprite)
	return sprite


## Lo llama el runner después de cada caso. Un `Sprite2D` sin liberar se queda con su
## textura y Godot avisa de fugas al salir, que es un error por consola como cualquier
## otro: la suite no puede dejarlo pasar.
func teardown() -> void:
	for sprite: ActorSprite in _alive:
		if is_instance_valid(sprite):
			sprite.free()
	_alive.clear()


## Fotograma absoluto que le toca a un actor mirando en una dirección.
func _frame_facing(sprite: ActorSprite, clip: StringName, facing: Vector2) -> int:
	sprite.set_facing(facing)
	return sprite.frame


## La fila de la rejilla en la que está el fotograma actual.
func _row(sprite: ActorSprite) -> int:
	return sprite.frame / maxi(1, sprite.hframes)


func register() -> Array:
	return [
		["las hojas del pack tienen la rejilla esperada", _sheet_grids],
		["el catálogo da hoja a cada actor", _catalog_sheets],
		["el jugador activo es la persona y el ninja queda de fallback", _player_visuals],
		["la muerte del humano es una pose fija de la hoja", _human_dead_is_fixed],
		["caminar usa la fila de la orientación", _walk_rows],
		["el golpe no cambia de fila al mirar de lado", _attack_row_is_fixed],
		["el golpe alterna de brazo en golpes seguidos", _attack_alternates_arms],
		["caminar avanza de fotograma con el tiempo", _walk_advances],
		["el golpe no se repite y para en el último", _attack_stops_at_end],
		["repetir la misma animación no la reinicia", _replay_is_noop],
		["un clip desconocido no cambia nada", _unknown_clip],
		["un enemigo golpea con la misma fila que el jugador", _enemy_attack_row],
		["cada tipo de enemigo lleva su tinte de paleta", _enemy_tints],
		["el efecto de golpe es una fila de cuatro, y ninguno vacío", _fx_grid],
		["el arco dura lo que dura el golpe", _fx_duration],
		["el arco se ancla en el torso y sale por delante", _fx_origin],
		["ninguna hoja se lee fuera de la rejilla", _frames_stay_in_grid],
		["la mano cae sobre el cuerpo en las cuatro direcciones", _hand_on_body],
	]


## Si alguien sustituye la hoja del jugador (la persona) o la del ninja por otra
## imagen de otro tamaño, esta prueba lo dice con el nombre de la hoja en vez de
## dejar un actor recortado en pedazos.
func _sheet_grids(ctx: ScriptTestContext) -> void:
	for label: String in SHEETS:
		var expected: Array = SHEETS[label]
		var path: String = expected[0]
		if not ctx.check(ResourceLoader.exists(path), "falta la hoja de %s" % label):
			continue
		var sheet := load(path) as Texture2D
		if not ctx.check(sheet != null, "la hoja de %s no carga" % label):
			continue
		# La celda puede traer ancho y alto distintos (las horneadas del Hormelz
		# miden 42x44); quien no los trae sigue siendo cuadrada de 16 px. Cada
		# eje se divide por SU medida: redondear la división cruzada con celdas
		# bastante altas daría una fila de más.
		var cell_w := float(
			expected[3] if expected.size() > 3 else GameConfig.ACTOR_FRAME_SIZE
		)
		var cell_h := float(
			expected[4] if expected.size() > 4 else int(cell_w)
		)
		ctx.check_equal(
			int(round(sheet.get_size().x / cell_w)),
			expected[1],
			"columnas de la hoja de %s" % label
		)
		ctx.check_equal(
			int(round(sheet.get_size().y / cell_h)),
			expected[2],
			"filas de la hoja de %s" % label
		)


func _catalog_sheets(ctx: ScriptTestContext) -> void:
	for id: StringName in ActorVisualCatalog.ids():
		var path := ActorVisualCatalog.sheet_of(id)
		ctx.check(not path.is_empty(), "el actor %s tiene hoja" % id)
		ctx.check(
			ResourceLoader.exists(path), "la hoja del actor %s existe (%s)" % [id, path]
		)
	# Un tipo de enemigo que no exista en el catálogo no puede acabar con un actor sin
	# dibujo: tiene que avisar y devolver vacío, no reventar.
	ctx.check(ActorVisualCatalog.sheet_of(&"dragon").is_empty(), "hoja de un actor desconocido")
	ctx.check(
		not ActorVisualCatalog.apply_to(&"dragon", null), "no se prepara un actor inexistente"
	)


## El jugador activo es la persona del Hormelz (hoja propia por orientación, con
## veinticuatro clips medidos del pack), y el humano y el ninja clásicos se
## conservan enteros como fallback: las tres definiciones existen y las tres
## hojas cargan. Si alguien quitara un clásico, esta prueba lo dice.
func _player_visuals(ctx: ScriptTestContext) -> void:
	var active: StringName = ActorVisualCatalog.active_player()
	ctx.check_equal(active, GameConfig.PLAYER_VISUAL, "el alias PLAYER resuelve al visual activo")
	ctx.check(
		active in [
			ActorVisualCatalog.PLAYER_HORMELZ,
			ActorVisualCatalog.PLAYER_HUMAN,
			ActorVisualCatalog.PLAYER_NINJA,
		],
		"el visual activo es una definición conocida"
	)
	var human := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HUMAN)
	var ninja := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_NINJA)
	var hormelz := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HORMELZ)
	ctx.check(human != null and not human.sheet.is_empty(), "la persona tiene definición")
	ctx.check(ninja != null and not ninja.sheet.is_empty(), "el ninja tiene definición")
	ctx.check(hormelz != null and not hormelz.sheet.is_empty(), "el Hormelz tiene definición")
	ctx.check_equal(human.sheet, "res://assets/characters/human_player.png", "hoja de la persona")
	ctx.check_equal(ninja.sheet, "res://assets/characters/ninja_blue.png", "hoja del ninja")
	ctx.check_equal(hormelz.sheet, HormelzVisualData.SHEET, "hoja representativa del Hormelz")
	# Los clips por orientación son la mitad que hace falta saber de una hoja
	# horneada: sin ellos el sprite no sabría qué archivo mirar en cada giro.
	ctx.check(not hormelz.sheet_clips.is_empty(), "el Hormelz trae sus clips")
	for id: StringName in [
		ActorVisualCatalog.PLAYER_HORMELZ,
		ActorVisualCatalog.PLAYER_HUMAN,
		ActorVisualCatalog.PLAYER_NINJA,
	]:
		var sprite := _prepared(id)
		ctx.check(
			sprite.texture != null, "el sprite de %s carga" % id
		)
		# La fila del golpe sale de la definición, no de una convención del pack:
		# la persona ataca en la fila 5, el ninja en la 4.
		ctx.check_equal(
			ActorVisualCatalog.attack_row_of(id),
			ActorVisualCatalog.definition_of(id).attack_row,
			"la fila del golpe de %s es la de su definición" % id
		)


## La persona no tiene fila de muerte direccional: muere en una pose fija de la
## hoja (yacente, fila 4 columna 2), igual en las cuatro orientaciones. El ninja
## seguía el otro camino (la pose quieta de la fila en la que mira), y esa
## diferencia es la que define la columna base del clip DEAD.
func _human_dead_is_fixed(ctx: ScriptTestContext) -> void:
	var sprite := _prepared(ActorVisualCatalog.PLAYER_HUMAN)
	var human := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HUMAN)
	ctx.check_equal(
		human.dead_directional, false, "la muerte de la persona no cambia con la orientación"
	)
	sprite.play(ActorSprite.DEAD, true)
	var expected := human.dead_row * sprite.hframes + human.dead_column
	for facing: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		sprite.set_facing(facing)
		ctx.check_equal(
			sprite.frame, expected,
			"muere en la misma pose mirando a %s (frame %d)" % [facing, expected]
		)
	ctx.check(
		expected < sprite.hframes * sprite.vframes,
		"la pose de la muerte cae dentro de la rejilla (%dx%d)" % [
			sprite.hframes, sprite.vframes
		]
	)
	# El fallback (ninja) no se lee vacío: su muerte es la fila de la orientación.
	var ninja := _prepared(ActorVisualCatalog.PLAYER_NINJA)
	ninja.play(ActorSprite.DEAD, true)
	ninja.set_facing(Vector2.UP)
	ctx.check_equal(
		_row(ninja), GameConfig.ACTOR_ROW_UP,
		"el ninja sigue muriendo en la fila en la que mira"
	)


## El corazón del recorte. Caminar es direccional, así que cada orientación tiene que
## caer en su fila: si las dos laterales estuvieran intercambiadas, el personaje
## caminaría de espaldas sin que nada fallara.
##
## El humano no usa el orden del pack (abajo, izquierda, arriba, derecha): su hoja
## trae [lateral de pie, frente, derecha, espalda] y la definición mapea frente=1,
## laterales=2 y espalda=3. La izquierda sale de reflejar el lateral de la derecha
## (`mirror_side`), así que izquierda y derecha comparten fila y se distinguen por
## el espejo. El ninja conserva el orden clásico, sin espejos.
func _walk_rows(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER)
	if def.sheet_clips.is_empty():
		_walk_rows_grid(ctx, sprite, def)
	else:
		_walk_rows_sheet(ctx, sprite, def)
	# El ninja sigue con el orden del pack sin reflejo: la regresión lo comprueba.
	var ninja := _prepared(ActorVisualCatalog.PLAYER_NINJA)
	ninja.play(ActorSprite.WALK, true)
	ctx.check_equal(
		_frame_facing(ninja, ActorSprite.WALK, Vector2.LEFT),
		GameConfig.ACTOR_ROW_SIDE * ninja.hframes,
		"el ninja usa la fila lateral del pack"
	)
	ctx.check_equal(ninja.flip_h, false, "y el ninja no refleja su lateral")


## Rama de rejilla clásica: filas por orientación, espejos cuando tocan.
func _walk_rows_grid(
	ctx: ScriptTestContext, sprite: ActorSprite, def: CharacterVisualDefinition
) -> void:
	sprite.play(ActorSprite.WALK, true)
	ctx.check_equal(
		_frame_facing(sprite, ActorSprite.WALK, Vector2.DOWN),
		def.walk_row * sprite.hframes,
		"abajo (el frente de la hoja)"
	)
	ctx.check_equal(
		_frame_facing(sprite, ActorSprite.WALK, Vector2.UP),
		def.row_up * sprite.hframes,
		"arriba (la espalda de la hoja)"
	)
	if def.mirror_side:
		ctx.check_equal(
			_frame_facing(sprite, ActorSprite.WALK, Vector2.LEFT),
			def.row_side * sprite.hframes,
			"la izquierda comparte fila con la derecha (el lateral dibujado)"
		)
		ctx.check_equal(
			sprite.flip_h, true, "y se refleja: la hoja solo camina hacia la derecha"
		)
		ctx.check_equal(
			_frame_facing(sprite, ActorSprite.WALK, Vector2.RIGHT),
			def.row_side_mirrored * sprite.hframes,
			"la derecha es la misma fila lateral"
		)
		ctx.check_equal(sprite.flip_h, false, "y sale sin reflejar")
	else:
		ctx.check_equal(
			_frame_facing(sprite, ActorSprite.WALK, Vector2.LEFT),
			def.row_side * sprite.hframes,
			"un lado"
		)
		ctx.check_equal(
			_frame_facing(sprite, ActorSprite.WALK, Vector2.RIGHT),
			def.row_side_mirrored * sprite.hframes,
			"el otro lado"
		)
		ctx.check_equal(sprite.flip_h, false, "caminar nunca se refleja: cada fila ya es la suya")


## Rama de hoja por orientación (el Hormelz): no hay filas ni espejos, pero sí
## cuatro cosas que cuadrar con la convención de los nombres de archivo del pack
## (`_dir_number`): el archivo que se carga al girar, el primer fotograma al
## plantarse, y que el arte ya viene dibujado para esa dirección, así que `flip_h`
## queda en `false`.
func _walk_rows_sheet(
	ctx: ScriptTestContext, sprite: ActorSprite, def: CharacterVisualDefinition
) -> void:
	var sheets: Dictionary = def.sheet_clips[ActorSprite.WALK]["sheets"]
	ctx.check(sheets.size() >= 4, "el clip de caminar trae las cuatro direcciones")
	sprite.play(ActorSprite.WALK, true)
	for facing: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		_frame_facing(sprite, ActorSprite.WALK, facing)
		var path := sprite.texture.resource_path if sprite.texture != null else ""
		ctx.check(
			path.ends_with("_dir%d.png" % _dir_number(facing)),
			"caminar mirando a %s carga la hoja de su dirección (%s)" % [facing, path]
		)
		ctx.check_equal(
			sprite.frame, 0,
			"al plantarse mirando a %s empieza en su primer fotograma" % facing
		)
		ctx.check_equal(sprite.flip_h, false, "la hoja de %s no se refleja" % facing)


## El golpe del pack solo existe mirando al frente. Si la fila cambiara con la
## orientación, al golpear hacia arriba saldría el fotograma de andar de frente.
func _attack_row_is_fixed(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER)
	sprite.play(ActorSprite.ATTACK, true)
	var row := _row(sprite)
	for facing: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		sprite.set_facing(facing)
		ctx.check_equal(_row(sprite), row, "el golpe no cambia de fila mirando a %s" % facing)
		if not def.sheet_clips.is_empty():
			# En una hoja por orientación no hay fila que proteger (el golpe es la
			# celda 0 de su hoja, `attack_row` = 0), pero sí que se dibuje con el
			# arte de la dirección: otro archivo, sin espejos. Ese es el análogo
			# aquí de "la fila no cambia".
			var path := sprite.texture.resource_path if sprite.texture != null else ""
			ctx.check(
				path.ends_with("_dir%d.png" % _dir_number(facing)),
				"el golpe mirando a %s sale de su propia hoja (%s)" % [facing, path]
			)
			ctx.check_equal(sprite.flip_h, false, "y no se refleja mirando a %s" % facing)
	ctx.check_equal(
		row,
		ActorVisualCatalog.attack_row_of(ActorVisualCatalog.PLAYER),
		"y es la fila del golpe de la definición visual del jugador"
	)


## El golpe del humano es un puñetazo (la fila 5 de la hoja). De frente o de
## espaldas se ve con las dos manos: en golpes seguidos se refleja para salir con
## una mano y luego con la otra, siempre hacia donde se mira. De lado la hoja solo
## guarda UN puño (el frame de impacto es asimétrico), así que ahí no se refleja en
## golpes alternos — medio golpe saldría hacia atrás — y el puño sale siempre hacia
## la orientación (izquierda reflejada, derecha tal cual). Solo cambia el dibujo:
## daño, alcance y reloj son los mismos en cada golpe. El ninja no alterna: su
## barrido es un solo gesto fijo.
func _attack_alternates_arms(ctx: ScriptTestContext) -> void:
	var sprite := _prepared(ActorVisualCatalog.PLAYER_HUMAN)
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER_HUMAN)
	ctx.check(def.alternate_attack, "la definición de la persona alterna brazos")
	# De frente se ven las dos manos: cada golpe nuevo sale con la otra, y los dos
	# hacia donde se mira.
	sprite.set_facing(Vector2.DOWN)
	var flips: Array[bool] = []
	for _i: int in range(4):
		sprite.play(ActorSprite.ATTACK, true)
		flips.append(sprite.flip_h)
	ctx.check(
		flips[0] != flips[1],
		"dos golpes seguidos salen con la misma mano (flips %s)" % str(flips)
	)
	ctx.check_equal(flips[0], flips[2], "el tercer golpe vuelve a la primera mano")
	ctx.check_equal(flips[1], flips[3], "y el cuarto a la segunda")
	# De lado la hoja solo tiene un puño: el golpe sale siempre hacia donde se mira
	# y no alterna (alternar lo mandaría hacia atrás).
	sprite.set_facing(Vector2.LEFT)
	var left_flips: Array[bool] = []
	for _i: int in range(2):
		sprite.play(ActorSprite.ATTACK, true)
		left_flips.append(sprite.flip_h)
	ctx.check_equal(
		left_flips, [true, true],
		"a la izquierda el puño sale siempre hacia la izquierda (flips %s)" % str(left_flips)
	)
	sprite.set_facing(Vector2.RIGHT)
	ctx.check_equal(sprite.flip_h, false, "a la derecha el puño sale tal cual, sin reflejar")
	# El ninja no alterna: sus dos golpes son idénticos.
	var ninja := _prepared(ActorVisualCatalog.PLAYER_NINJA)
	ninja.play(ActorSprite.ATTACK, true)
	ninja.set_facing(Vector2.DOWN)
	var ninja_flip := ninja.flip_h
	ninja.play(ActorSprite.ATTACK, true)
	ctx.check_equal(ninja.flip_h, ninja_flip, "el ninja no alterna sus golpes")


## El ciclo de caminata tiene que pasar por los cuatro fotogramas y volver al
## principio. Con un `delta` de verdad, no con un múltiplo exacto de la duración de un
## fotograma: si el ciclo solo avanzara cuando el tiempo cae justo en el borde, en el
## juego se vería a saltos.
func _walk_advances(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	sprite.play(ActorSprite.WALK, true)
	sprite.set_facing(Vector2.DOWN)
	var base := sprite.frame

	# Cuántos fotogramas de física dura un ciclo entero de caminata. Se lee del
	# clip que suena de verdad, no de una constante global: la hoja activa trae
	# 24 fotogramas a 50 fps y la clásica, los suyos de `GameConfig`, y el ciclo
	# tiene que cuadrar con cualquiera de las dos.
	var walk: Dictionary = sprite.clips[ActorSprite.WALK]
	var walk_frames := int(walk.get("frames", 1))
	var walk_fps := float(walk.get("fps", 1.0))
	var cycle := int(ceil(float(walk_frames) / walk_fps / STEP))
	var columns: Array[int] = []
	for _frame: int in range(cycle):
		sprite._process(STEP)
		columns.append(sprite.frame)
	ctx.check(sprite.is_playing(ActorSprite.WALK), "sigue andando")

	# Un ciclo entero tiene que pasar por todos los fotogramas de la fila y volver al
	# primero. No se comprueba fotograma a fotograma contra un número exacto porque los
	# deltas de verdad van CON.step y el acumulador se queda unas centesimas por debajo
	# del borde: eso retrasa un fotograma un frame y no se ve, pero haria fallar una
	# comparación exacta todos los dias.
	var visited: Array[int] = []
	for value: int in columns:
		if not visited.has(value - base):
			visited.append(value - base)
	visited.sort()
	ctx.check_equal(
		visited, range_array(walk_frames),
		"ha pasado por los %d fotogramas del clip" % walk_frames
	)
	ctx.check(
		absi(sprite.frame - base) <= sprite.hframes,
		"el ciclo ha vuelto al principio, no a mitad de la hoja"
	)
	ctx.check(
		sprite.frame - base < walk_frames,
		"y sin pasarse del último fotograma del clip"
	)


## El golpe no se repite. Si se repitiera, un ataque de N fotogramas se
## quedaría parpadeando mientras dure la ventana, y no se vería entero.
func _attack_stops_at_end(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	var clip: Dictionary = sprite.clips[ActorSprite.ATTACK]
	var attack_row := int(clip.get("row", 0))
	var attack_frames := int(clip.get("frames", 1))
	var attack_fps := float(clip.get("fps", 1.0))
	sprite.play(ActorSprite.ATTACK, true)
	var last := attack_row * sprite.hframes + attack_frames - 1
	# Se avanza el doble de lo que dura el golpe: tiene que quedarse quieto en el
	# último fotograma en vez de volver al principio.
	for _frame: int in range(int(attack_frames / attack_fps / STEP) * 2):
		sprite._process(STEP)
	ctx.check_equal(sprite.frame, last, "el golpe se queda en su último fotograma")
	ctx.check(not sprite.is_playing(ActorSprite.ATTACK), "y deja de reproducirse")
	# Y no vuelve solo a la caminata: eso lo decide quien lo llama.
	ctx.check_equal(sprite.current_clip(), ActorSprite.ATTACK, "sigue siendo el golpe")
	# Un fotograma de golpe no puede durar más que el clip entero: si no, se vería
	# siempre el primero. Se mira el clip real, no la constante global, porque cada
	# personaje puede traer su número de fotogramas.
	ctx.check(
		attack_frames / attack_fps <= GameConfig.ATTACK_RECOVERY,
		"el golpe (%.3f s) termina antes de que termine la recuperacion (%.3f s)" % [
			attack_frames / attack_fps, GameConfig.ATTACK_RECOVERY
		]
	)


## El código llama a `play()` en cada fotograma de física. Si eso reiniciara el ciclo,
## la caminata daría un paso y se volvería a poner en el primero, y el actor andaría
## temblando en el sitio.
func _replay_is_noop(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	sprite.play(ActorSprite.WALK, true)
	var down_frame := sprite.frame
	# Se avanza lo que miden un fotograma y medio del clip que suena: suficiente
	# para haber salido del primero, y no tanto como para haber vuelto a él. El
	# fps sale del clip, no de una constante: cada hoja camina al suyo.
	var walk: Dictionary = sprite.clips[ActorSprite.WALK]
	var walk_fps := float(walk.get("fps", 1.0))
	for _frame: int in range(
		maxi(1, int(ceil(1.5 / walk_fps / STEP)))
	):
		sprite._process(STEP)
	var advanced := sprite.frame
	ctx.check(
		advanced != down_frame,
		"el ciclo ha avanzado, está en %d" % advanced
	)
	ctx.check(not sprite.play(ActorSprite.WALK), "repetir la animación no devuelve nada")
	ctx.check_equal(sprite.frame, advanced, "y no reinicia el ciclo")
	ctx.check(sprite.play(ActorSprite.WALK, true), "pero reiniciarla sí, si se pide")
	ctx.check_equal(
		sprite.frame, down_frame, "vuelve al primero"
	)


## Un nombre mal escrito tiene que avisar y no cambiar lo que suena. Si no, un
## `&"attak"` se comería la animación entera sin que nadie se entere.
func _unknown_clip(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	sprite.play(ActorSprite.WALK, true)
	var before := sprite.frame
	ctx.check(not sprite.play(&"attak"), "un clip desconocido no se reproduce")
	ctx.check_equal(sprite.current_clip(), ActorSprite.WALK, "sigue sonando la anterior")
	ctx.check_equal(sprite.frame, before, "y el fotograma no se mueve")
	ctx.check(
		ActorSprite.KNOWN_CLIPS.has(ActorSprite.ATTACK), "el golpe es un clip conocido"
	)
	# La hoja activa amplía el vocabulario con sus clips de combate: el ataque
	# concreto tiene que existir para que quien lanza el golpe no caiga en
	# silencio al estándar.
	ctx.check(
		sprite.has_clip(ActorSprite.ATTACK), "el golpe es reproducible en la hoja activa"
	)
	if not ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER).sheet_clips.is_empty():
		for id: StringName in [&"left_jab", &"front_kick", &"roll_forward", &"hit_light"]:
			ctx.check(sprite.has_clip(id), "el clip %s existe en la hoja del jugador" % id)
		ctx.check(not sprite.has_clip(&"flamenco"), "y un clip inventado no existe")


## Los enemigos son personas: los cuatro tipos comparten hoja, definición y fila de
## ataque con el jugador activo, y su golpe no cambia de fila con la orientación.
##
## Este caso existía para los bichos del pack, que no traían fila de ataque y
## golpeaban con la pose de frente de su propia hoja. Hoy lo que hay que vigilar es
## lo contrario: que nadie deje a un tipo con la hoja vieja, con una hoja inventada
## o con una fila de ataque distinta de la del jugador. Se compara contra el visual
## ACTIVO (no contra la persona clásica): el enemigo y el jugador tienen que ser
## indistinguibles salvo por el tinte, vaya la hoja que vaya.
func _enemy_attack_row(ctx: ScriptTestContext) -> void:
	var active := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER)
	if not ctx.check(active != null, "el jugador activo tiene definición"):
		return
	for kind: StringName in NPC_KINDS:
		var sprite := _prepared(kind)
		if not _context_has_texture(sprite, kind, ctx):
			continue
		ctx.check_equal(
			ActorVisualCatalog.sheet_of(kind), active.sheet,
			"el enemigo %s usa la hoja del jugador" % kind
		)
		ctx.check_equal(
			ActorVisualCatalog.attack_row_of(kind), active.attack_row,
			"el enemigo %s golpea con la fila de ataque del jugador" % kind
		)
		sprite.play(ActorSprite.ATTACK, true)
		var row := _row(sprite)
		for facing: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
			sprite.set_facing(facing)
			ctx.check_equal(
				_row(sprite), row,
				"el golpe de %s no cambia de fila mirando a %s" % [kind, facing]
			)
			if not active.sheet_clips.is_empty():
				var path := sprite.texture.resource_path if sprite.texture != null else ""
				ctx.check(
					path.ends_with("_dir%d.png" % _dir_number(facing)),
					"el golpe de %s mirando a %s sale de su propia hoja" % [kind, facing]
				)
		ctx.check_equal(row, active.attack_row, "y esa fila es la del jugador")


## Los cuatro tipos comparten hoja, así que el color de la ropa es lo único que en
## pantalla dice quién es quién. Tiene que haber un color por tipo y ningún color
## que se confunda con un estado: un enemigo en reposo no puede parecer herido
## (rojo de la invulnerabilidad) ni aturdido (violeta).
func _enemy_tints(ctx: ScriptTestContext) -> void:
	var seen: Dictionary = {}
	for kind: StringName in NPC_KINDS:
		var tint := ActorVisualCatalog.tint_of(kind)
		seen[tint] = true
		ctx.check(
			not tint.is_equal_approx(Color.WHITE), "el %s tiene color propio" % kind
		)
		ctx.check(
			not tint.is_equal_approx(GameConfig.HURT_TINT)
			and not tint.is_equal_approx(GameConfig.STUN_TINT),
			"el tinte del %s no se confunde con el daño ni con el aturdimiento" % kind
		)
	ctx.check_equal(seen.size(), NPC_KINDS.size(), "los cuatro tintes son distintos")
	ctx.check_equal(
		ActorVisualCatalog.tint_of(&"dragon"), Color.WHITE,
		"un actor desconocido no se tiñe"
	)
	ctx.check_equal(
		ActorVisualCatalog.tint_of(ActorVisualCatalog.PLAYER), Color.WHITE,
		"el jugador va con su hoja y sin tinte"
	)


## Cualquier combinación de clip, orientación y tiempo tiene que dejar el fotograma
## dentro de la rejilla. Es la comprobacion de red de seguridad: si algo se sale, es
## que una fila o un numero de fotogramas se han inventado.
func _frames_stay_in_grid(ctx: ScriptTestContext) -> void:
	for kind: StringName in ActorVisualCatalog.ids():
		var sprite := _prepared(kind)
		if not _context_has_texture(sprite, kind, ctx):
			continue
		# Se recorren LOS CLIPS DE LA HOJA, no los cuatro estándar: una hoja por
		# orientación añade los doce golpes, las reacciones, las caídas y las
		# rodadas, y todos ellos tienen que caber en su rejilla. Recorrer solo
		# `KNOWN_CLIPS` dejaba sin probar medio combate.
		for clip: StringName in sprite.clips:
			for facing: Vector2 in [
				Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT
			]:
				sprite.set_facing(facing)
				sprite.play(clip, true)
				for _step: int in range(8):
					# Se avanza a saltos dispares, mayores que el clip entero, para
					# forzar el envoltura del ciclo y pillar el peor caso.
					sprite._process(0.25)
					ctx.check(
						sprite.frame >= 0
						and sprite.frame < sprite.hframes * sprite.vframes,
						"%s/%s mirando a %s se sale en %d (rejilla %dx%d)" % [
							kind,
							clip,
							facing,
							sprite.frame,
							sprite.hframes,
							sprite.vframes,
						]
					)


## Un actor cuya hoja no cargó no se puede probar de recorte: saltarse el caso en vez
## de contar miles de comprobaciones sobre una rejilla vacía.
func _context_has_texture(sprite: ActorSprite, kind: StringName, ctx: ScriptTestContext) -> bool:
	return ctx.check(
		sprite != null and sprite.texture != null, "el actor %s se prepara" % kind
	)


## Los numeros del 0 al `last` como `Array`, para comparar con la lista de fotogramas
## que ha ido visiting la caminata.
func range_array(last: int) -> Array[int]:
	var values: Array[int] = []
	for value: int in range(last):
		values.append(value)
	return values


## La rejilla de las hojas de efecto: una fila de fotogramas cuadrados.
##
## La hoja del pack mide 128x32 y su `Preview.gif` del pack juega las cuatro celdas
## de 32 px seguidas (comprobado fotograma a fotograma: coincide al 100 %). Recortada
## en celdas de 16 px no da ningún error: cada fotograma real se parte por la mitad y
## la animación sale como un arco, una cola suelta y media hoja en blanco, que es
## decir "parpadea" sin decir "falla". Por eso aquí se mide la hoja de verdad, y la
## comprobación fuerte es que ningún fotograma quede vacío: con la rejilla equivocada
## la mitad de los fotogramas no tienen ni un píxel.
##
## Se mide la hoja del arco, que es la misma para el jugador y para los enemigos:
## los dos son personas y golpean con lo mismo. Si algún día vuelve a haber una
## hoja por bando, aquí se añade.
func _fx_grid(ctx: ScriptTestContext) -> void:
	_fx_sheet_grid(ctx, SlashEffect.SHEET)


func _fx_sheet_grid(ctx: ScriptTestContext, path: String) -> void:
	if not ctx.check(ResourceLoader.exists(path), "falta la hoja del efecto (%s)" % path):
		return
	var sheet := load(path) as Texture2D
	if not ctx.check(sheet != null, "la hoja del efecto no carga (%s)" % path):
		return
	var width := GameConfig.FX_FRAME_WIDTH
	var height := GameConfig.FX_FRAME_HEIGHT
	ctx.check_equal(
		width, height, "el fotograma del efecto es cuadrado (%dx%d)" % [width, height]
	)
	ctx.check_equal(
		int(round(float(sheet.get_width()) / float(width))),
		GameConfig.FX_FRAMES,
		"la hoja %s se parte en %d fotogramas en horizontal" % [path, GameConfig.FX_FRAMES]
	)
	ctx.check_equal(
		int(round(float(sheet.get_height()) / float(height))),
		1,
		"y en una sola fila: la hoja no tiene una segunda tanda (%s)" % path
	)

	var image := sheet.get_image()
	var empty: Array[int] = []
	for column: int in range(GameConfig.FX_FRAMES):
		var painted := 0
		var left: int = column * width
		for y: int in range(mini(height, image.get_height())):
			for x: int in range(mini(width, maxi(0, image.get_width() - left))):
				if image.get_pixel(left + x, y).a > 0.05:
					painted += 1
		if painted == 0:
			empty.append(column)
	ctx.check(
		empty.is_empty(),
		"ningún fotograma de la hoja %s puede quedar vacío; vacíos: %s" % [path, empty]
	)


## La vida del efecto contra la duración de la pose de golpe.
##
## `FX_FRAMES / FX_FPS` es lo que tarda el arco en irse y `ATTACK_RECOVERY` lo que
## tarda el cuerpo en cerrar el golpe. Si el arco se alarga, el personaje vuelve a la
## pose de reposo con el rastro todavía barriendo en el aire; si se acorta, se corta
## el barrido por la mitad. Ninguna de las dos es un error de código: solo se ve, y
## por eso tiene que estar medida aquí.
func _fx_duration(ctx: ScriptTestContext) -> void:
	var life := float(GameConfig.FX_FRAMES) / GameConfig.FX_FPS
	var recovery := GameConfig.ATTACK_RECOVERY
	ctx.check(
		life <= recovery * 1.25,
		"el arco dura %.3f s y la pose %.3f s: el rastro se queda barriendo solo" % [
			life, recovery
		]
	)
	ctx.check(
		life >= recovery * 0.75,
		"el arco dura %.3f s y la pose %.3f s: el barrido se corta antes de tiempo" % [
			life, recovery
		]
	)


## El arco anclado en el torso y por delante del cuerpo, en las cuatro direcciones.
##
## El cuerpo se dibuja hacia arriba desde los pies y el arco gira sobre su centro. Con
## el centro en los pies el golpe lateral salía a la altura de las piernas y el de
## arriba se metía encima de la cabeza en vez de delante de ella: ninguna coordenada
## estaba mal, estaba mal el dibujo, que es la clase de fallo que solo se ve jugando.
##
## Por eso aquí no se comprueba una fórmula sino el resultado: se leen los píxeles de
## la hoja y los del personaje, se coloca el arco como lo coloca el juego (misma
## `origin_for`, misma rotación) y se mide dónde acaba respecto al cuerpo. Con la
## geometría vieja (anclada en los pies) este caso fallaba en las direcciones
## laterales y en la de arriba.
##
## Tolerancias: el centro del arco puede bailar 5 px respecto al del cuerpo, que la
## animación no está centrada fotograma a fotograma ni hace falta; pero el arco tiene
## que llegar 8 px por delante del cuerpo (media altura del actor) y no arrastrarse
## por detrás.
func _fx_origin(ctx: ScriptTestContext) -> void:
	var body_path: String = SHEETS["jugador"][0]
	var body := load(body_path) as Texture2D
	if not ctx.check(body != null, "falta la hoja del jugador para medir el cuerpo"):
		return
	var path: String = SlashEffect.SHEET
	var sheet := load(path) as Texture2D
	if not ctx.check(sheet != null, "falta la hoja del efecto (%s)" % path):
		return
	# El centro del torso lo pone la definición visual del actor que pega: la hoja
	# clásica lo tiene en -8 y la persona horneada en -14. El efecto no lo adivina,
	# y esta prueba tampoco: se le pasa el mismo dato que le pasa el presentador.
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER)
	if not ctx.check(def != null, "el jugador activo tiene definición"):
		return
	var frames := _fx_cells(sheet)
	for label: String in FX_DIRECTIONS:
		var direction: Vector2 = FX_DIRECTIONS[label]
		var silhouette := _fx_body_cells(body, direction)
		# Los pies en el origen, que es como vive el actor en el mundo.
		var origin := SlashEffect.origin_for(Vector2.ZERO, direction, def.torso_offset)
		var arc: Array[Vector2i] = []
		for cells: Array in frames:
			for point: Vector2i in cells:
				arc.append(
					_fx_rotate(point, direction)
					+ Vector2i(roundi(origin.x), roundi(origin.y))
				)
		if not ctx.check(
			arc.size() > 0 and silhouette.size() > 0,
			"%s: no hay píxeles que medir en %s" % [path, label]
		):
			continue
		var axis := Vector2i(roundi(direction.x), roundi(direction.y))
		var cross := Vector2i(-axis.y, axis.x)
		var body_span := _fx_span(silhouette, axis)
		var arc_span := _fx_span(arc, axis)
		var body_cross := _fx_span(silhouette, cross)
		var arc_cross := _fx_span(arc, cross)

		ctx.check(
			arc_span[1] >= body_span[1] + 8,
			"%s mirando a %s: el arco acaba en %d y el cuerpo en %d, y tiene que " % [
				path.get_file(), label, arc_span[1], body_span[1]
			] + "llegar 8 px más allá del cuerpo"
		)
		ctx.check(
			arc_span[0] >= body_span[0] - 2,
			"%s mirando a %s: el arco se cuela %d px por detrás del cuerpo" % [
				path.get_file(), label, body_span[0] - arc_span[0]
			]
		)
		var arc_mid := float(arc_cross[0] + arc_cross[1]) / 2.0
		var body_mid := float(body_cross[0] + body_cross[1]) / 2.0
		ctx.check(
			absf(arc_mid - body_mid) <= 5.0,
			"%s mirando a %s: el arco va desplazado %.1f px del centro del cuerpo" % [
				path.get_file(), label, arc_mid - body_mid
			]
		)


## Píxeles de cada fotograma de la hoja, centrados en su propio fotograma: así los
## dibuja `Sprite2D`, que va con `centered = true`.
func _fx_cells(sheet: Texture2D) -> Array:
	var image := sheet.get_image()
	var width := GameConfig.FX_FRAME_WIDTH
	var height := GameConfig.FX_FRAME_HEIGHT
	var cells: Array = []
	for column: int in range(GameConfig.FX_FRAMES):
		var points: Array[Vector2i] = []
		var left: int = column * width
		for y: int in range(mini(height, image.get_height())):
			for x: int in range(mini(width, maxi(0, image.get_width() - left))):
				if image.get_pixel(left + x, y).a > 0.05:
					points.append(Vector2i(x - width / 2, y - height / 2))
		cells.append(points)
	return cells


## Píxeles del cuerpo con los pies en el origen: pose de reposo, que es la columna
## 0, igual que los coloca `ActorSprite` al parar.
##
## En una hoja por orientación no hay filas: el archivo lo decide la dirección, el
## fotograma es la celda 0 y los pies salen del clip de reposo de esa dirección
## (una hoja horneada se planta a una altura distinta por lado). Se lee la hoja que
## carga la propia definición, no la que traiga el parámetro, porque en esa rama el
## dibujo viene entero por archivo.
func _fx_body_cells(body: Texture2D, direction: Vector2) -> Array[Vector2i]:
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER)
	if not def.sheet_clips.is_empty():
		return _fx_sheet_body_cells(def, direction)
	# Las filas del cuerpo son las de la definición del jugador (el humano ordena
	# las suyas distinto al pack: frente=1, laterales=2, espalda=3).
	var row := def.row_side
	if direction.y < 0.0:
		row = def.row_up
	elif direction.y > 0.0:
		row = def.walk_row
	var image := body.get_image()
	var size := GameConfig.ACTOR_FRAME_SIZE
	var points: Array[Vector2i] = []
	for y: int in range(size):
		for x: int in range(size):
			if image.get_pixel(x, row * size + y).a > 0.05:
				points.append(Vector2i(x - size / 2, y - size))
	return points


## Píxeles del cuerpo en una hoja por orientación: el archivo de la dirección, la
## celda de reposo, y los pies del clip de esa dirección en el origen (el cuerpo
## se sigue dibujando hacia arriba desde ahí).
func _fx_sheet_body_cells(
	def: CharacterVisualDefinition, direction: Vector2
) -> Array[Vector2i]:
	var idle: Dictionary = def.sheet_clips[ActorSprite.IDLE]
	var direction_number := _dir_number(direction)
	var path := str((idle["sheets"] as Dictionary).get(direction_number, ""))
	var sheet := load(path) as Texture2D
	if sheet == null:
		return []
	var feet := int((idle["feet"] as Dictionary).get(direction_number, def.cell_height()))
	var width := def.frame_size
	var height := def.cell_height()
	var image := sheet.get_image()
	var points: Array[Vector2i] = []
	for y: int in range(height):
		for x: int in range(width):
			if image.get_pixel(x, y).a > 0.05:
				points.append(Vector2i(x - width / 2, y - feet))
	return points


## Número de dirección del pack para una orientación, según la convención de los
## nombres de archivo del Hormelz: `dir8` abajo, `dir4` arriba, `dir2` izquierda,
## `dir6` derecha. La confirmó el análisis de contacto de los golpes (los laterales
## tienen media anchura del cuerpo, los de frente y espalda el ancho entero).
##
## Se escribe a mano a propósito, sin preguntarle al reproductor: si `ActorSprite`
## invertiera dos direcciones, esta prueba tendría que decirlo en vez de repetir el
## mismo error por los dos lados.
func _dir_number(facing: Vector2) -> int:
	if facing.y > 0.0:
		return 8
	if facing.y < 0.0:
		return 4
	if facing.x < 0.0:
		return 2
	return 6


## Rotación exacta de 90 en 90 grados, sin senos ni cosenos, que redondean.
func _fx_rotate(point: Vector2i, direction: Vector2) -> Vector2i:
	if direction == Vector2.RIGHT:
		return point
	if direction == Vector2.DOWN:
		return Vector2i(-point.y, point.x)
	if direction == Vector2.LEFT:
		return Vector2i(-point.x, -point.y)
	return Vector2i(point.y, -point.x)


## Recorrido mínimo y máximo de unos píxeles proyectados sobre un eje unitario.
func _fx_span(points: Array[Vector2i], axis: Vector2i) -> Vector2i:
	var low := 999999
	var high := -999999
	for point: Vector2i in points:
		var value: int = point.x * axis.x + point.y * axis.y
		low = mini(low, value)
		high = maxi(high, value)
	return Vector2i(low, high)


## El arma tiene que caer sobre el cuerpo, no en el suelo ni por encima de la cabeza.
##
## El origen del cuerpo esta en los pies y el actor se dibuja hacia arriba. Sin
## altura de mano, mirando hacia abajo el arma quedaba 3 px por debajo de los pies y
## mirando hacia azul 3 px por encima de la cabeza: en las dos orientaciones verticales
## no parecía un arma en la mano sino un objeto suelto.
func _hand_on_body(ctx: ScriptTestContext) -> void:
	# Se llama al método de la vista de verdad, no a una copia de su fórmula: si el
	# cálculo se moviera, esta prueba tiene que enterarse. No hace falta montar la
	# escena porque `hand_position()` es aritmética pura y `_ready()` no se ejecuta
	# fuera del árbol.
	var view := PlayerView.new()
	# El centro del cuerpo. Todo lo que se comprueba es geométrico, en coordenadas de
	# pantalla, para no repetir la fórmula que se está probando.
	var chest := Vector2(0.0, -float(GameConfig.ACTOR_FRAME_SIZE) * 0.5)
	for direction: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		var hand: Vector2 = view.hand_position(direction)
		var offset := hand - chest
		ctx.check(
			hand.y < 0.0,
			"la mano mirando a %s está a la altura de los pies o más abajo (%.1f)" % [
				direction, hand.y
			]
		)
		ctx.check(
			hand.y > -float(GameConfig.ACTOR_FRAME_SIZE),
			"la mano mirando a %s está por encima de la cabeza (%.1f)" % [direction, hand.y]
		)
		ctx.check(
			absi(hand.x) <= float(GameConfig.ACTOR_FRAME_SIZE) * 0.5,
			"la mano mirando a %s no se sale del ancho del cuerpo (%.1f)" % [
				direction, hand.x
			]
		)
		# La mano se adelanta hacia donde mira, medido en pantalla: hacia abajo es
		# hacia abajo, no hacia el fondo de la pantalla. En una vista cenital, mirar
		# hacia abajo pone la mano por debajo del centro del cuerpo.
		if not is_zero_approx(direction.y):
			ctx.check(
				signf(offset.y) == signf(direction.y),
				"la mano mirando a %s no se adelanta en vertical (desplaza %.1f)" % [
					direction, offset.y
				]
			)
		if not is_zero_approx(direction.x):
			ctx.check(
				signf(offset.x) == signf(direction.x),
				"la mano mirando a %s no se adelanta en horizontal (desplaza %.1f)" % [
					direction, offset.x
				]
			)
	view.free()


## Un `PlayerView` sin montar libera el cuerpo y la colisión que construye en su
## `_ready()`. Esta prueba crea uno, así que lo suelta: Godot avisa de fugas al salir.
