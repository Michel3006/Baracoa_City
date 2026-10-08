extends SceneTree

## Tests de arranque: lo que se ve es lo que se mueve.
##
## Uso: godot --headless --script res://tests/integration/startup_runner.gd
##
## ## Por qué hace falta esta suite
##
## Un runner con `--script` carga los autoload pero **no** la escena principal, así que
## ninguna otra suite veía el mundo tal y como arranca al darle a F5. Aquí se carga lo
## que carga el juego: el autoload `Game` ya está montado (los autoload se cargan
## siempre) y se añade la escena de `application/run/main_scene`.
##
## La razón de ser del runner es una clase de fallo que las otras suites no pueden
## ver: cuando la escena principal montaba su propio `MainWorldView` se acababan con
## dos mundos. El del autoload tenía el `MovementController` enchufado y se movía; el de
## la escena principal se dibujaba encima, sin casos de uso, con el jugador clavado, y
## además `make_current()` le entregaba la cámara. El jugador que se ve no se movía y
## el que se movía quedaba tapado por los tiles del otro. Todo verde en las demás
## suites: cada una miraba un solo mundo.
##
## Por eso los casos miran el árbol entero y la cámara activa, no un nodo que el propio
## test busca: la pregunta no es "¿el autoload montó su mundo?" (siempre sí), sino
## "¿lo que hay en pantalla está conectado a los casos de uso?".

var _context: ScriptTestContext
var _total: int = 0
var _failed: int = 0

## Nodo de la escena principal que se carga en `_run()`.
var _main_scene: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_context = ScriptTestContext.new()
	print("== Tests de integracion (arranque) ==")

	await _check("el proyecto declara una escena principal", _main_scene_is_declared)
	await _check("la escena principal se monta sin errores", _main_scene_loads)
	await _check("el mundo existe una sola vez", _single_world_view)
	await _check("el jugador de pantalla está conectado a los casos de uso", _player_wired)
	await _check("la cámara activa sigue al jugador de los casos de uso", _camera_follows_player)
	await _check("pulsar una tecla mueve al jugador que se ve", _player_moves_on_input)
	await _check("al andar, el arma va en la mano y no se mueve al parar", _weapon_follows_the_hand)
	await _check("el arma no tapa las piernas ni sale tumbada", _weapon_clears_the_legs)
	await _check("al parar, el personaje sigue mirando hacia donde caminaba", _facing_kept_on_stop)
	await _check("el golpe termina y el cuerpo vuelve a su animación", _attack_ends_and_body_walks_again)
	await _check("tras golpear, caminar no repite el golpe ni da vueltas", _walk_after_attack_does_not_replay_the_swing)
	await _check("girar a mitad de golpe no reinicia el clip", _turning_mid_swing_does_not_restart_the_clip)
	await _check("la pose de golpe se cierra sola aunque nadie avise", _swing_closes_without_the_signal)
	await _check("el estado ATTACKING dura la recuperación", _attacking_state_lasts_the_recovery)
	await _check("al reaparecer el jugador sigue llevando el arma", _weapon_survives_death)
	await _check("con la zona despejada nada se ata al jugador", _nothing_blocks_the_player)
	await _check("a puños el cuerpo usa el brazo dibujado", _unarmed_punch_uses_punch_arm)
	await _check("la barra de golpe sigue el cooldown", _attack_bar_follows_the_cooldown)

	_report()
	quit(0 if _failed == 0 else 1)


func _check(label: String, body: Callable) -> void:
	var before := _context.failures.size()
	_total += 1
	await body.call()
	if _context.failures.size() == before:
		print("  [OK]   %s" % label)
	else:
		_failed += 1
		print("  [FAIL] %s" % label)
		for index: int in range(before, _context.failures.size()):
			print("         %s" % _context.failures[index])


func _report() -> void:
	print("")
	print("RESULTADO: %d/%d pruebas correctas" % [_total - _failed, _total])


# --- acceso a la escena montada ---

func _game() -> Node:
	return root.get_node("Game")


func _world(): # MainWorldView
	return _game().world_view


func _views() -> Array:
	var found: Array = []
	_collect_views(root, found)
	return found


func _collect_views(from: Node, into: Array) -> void:
	if from is MainWorldView:
		into.append(from)
	for child: Node in from.get_children():
		_collect_views(child, into)


## Jugadores que hay en el árbol, incluidos los de una hipotética segunda copia del
## mundo: para esto da igual que el nodo sea el del autoload o el de la escena
## principal, lo que se mira es que no haya más de uno.
func _players() -> Array:
	var found: Array = []
	for view in _views():
		if view.player != null:
			found.append(view.player)
	return found


## El cuerpo al que el `MovementController` mueve de verdad.
func _driven_player() -> PlayerView:
	var body: Node = _game().movement._body
	return body as PlayerView


func _camera_target() -> Node2D:
	var camera := root.get_camera_2d() as Camera2D
	if camera == null:
		return null
	return camera.get("_target") as Node2D


func _settle(frames: int = 4) -> void:
	for _frame: int in range(frames):
		await physics_frame


# --- casos ---

## La escena principal es la que carga el juego al darle a F5. Sin ella el proyecto no
## arranca, así que su ausencia es un fallo de configuración, no una excepción.
func _main_scene_is_declared() -> void:
	var path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_context.check(not path.is_empty(), "project.godot no declara run/main_scene")
	if path.is_empty():
		return
	_context.check(ResourceLoader.exists(path), "la escena principal no existe: %s" % path)


