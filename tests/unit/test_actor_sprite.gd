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
	"jugador": ["res://assets/characters/ninja_blue.png", 4, 7],
	"limo": ["res://assets/characters/slime.png", 4, 4],
	"buho": ["res://assets/characters/owl.png", 4, 4],
	"arana": ["res://assets/characters/spider_red.png", 4, 4],
	"lagarto": ["res://assets/characters/lizard.png", 4, 4],
	# La hoja del efecto mide 128x32, que en celdas de 16 px son 8x2. Ojo: esa no es
	# su rejilla de dibujo (son cuatro fotogramas de 32x32, que lo comprueba
	# `_fx_grid`), aquí solo se fija que el archivo siga midiendo lo que mide.
	"golpe": ["res://assets/fx/slash.png", 8, 2],
}

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
		["caminar usa la fila de la orientación", _walk_rows],
		["el golpe no cambia de fila al mirar de lado", _attack_row_is_fixed],
		["el golpe se refleja solo mirando a la izquierda", _attack_flip],
		["caminar avanza de fotograma con el tiempo", _walk_advances],
		["el golpe no se repite y para en el último", _attack_stops_at_end],
		["repetir la misma animación no la reinicia", _replay_is_noop],
		["un clip desconocido no cambia nada", _unknown_clip],
		["un enemigo usa su propia fila de golpe", _enemy_attack_row],
		["el efecto de golpe es una fila de cuatro, y ninguno vacío", _fx_grid],
		["el arco dura lo que dura el golpe", _fx_duration],
		["el arco se ancla en el torso y sale por delante", _fx_origin],
		["ninguna hoja se lee fuera de la rejilla", _frames_stay_in_grid],
		["la mano cae sobre el cuerpo en las cuatro direcciones", _hand_on_body],
	]


