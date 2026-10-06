extends SceneTree

## Tests de integración del NPC y del combate cuerpo a cuerpo con enemigos
## (secciones 7, 9, 10 y 18).
##
## Uso: godot --headless --script res://tests/integration/npc_combat_runner.gd
##
## Aquí se prueba la cadena que los unitarios no pueden ver: que un `NpcView` creado
## en tiempo de ejecución aparezca de verdad en `Area2D.get_overlapping_bodies()`, que
## el golpe del jugador llegue hasta él y que él pueda devolver el golpe.
##
## ## Por qué otro runner y no añadir casos al de combate
##
## Porque aquí hay otra escena en pie: enemigos, director, IA y el ciclo de morir y
## reaparecer. Meterlo todo en el runner de combate lo convertiría en un runner de
## "todo lo que se mueve", y cuando algo fallaría no se sabría si es del combate del
## jugador o del NPC. La regla de `AGENTS.md` es que cada suite tiene que bajar de
## forma distinta cuando le rompes su cadena.
##
## ## Por qué hay que desactivar los presentadores
##
## Los presentadores leen el teclado y mueven el reloj. Si se dejaran vivos, un NPC
## se acercaría al jugador durante el propio test y el golpe saldría por casualidad
## en vez de por lo que el caso estaba comprobando. Los casos que sí quieren probar la
## IA los vuelven a activar uno a uno.

const DELTA := 1.0 / 60.0

var _context: ScriptTestContext
var _total: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_context = ScriptTestContext.new()
	print("== Tests de integracion (NPC) ==")

	_ensure_npcs()

	_presenter().set_physics_process(false)
	for presenter: NpcPresenter in _spawner().presenters():
		presenter.set_physics_process(false)
	# Nadie persigue a nadie mientras el test decide quién va contra quién.
	_spawner().distribute_target(Vector2(-100000.0, -100000.0))

	await _check("la zona tiene enemigos", _npcs_spawned)
	await _check("cada enemigo tiene cuerpo y sprite", _npcs_have_bodies)
	await _check("el cuerpo del NPC es CharacterBody2D", _npcs_are_bodies)
	await _check("ningún enemigo nace dentro de una pared", _npcs_not_in_walls)
	await _check("al aparecer se ve algún enemigo", _combat_is_discoverable)
	await _check("el golpe del jugador llega al NPC", _player_strikes_npc)
	await _check("el NPC muere y lo dice", _npc_dies)
	await _check("un NPC muerto ya no recibe daño", _dead_npc_ignored)
	await _check("el NPC golpea al jugador", _npc_hits_player)
	await _check("el golpe del NPC deja ver el arco", _npc_slash_spawns)
	await _check("al recibir daño el jugador se tiñe de rojo", _player_flashes_when_hurt)
	await _check("al recibir daño el enemigo se tiñe de rojo", _npc_flashes_when_hurt)
	await _check("el presentador del NPC golpea sin ayuda", _npc_presenter_strikes_player)
	await _check("la invulnerabilidad protege al jugador", _player_invulnerable)
	await _check("la invulnerabilidad del NPC aguanta", _npc_invulnerable)
	await _check("el NPC reacciona cuando el jugador se acerca", _npc_chases)
	await _check("el NPC se para a distancia de golpe", _npc_stops_in_range)
	await _check("la IA no rompe el grafo de estados", _ai_respects_graph)
	await _check("el jugador muere y se bloquea", _player_dies)
	await _check("la reaparición devuelve la vida", _respawn_restores)
	await _check("la reaparición alinea dominio y vista", _respawn_moves_domain)

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

## Deja la zona con enemigos aunque el juego arranque sin ellos.
##
## El juego arranca con `GameConfig.NPC_ENABLED` en `false` para poder probar el
## movimiento sin que la IA se meta. Depender de que el autoload haya poblado la zona
## ataría esta suite al contenido por defecto del juego, y el día que se cambie la
## bandera estos 18 tests se caerían sin que haya cambiado una línea de NPC. Aquí se
## montan los enemigos con la misma API que usa `Game`, así que lo que se prueba es la
## zona real y no una copia.
func _ensure_npcs() -> void:
	if _director() != null:
		return
	_world().setup_npcs(_session().setup_npcs())


func _game() -> Node:
	return root.get_node("Game")


