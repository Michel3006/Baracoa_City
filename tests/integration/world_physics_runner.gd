extends SceneTree

## Tests de integración del mundo con física real (secciones 7 y 9 del MVP).
##
## Uso: godot --headless --script res://tests/integration/world_physics_runner.gd
##
## Estos tests necesitan `SceneTree` porque `move_and_slide()` solo resuelve
## colisiones cuando el servidor de física ha avanzado. Por eso viven aparte de
## los tests unitarios, que no dependen de ninguna escena.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HOUSE_TILE := Vector2i(14, 30)
const TREE_TILE := Vector2i(9, 24)
const DELTA := 1.0 / 60.0

var _context: ScriptTestContext
var _total: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_context = ScriptTestContext.new()
	print("== Tests de integracion (mundo y fisica) ==")

	# El presentador lee el teclado; en un test headless interfiere con el
	# controlador que estos tests manejan a mano.
	_view().presenter.set_physics_process(false)

	await _check("el jugador se mueve en un espacio libre", _moves_in_open_space)
	await _check("el jugador no atraviesa la casa", _blocked_by_house)
	await _check("un arbol tambien bloquea", _blocked_by_tree)
	await _check("el muro de la zona contiene al jugador", _contained_by_bounds)
	await _check("el dominio refleja la posicion real", _domain_mirrors_position)
	await _check("mover y parar alterna IDLE y MOVING", _state_follows_motion)

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


func _game() -> Node:
	return root.get_node("Game")


func _view() -> MainWorldView:
	return _game().world_view


func _player() -> PlayerView:
	return _view().player


func _movement() -> MovementController:
	return _game().movement


func _domain() -> Player:
	return _game().session.player


func _step(intent: Vector2, frames: int) -> void:
	for _frame: int in range(frames):
		_movement().move(DELTA, intent)
		await physics_frame


func _place(at: Vector2) -> void:
	_game().session.teleport_to(at)
	await physics_frame


func _moves_in_open_space() -> void:
	await _place(Vector2(512, 320))
	var start := _player().global_position
	await _step(Vector2.RIGHT, 30)
	var moved := _player().global_position.x - start.x
	_context.check(moved > 50.0, "debe avanzar al menos 50 px, avanzó %.1f" % moved)


func _blocked_by_house() -> void:
	var tile := float(GameConfig.tile_size())
	var house_center := Vector2(HOUSE_TILE) * tile + Vector2(-tile * 0.5, -tile * 0.5)
	var wall_top := house_center.y - float(4 * tile)
	var radius: float = PlayerView.BODY_RADIUS

	await _place(Vector2(house_center.x, wall_top - 40.0))
	await _step(Vector2.DOWN, 90)
	var final_y := _player().global_position.y
	_context.check(
		final_y <= wall_top - radius + 0.5,
		"no debe bajar de %.1f, llegó a %.1f" % [wall_top - radius, final_y]
	)


func _contained_by_bounds() -> void:
	await _place(Vector2(300, 320))
	await _step(Vector2.LEFT, 240)
	var final_x := _player().global_position.x
	_context.check(final_x >= 0.0, "no debe salirse por la izquierda, quedó en %.1f" % final_x)

	await _step(Vector2.RIGHT, 240)
	_context.check(
		_player().global_position.x <= 1024.0,
		"no debe salirse por la derecha, quedó en %.1f" % _player().global_position.x
	)


func _blocked_by_tree() -> void:
	var tile := float(GameConfig.tile_size())
	var radius: float = PlayerView.BODY_RADIUS
	var tree_anchor := Vector2(TREE_TILE) * tile
	var canopy := tree_anchor - Vector2(tile * 0.5, tile)
	var start := Vector2(canopy.x, canopy.y - 30.0)

	await _place(start)
	await _step(Vector2.DOWN, 90)
	var final_y := _player().global_position.y
	_context.check(
		final_y <= canopy.y - radius + 0.5,
		"no debe bajar de %.1f, llegó a %.1f" % [canopy.y - radius, final_y]
	)


func _domain_mirrors_position() -> void:
	await _place(Vector2(512, 320))
	await _step(Vector2.DOWN, 20)
	var view_position := _player().global_position
	var domain_position := _domain().position
	_context.check(
		view_position.distance_to(domain_position) < 1.0,
		"dominio %s vs vista %s" % [domain_position, view_position]
	)


func _state_follows_motion() -> void:
	await _place(Vector2(512, 320))
	await _step(Vector2.RIGHT, 10)
	_context.check_equal(
		_domain().state, PlayerState.Kind.MOVING, "estado mientras se mueve"
	)
	await _step(Vector2.ZERO, 10)
	_context.check_equal(
		_domain().state, PlayerState.Kind.IDLE, "estado al detenerse"
	)