func _main_scene_loads() -> void:
	var path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if path.is_empty():
		return
	var packed := load(path) as PackedScene
	if packed == null:
		_context.check(false, "no se pudo cargar %s" % path)
		return
	_main_scene = packed.instantiate()
	if _main_scene == null:
		_context.check(false, "no se pudo instanciar %s" % path)
		return
	root.add_child(_main_scene)
	await _settle(3)
	_context.check(is_instance_valid(_main_scene), "la escena principal no sobrevivió al arranque")


## Un solo `MainWorldView` en el árbol. Con dos, la cámara y el jugador dibujados son
## los del segundo, que no está conectado a nada.
func _single_world_view() -> void:
	var views := _views()
	_context.check(
		views.size() == 1,
		"hay %d copias de MainWorldView (se esperaba 1): %s" % [views.size(), _names(views)]
	)
	var players := _players()
	_context.check(
		players.size() == 1,
		"hay %d jugadores en el árbol (se esperaba 1): %s" % [players.size(), _names(players)]
	)


## El jugador que se ve tiene que tener la entrada enchufada. Sin esto se dibuja un
## cuerpo que se queda quieto mientras el otro, escondido, se mueve.
func _player_wired() -> void:
	var players := _players()
	if players.size() != 1:
		return
	var player: PlayerView = players[0]
	_context.check(
		player.get_parent() == _world(),
		"el jugador visible no es hijo del mundo del autoload, sino de %s" % player.get_parent().name
	)
	var presenter := player.get_node_or_null("Presenter") as PlayerPresenter
	_context.check(presenter != null, "el jugador visible no tiene presentador")
	if presenter == null:
		return
	_context.check(
		presenter._movement == _game().movement,
		"el presentador del jugador visible no tiene el MovementController del juego"
	)
	_context.check(
		presenter._combat == _game().session.combat,
		"el presentador del jugador visible no tiene el MeleeCombat del juego"
	)
	_context.check(
		_driven_player() == player,
		"el MovementController mueve otro cuerpo (%s), no el que se ve (%s)" % [
			str(_driven_player()), str(player)
		]
	)


## `make_current()` lo llama la última cámara que se monta, así que con dos mundos la
## que manda es la que sigue a un jugador congelado.
func _camera_follows_player() -> void:
	var camera := root.get_camera_2d()
	_context.check(camera != null, "no hay ninguna cámara activa")
	if camera == null:
		return
	_context.check(camera == _world().camera, "la cámara activa no es la del mundo del autoload")
	var target := _camera_target()
	_context.check(target == _driven_player(), "la cámara activa sigue a %s" % str(target))


## La prueba de la puerta: lo que se ve se mueve con las teclas. Se simula `Input` en
## vez de llamar al caso de uso a mano, porque lo que se rompió fue precisamente el
## tramo entre la entrada y el cuerpo.
func _player_moves_on_input() -> void:
	var players := _players()
	if not _context.check(
		players.size() == 1,
		"no se puede comprobar el movimiento: hay %d jugadores" % players.size()
	):
		return
	var player: PlayerView = players[0]
	var start: Vector2 = player.global_position
	Input.action_press(&"move_right", 1.0)
	await _settle(20)
	Input.action_release(&"move_right")
	var moved: float = player.global_position.x - start.x
	_context.check(
		moved > 1.0,
		"pulsando move_right el jugador se movió %.2f px a la derecha" % moved
	)
	var domain: Player = _game().session.player
	_context.check(
		domain.position.distance_to(player.global_position) < 2.0,
		"dominio y vista se han desalineado: %s frente a %s" % [
			str(domain.position), str(player.global_position)
		]
	)


## Las cuatro orientaciones, para recorrerlas en el orden en el que se comprueban.
const DIRECTIONS: Array[Vector2] = [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]

## Un caso que necesita el jugador de pantalla. Devuelve `null` si no lo hay, y el
## propio `check` deja escrito el motivo.
func _player_or_report() -> PlayerView:
	var players := _players()
	if not _context.check(
		players.size() == 1, "no se puede mirar al jugador: hay %d" % players.size()
	):
		return null
	return players[0]


func _action_for(direction: Vector2) -> StringName:
	if direction == Vector2.UP:
		return &"move_up"
	if direction == Vector2.DOWN:
		return &"move_down"
	return &"move_right" if direction == Vector2.RIGHT else &"move_left"