func _world() -> MainWorldView:
	return _game().world_view


func _player() -> PlayerView:
	return _world().player


func _presenter() -> PlayerPresenter:
	return _world().presenter


func _spawner() -> NpcSpawner:
	return _world().npc_spawner


func _director() -> NpcDirector:
	return _game().session.npcs


func _combat() -> MeleeCombat:
	return _game().session.combat


func _session() -> GameSession:
	return _game().session


func _settle(frames: int = 3) -> void:
	for _frame: int in range(frames):
		await physics_frame


## Espera a que la capa de efectos se vacíe: los arcos se borran solos, así que solo
## hace falta darles tiempo; si no, el arco anterior se contaría como el nuevo.
func _drain_fx(layer: Node2D, limit: int = 120) -> void:
	var waited := 0
	while layer.get_child_count() > 0 and waited < limit:
		await physics_frame
		waited += 1


## En vivo y con la vida a tope. Si esto no hay, el resto de los casos no significan
## nada, así que se elige el más sano que quede.
func _healthy_npc() -> Npc:
	var best: Npc = null
	for body: Npc in _director().living():
		if best == null or body.health.current > best.health.current:
			best = body
	return best


func _presenter_of(npc: Npc) -> NpcPresenter:
	for presenter: NpcPresenter in _spawner().presenters():
		if presenter.npc() == npc:
			return presenter
	return null


func _view_of(npc: Npc) -> NpcView:
	var presenter := _presenter_of(npc)
	if presenter == null:
		return null
	return presenter.get_parent() as NpcView


## El `NpcCombat` que el director le dio a este enemigo, no uno nuevo creado aquí.
func _combat_of(npc: Npc) -> NpcCombat:
	for agent in _director().agents:
		if agent.npc == npc:
			return agent.combat
	return null


