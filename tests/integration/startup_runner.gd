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
	await _check("la entrada de defensa llega al combate", _defense_input_reaches_the_combat)
	await _check("al parar, el personaje sigue mirando hacia donde caminaba", _facing_kept_on_stop)
	await _check("el golpe termina y el cuerpo vuelve a su animación", _attack_ends_and_body_walks_again)
	await _check("tras golpear, caminar no repite el golpe ni da vueltas", _walk_after_attack_does_not_replay_the_swing)
	await _check("girar a mitad de golpe no reinicia el clip", _turning_mid_swing_does_not_restart_the_clip)
	await _check("la pose de golpe se cierra sola aunque nadie avise", _swing_closes_without_the_signal)
	await _check("el estado ATTACKING dura la recuperación", _attacking_state_lasts_the_recovery)
	await _check("con la zona despejada nada se ata al jugador", _nothing_blocks_the_player)
	await _check("a puños el cuerpo usa el brazo dibujado", _unarmed_punch_uses_punch_arm)
	await _check("la barra de golpe sigue el cooldown", _attack_bar_follows_the_cooldown)
	await _check("el golpe usa la animación de su ataque", _attack_uses_its_own_animation)
	await _check("la cámara tiembla al impacto y se queda quieta sola", _camera_shakes_on_impact)
	await _check("un golpe recibido congela al presentador y se descongela solo", _hit_stop_freezes_and_drains)
	await _check("el HUD de depuración se enciende, muestra y se apaga", _debug_hud_toggles_and_lines)
	await _check("la geometría de debug sigue a la hitbox y conmuta con F2", _debug_hitboxes_geometry_and_toggle)
	await _check("el muñeco de combate está en el mundo y no se mueve ni pega", _dummy_exists_and_is_passive)
	await _check("un golpe real del jugador entra al muñeco y reacciona", _dummy_takes_a_hit_and_reacts)
	await _check("un golpe fuerte al muñeco congela su presentador y se descongela solo", _dummy_presenter_hit_stops)
	await _check("el muñeco muere y reaparece a los dos segundos", _dummy_dies_and_respawns)
	await _check("el jugador arranca con ropa y pelo por defecto", _player_starts_dressed_by_default)
	await _check("al jugador se le puede poner y quitar ropa", _garment_can_be_put_on_and_taken_off)
	await _check("la prenda sigue al cuerpo sin reloj propio", _garment_follows_the_body_state)
	await _check("la prenda se dibuja encima del cuerpo y no toca la física", _garment_is_a_layer_over_the_body)
	await _check("el peinado se pinta en la cabeza y no en el torso", _hair_paints_the_head_not_the_torso)
	await _check("el vestuario abre con C, navega y pone la ropa", _appearance_panel_opens_and_dresses)
	await _check("con el mundo parado el vestuario sigue oyendo la entrada", _appearance_hears_input_while_paused)
	await _check("la mochila y el vestuario no pueden estar abiertos a la vez", _appearance_and_backpack_are_exclusive)
	await _check("el vestuario no se abre con el jugador muerto", _appearance_refuses_when_dead)
	await _check("la vista previa del vestuario es un espejo del cuerpo", _appearance_preview_mirrors_the_body)
	await _check("con ropa el cuerpo camina, golpea y muere igual", _garment_does_not_break_the_animation)

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