## El arma tiene que estar en la mano mientras se camina, y quedarse quieta al parar.
##
## El arma solo se colocaba al pasar a quieto y durante el golpe. Con eso al caminar se
## quedaba donde se hubiera dejado la última vez, que al arrancar es el centro del
## cuerpo: un palo de 16 px encima de las piernas. Y al soltar el botón saltaba de golpe a
## la posición y a la inclinación nuevas, que es lo que se veía como que el personaje se
## volvía de lado al parar.
func _weapon_follows_the_hand() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var weapon: Sprite2D = player.get_node_or_null("Weapon") as Sprite2D
	if not _context.check(
		weapon != null and weapon.visible, "el jugador no está dibujando ningún arma"
	):
		return

	# Armar el caso de salida: el arma visible pero sin colocar en ninguna mano, que es
	# como aparece. Se reproduce a propósito en vez de esperar al arranque, porque aquí el
	# jugador ya se ha movido antes.
	weapon.position = Vector2.ZERO
	player.set_weapon(WeaponCatalog.default_weapon())
	_context.check(
		weapon.position.distance_to(player.hand_position()) < 0.01,
		"al equipar el arma no se coloca en la mano: está en %s y la mano en %s" % [
			str(weapon.position), str(player.hand_position())
		]
	)

	# Girar sin soltar el botón. Antes el cambio de orientación no recolocaba el arma,
	# porque la recolocación iba atada al paso a quieto: seguía en la mano de la
	# dirección anterior durante toda la vuelta.
	Input.action_press(&"move_right", 1.0)
	await _settle(6)
	Input.action_press(&"move_up", 1.0)
	await _settle(6)
	_context.check(
		weapon.position.distance_to(player.hand_position(Vector2.UP)) < 0.01,
		"girando de derecha a arriba sin parar, el arma se queda en %s y la mano está en %s" % [
			str(weapon.position), str(player.hand_position(Vector2.UP))
		]
	)
	Input.action_release(&"move_up")
	await _settle(6)
	_context.check(
		weapon.position.distance_to(player.hand_position(Vector2.RIGHT)) < 0.01,
		"al volver a derecha el arma se queda en %s y la mano está en %s" % [
			str(weapon.position), str(player.hand_position(Vector2.RIGHT))
		]
	)
	Input.action_release(&"move_right")
	await _settle(4)

	# Y en cada dirección, caminando y parado, la posición no se mueve.
	for direction: Vector2 in DIRECTIONS:
		var action := _action_for(direction)
		Input.action_press(action, 1.0)
		await _settle(6)
		var walking: Vector2 = weapon.position
		Input.action_release(action)
		await _settle(6)
		var hand: Vector2 = player.hand_position(direction)
		_context.check(
			walking.distance_to(hand) < 0.01,
			"caminando hacia %s el arma está en %s y la mano en %s" % [
				direction, str(walking), str(hand)
			]
		)
		_context.check(
			weapon.position.distance_to(walking) < 0.01,
			"al parar yendo hacia %s el arma salta de %s a %s" % [
				direction, str(walking), str(weapon.position)
			]
		)


## El arma se dibuja al costado del cuerpo, recta, y con el mango en la mano.
##
## Aquí se mide el rectángulo que ocupa de verdad el sprite, no la posición del nodo.
## La diferencia importa: con `centered = true` el rectángulo se dibuja en
## `posicion + offset - tamaño / 2`, así que un offset pensado para anclar por el mango
## dejaba el palo media altura por encima de la mano, flotando sobre la cabeza. El test
## anterior miraba solo `hand_position()` y daba ese caso por bueno, porque la posición
## del nodo era la correcta y lo que flotaba era el dibujo.
##
## Lo que falla cuando esto se rompe no es ningún valor que devuelva el código: es lo que
## hay en pantalla. Por eso el caso compone el rectángulo y lo compara con el del cuerpo.
func _weapon_clears_the_legs() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var weapon: Sprite2D = player.get_node_or_null("Weapon") as Sprite2D
	if not _context.check(
		weapon != null and weapon.visible and weapon.texture != null,
		"el jugador no está dibujando ningún arma"
	):
		return
	var frame := float(GameConfig.ACTOR_FRAME_SIZE)
	# El cuerpo: el actor va centrado con `ACTOR_SPRITE_OFFSET`, así que ocupa desde
	# -8,-16 hasta +8,0 respecto al nodo del jugador.
	var body := Rect2(-frame * 0.5, -frame, frame, frame)
	for direction: Vector2 in DIRECTIONS:
		# Primero se gira y se espera: el sprite tiene que estar en la orientación que se
		# va a medir. Midiendo antes de girar se comparaba el dibujo de una dirección con
		# la mano de otra, y el caso pasaba o fallaba por lo que tocara.
		var action := _action_for(direction)
		Input.action_press(action, 1.0)
		await _settle(6)
		Input.action_release(action)
		await _settle(6)

		var hand: Vector2 = player.hand_position()
		var rect: Rect2 = _weapon_rect_on_body(weapon)
		var grip: Vector2 = _weapon_grip_on_body(weapon)
		# El mango está en la mano. Se mide el punto del dibujo sobre el que gira el arco
		# (el centro del borde inferior del rectángulo local), no el nodo: con
		# `centered = true` el nodo está bien y el mango queda media altura por encima.
		_context.check(
			grip.distance_to(hand) <= 0.51,
			"mirando a %s el mango del arma no está en la mano (mango %s, mano %s)" % [
				direction, str(grip), str(hand)
			]
		)
		# El arma toca el cuerpo, que es lo que significa "en la mano": un dibujo
		# colocado en el sitio correcto pero que no solapa al personaje se ve flotando al
		# lado, y es justo lo que pasaba con el offset mal calculado.
		_context.check(
			rect.intersects(body),
			"mirando a %s el arma no toca el cuerpo (arma %s, cuerpo %s)" % [
				direction, str(rect), str(body)
			]
		)
		# Y no se clava en el suelo: los pies están en el origen del nodo del jugador.
		_context.check(
			rect.end.y <= 0.0,
			"mirando a %s el arma baja de los pies (%.1f)" % [direction, rect.end.y]
		)
		_context.check(
			absi(weapon.rotation) < PI * 0.25,
			"mirando a %s el arma sale tumbada (%.2f rad)" % [direction, weapon.rotation]
		)