## Deja el combate del jugador en un estado conocido y lo pone mirando al este, que es
## la dirección en la que se colocan los enemigos de los casos de golpe.
func _reset_player_combat() -> void:
	_combat().grant_invulnerability(0.0)
	_combat().advance(GameConfig.INVULNERABILITY_TIME + 1.0)
	_combat().advance(GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
	_player().set_facing(Vector2.RIGHT)


## Coloca un NPC justo donde lo alcanza el golpe del jugador y desactiva su IA para que
## se quede ahí.
func _bring_npc_close(npc: Npc) -> NpcView:
	var view := _view_of(npc)
	if view == null:
		return null
	var presenter := _presenter_of(npc)
	presenter.set_physics_process(false)
	view.global_position = _player().global_position + Vector2(8.0, 0.0)
	npc.move_to(view.global_position, Vector2.RIGHT)
	_player().set_facing(Vector2.RIGHT)
	await _settle()
	return view


# --- casos ---

## Si esto falla, todo lo demás está midiendo el aire: se está probando con enemigos que
## no existen.
func _npcs_spawned() -> void:
	_context.check(_director() != null, "no hay director de NPC")
	_context.check(_spawner() != null, "no hay generador de NPC")
	if _director() == null or _spawner() == null:
		return
	_context.check(_director().count() > 0, "la zona no tiene enemigos")
	_context.check(
		_director().living().size() == _director().count(),
		"al arrancar todos los enemigos están vivos"
	)


func _npcs_have_bodies() -> void:
	_context.check_equal(
		_spawner().presenters().size(), _director().count(), "un cuerpo por enemigo"
	)
	for presenter: NpcPresenter in _spawner().presenters():
		var npc := presenter.npc()
		var view := presenter.get_parent() as NpcView
		if not _context.check(view != null, "el enemigo %d no tiene cuerpo" % npc.id):
			return
		_context.check(view.hitbox != null, "el enemigo %d no tiene hitbox" % npc.id)
		var actor := view.get_node_or_null("Actor") as ActorSprite
		_context.check(actor != null, "el enemigo %d no tiene sprite" % npc.id)
		if actor != null:
			_context.check(
				actor.texture != null, "el sprite del enemigo %d no cargó" % npc.id
			)
		_context.check(
			view.combat_target == _combat_of(npc),
			"el enemigo %d no expone su cuerpo de combate" % npc.id
		)


## El motivo por el que existe esta prueba: un NPC `StaticBody2D` aparecería sin
## error en todas las pruebas de dominio y sería invisible para el golpe, porque
## `Area2D.get_overlapping_bodies()` no ve cuerpos estáticos.
func _npcs_are_bodies() -> void:
	for presenter: NpcPresenter in _spawner().presenters():
		var npc := presenter.npc()
		var view := presenter.get_parent()
		_context.check(
			view is CharacterBody2D, "el enemigo %d no es CharacterBody2D" % npc.id
		)
		_context.check(
			CollisionLayers.has(view.collision_layer, CollisionLayers.NPC),
			"el enemigo %d no está en la capa npc" % npc.id
		)


## Ningún enemigo puede nacer dentro de una pared.
##
## La tabla de aparición está en Application, que no sabe qué hay dibujado en el mapa,
## así que no puede comprobarlo al construirse. Solo se ve aquí, con la escena montada:
## un `CharacterBody2D` que nace dentro de un `StaticBody2D` se queda encajonado y su
## IA choca contra la pared cada fotograma sin poder salir de ella.
##
## Ya pasó: el lagarto del tile (14, 25) nació dentro de un edificio y no se movía. Por
## eso esto es un caso y no una nota en el comentario de la tabla.
func _npcs_not_in_walls() -> void:
	for presenter: NpcPresenter in _spawner().presenters():
		var npc := presenter.npc()
		var view := presenter.get_parent() as CharacterBody2D
		if not _context.check(view != null, "el enemigo %d no tiene cuerpo" % npc.id):
			continue
		# Un solo fotograma de física: el servidor de cuerpos tiene que resolver el
		# solapamiento antes de que `get_slide_collision_count()` diga algo.
		view.move_and_slide()
		await physics_frame
		_context.check_equal(
			view.get_slide_collision_count(),
			0,
			"el enemigo %d nace encajonado en %s (tile %s)" % [
				npc.id, view.global_position, Vector2(view.global_position) / GameConfig.tile_size()
			]
		)


## El combate tiene que ser visible sin tener que ir a buscarlo.
##
## Con los enemigos repartidos por el centro del mapa, el jugador podía recorrer la
## zona entera sin ver uno: el más cercano aparecía a 126 píxeles, cuando la cámara
## solo enseña 64 a lo ancho y 36 a lo alto. El combate estaba implementado y
## probado, y aun así era invisible. Este caso mide al enemigo más cercano al aparecer
## y comprueba dos cosas: que la cámara lo enseña y que está dentro de su propio radio
## de detección. Lo segundo importa igual que lo primero: un enemigo que se ve pero no
## se mueve es una pista falsa.
func _combat_is_discoverable() -> void:
	var player_position := _player().global_position
	var nearest := INF
	var nearest_id := 0
	var nearest_offset := Vector2.ZERO
	for presenter: NpcPresenter in _spawner().presenters():
		var view := presenter.get_parent() as Node2D
		if view == null:
			continue
		var offset: Vector2 = view.global_position - player_position
		if offset.length() < nearest:
			nearest = offset.length()
			nearest_id = presenter.npc().id
			nearest_offset = offset

	# Lo que la cámara enseña a cada lado, con el zoom que tiene ahora. Se lee de la
	# cámara en vez de escribir 384, 216 y 3 a mano, para que cambiar el zoom o la
	# resolución no deje el caso mintiendo.
	var camera := _world().camera as Camera2D
	var size := _world().get_viewport_rect().size
	var zoom: Vector2 = camera.zoom if camera != null else Vector2.ONE
	var half := Vector2(size.x / (2.0 * zoom.x), size.y / (2.0 * zoom.y))

	_context.check(
		nearest < INF, "hay enemigos a los que mirar; si no, el caso no comprobó nada"
	)
	# Que caiga dentro del rectángulo de la cámara, no a menos distancia que él: un
	# punto 100 píxeles a la izquierda está fuera de pantalla aunque su distancia sea
	# menor que el ancho.
	_context.check(
		absi(nearest_offset.x) <= half.x and absi(nearest_offset.y) <= half.y,
		"al aparecer no se ve ningún enemigo: el más cercano (id %d) está en %s y la cámara enseña solo %.0f x %.0f px" % [
			nearest_id, nearest_offset, half.x * 2.0, half.y * 2.0
		]
	)
	# Y tiene que estar a tiro de la detección, o verlo no sirve de nada.
	var aggro := INF
	for agent: NpcDirector.Agent in _director().agents:
		if agent.npc.id == nearest_id:
			aggro = agent.npc.behavior.aggro_radius
	_context.check(
		nearest <= aggro,
		"el enemigo visible está fuera de su propio radio de detección (%.0f px de %.0f)" % [
			nearest, aggro
		]
	)


## La cadena entera: el jugador golpea, su hitbox ve un cuerpo real del servidor de
## física y el NPC pierde vida.
##
## Aquí el presentador del jugador sí tiene que estar vivo: es él quien consulta la
## hitbox y le pasa los objetivos al caso de uso. Con el presentador apagado se
## comprobaría la aritmética, que es justo lo que los unitarios ya cubren.
func _player_strikes_npc() -> void:
	var npc := _healthy_npc()
	if not _context.check(npc != null, "no hay enemigo con vida"):
		return
	var view := await _bring_npc_close(npc)
	if not _context.check(view != null, "el enemigo no tiene cuerpo"):
		return
	var before := npc.health.current
	_reset_player_combat()
	_presenter().set_physics_process(true)

	_context.check(_combat().try_attack(Vector2.RIGHT), "el golpe sale")
	await _settle(4)
	_presenter().set_physics_process(false)

	_context.check(npc.health.current < before, "el enemigo no perdió vida")
	_context.check(npc.is_alive, "y sigue vivo con un golpe")
	_context.check(
		npc.health.current < npc.health.maximum, "y no se ha curado por el camino"
	)


func _npc_dies() -> void:
	var npc := _healthy_npc()
	if not _context.check(npc != null, "no hay enemigo con vida"):
		return
	var view := await _bring_npc_close(npc)
	if not _context.check(view != null, "el enemigo no tiene cuerpo"):
		return

	var died := [false]
	npc.died.connect(func() -> void: died[0] = true)

	# La vida se quita de golpe, sin depender de acertar el ritmo del golpe.
	NpcCombat.new(npc).receive_damage(npc.health.maximum * 10.0)
	await _settle()

	_context.check(npc.is_dead, "el enemigo sigue vivo")
	_context.check(died[0], "no avisó de la muerte")
	_context.check_equal(npc.state, NpcState.Kind.DEAD, "y no pasó a DEAD")
	_context.check(not view.hitbox.is_active, "sigue con la hitbox encendida")


## Un enemigo muerto tiene que quedarse fuera del cálculo de daño: si no, el segundo
## golpe de una ráfaga avisaría de una muerte que ya había pasado.
func _dead_npc_ignored() -> void:
	var npc := _healthy_npc()
	if not _context.check(npc != null, "no hay enemigo con vida"):
		return
	npc.take_damage(npc.health.maximum)
	await _settle()
	var deaths := [0]
	npc.died.connect(func() -> void: deaths[0] += 1)

	_context.check_equal(npc.take_damage(50.0), 0.0, "un NPC muerto recibe daño")
	await _settle(2)
	_context.check_equal(deaths[0], 0, "y no vuelve a morir")


## La cadena inversa, la que antes no existía porque no había a quién golpear.
##
## Usa el `NpcCombat` que el director le dio al enemigo, no uno nuevo: así también
## comprueba que el enemigo está cableado al caso de uso que mueve su presentador, y no
## con un objeto aparte que solo existe dentro del test.
func _npc_hits_player() -> void:
	var npc := _healthy_npc()
	if not _context.check(npc != null, "no hay enemigo con vida"):
		return
	var view := await _bring_npc_close(npc)
	if not _context.check(view != null, "el enemigo no tiene cuerpo"):
		return
	var combat := _combat_of(npc)
	if not _context.check(combat != null, "el enemigo no tiene combate propio"):
		return
	# Reloj a cero: al golpearlo el jugador en un caso anterior, el enemigo quedó
	# aturdido e invulnerable (su presentador está apagado, así que nada avanza su
	# reloj). Sin esta limpieza su propio `try_attack` se rechazaría.
	combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)

	var before := _session().player.health.current
	# Se golpea con el cuerpo de combate del jugador, que es lo que expone su vista.
	# Así el daño pasa por la invulnerabilidad en vez de saltársela.
	_context.check(combat.try_attack(Vector2.LEFT), "el golpe del NPC sale")
	_context.check_equal(
		combat.strike([_combat()]), 1, "el golpe llega al cuerpo de combate del jugador"
	)
	await _settle()

	_context.check(
		_session().player.health.current < before, "el jugador no recibió daño"
	)
	# La invulnerabilidad que se comprueba es la del jugador, que es el que acaba de
	# recibir el golpe: el combate del NPC ya estaba en su propio cooldown.
	_context.check(_combat().is_invulnerable, "el jugador queda invulnerable")
	_context.check_equal(
		_session().player.health.current,
		before - DamageRules.compute(
			npc.behavior.attack_damage, _session().player.stats.defense
		),
		"y el daño es el que dice la fórmula"
	)