## Si alguien sustituye `ninja_blue.png` por otra imagen de otro tamaño, esta prueba
## lo dice con el nombre de la hoja en vez de dejar un actor recortado en pedazos.
func _sheet_grids(ctx: ScriptTestContext) -> void:
	for label: String in SHEETS:
		var expected: Array = SHEETS[label]
		var path: String = expected[0]
		if not ctx.check(ResourceLoader.exists(path), "falta la hoja de %s" % label):
			continue
		var sheet := load(path) as Texture2D
		if not ctx.check(sheet != null, "la hoja de %s no carga" % label):
			continue
		var frame := float(GameConfig.ACTOR_FRAME_SIZE)
		ctx.check_equal(
			int(round(sheet.get_size().x / frame)),
			expected[1],
			"columnas de la hoja de %s" % label
		)
		ctx.check_equal(
			int(round(sheet.get_size().y / frame)),
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


## El corazón del recorte. Caminar es direccional, así que cada orientación tiene que
## caer en su fila: si las dos laterales estuvieran intercambiadas, el personaje
## caminaría de espaldas sin que nada fallara.
func _walk_rows(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	sprite.play(ActorSprite.WALK, true)
	ctx.check_equal(
		_frame_facing(sprite, ActorSprite.WALK, Vector2.DOWN),
		GameConfig.ACTOR_ROW_DOWN * sprite.hframes,
		"abajo"
	)
	ctx.check_equal(
		_frame_facing(sprite, ActorSprite.WALK, Vector2.UP),
		GameConfig.ACTOR_ROW_UP * sprite.hframes,
		"arriba"
	)
	ctx.check_equal(
		_frame_facing(sprite, ActorSprite.WALK, Vector2.LEFT),
		GameConfig.ACTOR_ROW_SIDE * sprite.hframes,
		"un lado"
	)
	ctx.check_equal(
		_frame_facing(sprite, ActorSprite.WALK, Vector2.RIGHT),
		GameConfig.ACTOR_ROW_SIDE_MIRRORED * sprite.hframes,
		"el otro lado"
	)
	ctx.check_equal(sprite.flip_h, false, "caminar nunca se refleja: cada fila ya es la suya")


## El golpe del pack solo existe mirando al frente. Si la fila cambiara con la
## orientación, al golpear hacia arriba saldría el fotograma de andar de frente.
func _attack_row_is_fixed(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	sprite.play(ActorSprite.ATTACK, true)
	var row := _row(sprite)
	for facing: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		sprite.set_facing(facing)
		ctx.check_equal(_row(sprite), row, "el golpe no cambia de fila mirando a %s" % facing)
	ctx.check_equal(
		row,
		GameConfig.ACTOR_ROW_DOWN + 4,
		"y es la fila del golpe de la hoja del jugador"
	)


func _attack_flip(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	sprite.play(ActorSprite.ATTACK, true)
	sprite.set_facing(Vector2.RIGHT)
	ctx.check_equal(sprite.flip_h, false, "a la derecha no se refleja")
	sprite.set_facing(Vector2.LEFT)
	ctx.check_equal(sprite.flip_h, true, "a la izquierda sí")
	sprite.set_facing(Vector2.DOWN)
	ctx.check_equal(sprite.flip_h, false, "abajo no se refleja")


## El ciclo de caminata tiene que pasar por los cuatro fotogramas y volver al
## principio. Con un `delta` de verdad, no con un múltiplo exacto de la duración de un
## fotograma: si el ciclo solo avanzara cuando el tiempo cae justo en el borde, en el
## juego se vería a saltos.
func _walk_advances(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	sprite.play(ActorSprite.WALK, true)
	sprite.set_facing(Vector2.DOWN)
	var base := GameConfig.ACTOR_ROW_DOWN * sprite.hframes

	# Cuántos fotogramas de física dura un ciclo entero de caminata.
	var cycle := int(
		ceil(float(GameConfig.ACTOR_WALK_FRAMES) / GameConfig.ACTOR_WALK_FPS / STEP)
	)
	var columns: Array[int] = []
	for _frame: int in range(cycle):
		sprite._process(STEP)
		columns.append(sprite.frame)
	ctx.check(sprite.is_playing(ActorSprite.WALK), "sigue andando")

	# Un ciclo entero tiene que pasar por los cuatro fotogramas de la fila y volver al
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
		visited, range_array(GameConfig.ACTOR_WALK_FRAMES), "ha pasado por los cuatro"
	)
	ctx.check(
		absi(sprite.frame - base) <= sprite.hframes,
		"el ciclo ha vuelto a la fila de abajo, no a otra"
	)
	ctx.check(
		sprite.frame - base < GameConfig.ACTOR_WALK_FRAMES,
		"y sin pasarse del último fotograma de la fila"
	)


## El golpe no se repite. Si se repitiera, un ataque de cuatro fotogramas se
## quedaría parpadeando mientras dure la ventana, y no se vería entero.
func _attack_stops_at_end(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	sprite.play(ActorSprite.ATTACK, true)
	var last := (
		(GameConfig.ACTOR_ROW_DOWN + 4) * sprite.hframes
		+ GameConfig.ACTOR_ATTACK_FRAMES
		- 1
	)
	# Se avanza el doble de lo que dura el golpe: tiene que quedarse quieto en el
	# último fotograma en vez de volver al principio.
	for _frame: int in range(
		int(GameConfig.ACTOR_ATTACK_FRAMES / GameConfig.ACTOR_ATTACK_FPS / STEP) * 2
	):
		sprite._process(STEP)
	ctx.check_equal(sprite.frame, last, "el golpe se queda en su último fotograma")
	ctx.check(not sprite.is_playing(ActorSprite.ATTACK), "y deja de reproducirse")
	# Y no vuelve solo a la caminata: eso lo decide quien lo llama.
	ctx.check_equal(sprite.current_clip(), ActorSprite.ATTACK, "sigue siendo el golpe")
	# Un fotograma de golpe no puede durar más que el clip entero: si no, se vería
	# siempre el primero.
	ctx.check(
		GameConfig.ACTOR_ATTACK_FRAMES / GameConfig.ACTOR_ATTACK_FPS
		<= GameConfig.ATTACK_RECOVERY,
		"el golpe termina antes de que termine la recuperacion"
	)


## El código llama a `play()` en cada fotograma de física. Si eso reiniciara el ciclo,
## la caminata daría un paso y se volvería a poner en el primero, y el actor andaría
## temblando en el sitio.
func _replay_is_noop(ctx: ScriptTestContext) -> void:
	var sprite := _sprite()
	sprite.play(ActorSprite.WALK, true)
	# Se avanza lo que miden un fotograma y medio: suficiente para haber salido del
	# primero, y no tanto como para haber vuelto a él.
	for _frame: int in range(
		maxi(1, int(ceil(1.5 / GameConfig.ACTOR_WALK_FPS / STEP)))
	):
		sprite._process(STEP)
	var advanced := sprite.frame
	ctx.check(
		advanced != GameConfig.ACTOR_ROW_DOWN * sprite.hframes,
		"el ciclo ha avanzado, está en %d" % advanced
	)
	ctx.check(not sprite.play(ActorSprite.WALK), "repetir la animación no devuelve nada")
	ctx.check_equal(sprite.frame, advanced, "y no reinicia el ciclo")
	ctx.check(sprite.play(ActorSprite.WALK, true), "pero reiniciarla sí, si se pide")
	ctx.check_equal(
		sprite.frame, GameConfig.ACTOR_ROW_DOWN * sprite.hframes, "vuelve al primero"
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


## Los enemigos del pack traen solo las cuatro filas de caminar. Para ellos el golpe
## reutiliza la pose de frente, y hay que comprobar que no se salen de la hoja.
func _enemy_attack_row(ctx: ScriptTestContext) -> void:
	for kind: StringName in [
		NpcKind.SLIME, NpcKind.OWL, NpcKind.SPIDER, NpcKind.LIZARD
	]:
		var sprite := _prepared(kind)
		if not _context_has_texture(sprite, kind, ctx):
			continue
		ctx.check_equal(
			ActorVisualCatalog.attack_row_of(kind),
			GameConfig.ACTOR_ROW_DOWN,
			"el enemigo %s golpea con la pose de frente" % kind
		)
		sprite.play(ActorSprite.ATTACK, true)
		ctx.check_equal(_row(sprite), GameConfig.ACTOR_ROW_DOWN, "y sale de su hoja")
		ctx.check_equal(sprite.flip_h, false, "mirando al frente no se refleja")


## Cualquier combinación de clip, orientación y tiempo tiene que dejar el fotograma
## dentro de la rejilla. Es la comprobacion de red de seguridad: si algo se sale, es
## que una fila o un numero de fotogramas se han inventado.
func _frames_stay_in_grid(ctx: ScriptTestContext) -> void:
	for kind: StringName in ActorVisualCatalog.ids():
		var sprite := _prepared(kind)
		if not _context_has_texture(sprite, kind, ctx):
			continue
		for clip: StringName in ActorSprite.KNOWN_CLIPS:
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
## Se miden las dos hojas (espada del jugador y zarpazo de los enemigos): son del
## mismo pack y hoy comparten rejilla, pero nada obliga a que cambien juntas.
func _fx_grid(ctx: ScriptTestContext) -> void:
	_fx_sheet_grid(ctx, SlashEffect.SHEET)
	_fx_sheet_grid(ctx, SlashEffect.NPC_SHEET)


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
	for path: String in [SlashEffect.SHEET, SlashEffect.NPC_SHEET]:
		var sheet := load(path) as Texture2D
		if not ctx.check(sheet != null, "falta la hoja del efecto (%s)" % path):
			continue
		var frames := _fx_cells(sheet)
		for label: String in FX_DIRECTIONS:
			var direction: Vector2 = FX_DIRECTIONS[label]
			var silhouette := _fx_body_cells(body, direction)
			# Los pies en el origen, que es como vive el actor en el mundo.
			var origin := SlashEffect.origin_for(Vector2.ZERO, direction)
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


## Píxeles del cuerpo con los pies en el origen: fila de la orientación y fotograma
## de reposo, que es la columna 0, igual que los coloca `ActorSprite` al parar.
func _fx_body_cells(body: Texture2D, direction: Vector2) -> Array[Vector2i]:
	var row := GameConfig.ACTOR_ROW_SIDE
	if direction.y < 0.0:
		row = GameConfig.ACTOR_ROW_UP
	elif direction.y > 0.0:
		row = GameConfig.ACTOR_ROW_DOWN
	var image := body.get_image()
	var size := GameConfig.ACTOR_FRAME_SIZE
	var points: Array[Vector2i] = []
	for y: int in range(size):
		for x: int in range(size):
			if image.get_pixel(x, row * size + y).a > 0.05:
				points.append(Vector2i(x - size / 2, y - size))
	return points


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