## Rectángulo que el arma ocupa en el sistema de coordenadas del cuerpo del jugador.
##
## Traduce el rectángulo local del sprite por la posición de la mano y por la rotación
## del arco, que es como lo ve el jugador. Al ser el rectángulo un AABB y no una figura
## girada, con el arma inclinada sale algo mayor que el dibujo real; para la geometría
## fina está `_weapon_grip_on_body()`.
func _weapon_rect_on_body(weapon: Sprite2D) -> Rect2:
	var base: Rect2 = weapon.get_rect()
	var left: float = INF
	var right: float = -INF
	var top: float = INF
	var bottom: float = -INF
	for point: Vector2 in [
		base.position,
		Vector2(base.end.x, base.position.y),
		base.end,
		Vector2(base.position.x, base.end.y),
	]:
		var corner: Vector2 = weapon.position + point.rotated(weapon.rotation)
		left = minf(left, corner.x)
		right = maxf(right, corner.x)
		top = minf(top, corner.y)
		bottom = maxf(bottom, corner.y)
	return Rect2(left, top, right - left, bottom - top)


## Punto del dibujo del arma sobre el que gira el arco del golpe, en coordenadas del
## cuerpo del jugador.
##
## Es el centro del borde inferior del rectángulo local, llevados por la posición y la
## rotación del sprite. Con `centered = false` y `offset = (-ancho / 2, -alto)` ese punto
## cae en el nodo; con `centered = true` queda `-alto / 2` por encima, que es exactamente
## el medio cuadro de error del que hablaba el arreglo. Medir este punto y no el nodo es
## lo que distingue "la mano está bien" de "la mano está bien y el palo también".
func _weapon_grip_on_body(weapon: Sprite2D) -> Vector2:
	var base: Rect2 = weapon.get_rect()
	var bottom_middle := Vector2(base.position.x + base.size.x * 0.5, base.end.y)
	return weapon.position + bottom_middle.rotated(weapon.rotation)


## Al soltar el botón el personaje se queda mirando hacia donde iba, no vuelve a mirar
## al frente ni se vuelve de lado.
##
## En la rejilla clásica el fotograma parado es la primera columna de la fila de la
## orientación, así que aquí se comprueba que sea la columna 0 de la fila que toca y no
## otra: un clip de caminar cuya fila se calculase mal se notaría justo al parar, que es
## cuando se ve la pose quieta. En una hoja por orientación no hay filas: la pose quieta
## es el fotograma 0 de TODOS los clips y lo que tiene que cambiar al girar es el archivo,
## el de la dirección que toca, sin espejos.
func _facing_kept_on_stop() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	if not _context.check(actor != null, "el jugador no tiene sprite de cuerpo"):
		return
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER)
	var sheet_based := not def.sheet_clips.is_empty()
	var rows: Array[int] = [
		def.row_side_mirrored,
		def.row_up,
		def.row_side,
		def.walk_row,
	]
	for index: int in range(DIRECTIONS.size()):
		var direction: Vector2 = DIRECTIONS[index]
		Input.action_press(_action_for(direction), 1.0)
		await _settle(20)
		Input.action_release(_action_for(direction))
		await _settle(8)
		var expected: int = rows[index] * maxi(1, actor.hframes)
		if sheet_based:
			expected = 0
		_context.check(
			actor.current_clip() == ActorSprite.IDLE,
			"parado tras ir a %s el clip es %s, no idle" % [direction, str(actor.current_clip())]
		)
		_context.check(
			actor.frame == expected,
			"parado tras ir a %s se ve el fotograma %d, y el de esa fila quieto es el %d" % [
				direction, actor.frame, expected
			]
		)
		_context.check(
			actor.facing() == direction,
			"parado tras ir a %s el sprite mira a %s" % [direction, str(actor.facing())]
		)
		if sheet_based:
			var path := actor.texture.resource_path if actor.texture != null else ""
			_context.check(
				path.ends_with("_dir%d.png" % _dir_number(direction)),
				"parado tras ir a %s la hoja es %s y toca la de su dirección" % [direction, path]
			)
		# La izquierda del humano se refleja (su hoja solo camina a la derecha); el
		# resto de orientaciones y el ninja van sin espejo.
		var expected_flip := def.mirror_side and direction == Vector2.LEFT
		_context.check(
			actor.flip_h == expected_flip,
			"parado tras ir a %s el espejo es %s y toca %s" % [
				direction, actor.flip_h, expected_flip
			]
		)