## El enemigo tiene que verse que pega.
##
## Hasta ahora el NPC quitaba vida sin que saliera nada en pantalla: la pose de
## golpe sí se lanzaba, pero no había arco, así que en una pelea no se distinguía un
## zarpazo de un encontrado. El arco va a la misma capa que el del jugador y se
## suelta en el mismo fotograma en que empieza la pose (`attack_started`), no cuando
## el golpe conecta: un zarpazo fallado también se ve, que es como funciona un golpe.
##
## El caso mide la cadena entera: caso de uso -> señal -> presentador -> efecto en la
## capa del mundo. Si el presentador perdiera el cable del generador de efectos, la
## capa se quedaría vacía aquí y en el juego.
func _npc_slash_spawns() -> void:
	var layer: Node2D = _world().fx_layer
	if not _context.check(layer != null, "la capa de efectos existe"):
		return
	await _drain_fx(layer)

	var npc := _healthy_npc()
	if not _context.check(npc != null, "no hay enemigo con vida"):
		return
	var combat := _combat_of(npc)
	if not _context.check(combat != null, "el enemigo no tiene combate propio"):
		return
	# Los relojes a cero: el caso anterior deja al NPC con el golpe en curso y
	# `try_attack()` se rechazaría por cooldown, que no es lo que se mide aquí.
	combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)

	_context.check(combat.try_attack(Vector2.RIGHT), "el zarpazo sale")
	await _settle(2)
	_context.check(layer.get_child_count() >= 1, "aparece el arco del NPC")
	if layer.get_child_count() >= 1:
		var effect := layer.get_child(0) as SlashEffect
		if _context.check(effect != null, "y es un efecto de golpe"):
			var frames := effect.get_node_or_null("Frames") as Sprite2D
			var texture_path := ""
			if frames != null and frames.texture != null:
				texture_path = frames.texture.resource_path
			_context.check_equal(
				texture_path,
				SlashEffect.NPC_SHEET,
				"y con la hoja de zarpazo, no con la espada del jugador"
			)

	await _drain_fx(layer)
	_context.check_equal(layer.get_child_count(), 0, "y se borra al terminar")


