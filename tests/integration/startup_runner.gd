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
	await _check("con la zona despejada nada se ata al jugador", _nothing_blocks_the_player)

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


func _names(nodes: Array) -> String:
	var labels: Array[String] = []
	for node in nodes:
		labels.append("%s(%s, padre %s)" % [node.name, node.get_instance_id(), node.get_parent().name])
	return ", ".join(labels)