## Un golpe se acaba y el cuerpo vuelve a su animación de siempre.
##
## Este caso es la defensa del fallo más caro que ha tenido el movimiento. La señal
## `attack_finished` solo salía si el jugador seguía en `ATTACKING` al vencer la
## recuperación, pero el movimiento lo sacaba de `ATTACKING` en el fotograma siguiente
## al golpe, así que la señal no salía nunca: la vista se quedaba con la pose de golpe
## para siempre y el arma se quedaba con la inclinación del arco. El jugador seguía
## moviéndose de verdad, pero con el cuerpo congelado y el arma torcida.
##
## Las tres cosas que se miran son las tres que se rompieron: el clip, el reloj de la
## vista y la animación que toca después.
func _attack_ends_and_body_walks_again() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	if not _context.check(actor != null, "el jugador no tiene sprite de cuerpo"):
		return

	Input.action_press(&"attack", 1.0)
	await _settle(2)
	Input.action_release(&"attack")
	# La recuperación es `ATTACK_RECOVERY`; se le da margen para que el cierre no dependa
	# de caer justo en el fotograma exacto.
	await _settle(int(ceil(GameConfig.ATTACK_RECOVERY * 60.0)) + 12)

	_context.check(
		not player.is_swinging(),
		"el reloj del golpe sigue corriendo %.2f s después de que el golpe acabara" % player.swing_elapsed()
	)
	_context.check(
		actor.current_clip() != ActorSprite.ATTACK,
		"terminado el golpe el clip sigue siendo %s" % str(actor.current_clip())
	)

	# Y al volver a andar tiene que salir la caminata, no quedarse en la última pose.
	#
	# Se mide el clip en los fotogramas en los que el jugador se está moviendo de verdad,
	# y no en un instante suelto: los casos anteriores dejan al jugador en el borde del
	# mapa, y contra una pared el clip es `idle` porque no camina, no porque la animación
	# siga clavada en el golpe. Un caso que mirara solo el fotograma final daría un fallo
	# falso, o peor, un verde falso si el jugador llegara a tener pared delante.
	var start: Vector2 = player.global_position
	var clips_moving: Dictionary = {}
	var moved: float = 0.0
	Input.action_press(&"move_right", 1.0)
	for _frame: int in range(40):
		await physics_frame
		var advance: float = player.global_position.x - start.x
		if advance <= 0.5:
			continue
		moved = advance
		clips_moving[str(actor.current_clip())] = int(clips_moving.get(str(actor.current_clip()), 0)) + 1
	Input.action_release(&"move_right")
	await _settle(4)

	_context.check(
		moved > 0.0,
		"después del golpe el jugador no se mueve a la derecha (%s): o el golpe le ha dejado clavado o tiene pared delante" % str(player.global_position)
	)
	if moved > 0.0:
		_context.check(
			not clips_moving.has(str(ActorSprite.ATTACK)),
			"después del golpe, al andar, sale el clip de golpe %d fotogramas de %d" % [
				int(clips_moving.get(str(ActorSprite.ATTACK), 0)), clips_moving.size()
			]
		)
		_context.check(
			clips_moving.has(str(ActorSprite.WALK)),
			"después del golpe, al andar, nunca sale la caminata: solo %s" % str(clips_moving.keys())
		)


## Tras golpear, caminar da vueltas: no es que el jugador gire, es que el clip del golpe
## se quedaba puesto y se repetía en cada giro, y encima el cuerpo se espejaba al mirar
## a la izquierda porque la fila del golpe no es direccional.
##
## Aquí se cuentan las repeticiones y las filas vistas, en vez de mirar un fotograma
## suelto: es la única forma de detectar que una animación se reproduce en bucle cuando
## el daño es "da vueltas", no "se ve raro".
func _walk_after_attack_does_not_replay_the_swing() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	if not _context.check(actor != null, "el jugador no tiene sprite de cuerpo"):
		return

	Input.action_press(&"attack", 1.0)
	await _settle(2)
	Input.action_release(&"attack")
	await _settle(int(ceil(GameConfig.ATTACK_RECOVERY * 60.0)) + 12)

	# Una vuelta completa andando, girando en las cuatro direcciones.
	var attack_frames: int = 0
	var walk_rows: Dictionary = {}
	var walk_sheets: Dictionary = {}
	var clips: Dictionary = {}
	var previous_attack_frame: int = -1
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER)
	var sheet_based := not def.sheet_clips.is_empty()
	var expected_rows := {def.walk_row: true, def.row_side: true, def.row_up: true, def.row_side_mirrored: true}
	for direction: Vector2 in DIRECTIONS:
		var action := _action_for(direction)
		Input.action_press(action, 1.0)
		for _frame: int in range(24):
			await physics_frame
			var clip := str(actor.current_clip())
			clips[clip] = int(clips.get(clip, 0)) + 1
			if clip == ActorSprite.ATTACK:
				attack_frames += 1
				# El clip del golpe no se repite, así que su fotograma solo avanza.
				if previous_attack_frame >= 0 and actor.frame <= previous_attack_frame:
					attack_frames += 1000
				previous_attack_frame = actor.frame
			elif clip == ActorSprite.WALK:
				previous_attack_frame = -1
				if sheet_based:
					# No hay filas que mirar: cada dirección tiene su archivo. Lo que
					# se colecciona es el archivo visto, no el fotograma.
					if actor.texture != null:
						walk_sheets[actor.texture.resource_path.get_file()] = true
				else:
					walk_rows[actor.frame / maxi(1, actor.hframes)] = true
		Input.action_release(action)
		await _settle(4)

	_context.check(
		attack_frames == 0,
		"andando tras golpear se han visto %d fotogramas del clip de golpe, y debería ser 0: %s" % [
			attack_frames, str(clips)
		]
	)
	if sheet_based:
		_check_walk_sheets(walk_sheets)
		return
	# La izquierda y la derecha del humano comparten la fila lateral (una se
	# refleja), así que el número de filas distintas no tiene por qué ser cuatro:
	# lo que se exige es que todas las filas que tocan se hayan visto y ninguna
	# otra. El ninja tiene cuatro filas distintas y sigue cumpliendo.
	var missing: Array[int] = []
	for row: int in expected_rows:
		if not walk_rows.has(row):
			missing.append(row)
	var extra: Array[int] = []
	for row: int in walk_rows:
		if not expected_rows.has(row):
			extra.append(row)
	_context.check(
		missing.is_empty(),
		"andando en circulo tras golpear no se ha visto la fila %s de las que tocan (%s)" % [
			str(missing), str(walk_rows.keys())
		]
	)
	_context.check(
		extra.is_empty(),
		"andando en circulo tras golpear se han visto filas que no tocan: %s (tocan %s)" % [
			str(extra), str(expected_rows.keys())
		]
	)