## El destello de daño: mientras dura la invulnerabilidad el cuerpo entero se tiñe.
##
## Es la otra mitad del feedback de "el enemigo golpea", junto al arco que suelta el
## atacante: sin el tinte, recibir un golpe es solo la barra de vida bajando, que a
## 384x216 son cuatro píxeles. El tinte lo pone la vista al recibir
## `invulnerability_changed`, así que el caso mide la cadena daño -> señal ->
## presentador -> `modulate`, que es lo que se ve en pantalla.
##
## Se comprueba también que se apaga al terminar la invulnerabilidad: un tinte que no
## volviera a la normal dejaría al jugador rojo para el resto de la partida, que es el
## mismo fallo del revés.
func _player_flashes_when_hurt() -> void:
	var body := _player()
	if not _context.check(body != null, "el mundo tiene jugador"):
		return
	_reset_player_combat()
	await _settle(2)
	_context.check(
		body.modulate.is_equal_approx(body.tint),
		"sin daño reciente el cuerpo está con su tinte normal, no con el rojo (%s)" % str(body.modulate)
	)

	var npc := _healthy_npc()
	if not _context.check(npc != null, "no hay enemigo con vida"):
		return
	var view := await _bring_npc_close(npc)
	if not _context.check(view != null, "el enemigo no tiene cuerpo"):
		return
	var combat := _combat_of(npc)
	if not _context.check(combat != null, "el enemigo no tiene combate propio"):
		return
	# Relojes a cero, que el caso anterior deja al NPC con el golpe en curso.
	combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)

	var before := _session().player.health.current
	_context.check(combat.try_attack(Vector2.LEFT), "el zarpazo sale")
	_context.check(combat.strike([_combat()]) == 1, "el golpe le llega al jugador")
	await _settle(2)

	_context.check(
		_session().player.health.current < before,
		"y le quita vida (%.1f -> %.1f)" % [before, _session().player.health.current]
	)
	# El aturdimiento dura menos que la invulnerabilidad: recién golpeado, el cuerpo
	# se tiñe de violeta (aturdido) y al expirar el aturdimiento vuelve el rojo.
	_context.check(
		body.modulate.is_equal_approx(GameConfig.STUN_TINT),
		"recién aturdido el cuerpo se tiñe de violeta y está en %s" % str(body.modulate)
	)

	_combat().advance(GameConfig.HURT_STUN_TIME + DELTA)
	await _settle(2)
	_context.check(
		body.modulate.is_equal_approx(GameConfig.HURT_TINT),
		"al acabar el aturdimiento se tiñe de rojo y está en %s" % str(body.modulate)
	)

	# Y se apaga: pasada la invulnerabilidad vuelve a su tinte.
	_combat().advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
	await _settle(2)
	_context.check(
		body.modulate.is_equal_approx(body.tint),
		"pasada la invulnerabilidad el tinte se apaga y queda en %s" % str(body.modulate)
	)