## La defensa no es un atajo del dominio: las teclas tienen que llegar hasta el
## cuerpo de combate. Rodar se dispara con una pulsación y cambia el estado del
## jugador, y la guardia se mantiene mientras se pulsa y aguanta un golpe de
## frente pagando stamina, no vida. Es el mismo tramo entrada -> cuerpo que
## `_player_moves_on_input`, pero para las teclas nuevas.
##
## Se despeja la zona primero, como los casos que miden poses: medir la guardia
## con un enemigo golpeando al jugador es medir otra cosa. El pulso va con
## `action_press`, que `is_action_just_pressed` sí ve en el siguiente fotograma
## físico (comprobado; `parse_input_event` no entrega en headless).
func _defense_input_reaches_the_combat() -> void:
	var players := _players()
	if not _context.check(
		players.size() == 1,
		"no se puede comprobar la defensa: hay %d jugadores" % players.size()
	):
		return
	_clear_zone()
	var player: PlayerView = players[0]
	var combat: MeleeCombat = _game().session.combat

	# El caso anterior caminó con los enemigos vivos y el jugador puede haber
	# recibido un golpe al final: esperar a que el trance (reacción, aturdimiento
	# e invulnerabilidad) expire del todo antes de medir la entrada, o `try_dodge`
	# se rechaza.
	await _settle(25)

	Input.action_press(&"dodge")
	await _settle(1)
	Input.action_release(&"dodge")
	# El presentador arranca la rodada al leer la pulsación, en el tramo del
	# fotograma que cae después de la señal de `physics_frame`: comprobarlo un
	# fotograma más tarde.
	await _settle(1)
	_context.check(
		_game().session.player.state == PlayerState.Kind.DODGING,
		"pulsar dodge hace rodar al jugador"
	)
	_context.check(
		player.reaction_clip() == &"", "la rodada no pisa ninguna pose previa"
	)

	# La rodada dura su gesto entero (16 fotogramas a 68 fps); se espera a que
	# termine para levantar la guardia, que no puede subir rodando.
	await _settle(20)
	_context.check(not combat.is_dodging, "y la rodada termina sola")

	Input.action_press(&"block")
	await _settle(1)
	_context.check(combat.is_blocking, "mantener block levanta la guardia")

	# El jugador mira al este (lo dejó el caso anterior): un golpe desde el oeste
	# es de frente.
	var stamina_before: float = _game().session.player.stamina
	var health_before: float = _game().session.player.health.current
	var dealt := combat.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.LEFT)
	Input.action_release(&"block")

	_context.check_equal(dealt, 0.0, "y de frente el golpe no entra")
	_context.check_equal(
		_game().session.player.health.current, health_before, "sin perder vida"
	)
	_context.check_equal(
		stamina_before - _game().session.player.stamina,
		GameConfig.BLOCK_STAMINA_COST,
		"pagando la stamina de la guardia"
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
	_clear_zone()
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


## Despeja la zona de enemigos vivos para los casos que miden la pose del jugador.
##
## Un enemigo que llega a pegarle durante la medición la tapa con la reacción al
## golpe (`hit_light`/`hit_body`/`hit_head`): eso está bien en el juego, pero aquí
## convierte "qué pose tiene el jugador al parar" en una carrera contra la IA. Se
## matan los agentes para que la medición dependa solo de lo que se está probando.
func _clear_zone() -> void:
	var game := _game()
	if game.session == null or game.session.npcs == null:
		return
	for agent in game.session.npcs.agents:
		if not agent.npc.is_dead:
			agent.npc.take_damage(agent.npc.health.maximum)


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
	_clear_zone()

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
		not ActorSprite.is_attack_clip(actor.current_clip()),
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
		var stuck: int = _attack_clip_frames(clips_moving)
		_context.check(
			stuck == 0,
			"después del golpe, al andar, sale un clip de golpe %d fotogramas de %d: %s" % [
				stuck, clips_moving.size(), str(clips_moving.keys())
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
			if ActorSprite.is_attack_clip(StringName(clip)):
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
## Aquí se mide que el fotograma del golpe solo avance mientras el giro entra a mitad de
## arco: si el clip se reiniciase, el fotograma retrocedería.
func _turning_mid_swing_does_not_restart_the_clip() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	if not _context.check(actor != null, "el jugador no tiene sprite de cuerpo"):
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
	var attack_frames: int = 0
	for _frame: int in range(total):
		if _frame == turn_at:
			Input.action_press(&"move_up", 1.0)
		await physics_frame
		if not ActorSprite.is_attack_clip(actor.current_clip()):
			continue
		attack_frames += 1
		# Solo retroceder es reiniciar. Un clip que no se repite se queda clavado en su
		# ultimo fotograma (`ActorSprite._process()`), asi que dos fotogramas seguidos
		# iguales son lo normal y contarlos como reinicio haria fallar el caso siempre.
		if previous >= 0 and actor.frame < previous:
			restarts += 1
		previous = actor.frame
	Input.action_release(&"move_up")
	await _settle(4)

	_context.check(
		restarts == 0,
		"girando a mitad de golpe el clip se ha reiniciado %d veces" % restarts
	)
	_context.check(
		attack_frames >= 3,
		"el golpe no ha dado ni 3 fotogramas de clip (%d), el caso no está midiendo nada" % attack_frames
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
		not ActorSprite.is_attack_clip(actor.current_clip()),
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
			ActorSprite.is_attack_clip(clip),
			"a puños el cuerpo debe usar un clip de golpe y está en %s" % str(clip)
		)
		var is_active := false
		if punch != null:
			if punch.has_method("is_active"):
				is_active = punch.call("is_active")
			elif punch.get("active") != null:
				is_active = punch.active
		_context.check(not is_active, "el brazo dibujado por código no debe estar activo cuando se usa la animación del cuerpo")

	await _settle(int(ceil(GameConfig.ATTACK_RECOVERY * 60.0)) + 6)


## Cuántos fotogramas de un recuento por clip son clips de golpe.
##
## El golpe ya no es un clip único: cada ataque tiene el suyo (`left_jab`,
## `straight`, `front_kick`...), así que mirar solo `ATTACK` dejaría pasar un
## cuerpo clavado en la pose de un jab mientras la prueba veía "no es attack,
## correcto".
func _attack_clip_frames(clips: Dictionary) -> int:
	var total := 0
	for clip: String in clips:
		if ActorSprite.is_attack_clip(StringName(clip)):
			total += int(clips[clip])
	return total


## Cada golpe se anima con su propio clip (sección 11), no con uno genérico.
##
## La hoja del pack trae una animación por ataque, así que un jab tiene que
## verse como jab y una cruzada como cruzada, aunque por dentro los dos sean
## "un ataque de la cadena". Si esto falla, los doce golpes se ven idénticos y
## el jugador no puede distinguir una patada de un jab mirando la pantalla.
func _attack_uses_its_own_animation() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	if not _context.check(actor != null, "el jugador no tiene sprite de cuerpo"):
		return
	var combat: MeleeCombat = _game().session.combat
	if not _context.check(combat != null, "la sesión no tiene combate"):
		return

	# Partida de cero: si el golpe anterior deja cooldown, este caso diría que la
	# animación no cambia cuando en realidad no ha salido ningún golpe.
	combat.grant_invulnerability(0.0)
	combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
	_game().session.player.restore_stamina(float(GameConfig.PLAYER_MAX_STAMINA))
	await _settle(2)

	_context.check(
		actor.has_clip(&"left_jab") and actor.has_clip(&"straight"),
		"la hoja no trae los clips de los ataques: el caso no mide nada"
	)

	Input.action_press(&"attack", 1.0)
	await _settle(2)
	Input.action_release(&"attack")
	_context.check_equal(
		actor.current_clip(), &"left_jab",
		"el jab izquierdo se anima como jab izquierdo"
	)

	await _settle(int(ceil(GameConfig.DEFAULT_ATTACK_COOLDOWN * 60.0)) + 12)
	Input.action_press(&"attack_heavy", 1.0)
	await _settle(2)
	Input.action_release(&"attack_heavy")
	_context.check_equal(
		actor.current_clip(), &"straight",
		"la cruzada se anima como cruzada, no como el jab de antes"
	)
	await _settle(int(ceil(GameConfig.ATTACK_RECOVERY * 60.0)) + 12)


func _names(nodes: Array) -> String:
	var labels: Array[String] = []
	for node in nodes:
		labels.append("%s(%s, padre %s)" % [node.name, node.get_instance_id(), node.get_parent().name])
	return ", ".join(labels)


# --- personalizacion: ropa y peinados (plan de ropa, Fase 3) ---

## Capas de ropa y peinado del jugador, indexadas por parte del cuerpo.
func _garment_layers(player: PlayerView) -> Dictionary:
	var layers: Dictionary = {}
	for child in player.get_children():
		if child is GarmentLayer:
			layers[child.part] = child
	return layers


## Cuántos píxeles de la superposición de una capa son justo de ese color.
##
## Contar píxeles, no mirar el `modulate`: es la regla del proyecto para lo que
## se ve. Un `modulate` aplicado no dice qué sale dibujado; un recuento sí.
func _count_overlay_color(layer: GarmentLayer, color: Color) -> int:
	if layer == null or layer.texture == null:
		return 0
	var image := layer.texture.get_image()
	if image == null:
		return 0
	var total := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var px := image.get_pixel(x, y)
			if px.a8 > 0 and px.r8 == color.r8 and px.g8 == color.g8 and px.b8 == color.b8:
				total += 1
	return total


## El jugador arranca vestido: `GameConfig.DEFAULT_SHIRT` y `DEFAULT_HAIR` están
## puestos desde que se construye la vista, sin abrir el vestuario, y las capas
## los dibujan. Es lo que se ve al darle a F5 sin tocar nada.
##
## El caso va el primero de la sección de ropa y **mide el estado inicial**: si
## otro caso que lo toque pasara antes, este mediría lo que dejara ese caso y no
## el arranque (misma razón por la que el primer caso de la suite mira la escena
## principal declarada).
func _player_starts_dressed_by_default() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var state := player.appearance_state()
	_context.check_equal(
		state.shirt_id, GameConfig.DEFAULT_SHIRT, "el jugador no arranca con la camiseta por defecto"
	)
	_context.check_equal(
		state.hair_id, GameConfig.DEFAULT_HAIR, "el jugador no arranca con el peinado por defecto"
	)
	var layers := _garment_layers(player)
	var shirt := layers.get(GarmentDefinition.Part.SHIRT) as GarmentLayer
	var hair := layers.get(GarmentDefinition.Part.HAIR) as GarmentLayer
	if not _context.check(shirt != null and hair != null, "al jugador le faltan las capas de ropa"):
		return
	await _settle(2)
	_context.check(
		_paints_garment(shirt, GarmentDefinition.Part.SHIRT, GameConfig.DEFAULT_SHIRT),
		"la camiseta por defecto no se dibuja al arrancar"
	)
	_context.check(
		_paints_garment(hair, GarmentDefinition.Part.HAIR, GameConfig.DEFAULT_HAIR),
		"el peinado por defecto no se dibuja al arrancar"
	)


## La ropa es cosmética: se pone y se quita, y mientras no hay nada puesto la
## capa no dibuja nada (no tapa al cuerpo con una prenda fantasma).
func _garment_can_be_put_on_and_taken_off() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	if not _context.check(actor != null, "el jugador no tiene sprite de cuerpo"):
		return
	var shirt := _garment_layers(player).get(GarmentDefinition.Part.SHIRT) as GarmentLayer
	if not _context.check(shirt != null, "el jugador no tiene capa de camiseta"):
		return

	# De entrada, sin ropa: la capa no dibuja.
	player.set_shirt(&"")
	await _settle(2)
	_context.check(not shirt.is_painting(), "sin camiseta la capa no debería pintar nada")

	# Se pone una camiseta: la capa dibuja, y su superposición no es la hoja del
	# cuerpo (si lo fuera, taparía al jugador con una segunda copia).
	player.set_shirt(GarmentCatalog.SHIRT_RED)
	await _settle(2)
	_context.check(shirt.is_painting(), "con camiseta la capa debería pintar")
	_context.check(
		shirt.texture != null and shirt.texture != actor.texture,
		"la superposición de la camiseta no puede ser la propia hoja del cuerpo"
	)
	var base: Color = GarmentCatalog.shirt(
		GarmentCatalog.SHIRT_RED
	).palette[GarmentCatalog.SKIN_BASE]
	_context.check(
		_count_overlay_color(shirt, base) > 0,
		"la superposición no trae ni un píxel del color de la camiseta"
	)

	# Se la quita: vuelve a estar como estaba.
	player.set_shirt(&"")
	await _settle(2)
	_context.check(not shirt.is_painting(), "quitada la camiseta la capa debería dejar de pintar")


## La capa no tiene reloj propio: copia fotograma, espejo, rejilla y anclaje del
## cuerpo. Se camina en las cuatro direcciones y se comprueba que en cada
## fotograma dibujado la prenda y el cuerpo coinciden.
##
## Esto es lo que impide el fallo clásico de una capa con estado propio: la ropa
## moviéndose a su aire mientras el cuerpo va por otro lado.
func _garment_follows_the_body_state() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	var shirt := _garment_layers(player).get(GarmentDefinition.Part.SHIRT) as GarmentLayer
	if not _context.check(actor != null and shirt != null, "faltan el cuerpo o la capa de ropa"):
		return

	player.set_shirt(GarmentCatalog.SHIRT_BLUE)
	await _settle(2)
	if not _context.check(shirt.is_painting(), "la capa no pinta con la camiseta puesta"):
		return

	var desync := 0
	var samples := 0
	var textures: Dictionary = {}
	for action: StringName in [&"move_right", &"move_down", &"move_left", &"move_up"]:
		Input.action_press(action, 1.0)
		for _frame: int in range(10):
			await physics_frame
			if actor.frame != shirt.frame or actor.flip_h != shirt.flip_h:
				desync += 1
			if shirt.texture != null:
				textures[shirt.texture.get_instance_id()] = true
			samples += 1
		Input.action_release(action)
	await _settle(2)

	_context.check(samples > 0, "no se llegó a caminar: el caso no mide nada")
	_context.check_equal(desync, 0, "el cuerpo y la prenda se separaron en %d fotogramas" % desync)
	_context.check(
		textures.size() >= 2,
		"la prenda no se reconstruyó por orientación: solo %d superposición(es)" % textures.size()
	)
	player.set_shirt(&"")
	await _settle(1)


## La prenda es una capa de dibujo: va encima del cuerpo (mismo `z_index`,
## después en el árbol) y no añade un solo nodo de física, así que no puede
## cambiar el combate. Se comprueba que el cuerpo de combate y la hitbox del
## jugador siguen exactamente donde estaban.
func _garment_is_a_layer_over_the_body() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as Node2D
	var shirt := player.get_node_or_null("ShirtLayer") as Node2D
	if not _context.check(actor != null and shirt != null, "faltan el cuerpo o la capa de ropa"):
		return

	player.set_shirt(GarmentCatalog.SHIRT_GREEN)
	await _settle(2)

	_context.check_equal(
		shirt.z_index, actor.z_index,
		"la capa y el cuerpo deberían dibujarse en la misma franja de z"
	)
	_context.check(
		shirt.get_index() > actor.get_index(),
		"la capa debería dibujarse después del cuerpo (encima)"
	)

	var physics := 0
	for child in shirt.get_children():
		if child is CollisionObject2D or child is Area2D or child is CollisionShape2D:
			physics += 1
	_context.check_equal(physics, 0, "la capa de ropa no debería traer nodos de física")
	_context.check(player.combat_target != null, "el jugador se quedó sin cuerpo de combate")
	_context.check(player.hitbox != null, "el jugador se quedó sin hitbox")

	player.set_shirt(&"")
	await _settle(1)


## El peinado se pinta en la parte alta de la cabeza y la camiseta en el torso, y
## las dos bandas no se solapan: ninguna capa pisa a la otra.
func _hair_paints_the_head_not_the_torso() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var layers := _garment_layers(player)
	var shirt := layers.get(GarmentDefinition.Part.SHIRT) as GarmentLayer
	var hair := layers.get(GarmentDefinition.Part.HAIR) as GarmentLayer
	if not _context.check(shirt != null and hair != null, "faltan las capas de ropa o peinado"):
		return

	player.set_shirt(GarmentCatalog.SHIRT_RED)
	player.set_hair(GarmentCatalog.HAIR_BLOND)
	await _settle(2)
	if not _context.check(hair.is_painting(), "el peinado no pintó nada"):
		return
	var hair_base: Color = GarmentCatalog.hair(
		GarmentCatalog.HAIR_BLOND
	).palette[GarmentCatalog.SKIN_BASE]
	_context.check(
		_count_overlay_color(hair, hair_base) > 0,
		"la superposición del peinado no trae ni un píxel de su color"
	)

	# Las dos superposiciones no comparten un solo píxel: el peinado está por
	# encima de la banda de la camiseta, no metido en ella.
	var shirt_image: Image = shirt.texture.get_image() if shirt.texture != null else null
	var hair_image: Image = hair.texture.get_image() if hair.texture != null else null
	if shirt_image == null or hair_image == null:
		_context.check(false, "no se pudieron leer las superposiciones para compararlas")
	else:
		var overlap := 0
		for y in range(hair_image.get_height()):
			for x in range(hair_image.get_width()):
				if hair_image.get_pixel(x, y).a8 > 0 and shirt_image.get_pixel(x, y).a8 > 0:
					overlap += 1
		_context.check_equal(overlap, 0, "el peinado y la camiseta se solapan en %d píxeles" % overlap)

	player.set_shirt(&"")
	player.set_hair(&"")
	await _settle(1)


# --- vestuario (plan de ropa y peinados, Fase 4) ---


## Sonda de entrada: un nodo corriente, sin `PROCESS_MODE_ALWAYS`, que solo cuenta lo
## que le llega. Es el testigo del caso de abajo: si el reparto de entrada respeta la
## pausa, la sonda calla con el mundo parado mientras el panel sigue oyendo.
class InputProbe extends Node:
	var seen: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		# Solo la pulsación: la suelta del mismo `_press` no dice nada de si el nodo
		# sigue oyendo con el mundo parado.
		var key := event as InputEventKey
		if key != null and key.pressed:
			seen += 1


## Deja al jugador vivo, sano y con el combate en reposo, y lo devuelve.
##
## Casi todos los casos del vestuario necesitan partir de ahí: si el caso anterior lo
## dejó muerto, aturdido o en mitad de un golpe, el panel no abre y el caso mediría
## otra cosa. Tras la muerte hacen falta unos fotogramas, porque el cuerpo se entera
## de la reaparición por el presentador, no al instante.
func _living_player() -> PlayerView:
	var session: GameSession = _game().session
	if session == null or session.player == null:
		return null
	if session.player.is_dead:
		session.respawn()
	session.player.heal(999.0)
	session.player.restore_stamina(float(GameConfig.PLAYER_MAX_STAMINA))
	var combat: MeleeCombat = session.combat
	if combat != null:
		combat.grant_invulnerability(0.0)
		combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
	var view := _player_or_report()
	if view == null:
		return null
	await _settle(3)
	return view


## Empuja una tecla al viewport como la empujaría el motor: pulsación y suelta, con el
## código físico, que es como están atadas las acciones del proyecto.
##
## Se empuja en vez de llamar al método del panel a mano porque así se mide de paso
## que la entrada llega de verdad, que es justo lo que se rompe cuando alguien olvida
## el `PROCESS_MODE_ALWAYS` del panel.
func _press(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		root.push_input(event)


## ¿La capa está pintando esa prenda? Se mira el color de la superposición y no el id:
## lo que ve el jugador es el color, y un `id` bien puesto con una superposición vacía
## se vería como si no llevara nada.
func _paints_garment(layer: GarmentLayer, part: int, id: StringName) -> bool:
	if layer == null:
		return false
	var definition := GarmentCatalog.definition(part, id)
	if definition == null:
		return false
	return _count_overlay_color(layer, definition.palette[GarmentCatalog.SKIN_BASE]) > 0


## El vestuario es la pantalla del plan de ropa: abre con C, se recorre con los ejes,
## elegir es ponerse (no hay confirmación aparte) y E cierra dejando lo elegido.
##
## Mientras está abierto el mundo está pausado, así que lo que se mide ahí es el estado
## del jugador y la vista previa; la capa del mundo se comprueba al cerrar, cuando el
## árbol vuelve a la marcha.
func _appearance_panel_opens_and_dresses() -> void:
	var player := await _living_player()
	if player == null:
		return
	var panel: AppearancePanel = _world().appearance_panel
	if not _context.check(panel != null, "el mundo no tiene pantalla de vestuario"):
		return
	if not _context.check(
		InputMap.has_action(AppearancePanel.ACTION_TOGGLE),
		"el proyecto no declara la acción de abrir el vestuario"
	):
		return
	var state := player.appearance_state()

	player.set_shirt(&"")
	player.set_hair(&"")
	await _settle(2)
	_context.check(not panel.is_open, "el vestuario arranca cerrado")
	_context.check(not panel.visible, "y oculto")
	_context.check(panel.size.x > 0.0 and panel.size.y > 0.0, "el panel quedó sin tamaño (0x0)")

	# Geometría: el panel cabe en la pantalla y sus partes no se pisan entre sí. Es la
	# comprobación que faltaba cuando el velo de la muerte nunca llegó a dibujarse por
	# medir 0x0.
	var screen := Rect2(Vector2.ZERO, panel.size)
	var box: Rect2 = panel.panel_rect()
	_context.check(screen.encloses(box), "el vestuario se sale de la pantalla: %s" % str(box))
	var preview: Rect2 = panel.preview_rect()
	_context.check(box.encloses(preview), "la vista previa se sale del panel")
	var shirt_row: Rect2 = panel.row_rect(GarmentDefinition.Part.SHIRT)
	var hair_row: Rect2 = panel.row_rect(GarmentDefinition.Part.HAIR)
	_context.check(box.encloses(shirt_row), "la fila de la camiseta se sale del panel")
	_context.check(box.encloses(hair_row), "la fila del peinado se sale del panel")
	_context.check(preview.end.y <= shirt_row.position.y, "las filas pisan la vista previa")
	_context.check(shirt_row.end.y <= hair_row.position.y, "las dos filas se solapan")

	# Abrir con la tecla de verdad.
	_press(KEY_C)
	await _settle(2)
	_context.check(panel.is_open, "C no abrió el vestuario")
	_context.check(panel.visible, "el vestuario no se enseña al abrirse")
	_context.check(self.paused, "el vestuario no pausó el mundo")
	_context.check_equal(
		panel.selected_part(), GarmentDefinition.Part.SHIRT, "no abrió en la fila de la camiseta"
	)
	_context.check_equal(
		panel.selected_id(GarmentDefinition.Part.SHIRT), &"", "no abrió en 'nada puesto'"
	)
	_context.check_equal(
		panel.row_value(GarmentDefinition.Part.SHIRT),
		GameConfig.APPEARANCE_NONE_SHIRT,
		"la fila de la camiseta no enseña 'nada'"
	)

	# Navegar es ponerse: la derecha pone la primera camiseta y no hay confirmación.
	var first_shirt := GarmentCatalog.shirt_ids()[0]
	_press(KEY_RIGHT)
	await _settle(2)
	_context.check_equal(
		panel.selected_id(GarmentDefinition.Part.SHIRT),
		first_shirt,
		"la derecha no eligió la primera camiseta"
	)
	_context.check_equal(state.shirt_id, first_shirt, "elegir una camiseta no la puso en el jugador")
	_context.check_equal(
		panel.row_value(GarmentDefinition.Part.SHIRT),
		GarmentCatalog.shirt(first_shirt).label,
		"la fila no enseña el nombre de la camiseta elegida"
	)
	# La vista previa sí se rehace con el mundo parado: es lo que se está viendo.
	var preview_shirt := panel.get_node_or_null("Preview/PreviewShirt") as GarmentLayer
	if _context.check(preview_shirt != null, "el recuadro no tiene capa de camiseta"):
		await _settle(2)
		_context.check(
			_paints_garment(preview_shirt, GarmentDefinition.Part.SHIRT, first_shirt),
			"el recuadro no dibuja la camiseta elegida con el mundo parado"
		)

	# Bajar cambia de fila sin tocar la camiseta, y elegir peinado no la desviste.
	_press(KEY_DOWN)
	await _settle(1)
	_context.check_equal(panel.selected_part(), GarmentDefinition.Part.HAIR, "abajo no cambió de fila")
	_context.check_equal(
		panel.selected_id(GarmentDefinition.Part.HAIR), &"", "el peinado no arranca en 'nada'"
	)
	_context.check_equal(state.hair_id, &"", "cambiar de fila puso un peinado solo")
	var first_hair := GarmentCatalog.hair_ids()[0]
	_press(KEY_RIGHT)
	await _settle(2)
	_context.check_equal(state.hair_id, first_hair, "elegir un peinado no lo puso")
	_context.check_equal(state.shirt_id, first_shirt, "elegir el peinado cambió la camiseta")

	# Subir vuelve a la camiseta con la elección guardada, y hacia atrás desde la
	# primera vuelve a "nada": el carrusel da la vuelta.
	_press(KEY_UP)
	await _settle(1)
	_context.check_equal(
		panel.selected_part(), GarmentDefinition.Part.SHIRT, "arriba no volvió a la camiseta"
	)
	_context.check_equal(
		panel.selected_id(GarmentDefinition.Part.SHIRT),
		first_shirt,
		"el cursor perdió la camiseta al cambiar de fila"
	)
	_press(KEY_LEFT)
	await _settle(2)
	_context.check_equal(state.shirt_id, &"", "hacia atrás desde la primera no volvió a 'nada'")

	# E cierra y lo elegido se queda: no hay borrador que descartar.
	_press(KEY_E)
	await _settle(2)
	_context.check(not panel.is_open, "E no cerró el vestuario")
	_context.check(not panel.visible, "el vestuario sigue dibujándose después de cerrarlo")
	_context.check(not self.paused, "cerrar no reanudó el mundo")
	_context.check_equal(state.hair_id, first_hair, "cerrar deshizo el peinado elegido")
	_context.check_equal(state.shirt_id, &"", "cerrar puso una camiseta que se había quitado")

	# Con el mundo en marcha la capa ya dibuja lo que quedó puesto: aquí sí.
	var shirt := _garment_layers(player).get(GarmentDefinition.Part.SHIRT) as GarmentLayer
	var hair := _garment_layers(player).get(GarmentDefinition.Part.HAIR) as GarmentLayer
	await _settle(2)
	_context.check(not shirt.is_painting(), "la camiseta quitada sigue dibujándose en el mundo")
	_context.check(
		_paints_garment(hair, GarmentDefinition.Part.HAIR, first_hair),
		"el peinado elegido no llega a dibujarse en el mundo"
	)

	# Reabrir con C coloca el cursor donde está el jugador, no en la primera opción.
	_press(KEY_C)
	await _settle(2)
	_context.check(panel.is_open, "C no volvió a abrir el vestuario")
	_context.check_equal(
		panel.selected_id(GarmentDefinition.Part.SHIRT),
		&"",
		"al reabrir, el cursor no abrió en la camiseta que llevaba (ninguna)"
	)
	_context.check_equal(
		panel.selected_id(GarmentDefinition.Part.HAIR),
		first_hair,
		"al reabrir, el cursor no abrió en el peinado que lleva puesto"
	)
	_press(KEY_C)
	await _settle(2)
	_context.check(not panel.is_open, "la segunda C no cerró el vestuario")
	_context.check(not self.paused, "y dejó el mundo pausado")

	player.set_shirt(&"")
	player.set_hair(&"")
	await _settle(2)


## El vestuario va en `PROCESS_MODE_ALWAYS` porque con el mundo parado tiene que seguir
## oyendo la entrada: si no, la tecla de cerrar no haría nada y el mundo se quedaría
## pausado para siempre.
##
## El caso no se fía de leer el `process_mode`: comprueba que un nodo corriente del
## árbol **no** recibe la entrada con el mundo parado y que el panel sí. Con las dos
## mitades, el testigo demuestra que el reparto respeta la pausa.
func _appearance_hears_input_while_paused() -> void:
	var panel: AppearancePanel = _world().appearance_panel
	if not _context.check(panel != null, "el mundo no tiene pantalla de vestuario"):
		return
	var player := await _living_player()
	if player == null:
		return
	var probe := InputProbe.new()
	probe.name = "InputProbe"
	root.add_child(probe)
	await _settle(1)

	# En marcha la sonda oye: así vale como testigo de lo de abajo.
	_press(KEY_B)
	await _settle(1)
	_context.check_equal(probe.seen, 1, "el reparto de entrada no llega al árbol")

	_context.check(panel.open(), "el vestuario no se abre")
	_context.check(self.paused, "el vestuario no pausa el mundo")
	_context.check_equal(
		panel.process_mode, Node.PROCESS_MODE_ALWAYS, "el vestuario no está en PROCESS_MODE_ALWAYS"
	)
	probe.seen = 0
	_press(KEY_B)
	await _settle(1)
	_context.check_equal(
		probe.seen, 0, "con el mundo parado un nodo corriente no debería oír la entrada"
	)
	_context.check(panel.is_open, "el vestuario se cerró solo")

	# Y el panel sí la oye: C lo cierra con el árbol parado.
	_press(KEY_C)
	await _settle(1)
	_context.check(not panel.is_open, "con el mundo parado, C no cerró el vestuario")
	_context.check(not self.paused, "al cerrar, el mundo no volvió a la marcha")

	probe.queue_free()
	await _settle(1)


## El mundo se pausa una sola vez: dos paneles abiertos a la vez lo dejarían corriendo
## al cerrar el primero (cada uno des-pausa al cerrarse). Se comprueba por los dos
## lados, porque la regla vale en los dos sentidos.
func _appearance_and_backpack_are_exclusive() -> void:
	var player := await _living_player()
	if player == null:
		return
	var appearance: AppearancePanel = _world().appearance_panel
	var backpack: InventoryPanel = _world().inventory_panel
	if not _context.check(
		appearance != null and backpack != null, "faltan el vestuario o la mochila"
	):
		return
	_context.check(not self.paused, "el mundo no está en marcha para empezar")

	_context.check(appearance.open(), "el vestuario no se abre")
	_context.check(self.paused, "y no pausa el mundo")
	_context.check(not backpack.open(), "la mochila se abrió encima del vestuario")
	_context.check(appearance.is_open, "y cerró el vestuario")
	_context.check(self.paused, "el mundo sigue pausado")
	appearance.close()
	_context.check(not self.paused, "al cerrar el vestuario el mundo vuelve a la marcha")

	_context.check(backpack.open(), "la mochila no se abre")
	_context.check(self.paused, "y no pausa el mundo")
	_context.check(not appearance.open(), "el vestuario se abrió encima de la mochila")
	_context.check(backpack.is_open, "y cerró la mochila")
	_context.check(self.paused, "el mundo sigue pausado")
	backpack.close()
	_context.check(not self.paused, "al cerrar la mochila el mundo vuelve a la marcha")


## Elegir ropa no es algo que se haga muerto: abrir el vestuario con la pantalla de
## muerte delante pausaría el mundo detrás de ella y rompería la reaparición.
##
## De paso se mide que la muerte llega a la vista, que es lo que sincroniza el
## presentador: sin eso el guardián del vestuario no tendría de dónde leer.
func _appearance_refuses_when_dead() -> void:
	var player := await _living_player()
	if player == null:
		return
	var appearance: AppearancePanel = _world().appearance_panel
	if not _context.check(appearance != null, "el mundo no tiene pantalla de vestuario"):
		return
	var session: GameSession = _game().session
	var actor := player.get_node_or_null("Actor") as ActorSprite
	if not _context.check(actor != null, "el jugador no tiene sprite de cuerpo"):
		return

	session.player.take_damage(session.player.health.maximum)
	await _settle(3)
	_context.check(session.player.is_dead, "el jugador no murió")
	_context.check(player.is_dead(), "la vista no se enteró de la muerte: nadie dibuja la pose")
	_context.check_equal(
		actor.current_clip(), ActorSprite.DEAD, "el cuerpo muerto no usa la animación de morir"
	)
	_context.check(not appearance.open(), "el vestuario se abre con el jugador muerto")
	_context.check(not self.paused, "y no debería haber pausado el mundo detrás de la muerte")

	# Al reaparecer vuelve a poder abrirse.
	session.respawn()
	await _settle(3)
	_context.check(not player.is_dead(), "al reaparecer la vista sigue dibujando la muerte")
	_context.check(
		actor.current_clip() != ActorSprite.DEAD, "el cuerpo revivido sigue con la animación de morir"
	)
	_context.check(appearance.open(), "y con el jugador vivo el vestuario no se abre")
	appearance.close()
	await _settle(2)


## La vista previa es un espejo del cuerpo, no un muñeco aparte: copia su hoja,
## fotograma, anclaje y espejo, y sus capas de ropa apuntan al cuerpo de verdad. Si el
## recuadro tuviera estado propio podría enseñar una prenda que el jugador no lleva.
func _appearance_preview_mirrors_the_body() -> void:
	var player := await _living_player()
	if player == null:
		return
	var panel: AppearancePanel = _world().appearance_panel
	if not _context.check(panel != null, "el mundo no tiene pantalla de vestuario"):
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	var mirror := panel.get_node_or_null("Preview") as Node2D
	var body := panel.get_node_or_null("Preview/PreviewBody") as Sprite2D
	var preview_shirt := panel.get_node_or_null("Preview/PreviewShirt") as GarmentLayer
	var preview_hair := panel.get_node_or_null("Preview/PreviewHair") as GarmentLayer
	if not _context.check(
		actor != null and mirror != null and body != null
		and preview_shirt != null and preview_hair != null,
		"falta el espejo de la vista previa"
	):
		return

	# El espejo se mide contra el cuerpo del jugador y la coreografía dura varios
	# fotogramas con el panel abierto. Un enemigo de la zona que le entre en ese hueco
	# cambia el estado del cuerpo (golpe, aturdimiento, muerte) por debajo del caso, y
	# entonces el espejo copia una hoja que el caso no puso: la medición se vuelve una
	# carrera contra la IA y falla según le toque (medido: con el editor y varias
	# instancias de juego comiendo CPU falló; en reposo, verde). Se deja la zona limpia
	# y al jugador invulnerable, que es lo que ya hace el caso de la animación.
	_clear_zone()
	var session: GameSession = _game().session
	var combat: MeleeCombat = session.combat if session != null else null
	if combat != null:
		combat.grant_invulnerability(60.0)

	player.set_shirt(GarmentCatalog.SHIRT_PURPLE)
	player.set_hair(GarmentCatalog.HAIR_BLUE)
	await _settle(2)
	_context.check(panel.open(), "el vestuario no se abre")
	await _settle(2)

	# Las capas del recuadro no tienen estado propio: apuntan al cuerpo y al estado de
	# ropa del jugador, literalmente.
	_context.check(
		preview_shirt.actor == actor and preview_hair.actor == actor,
		"las capas del recuadro no apuntan al cuerpo de verdad"
	)
	_context.check(
		preview_shirt.appearance == player.appearance_state(),
		"el recuadro no comparte el estado de ropa del jugador"
	)

	# El espejo copia lo que el cuerpo está dibujando, campo a campo.
	_context.check_equal(body.texture, actor.texture, "el espejo no copió la hoja del cuerpo")
	_context.check_equal(body.frame, actor.frame, "el espejo no copió el fotograma")
	_context.check_equal(body.hframes, actor.hframes, "el espejo no copió las columnas de la rejilla")
	_context.check_equal(body.vframes, actor.vframes, "el espejo no copió las filas de la rejilla")
	_context.check_equal(body.offset, actor.offset, "el espejo no copió el anclaje")
	_context.check_equal(body.flip_h, actor.flip_h, "el espejo no copió el espejo horizontal")
	_context.check_equal(body.centered, actor.centered, "el espejo no copió el centrado")

	# Y se dibuja dentro del recuadro, con los pies apoyados cerca del borde bajo. Se
	# mide el rectángulo que se dibuja de verdad, no la posición del nodo.
	var box := panel.preview_rect()
	var drawn := body.get_rect()
	drawn.position += mirror.position
	_context.check(box.encloses(drawn), "el espejo no cabe en el recuadro: %s fuera de %s" % [str(drawn), str(box)])
	_context.check(
		drawn.end.y >= box.end.y - 16.0,
		"el espejo queda despegado del suelo del recuadro: %s contra %s" % [str(drawn), str(box)]
	)
	_context.check(
		_paints_garment(preview_shirt, GarmentDefinition.Part.SHIRT, GarmentCatalog.SHIRT_PURPLE)
		and _paints_garment(preview_hair, GarmentDefinition.Part.HAIR, GarmentCatalog.HAIR_BLUE),
		"el recuadro no enseña la ropa que lleva puesta el jugador"
	)

	# El espejo sigue al cuerpo aunque el cuerpo no se mueva: se le cambia la
	# orientación (el presentador está parado, así que se queda) y el recuadro tiene
	# que copiar la hoja nueva. Se parte de una orientación puesta a mano y no de la
	# que dejara el caso anterior, que depende de por dónde acabara caminando.
	player.set_facing(Vector2.DOWN)
	await _settle(2)
	var before_sheet := body.texture
	player.set_facing(Vector2.UP)
	await _settle(2)
	_context.check(body.texture != before_sheet, "el espejo no siguió el cambio de orientación")
	_context.check_equal(
		body.texture, actor.texture, "el espejo no copió la hoja de la orientación nueva"
	)
	_context.check_equal(body.offset, actor.offset, "el espejo no copió el anclaje de la orientación nueva")
	player.set_facing(Vector2.DOWN)
	await _settle(2)

	# Y lo que enseña el recuadro es la misma superposición que acaba en el mundo, no
	# una parecida: se elige otra camiseta desde el menú y se comparan los píxeles.
	panel.move_selection(Vector2i(1, 0))
	await _settle(2)
	var chosen := player.appearance_state().shirt_id
	_context.check(chosen != GarmentCatalog.SHIRT_PURPLE, "elegir no cambió de camiseta")
	_context.check(
		_paints_garment(preview_shirt, GarmentDefinition.Part.SHIRT, chosen),
		"el recuadro no se rehízo al elegir otra camiseta"
	)
	var preview_image := preview_shirt.texture.get_image().get_data()
	panel.close()
	await _settle(2)
	var world_shirt := _garment_layers(player).get(GarmentDefinition.Part.SHIRT) as GarmentLayer
	if not _context.check(
		world_shirt != null and world_shirt.texture != null, "el mundo no dibuja la camiseta elegida"
	):
		return
	_context.check_equal(
		preview_image,
		world_shirt.texture.get_image().get_data(),
		"el recuadro y el mundo no enseñan la misma camiseta"
	)

	player.set_shirt(&"")
	player.set_hair(&"")
	await _settle(2)


## La ropa no toca la animación: con camiseta y peinado puestos el cuerpo camina, golpea
## y muere igual, y las dos capas siguen al cuerpo sin separarse. Se mide además que
## elegir ropa no cambia ni la vida, ni la posición, ni el cuerpo de combate.
func _garment_does_not_break_the_animation() -> void:
	var player := await _living_player()
	if player == null:
		return
	var actor := player.get_node_or_null("Actor") as ActorSprite
	var layers := _garment_layers(player)
	var shirt := layers.get(GarmentDefinition.Part.SHIRT) as GarmentLayer
	var hair := layers.get(GarmentDefinition.Part.HAIR) as GarmentLayer
	if not _context.check(
		actor != null and shirt != null and hair != null, "faltan el cuerpo o las capas de ropa"
	):
		return
	var panel: AppearancePanel = _world().appearance_panel
	if not _context.check(panel != null, "el mundo no tiene pantalla de vestuario"):
		return
	var session: GameSession = _game().session
	var combat: MeleeCombat = session.combat
	if not _context.check(combat != null, "la sesión no tiene combate"):
		return

	# Los enemigos de la zona no deben meter ruido en una secuencia de dos segundos.
	_clear_zone()
	combat.grant_invulnerability(60.0)
	player.set_shirt(&"")
	player.set_hair(&"")
	await _settle(2)

	# Elegir ropa no puede tocar nada del juego: se recorre el menú entero y se compara.
	var health: float = session.player.health.current
	var stamina: float = session.player.stamina
	var position := player.global_position
	var target := player.combat_target
	var sensor := player.hitbox
	_context.check(panel.open(), "el vestuario no se abre")
	for _step: int in range(GarmentCatalog.shirt_ids().size() + 1):
		panel.move_selection(Vector2i(1, 0))
		await _settle(1)
	panel.move_selection(Vector2i(0, 1))
	for _step: int in range(GarmentCatalog.hair_ids().size() + 1):
		panel.move_selection(Vector2i(1, 0))
		await _settle(1)
	panel.close()
	await _settle(2)
	_context.check_equal(session.player.health.current, health, "elegir ropa cambió la vida")
	_context.check_equal(session.player.stamina, stamina, "elegir ropa cambió la stamina")
	_context.check_equal(player.global_position, position, "elegir ropa movió al jugador")
	_context.check(player.combat_target == target, "elegir ropa cambió el cuerpo de combate")
	_context.check(player.hitbox == sensor, "elegir ropa cambió la hitbox")

	# Con ropa puesta, caminar: el cuerpo se mueve y la prenda lo sigue en cada fotograma.
	player.set_shirt(GarmentCatalog.SHIRT_YELLOW)
	player.set_hair(GarmentCatalog.HAIR_BLACK)
	await _settle(2)
	var desync := 0
	var walked := false
	for action: StringName in [&"move_right", &"move_left", &"move_up", &"move_down"]:
		var from := player.global_position
		Input.action_press(action, 1.0)
		for _frame: int in range(12):
			await physics_frame
			if actor.frame != shirt.frame or actor.flip_h != shirt.flip_h or actor.offset != shirt.offset:
				desync += 1
		Input.action_release(action)
		walked = walked or player.global_position != from
	await _settle(2)
	_context.check(walked, "con ropa el jugador no se movió en ninguna dirección")
	_context.check_equal(desync, 0, "caminando con ropa, la prenda y el cuerpo se separaron %d veces" % desync)
	_context.check(shirt.is_painting(), "caminando con ropa, la camiseta dejó de pintar")

	# Golpear: el cuerpo usa su animación de golpe y la prenda la sigue.
	Input.action_press(&"attack", 1.0)
	var attack_clips: Dictionary = {}
	var attack_desync := 0
	for frame: int in range(30):
		await physics_frame
		if frame == 2:
			Input.action_release(&"attack")
		if ActorSprite.is_attack_clip(actor.current_clip()):
			attack_clips[str(actor.current_clip())] = true
			if actor.frame != shirt.frame or actor.flip_h != shirt.flip_h:
				attack_desync += 1
	await _settle(int(ceil(GameConfig.ATTACK_RECOVERY * 60.0)) + 6)
	_context.check(not attack_clips.is_empty(), "con ropa el cuerpo no llegó a golpear")
	_context.check_equal(attack_desync, 0, "golpeando con ropa, la prenda y el cuerpo se separaron")
	_context.check(shirt.is_painting(), "golpeando con ropa, la camiseta dejó de pintar")

	# Morir: la vista se entera (pose yacente) y la prenda sigue el clip de la muerte.
	combat.grant_invulnerability(0.0)
	session.player.take_damage(session.player.health.maximum)
	await _settle(3)
	_context.check(player.is_dead(), "con ropa el cuerpo no se enteró de la muerte")
	_context.check_equal(
		actor.current_clip(), ActorSprite.DEAD, "con ropa el cuerpo muerto no usa el clip de morir"
	)
	await _settle(2)
	_context.check(shirt.is_painting(), "muerto, la camiseta dejó de pintar")
	_context.check_equal(shirt.frame, actor.frame, "muerto, la prenda no sigue el fotograma del cuerpo")

	# Y la reaparición lo devuelve todo.
	session.respawn()
	await _settle(3)
	_context.check(not player.is_dead(), "al reaparecer el cuerpo sigue muerto")
	_context.check(
		actor.current_clip() != ActorSprite.DEAD, "el cuerpo revivido sigue en la animación de morir"
	)
	player.set_shirt(&"")
	player.set_hair(&"")
	await _settle(2)


## La cámara tiembla cuando un golpe conecta (sección 37), y el temblor se
## disuelve solo. Se mide el cableado completo: la señal `impact_struck` del
## combate llega al mundo y este pide la sacudida a la cámara.
func _camera_shakes_on_impact() -> void:
	var camera = _world().camera
	if not _context.check(camera != null, "el mundo no tiene cámara"):
		return
	var combat: MeleeCombat = _game().session.combat
	if not _context.check(combat != null, "la sesión no tiene combate"):
		return
	_clear_zone()
	await _settle(15)
	# Partida de cero, por si el caso anterior dejó al jugador aturdido o sin vida.
	combat.grant_invulnerability(0.0)
	combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
	_game().session.player.restore_stamina(float(GameConfig.PLAYER_MAX_STAMINA))
	_game().session.player.heal(999.0)
	camera.offset = Vector2.ZERO
	await _settle(2)

	# Sacudida directa: se pide y se disuelve al agotar el tiempo fijo.
	camera.shake(GameConfig.CAMERA_SHAKE_HEAVY)
	_context.check(camera.is_shaking(), "pedir la sacudida la enciende")
	var frames := int(ceil(GameConfig.CAMERA_SHAKE_TIME * 60.0)) + 3
	await _settle(frames)
	_context.check(not camera.is_shaking(), "y se apaga sola al agotarse el tiempo")
	_context.check_equal(camera.offset, Vector2.ZERO, "dejando el offset en cero")

	# Sacudida por el cableado: un golpe que entra al jugador pasó por la señal
	# que `connect_cases` conectó a la cámara.
	var dealt := combat.take_attack(
		AttackCatalog.of(AttackCatalog.LEFT_HOOK), 12.0, Vector2.LEFT
	)
	_context.check(dealt > 0.0, "el golpe entra al jugador")
	_context.check(camera.is_shaking(), "y la cámara tiembla por el cableado del mundo")
	await _settle(frames)


## El hit stop llega al presentador con los presentadores encendidos, y el
## congelamiento se agota solo con el reloj de la presentación: es el freeze de
## verdad, no el contador de un test que avanza a mano.
func _hit_stop_freezes_and_drains() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var presenter := player.get_node_or_null("Presenter") as PlayerPresenter
	if not _context.check(presenter != null, "el jugador no tiene presentador"):
		return
	var combat: MeleeCombat = _game().session.combat
	if not _context.check(combat != null, "la sesión no tiene combate"):
		return

	combat.grant_invulnerability(0.0)
	combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
	_game().session.player.restore_stamina(float(GameConfig.PLAYER_MAX_STAMINA))
	_game().session.player.heal(999.0)
	await _settle(2)

	var dealt := combat.take_attack(
		AttackCatalog.of(AttackCatalog.LEFT_HOOK), 12.0, Vector2.LEFT
	)
	_context.check(dealt > 0.0, "el golpe entra al jugador")
	_context.check(presenter.is_hit_stopped(), "y el presentador queda congelado")
	_context.check_almost_equal(
		presenter.hit_stop_remaining(),
		CombatImpact.hit_stop_of(AttackCatalog.of(AttackCatalog.LEFT_HOOK).knockback),
		"con el tiempo del tier del ataque"
	)

	var waited := 0
	while presenter.is_hit_stopped() and waited < 120:
		await physics_frame
		waited += 1
	_context.check(not presenter.is_hit_stopped(), "y se descongela solo al agotarse")
	_context.check(waited < 120, "el descongelado no necesitó el límite de espera")


## El HUD de depuración (sección 34) se enciende, muestra las líneas de la
## sección y se apaga, tanto por su API como por la tecla F1 a través del mundo.
func _debug_hud_toggles_and_lines() -> void:
	var hud = _world().hud
	if not _context.check(hud != null, "el mundo no tiene HUD"):
		return

	hud.set_debug_enabled(true)
	_context.check(hud.is_debug_enabled(), "el HUD de depuración se enciende")
	var lines: Array[String] = hud.debug_lines()
	_context.check(
		lines.size() >= 8,
		"el HUD de depuración no trae las líneas de la sección 34: %d" % lines.size()
	)
	if lines.size() > 0:
		_context.check(
			str(lines[0]).begins_with("HP:"), "la primera línea es la vida: %s" % lines[0]
		)
	_context.check(
		lines.any(func(line: String) -> bool: return line.begins_with("COMBO:")),
		"y hay línea de combo en %s" % str(lines)
	)
	_context.check(
		lines.any(func(line: String) -> bool: return line.begins_with("STATE:")),
		"y línea de estado"
	)

	# F1 conmuta desde el mundo: se entrega el evento a mano, porque el driver
	# headless no reparte eventos de teclado.
	var f1 := InputEventKey.new()
	f1.physical_keycode = KEY_F1
	f1.pressed = true
	_world()._unhandled_input(f1)
	await _settle(1)
	_context.check(not hud.is_debug_enabled(), "pulsar F1 apaga el HUD de depuración")
	hud.set_debug_enabled(false)


## La geometría de depuración (sección 35) es la de la física: el círculo de la
## hitbox sale delante del cuerpo, hacia la mirada, con la distancia y el radio
## que usa `HitboxSensor`. Y F2 conmuta el dibujo global desde el mundo.
func _debug_hitboxes_geometry_and_toggle() -> void:
	var player := _player_or_report()
	if player == null:
		return
	var hitbox := player.hitbox
	if not _context.check(hitbox != null, "el jugador no tiene hitbox"):
		return
	_clear_zone()
	await _settle(2)

	player.set_facing(Vector2.RIGHT)
	await _settle(1)
	var circle := CombatDebug.hitbox_circle(player)
	var expected_center: Vector2 = player.global_position \
		+ Vector2.RIGHT * hitbox.reach * GameConfig.HITBOX_FORWARD_RATIO
	_context.check_almost_equal(
		float(Vector2(circle["center"]).distance_to(expected_center)),
		0.0,
		"el centro de la hitbox sale delante, hacia la mirada"
	)
	_context.check_almost_equal(
		float(circle["radius"]),
		hitbox.reach * GameConfig.HITBOX_RADIUS_RATIO,
		"y su radio es el de la geometría del golpe"
	)
	_context.check_almost_equal(
		float(CombatDebug.hurtbox_circle(player)["radius"]),
		player.hurtbox_radius(),
		"la hurtbox dibuja el radio del cuerpo"
	)

	# F2 conmuta el interruptor global; se devuelve al final para no dejar el
	# mundo dibujando en depuración para los casos siguientes.
	var before := CombatDebug.show
	var f2 := InputEventKey.new()
	f2.physical_keycode = KEY_F2
	f2.pressed = true
	_world()._unhandled_input(f2)
	await _settle(1)
	_context.check_equal(CombatDebug.show, not before, "pulsar F2 conmuta el dibujo de hitboxes")
	if CombatDebug.show != before:
		CombatDebug.toggle()


# --- muñeco de entrenamiento (seccion 33) ---

func _collect_dummies(from: Node, into: Array) -> void:
	if from is CombatDummySpawner:
		into.append(from)
	for child: Node in from.get_children():
		_collect_dummies(child, into)


## El muñeco está en el mundo como un elemento pasivo, no como un enemigo: un
## solo generador (si un segundo mundo montara otro, habría dos, como pasó con
## el jugador), un cuerpo en la capa de los objetivos de golpe que expone su
## cuerpo de combate, con su tinte de piedra y sin moverse ni pegar aunque el
## jugador se le eche encima.
func _dummy_exists_and_is_passive() -> void:
	var spawner: CombatDummySpawner = _world().dummy_spawner
	if not _context.check(spawner != null, "el mundo no tiene muñeco de combate"):
		return
	_clear_zone()
	await _settle(2)

	var found: Array = []
	_collect_dummies(root, found)
	_context.check(
		found.size() == 1,
		"hay %d muñecos en el árbol (se esperaba 1)" % found.size()
	)

	var view := spawner.view()
	if not _context.check(
		view != null and is_instance_valid(view), "el muñeco no tiene cuerpo"
	):
		return
	_context.check(
		view.collision_layer == CollisionLayers.NPC,
		"el cuerpo está en la capa de los objetivos de golpe"
	)
	_context.check(
		DamageRules.is_damageable(view.combat_target),
		"y expone su cuerpo de combate como objetivo (la hitbox del jugador le pega)"
	)
	_context.check_equal(
		spawner.dummy().kind, CombatDummy.KIND, "con su identidad de muñeco"
	)
	_context.check_equal(
		spawner.dummy().health.ratio, 1.0, "con la vida llena al arrancar"
	)

	# Pasivo: ni se mueve solo ni le pega al jugador. Se observa un rato y las
	# dos medidas tienen que quedarse quietas.
	var start: Vector2 = view.global_position
	var life: float = _game().session.player.health.current
	for _frame: int in range(30):
		await physics_frame
	_context.check(
		view.global_position.distance_to(start) < 0.5,
		"el muñeco no se mueve solo"
	)
	_context.check(
		_game().session.player.health.current >= life,
		"y el jugador no recibe daño (el muñeco no pega)"
	)
	_context.check_equal(
		view.modulate, GameConfig.DUMMY_TINT,
		"y lleva el aspecto de muñeco, no el de un enemigo"
	)


## Un golpe de verdad del jugador (presentador encendido, sin atajos de prueba)
## entra en el muñeco y le produce la cadena entera de la sección 33: la vida
## baja, reproduce el clip de reacción, queda aturdido un instante y el retroceso
## lo desplaza. El muñeco no devuelve nada.
func _dummy_takes_a_hit_and_reacts() -> void:
	var spawner: CombatDummySpawner = _world().dummy_spawner
	if not _context.check(spawner != null, "el mundo no tiene muñeco de combate"):
		return
	var player := _player_or_report()
	if player == null:
		return
	_clear_zone()

	# Partida de cero para el jugador: el aturdimiento de otro caso deja bloqueado
	# el movimiento, y la invulnerabilidad pendiente se drena con el reloj. Si no,
	# las teclas no le moverían (es la fuga de estado que rompió un caso de F6).
	var combat: MeleeCombat = _game().session.combat
	combat.grant_invulnerability(0.0)
	combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
	_game().movement.advance(1000.0)
	_game().movement.external_velocity = Vector2.ZERO
	_game().session.player.restore_stamina(float(GameConfig.PLAYER_MAX_STAMINA))
	_game().session.player.heal(999.0)
	# Los casos anteriores movieron al jugador y puede estar en cualquier lado: se
	# lo acerca al muñeco por la vía única de teleportación (dominio y vista van
	# juntos) para empezar a tiro. Si algún caso lo dejó muerto, se lo revive.
	const APPROACH := Vector2(200.0, 202.0)
	if _game().session.player.is_dead:
		_game().session.respawn(APPROACH)
	else:
		_game().session.teleport_to(APPROACH)
	await _settle(4)

	var dummy := spawner.dummy()
	var view := spawner.view()
	var health_before: float = dummy.health.current
	var start: Vector2 = view.global_position

	# Se camina hacia el muñeco hasta quedar dentro del alcance del puñetazo; el
	# propio cuerpo del muñeco para al jugador rozándolo (a 10 px, dentro del
	# alcance 12 de la hitbox).
	Input.action_press(&"move_down", 1.0)
	var reached := false
	var distance := player.global_position.distance_to(view.global_position)
	for _frame: int in range(120):
		await physics_frame
		distance = player.global_position.distance_to(view.global_position)
		if distance <= 11.5:
			reached = true
			break
	Input.action_release(&"move_down")
	await _settle(4)
	if not _context.check(
		reached, "el jugador no llegó a ponerse a tiro (se quedó a %.1f px)" % distance
	):
		return

	# Puñetazo real, y muestreo desde el propio fotograma de la pulsación: la
	# reacción y el aturdimiento son ventanas cortas y no se pueden mirar en un
	# instante suelto.
	var saw_reaction := false
	var saw_stun := false
	var max_displacement := 0.0
	Input.action_press(&"attack", 1.0)
	var swing := int(ceil(GameConfig.ATTACK_RECOVERY * 60.0)) + 12
	for _frame: int in range(swing):
		await physics_frame
		if _frame == 1:
			# El patrón probado: la pulsación dura dos fotogramas de física antes de
			# soltarse, y el golpe arranca durante esos dos.
			Input.action_release(&"attack")
		if view.reaction_clip() != &"":
			saw_reaction = true
		if spawner.combat().is_stunned:
			saw_stun = true
		max_displacement = maxf(
			max_displacement, view.global_position.distance_to(start)
		)
	await _settle(6)

	_context.check(
		dummy.health.current < health_before,
		"el golpe del jugador entra (de %s a %s)" % [health_before, dummy.health.current]
	)
	_context.check(not dummy.is_dead, "y de un puñetazo no muere")
	_context.check(saw_reaction, "reproduce el clip de reacción")
	_context.check(saw_stun, "y queda aturdido un instante")
	_context.check(
		max_displacement > 1.0,
		"y el retroceso lo desplaza (%.2f px)" % max_displacement
	)
	_context.check_equal(
		_game().session.player.health.current,
		_game().session.player.health.maximum,
		"y el jugador no recibe nada a cambio"
	)


## El hit stop no es solo del jugador: la F6 lo enchufó a las dos puntas del
## golpe, pero solo la del jugador tenía pruebas. Aquí se congela el presentador
## del muñeco con un golpe controlado de tier alto (25 de daño, reloj de 0.07 s)
## y se comprueba que el reloj lo suelta solo.
func _dummy_presenter_hit_stops() -> void:
	var spawner: CombatDummySpawner = _world().dummy_spawner
	if not _context.check(spawner != null, "el mundo no tiene muñeco de combate"):
		return
	var combat := spawner.combat()
	combat.advance(GameConfig.NPC_INVULNERABILITY_TIME + 1.0)
	var dealt := combat.take_attack(
		AttackCatalog.of(AttackCatalog.LEFT_HOOK), 25.0, Vector2.UP
	)
	_context.check(dealt > 0.0, "el golpe entra")
	_context.check(
		spawner.presenter().is_hit_stopped(),
		"y congela al presentador del muñeco"
	)
	var waited := 0
	while spawner.presenter().is_hit_stopped() and waited < 120:
		await physics_frame
		waited += 1
	_context.check(
		not spawner.presenter().is_hit_stopped(),
		"y se descongela solo al agotarse el reloj"
	)
	# El golpe dejó al muñeco herido y aturdido: drenar para que el caso de la
	# muerte siguiente empiece con un golpe limpio.
	combat.advance(GameConfig.NPC_INVULNERABILITY_TIME + 1.0)
	await _settle(2)


## La muerte del muñeco se ve (queda en la pose de muerte, apagado) y a los dos
## segundos de `DUMMY_RESPAWN_TIME` reaparece entero en su puesto, con la vida
## llena y sin tintes de estado encima.
func _dummy_dies_and_respawns() -> void:
	var spawner: CombatDummySpawner = _world().dummy_spawner
	if not _context.check(spawner != null, "el mundo no tiene muñeco de combate"):
		return
	var combat := spawner.combat()
	var dummy := spawner.dummy()
	var view := spawner.view()
	# El caso anterior lo dejó aturdido e invulnerable: se drena el reloj para que
	# el golpe de prueba entre.
	combat.advance(GameConfig.NPC_INVULNERABILITY_TIME + 1.0)

	var dealt := combat.take_attack(
		AttackCatalog.of(AttackCatalog.LEFT_HOOK), 999.0, Vector2.UP
	)
	_context.check(dealt > 0.0, "el golpe de prueba entra")
	_context.check(dummy.is_dead, "y el muñeco muere")
	# El golpe matador congela al presentador del muñeco con su hit stop (el tier
	# alto son 0.07 s): hasta que ese reloj no se drena, `_sync_state` no corre y
	# la vista no se entera de la muerte. Esperar el hit stop antes de mirarla.
	var stop_frames := int(ceil(GameConfig.HIT_STOP_HEAVY * 60.0)) + 2
	await _settle(stop_frames)
	var actor := view.get_node_or_null("Actor") as ActorSprite
	if actor != null:
		_context.check_equal(actor.current_clip(), ActorSprite.DEAD, "en la pose de muerte")
	_context.check(
		view.modulate != GameConfig.DUMMY_TINT and view.modulate.a < 1.0,
		"y la vista lo muestra apagado y casi transparente"
	)

	# La reaparición (opcional en la sección 33; aquí 2 s) la mueve el generador
	# con su propio reloj de física: se espera la cuenta y vuelve entero al puesto.
	var waited := 0
	var cap := int(ceil(GameConfig.DUMMY_RESPAWN_TIME * 60.0)) + 8
	var respawned := false
	while not respawned and waited <= cap:
		await physics_frame
		waited += 1
		respawned = (
			dummy.is_alive
			and view.global_position.distance_to(GameConfig.DUMMY_SPAWN) < 0.5
		)
	_context.check(
		respawned,
		"reaparece a los %d fotogramas (se esperaban %d)" % [
			waited, int(ceil(GameConfig.DUMMY_RESPAWN_TIME * 60.0))
		]
	)
	await _settle(6)
	_context.check_equal(dummy.health.ratio, 1.0, "con la vida llena")
	_context.check_equal(view.modulate, GameConfig.DUMMY_TINT, "y sin tintes de estado encima")