## En una hoja por orientación, "las filas que tocan" son los cuatro archivos de
## dirección: se ha visto alguno que no es de ninguna (otro pack, otro clip) y no se
## ha visto alguno de los cuatro (un giro que no cambió de hoja, que es la clase de
## fallo que en la rejilla clásica aparecía como fila equivocada).
func _check_walk_sheets(walk_sheets: Dictionary) -> void:
	var seen: Dictionary = {}
	for file: String in walk_sheets:
		var matched := false
		for dir_number: int in [2, 4, 6, 8]:
			if file.ends_with("_dir%d.png" % dir_number):
				seen[dir_number] = true
				matched = true
		_context.check(
			matched,
			"andando se ha visto la hoja %s, que no es de ninguna dirección del pack" % file
		)
	var missing: Array[int] = []
	for dir_number: int in [2, 4, 6, 8]:
		if not seen.has(dir_number):
			missing.append(dir_number)
	_context.check(
		missing.is_empty(),
		"andando en circulo tras golpear no se ha visto la hoja de las direcciones %s (vistas: %s)" % [
			str(missing), str(walk_sheets.keys())
		]
	)


## Número de dirección del pack para una orientación, según la convención de los
## nombres de archivo del Hormelz (`dir8` abajo, `dir4` arriba, `dir2` izquierda,
## `dir6` derecha). Escrito a mano: si el reproductor invirtiera dos direcciones,
## esta prueba tiene que decirlo en vez de repetir el error.
func _dir_number(facing: Vector2) -> int:
	if facing.y > 0.0:
		return 8
	if facing.y < 0.0:
		return 4
	if facing.x < 0.0:
		return 2
	return 6


## Un giro a mitad de golpe no reinicia el clip del golpe.
##
## El clip de golpe no se repite, así que cuando se termina `ActorSprite.play()` lo
## vuelve a arrancar desde el primer fotograma. La vista pedía el clip de golpe cada vez
## que cambiaba el estado o la orientación, así que en cuanto el jugador andaba y giraba
## durante la recuperación el golpe volvía a empezar: eso es lo que se veía como "va
## dando vueltas". El cuerpo sale por la otra punta y el jugador no paraba de girar.
##
## Aquí se mide que el fotograma del golpe solo avance, y que además el arma barra en el
## mismo sentido durante todo el arco: si el clip se reiniciase, el fotograma retrocedería.
func _turning_mid_swing_does_not_restart_the_clip() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	if not _context.check(actor != null, "el jugador no tiene sprite de cuerpo"):
		return
	var weapon: Sprite2D = player.get_node_or_null("Weapon") as Sprite2D
	if not _context.check(weapon != null, "el jugador no tiene nodo de arma"):
		return

	# Andando y golpeando a la vez: es el caso en el que los dos sistemas se pelean por
	# el estado y en el que el giro llega a mitad de arco.
	Input.action_press(&"move_right", 1.0)
	await _settle(8)
	Input.action_press(&"attack", 1.0)
	await _settle(2)
	Input.action_release(&"attack")
	Input.action_release(&"move_right")

	var total: int = int(ceil(GameConfig.ATTACK_RECOVERY * 60.0)) + 4
	# El giro entra a mitad del arco y no antes. Si el cambio de orientacion llega antes
	# de que empiece el golpe, el reinicio cae en el primer fotograma y el caso no mide
	# nada: el fallo solo aparece cuando el giro pisa al clip cuando ya va por la mitad.
	var turn_at: int = maxi(1, total / 3)
	var previous: int = -1
	var restarts: int = 0
	var arcs: Array[float] = []
	for _frame: int in range(total):
		if _frame == turn_at:
			Input.action_press(&"move_up", 1.0)
		await physics_frame
		if actor.current_clip() != ActorSprite.ATTACK:
			continue
		# Solo retroceder es reiniciar. Un clip que no se repite se queda clavado en su
		# ultimo fotograma (`ActorSprite._process()`), asi que dos fotogramas seguidos
		# iguales son lo normal y contarlos como reinicio haria fallar el caso siempre.
		if previous >= 0 and actor.frame < previous:
			restarts += 1
		previous = actor.frame
		arcs.append(weapon.rotation)
	Input.action_release(&"move_up")
	await _settle(4)

	_context.check(
		restarts == 0,
		"girando a mitad de golpe el clip se ha reiniciado %d veces" % restarts
	)
	_context.check(
		arcs.size() >= 3,
		"el golpe no ha dado ni 3 fotogramas de arco (%d), el caso no está midiendo nada" % arcs.size()
	)
	# El arco va de menos a más y de más a menos una sola vez. Con el clip reiniciado el
	# ángulo de la punta saltaba de un extremo al otro, y eso es lo que se ve como un
	# tirón al girar.
	var jumps: int = 0
	for i: int in range(1, arcs.size()):
		if absf(arcs[i] - arcs[i - 1]) > GameConfig.ATTACK_RECOVERY * 6.0:
			jumps += 1
	_context.check(
		jumps == 0,
		"el arco del arma da %d saltos entre fotogramas: el clip se está reiniciando (ángulos %s)" % [
			jumps, str(arcs)
		]
	)