## El revés de `_player_flashes_when_hurt`: el enemigo también se tiñe mientras dura
## su invulnerabilidad. Es la misma ley para todos los seres del juego.
##
## Antes la vista del NPC exponía el `Npc` del dominio como objetivo, y el golpe del
## jugador llamaba a `take_damage` sobre él: sin pasar por `NpcCombat` no había
## invulnerabilidad, no había señal y el enemigo nunca se teñía. Ahora expone el
## cuerpo de combate, y aquí se mide la cadena entera: golpe -> hitbox -> NpcCombat
## -> señal -> presentador -> `modulate`, que es lo que se ve en pantalla.
func _npc_flashes_when_hurt() -> void:
	var npc := _healthy_npc()
	if not _context.check(npc != null, "no hay enemigo con vida"):
		return
	var view := await _bring_npc_close(npc)
	if not _context.check(view != null, "el enemigo no tiene cuerpo"):
		return
	var combat := _combat_of(npc)
	if not _context.check(combat != null, "el enemigo no tiene combate propio"):
		return
	# Relojes a cero: los casos anteriores han golpeado a este enemigo (o a su
	# combate) y no se puede medir el destello con la ventana ya abierta.
	combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
	_reset_player_combat()
	await _settle(2)
	_context.check(
		not combat.is_invulnerable, "el enemigo parte sin invulnerabilidad"
	)
	_context.check(
		view.modulate.is_equal_approx(view.tint),
		"sin daño reciente el enemigo está con su tinte normal, no con el rojo (%s)" % str(view.modulate)
	)

	var before := npc.health.current
	_presenter().set_physics_process(true)
	_context.check(_combat().try_attack(Vector2.RIGHT), "el golpe sale")
	await _settle(4)
	_presenter().set_physics_process(false)

	_context.check(npc.health.current < before, "el enemigo no perdió vida")
	_context.check(
		combat.is_invulnerable, "el golpe pasó por el cuerpo de combate del enemigo"
	)
	# Igual que el jugador: violeta mientras dura el aturdimiento y rojo al expirarlo,
	# porque el aturdimiento dura menos que la invulnerabilidad.
	_context.check(
		view.modulate.is_equal_approx(GameConfig.STUN_TINT),
		"recién aturdido el enemigo se tiñe de violeta y está en %s" % str(view.modulate)
	)

	combat.advance(combat.npc.behavior.hurt_stun_time + DELTA)
	await _settle(2)
	_context.check(
		view.modulate.is_equal_approx(GameConfig.HURT_TINT),
		"al acabar el aturdimiento el enemigo se tiñe de rojo y está en %s" % str(view.modulate)
	)

	# Y se apaga: pasada la invulnerabilidad vuelve a su tinte.
	combat.advance(GameConfig.INVULNERABILITY_TIME + GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
	await _settle(2)
	_context.check(
		view.modulate.is_equal_approx(view.tint),
		"pasada la invulnerabilidad el tinte se apaga y queda en %s" % str(view.modulate)
	)


## El mismo golpe, pero ejecutado por el presentador con la física puesta: la hitbox
## del enemigo tiene que ver al jugador de verdad, no una lista que le pasa el test.
## Se le da un margen de varios fotogramas porque aquí manda el reloj del caso de uso:
## el enemigo necesita su cooldown a cero antes de que su IA le deje pegar.
func _npc_presenter_strikes_player() -> void:
	var npc := _healthy_npc()
	var presenter := _presenter_of(npc)
	if not _context.check(npc != null and presenter != null, "no hay enemigo con cuerpo"):
		return
	var combat := _combat_of(npc)
	var view := _view_of(npc)
	# Se deja al enemigo pegado al jugador, con su correa en el sitio y el jugador como
	# objetivo, para que su IA llegue sola a la conclusión de que toca golpear.
	view.global_position = _player().global_position + Vector2(6.0, 0.0)
	npc.move_to(view.global_position, Vector2.LEFT)
	npc.home = npc.position
	_spawner().distribute_target(_player().global_position)

	# El jugador empieza sin invulnerabilidad para que el primer golpe cuente, y con el
	# reloj del NPC limpio para que no esté en medio de un golpe anterior.
	_combat().grant_invulnerability(0.0)
	_combat().advance(GameConfig.INVULNERABILITY_TIME + 1.0)
	combat.advance(npc.behavior.attack_cooldown + 1.0)

	var before := _session().player.health.current
	presenter.set_physics_process(true)
	await _settle(12)
	presenter.set_physics_process(false)

	_context.check(
		npc.state == NpcState.Kind.ATTACK,
		"el enemigo %d no llegó a ATTACK (está en %s)" % [
			npc.id, NpcState.name_of(npc.state)
		]
	)
	_context.check(
		_session().player.health.current < before,
		"el presentador del enemigo no hizo ningún daño"
	)


## Cada caso tiene que partir de un jugador sin invulnerabilidad: el caso anterior le
## acaba de dar un golpe, y si no se limpiara el estado, este mediría que ya la tiene.
func _player_invulnerable() -> void:
	_reset_player_combat()
	var before := _session().player.health.current
	_context.check(not _combat().is_invulnerable, "el jugador parte sin invulnerabilidad")
	_combat().receive_damage(10.0, null)
	_context.check(
		_session().player.health.current < before, "el primer golpe quita vida"
	)
	_context.check(_combat().is_invulnerable, "y da invulnerabilidad")
	_context.check_equal(_combat().receive_damage(10.0, null), 0.0, "el segundo no quita")


func _npc_invulnerable() -> void:
	var npc := _healthy_npc()
	if not _context.check(npc != null, "no hay enemigo con vida"):
		return
	var combat := NpcCombat.new(npc)
	_context.check(combat.receive_damage(3.0) > 0.0, "el primer golpe entra")
	_context.check(combat.is_invulnerable, "y da invulnerabilidad")
	_context.check_equal(combat.receive_damage(3.0), 0.0, "el segundo no")


## La IA en la zona montada: el enemigo ve al jugador y reacciona, sin que nadie mueva
## nada a mano salvo el presentador que sí tiene que estar vivo.
func _npc_chases() -> void:
	var npc := _healthy_npc()
	if not _context.check(npc != null, "no hay enemigo con vida"):
		return
	var view := _view_of(npc)
	var presenter := _presenter_of(npc)
	if not _context.check(view != null and presenter != null, "el enemigo no tiene cuerpo"):
		return

	# Se pone al enemigo dentro del radio de detección y con la correa muy lejos, para
	# que lo que decida sea la deteccion y no la correa.
	npc.home = view.global_position - Vector2(0.0, npc.behavior.leash_radius)
	npc.move_to(view.global_position, Vector2.RIGHT)
	presenter.set_physics_process(true)
	_spawner().distribute_target(view.global_position)

	await _settle(2)
	_context.check(
		npc.state == NpcState.Kind.ATTACK or npc.state == NpcState.Kind.CHASE,
		"el enemigo %d no reaccionó (estado %s)" % [npc.id, NpcState.name_of(npc.state)]
	)
	presenter.set_physics_process(false)


## Un enemigo que anduviera hasta el jugador tendría el alcance a cero y sus golpes no
## llegarían nunca, así que tiene que pararse justo antes.
func _npc_stops_in_range() -> void:
	var npc := _healthy_npc()
	if not _context.check(npc != null, "no hay enemigo con vida"):
		return
	var view := _view_of(npc)
	if not _context.check(view != null, "el enemigo no tiene cuerpo"):
		return
	view.global_position = _player().global_position + Vector2(4.0, 0.0)
	npc.move_to(view.global_position, Vector2.LEFT)
	npc.home = npc.position
	_spawner().distribute_target(_player().global_position)
	await _settle(2)
	var distance := npc.position.distance_to(_session().player.position)
	_context.check(
		distance <= npc.behavior.attack_range + 2.0,
		"el enemigo está a %.1f px, más allá de su alcance de %.1f" % [
			distance, npc.behavior.attack_range
		]
	)


## La IA no puede inventarse estados: si escribiera el estado a mano saltaría el grafo
## y un NPC podría quedarse persiguiendo después de morir. Se comprueba en los dos
## sentidos, vivo y muerto, porque los casos anteriores ya han matado a varios.
func _ai_respects_graph() -> void:
	var saw_dead := false
	var saw_alive := false
	for presenter: NpcPresenter in _spawner().presenters():
		var npc := presenter.npc()
		_context.check(
			npc.state != NpcState.Kind.DEAD or npc.is_dead,
			"el enemigo %d está muerto pero su estado es %s" % [
				npc.id, NpcState.name_of(npc.state)
			]
		)
		_context.check(
			npc.is_alive or npc.state == NpcState.Kind.DEAD,
			"el enemigo %d está muerto pero su estado es %s" % [
				npc.id, NpcState.name_of(npc.state)
			]
		)
		# Un enemigo vivo tiene que quedarse dentro de los estados que el grafo
		# declara vivos: ni uno inventado ni el terminal.
		_context.check(
			npc.is_alive == NpcState.is_alive(npc.state),
			"el enemigo %d está desincronizado: vivo=%s estado=%s" % [
				npc.id, npc.is_alive, NpcState.name_of(npc.state)
			]
		)
		if npc.is_dead:
			saw_dead = true
		else:
			saw_alive = true
	_context.check(saw_alive, "ningún enemigo quedó vivo: el caso no comprobó nada")
	_context.check(saw_dead, "ningún enemigo murió: el caso no comprobó nada")


func _player_dies() -> void:
	var session := _session()
	session.player.take_damage(session.player.health.maximum * 10.0)
	await _settle(2)
	_context.check(session.player.is_dead, "el jugador sigue vivo")
	_context.check(not session.can_respawn(), "y se puede revivir antes de tiempo")
	_context.check(
		not session.request_respawn(), "y el botón no hace nada antes de tiempo"
	)


## Reaparecer devuelve la vida, la stamina y el estado.
func _respawn_restores() -> void:
	var session := _session()
	if not _context.check(session.player.is_dead, "el caso parte de un jugador muerto"):
		return
	session.advance(GameConfig.RESPAWN_DELAY + 0.1)
	_context.check(session.can_respawn(), "pasado el tiempo, se puede revivir")
	_context.check(session.request_respawn(GameConfig.PLAYER_SPAWN), "el botón funciona")
	_context.check(session.player.is_alive, "el jugador sigue muerto")
	_context.check_equal(
		session.player.health.current, session.player.health.maximum, "vida llena"
	)
	_context.check_equal(
		session.player.state, PlayerState.Kind.IDLE, "y vuelve a reposo"
	)


## El dominio es la fuente de verdad de la posición: al revivir, dominio y vista tienen
## que acabar en el mismo sitio o el jugador reaparece donde no le han puesto.
func _respawn_moves_domain() -> void:
	var session := _session()
	session.player.take_damage(session.player.health.maximum * 10.0)
	await _settle(2)
	var target := Vector2(200.0, 200.0)
	session.advance(GameConfig.RESPAWN_DELAY + 0.1)
	session.request_respawn(target)
	await _settle(2)
	_context.check_equal(session.player.position, target, "el dominio está en el punto")
	_context.check_equal(_player().global_position, target, "la vista también")