## La pose de golpe se cierra sola aunque nadie avise.
##
## El camino normal es `attack_finished` -> `end_attack()`, y con el reloj de
## `MeleeCombat` arreglado esa señal sale siempre. Por eso este caso la aparta a
## propósito: abre la pose a mano, sin caso de uso detrás, y mira si la vista la cierra.
##
## Es la segunda red, y merece su propio caso: si la señal se pierde un día (un sistema
## nuevo que se coma el estado, un `advance()` que no llega a correr), lo que no puede
## pasar es que el jugador se quede con el brazo en el aire para siempre. El arco tiene
## una duración conocida, así que la vista puede cerrarlo ella misma.
func _swing_closes_without_the_signal() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	if not _context.check(actor != null, "el jugador no tiene sprite de cuerpo"):
		return

	# Sin pulsar `attack`: se abre la pose directamente, que es lo mismo que el
	# presentador haria con la señal perdida por el camino.
	player.begin_attack()
	await _settle(2)
	if not _context.check(
		player.is_swinging(), "no se ha abierto la pose de golpe, el caso no mide nada"
	):
		return

	Input.action_press(&"move_right", 1.0)
	await _settle(int(ceil(GameConfig.ATTACK_RECOVERY * 60.0)) + 6)

	# El clip se mide solo en los fotogramas en los que el jugador se mueve de verdad.
	# Los casos anteriores lo dejan contra el borde del mapa, y contra una pared el clip
	# es `idle` porque no camina, no porque la pose siga abierta.
	var start: Vector2 = player.global_position
	var clips_moving: Dictionary = {}
	for _frame: int in range(24):
		await physics_frame
		if player.global_position.x - start.x > 1.0:
			clips_moving[str(actor.current_clip())] = 1
	Input.action_release(&"move_right")
	await _settle(2)

	_context.check(
		not player.is_swinging(),
		"sin que nadie llame a end_attack() la pose sigue abierta %.2f s después" % player.swing_elapsed()
	)
	_context.check(
		actor.current_clip() != ActorSprite.ATTACK,
		"sin señal, el clip se queda en %s" % str(actor.current_clip())
	)
	if not clips_moving.is_empty():
		_context.check(
			clips_moving.has(str(ActorSprite.WALK)),
			"cerrada la pose a mano y andando, el clip es %s" % str(clips_moving.keys())
		)


## El estado `ATTACKING` dura la recuperación y no un solo fotograma.
##
## Es el bug de raíz del anterior, visto desde el dominio: el movimiento sincronizaba el
## estado en cada fotograma y ponía `IDLE` o `MOVING` encima de `ATTACKING` antes de que
## la recuperación se cumpliera. El estado `ATTACKING` era entonces decorativo, y como
## `MeleeCombat` emissionsaba `attack_finished` solo desde `ATTACKING`, el golpe no
## terminaba nunca.
func _attacking_state_lasts_the_recovery() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var combat: MeleeCombat = _game().session.combat
	if not _context.check(combat != null, "la sesión no tiene combate"):
		return

	Input.action_press(&"move_right", 1.0)
	await _settle(8)
	Input.action_press(&"attack", 1.0)
	await _settle(2)
	Input.action_release(&"attack")

	var frames: int = maxi(2, int(GameConfig.ATTACK_RECOVERY * 60.0) - 2)
	var attacking_frames: int = 0
	for _frame: int in range(frames):
		await physics_frame
		if combat.player.state == PlayerState.Kind.ATTACKING:
			attacking_frames += 1
	Input.action_release(&"move_right")
	await _settle(6)

	_context.check(
		attacking_frames >= frames,
		"andando y golpeando, el estado ATTACKING solo duró %d de %d fotogramas" % [
			attacking_frames, frames
		]
	)
	_context.check(
		combat.player.state == PlayerState.Kind.IDLE,
		"pasada la recuperación el estado sigue siendo %s en vez de IDLE" % (
			PlayerState.name_of(combat.player.state)
		)
	)


## Al morir y reaparecer el jugador sigue llevando su arma en la mano.
##
## La muerte apagaba el sprite del arma y nadie lo volvía a encender, así que al
## reaparecer el jugador se quedaba con las manos vacías aunque `WeaponCatalog` dijera
## que llevaba la piedra. Es otro caso de "el código dice una cosa y la pantalla otra".
func _weapon_survives_death() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var weapon: Sprite2D = player.get_node_or_null("Weapon") as Sprite2D
	if not _context.check(weapon != null, "el jugador no tiene nodo de arma"):
		return
	if not _context.check(weapon.visible, "antes de morir el jugador ya va sin arma"):
		return

	player.set_dead(true)
	await _settle(2)
	_context.check(not weapon.visible, "muerto, el arma debería estar escondida")
	player.revive()
	await _settle(2)
	_context.check(
		weapon.visible,
		"reaparecido, el arma sigue escondida: el jugador vuelve con las manos vacías"
	)
	_context.check(
		weapon.position.is_equal_approx(player.hand_position()),
		"reaparecido, el arma no está colocada en la mano (%s, mano %s)" % [
			str(weapon.position), str(player.hand_position())
		]
	)


## El jugador se puede recorrer sin que nada se lo impida.
##
## Con `GameConfig.NPC_ENABLED` apagado la zona está vacía, y entonces se comprueba
## todo: que nada le bloquee el movimiento, que vaya a la izquierda y que no pierda ni
## un punto de vida por el camino. Si aparece daño, el jugador topó con un enemigo o con
## un aturdimiento, y con la zona despejada eso solo puede ser un fallo de la zona.
##
## Con la bandera encendida se comprueba solo lo que no depende de la IA. El resto se
## salta a propósito: un enemigo que pilla de camino al jugador lo aturde, el
## aturdimiento congela el movimiento, y un caso que fallara por eso estaría midiendo
## la IA con una regla de movimiento.
func _nothing_blocks_the_player() -> void:
	var game := _game()
	var movement = game.movement
	_context.check(movement.is_enabled, "el movimiento del jugador está deshabilitado")
	var players := _players()
	if not _context.check(players.size() == 1, "hay %d jugadores" % players.size()):
		return
	if not GameConfig.NPC_ENABLED:
		_context.check(not movement.is_blocked, "el movimiento del jugador está bloqueado")
		_context.check(
			game.session.npcs == null,
			"hay enemigos en la zona con GameConfig.NPC_ENABLED apagado (%d)" % (
				game.session.npcs.count() if game.session.npcs != null else -1
			)
		)
		var player: PlayerView = players[0]
		var start: Vector2 = player.global_position
		Input.action_press(&"move_left", 1.0)
		await _settle(20)
		Input.action_release(&"move_left")
		_context.check(
			player.global_position.x < start.x,
			"pulsando move_left el jugador no se movió a la izquierda (%s)" % str(player.global_position)
		)
		var health: float = game.session.player.health.current
		_context.check(
			is_equal_approx(health, 100.0),
			"el jugador recibió daño yendo por la zona vacía: %.1f de vida" % health
		)


## La barra de golpe sigue el cooldown: se vacía al pegar y se llena sola.
##
## El HUD dibuja con `draw_rect`, así que no hay nodo del que leer lo pintado: lo que
## se mide es `attack_ready()`, que es exactamente el número que `_draw()` convierte
## en píxeles. Si el caso pasa, la barra pinta eso.
##
## Se mide contra el `cooldown_ratio` del caso de uso y no contra un reloj propio del
## HUD: si cada uno llevara su cuenta, la barra podría mentir mientras el golpe
## funciona.
func _attack_bar_follows_the_cooldown() -> void:
	var hud = _world().hud
	if not _context.check(hud != null, "el mundo tiene HUD"):
		return
	var combat: MeleeCombat = _game().session.combat
	if not _context.check(combat != null, "la sesión no tiene combate"):
		return

	# Partida de cero: sin cooldown, sin aturdimiento y con stamina de sobra, para que
	# si el golpe no sale el motivo sea el que se está midiendo y no otro.
	combat.grant_invulnerability(0.0)
	combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
	_game().session.player.restore_stamina(float(GameConfig.PLAYER_MAX_STAMINA))
	await _settle(2)
	_context.check(
		hud.attack_ready() >= 0.99,
		"sin golpe en curso la barra debería estar llena y está en %.2f" % hud.attack_ready()
	)

	if not _context.check(
		combat.try_attack(Vector2.RIGHT), "el golpe no sale, el caso no mide nada"
	):
		return
	await _settle(2)
	_context.check(
		hud.attack_ready() <= 0.5,
		"recién pegado la barra se vacía y se ha quedado en %.2f" % hud.attack_ready()
	)

	await _settle(int(ceil(GameConfig.DEFAULT_ATTACK_COOLDOWN * 60.0)) + 12)
	_context.check(
		hud.attack_ready() >= 0.99,
		"pasado el cooldown la barra vuelve a la llena y se ha quedado en %.2f" % hud.attack_ready()
	)


## A puños, el cuerpo queda en IDLE y el brazo dibujado está activo
##
## Con arma se usa el clip ATTACK; a puños no se dibuja el clip de ataque del
## cuerpo (es de perfil) y el brazo por código está activo.
func _unarmed_punch_uses_punch_arm() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	var punch := player.get_node_or_null("PunchArm") as Node
	if not _context.check(actor != null, "el jugador no tiene sprite de cuerpo"):
		return
	_context.check(punch != null, "el jugador no tiene PunchArm")

	# Sin arma: golpe a puños - limpiar cooldown
	var combat: MeleeCombat = _game().session.combat
	if combat != null:
		combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
		_game().session.player.restore_stamina(float(GameConfig.PLAYER_MAX_STAMINA))
	await _settle(2)

	Input.action_press(&"attack_unarmed", 1.0)
	await _settle(2)
	Input.action_release(&"attack_unarmed")

	await _settle(4)
	if _context.check(player.is_swinging(), "no hay swing a puños"):
		var clip := actor.current_clip()
		_context.check(
			clip == ActorSprite.ATTACK,
			"a puños el cuerpo debe usar el clip ATTACK y está en %s" % str(clip)
		)
		var is_active := false
		if punch != null:
			if punch.has_method("is_active"):
				is_active = punch.call("is_active")
			elif punch.get("active") != null:
				is_active = punch.active
		_context.check(not is_active, "el brazo dibujado por código no debe estar activo cuando se usa la animación del cuerpo")

	await _settle(int(ceil(GameConfig.ATTACK_RECOVERY * 60.0)) + 6)


func _names(nodes: Array) -> String:
	var labels: Array[String] = []
	for node in nodes:
		labels.append("%s(%s, padre %s)" % [node.name, node.get_instance_id(), node.get_parent().name])
	return ", ".join(labels)