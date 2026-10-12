extends SceneTree

## Tests de integración del combate cuerpo a cuerpo (secciones 7, 9 y 10).
##
## Uso: godot --headless --script res://tests/integration/combat_runner.gd
##
## Aquí se prueba la cadena completa, que es justo la que se rompió en silencio:
## el presentador enciende la `HitboxSensor`, esta detecta un cuerpo real del
## servidor de física y `MeleeCombat` aplica el daño.
##
## Los unitarios de `MeleeCombat` pasaban mientras tanto porque no dependen de la
## física: dado un objetivo, la aritmética es correcta. Lo que no cubrían es que
## la hitbox llegara a existir y a ver a alguien.

const DELTA := 1.0 / 60.0

## Objetivo de dominio. Solo implementa `take_damage`, que es lo que
## `DamageRules.is_damageable()` exige, y expone `stats` para la defensa.
class DummyTarget:
	extends RefCounted

	var stats: CharacterStats
	## Daño recibido en cada golpe, en orden.
	var taken: Array[float] = []

	func _init(defense: float = 0.0) -> void:
		stats = CharacterStats.new()
		stats.defense = defense

	func take_damage(amount: float) -> float:
		taken.append(amount)
		return amount

	var total: float:
		get:
			var sum := 0.0
			for value: float in taken:
				sum += value
			return sum


## Cuerpo físico que la hitbox puede golpear.
##
## OJO: tiene que ser `CharacterBody2D`. Un `StaticBody2D` añadido en tiempo de
## ejecución **no** aparece nunca en `Area2D.get_overlapping_bodies()`: se
## comprobó con más de 200 frames de física y reactivando `monitoring`, y sigue
## sin salir, mientras que un `CharacterBody2D` en la misma posición se detecta
## al instante. Los cuerpos estáticos no entran en el monitoreo del área.
##
## Para el juego esto no es una limitación: un NPC que se mueve es un
## `CharacterBody2D` igualmente. Pero sí explica por qué un objetivo de prueba
## estático daría un falso negativo.
class DummyBody:
	extends CharacterBody2D

	var combat_target: Object


var _context: ScriptTestContext
var _total: int = 0
var _failed: int = 0
var _sacrificial: Array[Node] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_context = ScriptTestContext.new()
	print("== Tests de integracion (combate) ==")

	# El presentador lee el teclado y mueve el reloj del combate; aquí se maneja
	# el caso de uso a mano para no pelearse con la entrada.
	_presenter().set_physics_process(false)

	await _check("la hitbox existe y tiene colisión", _hitbox_exists)
	await _check("la hitbox se enciende con el golpe", _hitbox_activates)
	await _check("la hitbox detecta un cuerpo cercano", _hitbox_detects_body)
	await _check("la hitbox ignora al propio jugador", _hitbox_ignores_owner)
	await _check("un golpe quita vida al objetivo", _strike_damages_target)
	await _check("la defensa reduce el daño con mínimo de 1", _defense_applies)
	await _check("el cooldown bloquea el segundo golpe", _cooldown_blocks)
	await _check("la invulnerabilidad evita el daño repetido", _invulnerability_holds)
	await _check("el reloj no retrocede", _clock_never_rewinds)
	await _check("el arco sale al golpear con arma", _slash_spawns_armed)
	await _check("a puños no sale arco", _no_slash_unarmed)
	await _check("el golpe recibido levanta su reacción en la vista", _reaction_reaches_the_view)
	await _check("el empuje del golpe mueve el cuerpo", _knockback_moves_the_body)
	await _check("el impacto del golpe llega al presentador", _impact_struck_reaches_the_presenter)
	await _check("un golpe bloqueado no congela nada", _blocked_impact_does_not_reach_the_presenter)
	await _check("el golpe del jugador congela y suelta el burst", _hit_stop_and_impact_fire_when_striking)

	_cleanup()
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


func _player() -> PlayerView:
	return _game().world_view.player


func _presenter() -> PlayerPresenter:
	return _game().world_view.presenter


func _combat() -> MeleeCombat:
	return _game().session.combat


func _hitbox() -> HitboxSensor:
	return _player().hitbox


## Avanza la física para que el servidor de cuerpos resuelva solapamientos.
func _settle(frames: int = 3) -> void:
	for _frame: int in range(frames):
		await physics_frame


## Deja el combate en un estado conocido: sin cooldown, sin aturdimiento y sin
## invulnerabilidad, para que cada caso parta de cero. El presentador (apagado en
## toda la suite) puede llevar un congelamiento de impacto de un caso anterior,
## y como apagado nadie descuenta ese reloj, también se le limpia: si no, un caso
## nuevo mediría el congelamiento del anterior.
##
## El bloqueo del movimiento es la misma clase de fuga: un aturdimiento lo pone
## (`block_for`) y solo lo descuenta el presentador del jugador, que aquí está
## apagado. Sin drenarlo, el siguiente caso hereda un jugador clavado que no
## actualiza la orientación aunque las teclas se pulsen.
func _reset_combat() -> void:
	var combat := _combat()
	combat.grant_invulnerability(0.0)
	combat.advance(GameConfig.INVULNERABILITY_TIME + 1.0)
	combat.advance(GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)
	_presenter()._hit_stop_remaining = 0.0
	var movement: MovementController = _game().movement
	movement.advance(1000.0)
	movement.external_velocity = Vector2.ZERO


## Coloca un objetivo cuerpo a cuerpo a `offset` del jugador y lo devuelve.
func _spawn_target(offset: Vector2, defense: float = 0.0) -> DummyTarget:
	var body := DummyBody.new()
	body.collision_layer = CollisionLayers.NPC
	body.collision_mask = 0
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	body.add_child(shape)
	_game().world_view.add_child(body)
	body.global_position = _player().global_position + offset

	var target := DummyTarget.new(defense)
	body.combat_target = target
	_sacrificial.append(body)
	return target


func _cleanup() -> void:
	for body: Node in _sacrificial:
		if is_instance_valid(body):
			body.queue_free()
	_sacrificial.clear()


## El arco de golpe tiene que aparecer y desaparecer solo.
##
## El efecto no decide nada: aparece porque el presentador oyó el aviso del caso de
## uso. Se comprueba con la escena real porque el efecto vive en una capa aparte y no
## cuelga de nadie a quien se le pueda preguntar por su cuenta.
func _slash_spawns_armed() -> void:
	var layer: Node2D = _game().world_view.fx_layer
	if not _context.check(layer != null, "la capa de efectos existe"):
		return
	await _drain_fx(layer)
	_reset_combat()

	_context.check(_combat().try_attack(Vector2.RIGHT), "el golpe con arma sale")
	await _settle()
	_context.check_equal(layer.get_child_count(), 1, "aparece un arco")
	if layer.get_child_count() == 1:
		_context.check(
			layer.get_child(0) is SlashEffect, "y es un efecto de golpe"
		)

	# Se suelta solo: si se quedara colgado en la capa, se acumularían arcos y
	# taparían la escena.
	await _drain_fx(layer)
	_context.check_equal(layer.get_child_count(), 0, "y se borra al terminar")


## A puños no hay nada que corte el aire, así que no sale arco.
##
## Es la diferencia visible entre las dos formas de pegar que se pidieron, y la que
## distingue el golpe desarmado del armada con solo mirar la pantalla. Salía porque el
## presentador soltava el efecto sin mirar qué iba en la mano.
func _no_slash_unarmed() -> void:
	var layer: Node2D = _game().world_view.fx_layer
	if not _context.check(layer != null, "la capa de efectos existe"):
		return
	await _drain_fx(layer)
	_reset_combat()

	_context.check(_combat().try_attack(Vector2.RIGHT, true), "el puñetazo sale")
	await _settle()
	_context.check_equal(
		layer.get_child_count(), 0, "sin arco: a puños no hay hoja que corte el aire"
	)

	# Y el golpe desarmado no apaga el arma que llevas: eso se comprueba en los
	# unitarios, aquí solo que la diferencia existe de verdad.
	_context.check(
		not WeaponCatalog.is_unarmed(_combat().active_weapon(false)),
		"y el arma sigue siendo la de antes"
	)


## Espera a que la capa de efectos se vacíe. Los arcos se borran solos, así que solo
## hay que darles tiempo; si no, el arco anterior se contaría como el nuevo.
func _drain_fx(layer: Node2D, limit: int = 120) -> void:
	var waited := 0
	while layer.get_child_count() > 0 and waited < limit:
		await physics_frame
		waited += 1


## Golpea en una dirección y deja la ventana de impacto abierta, para poder actuar
## sobre el objetivo mientras el golpe está en curso.
##
## OJO: con las fases de la sección 10 un golpe no pega al empezar. Arranca en
## WINDUP y la hitbox se enciende al entrar en ACTIVE, así que aquí hay que
## mover el reloj a mano hasta que abra: el presentador está apagado en estos
## tests, que es quien lo haría en el juego.
func _attack_toward(direction: Vector2) -> void:
	_combat().try_attack(direction)
	await _advance_to_window()


## Avanza la física, un fotograma por `delta`, hasta que la ventana del golpe en
## curso se abra. Devuelve `false` si el golpe termina sin llegar a abrirse, que
## es lo que hace que una prueba falle en vez de pasar por accidente.
func _advance_to_window(limit: int = 60) -> bool:
	var waited := 0
	while _combat().is_attacking and not _combat().is_window_open and waited < limit:
		_combat().advance(DELTA)
		await physics_frame
		waited += 1
	# Un fotograma más: `HitboxSensor` enciende `monitoring` con `set_deferred`
	# y solo está visible en el servidor de física a partir del frame siguiente.
	if _combat().is_window_open:
		await physics_frame
		return true
	return false


# --- casos ---

func _hitbox_exists() -> void:
	var hitbox := _hitbox()
	if not _context.check(hitbox != null, "el jugador no tiene hitbox"):
		return
	_context.check(not hitbox.is_active, "la hitbox nace apagada")

	var shape := hitbox.get_node_or_null("Shape") as CollisionShape2D
	if not _context.check(shape != null, "la hitbox no tiene CollisionShape2D"):
		return
	var circle := shape.shape as CircleShape2D
	_context.check(circle != null, "la forma de la hitbox no es un círculo")
	if circle == null:
		return
	_context.check(circle.radius > 0.0, "el radio de la hitbox es 0")


func _hitbox_activates() -> void:
	_reset_combat()
	var combat := _combat()
	_context.check(combat.try_attack(Vector2.RIGHT), "el golpe debería salir")
	_context.check(combat.is_attacking, "el jugador queda en ATTACKING")
	# Durante el arranque (WINDUP) la hitbox tiene que seguir apagada: si se
	# encendiera al empezar la pose, un golpe lento estaría pegando durante todo
	# su windup, que es justo lo que la sección 10 prohíbe.
	await _settle()
	_context.check(not _hitbox().is_active, "en el arranque la hitbox sigue apagada")

	# El encendido va diferido: no es visible hasta el siguiente frame.
	_context.check(await _advance_to_window(), "la ventana se abre dentro del golpe")
	_context.check(_hitbox().is_active, "la hitbox debe encenderse con la ventana")
	_context.check(_hitbox().monitoring, "y con el monitoreo activo")


func _hitbox_detects_body() -> void:
	_reset_combat()
	_spawn_target(Vector2(12.0, 0.0))
	await _settle()

	await _attack_toward(Vector2.RIGHT)
	var found := _hitbox().overlapping_bodies()
	var sees_target := false
	for body: Node2D in found:
		if body is DummyBody:
			sees_target = true
	_context.check(sees_target, "la hitbox debería ver el cuerpo cercano")
	_cleanup()


func _hitbox_ignores_owner() -> void:
	_reset_combat()
	# El propio jugador está en la capa PLAYER, que la hitbox sí detecta: sin
	# filtrado se golpearía a sí mismo.
	await _attack_toward(Vector2.RIGHT)
	var raw := _hitbox().get_overlapping_bodies()
	_context.check(
		raw.has(_player()), "el jugador debería solaparse con su propia hitbox"
	)
	_context.check(
		not _hitbox().overlapping_bodies().has(_player()),
		"pero la hitbox no debe contarlo como objetivo"
	)


func _strike_damages_target() -> void:
	_reset_combat()
	var target := _spawn_target(Vector2(12.0, 0.0))
	await _settle()

	await _attack_toward(Vector2.RIGHT)
	# Lo que decide el daño es el caso de uso, no la física: se le pasa el
	# objetivo que la vista encontró.
	var hits := _combat().strike([target])
	_context.check_equal(hits, 1, "un objetivo alcanzable recibe daño")
	_context.check_equal(target.taken.size(), 1, "take_damage se llamó una vez")
	if target.taken.size() == 1:
		_context.check_equal(
			target.taken[0],
			GameConfig.WEAPON_STONE_DAMAGE,
			"el daño sin defensa es el del arma"
		)
	_cleanup()


func _defense_applies() -> void:
	_reset_combat()
	# Defensa mayor que el daño: aun así el golpe se lleva el mínimo (sección 10).
	var armored := _spawn_target(Vector2(12.0, 0.0), GameConfig.WEAPON_STONE_DAMAGE + 10.0)
	await _settle()
	await _attack_toward(Vector2.RIGHT)
	_combat().strike([armored])
	_context.check_equal(armored.taken.size(), 1, "el objetivoerala alcanzable")
	if armored.taken.size() == 1:
		_context.check_equal(
			armored.taken[0], DamageRules.MINIMUM_DAMAGE, "la defensa no baja de 1"
		)
	_cleanup()

	# Y con una defensa parcial: menos daño que sin defensa.
	_reset_combat()
	var shielded := _spawn_target(Vector2(12.0, 0.0), 3.0)
	await _settle()
	await _attack_toward(Vector2.RIGHT)
	_combat().strike([shielded])
	if _context.check_equal(shielded.taken.size(), 1, "el objetivo con escudo es alcanzable"):
		_context.check_equal(
			shielded.taken[0],
			GameConfig.WEAPON_STONE_DAMAGE - 3.0,
			"la defensa descuenta del daño"
		)
	_cleanup()


func _cooldown_blocks() -> void:
	_reset_combat()
	var combat := _combat()
	_context.check(combat.try_attack(Vector2.RIGHT), "el primer golpe sale")
	_context.check(not combat.try_attack(Vector2.RIGHT), "el segundo se rechaza")
	_context.check_equal(
		combat.rejection_reason(), MeleeCombat.REASON_BUSY, "motivo: ocupado attacking"
	)
	# Al agotarse la recuperación sigue mandando el cooldown.
	combat.advance(GameConfig.ATTACK_RECOVERY + 0.01)
	_context.check(not combat.try_attack(Vector2.RIGHT), "el cooldown sigue activo")
	_context.check_equal(
		combat.rejection_reason(), MeleeCombat.REASON_COOLDOWN, "motivo: cooldown"
	)


func _invulnerability_holds() -> void:
	_reset_combat()
	var combat := _combat()
	combat.grant_invulnerability()
	var before := combat.player.health.current
	await _settle()
	_context.check(combat.is_invulnerable, "la invulnerabilidad está activa")
	var dealt := combat.receive_damage(50.0, null)
	_context.check_equal(dealt, 0.0, "invulnerable no recibe daño")
	_context.check_equal(combat.player.health.current, before, "la vida no baja")

	# Al expirar vuelve a poder recibir daño.
	combat.advance(GameConfig.INVULNERABILITY_TIME + 0.01)
	_context.check(not combat.is_invulnerable, "la invulnerabilidad caduca")
	combat.advance(GameConfig.DEFAULT_ATTACK_COOLDOWN + 1.0)


func _clock_never_rewinds() -> void:
	_reset_combat()
	var combat := _combat()
	combat.try_attack(Vector2.RIGHT)
	combat.advance(-5.0)
	_context.check(
		not combat.can_attack(), "advance(negativo) no debe limpiar el cooldown"
	)


## La reacción no es un número de la aritmética: es lo que se ve. El golpe que
## recibe el jugador llega a la vista vía las señales del caso de uso —aunque el
## presentador esté apagado, las señales siguen conectadas— y reproduce el clip del
## tier, y el trance lo cierra el reloj del combate, no la vista.
func _reaction_reaches_the_view() -> void:
	_reset_combat()
	var combat := _combat()
	# Limpia cualquier reacción previa que un caso anterior haya dejado a medias:
	# esta suite comparte el mismo combate.
	combat.advance(GameConfig.REACTION_HEAD_TIME + GameConfig.STAGGER_EXTRA_HIGH + 0.5)
	await _settle()

	_context.check_equal(_player().reaction_clip(), &"", "sin golpes no hay clip de reacción")

	var dealt := combat.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.UP)
	_context.check(dealt > 0.0, "el golpe entra al jugador")
	_context.check_equal(
		_player().reaction_clip(), &"hit_light", "y la vista reproduce el clip ligero"
	)

	combat.advance(GameConfig.REACTION_LIGHT_TIME + DELTA)
	_context.check_equal(_player().reaction_clip(), &"", "al terminar el trance se limpia")


## El empuje del golpe (sección 27) no es un número en el dominio: es el cuerpo que
## se desplaza. Con el presentador apagado se hace a mano lo que hace su
## `_physics_process` (avanzar el reloj, copiar el empuje al movimiento y mover), y
## el cuerpo tiene que acabar unos píxeles a la derecha y luego quedarse quieto.
func _knockback_moves_the_body() -> void:
	_reset_combat()
	var combat := _combat()
	combat.advance(GameConfig.REACTION_HEAD_TIME + GameConfig.STAGGER_EXTRA_HIGH + 0.5)
	var movement: MovementController = _game().movement
	await _settle()

	var start := _player().global_position
	combat.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.RIGHT)

	for _frame: int in range(12):
		combat.advance(DELTA)
		movement.external_velocity = combat.external_velocity
		movement.move(DELTA, Vector2.ZERO)
		await physics_frame

	_context.check(
		_player().global_position.x > start.x + 1.0,
		"el empuje desplaza el cuerpo hacia donde venía el golpe"
	)

	# El empuje se agota y el cuerpo se queda: terminado el tiempo, mover no
	# desplaza más.
	var settled := _player().global_position
	for _frame: int in range(6):
		combat.advance(DELTA)
		movement.external_velocity = combat.external_velocity
		movement.move(DELTA, Vector2.ZERO)
		await physics_frame
	_context.check(
		(_player().global_position - settled).length() < 0.5,
		"y al agotarse deja de moverse"
	)


## El hit stop (sección 36) no depende del reloj de la presentación: el presentador
## lo recibe por la señal `impact_struck` del propio combate, así que aunque esté
## apagado se le pone el contador. Es lo que hace que el freeze funcione igual en
## un test que con los presentadores encendidos.
func _impact_struck_reaches_the_presenter() -> void:
	_reset_combat()
	var combat := _combat()
	var presenter := _presenter()
	_player().set_facing(Vector2.DOWN)
	var attack := AttackCatalog.of(AttackCatalog.LEFT_HOOK)

	var dealt := combat.take_attack(attack, 12.0, Vector2.UP)

	_context.check(dealt > 0.0, "el golpe entra")
	_context.check(presenter.is_hit_stopped(), "el presentador se congela")
	_context.check_almost_equal(
		presenter.hit_stop_remaining(),
		CombatImpact.hit_stop_of(attack.knockback),
		"con el tiempo del tier del ataque (%s)" % attack.knockback
	)


## Bloqueado no hay hit stop: el golpe entró en la guardia, no en el cuerpo, y no
## hay nada que congelar. Un freeze al bloquear se notaría en que el mundo se
## detiene sin daño, que es justo lo que la sección 40 no quiere.
func _blocked_impact_does_not_reach_the_presenter() -> void:
	_reset_combat()
	var combat := _combat()
	var presenter := _presenter()
	_player().set_facing(Vector2.DOWN)
	combat.set_blocking(true)

	var dealt := combat.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.UP)

	_context.check_equal(dealt, 0.0, "de frente el golpe no entra")
	_context.check(not presenter.is_hit_stopped(), "y el presentador no se congela")


## El golpe del jugador dispara la cadena entera: el presentador lo saca por la
## tecla (presentadores encendidos), la ventana se abre, el golpe conecta, el
## presentador se congela los milisegundos del tier y la capa de efectos recibe el
## burst de partículas.
func _hit_stop_and_impact_fire_when_striking() -> void:
	_reset_combat()
	# Sin enemigos: un golpe de un NPC al jugador también dispara `impact_struck`
	# (por el lado que recibe) y confundiría el caso, que quiere medir el golpe
	# que DA el jugador.
	_pacify_npcs()
	var layer: Node2D = _game().world_view.fx_layer
	if not _context.check(layer != null, "la capa de efectos existe"):
		return
	await _drain_fx(layer)

	_spawn_target(Vector2(12.0, 0.0))
	await _settle()

	var combat := _combat()
	var connected: Array[bool] = [false]
	combat.impact_struck.connect(func(_tier: StringName) -> void: connected[0] = true)

	# Mirar a la derecha como haría el jugador y atacar con la tecla: el
	# presentador enciende la hitbox solo y la ventana golpea al muñeco.
	_presenter().set_physics_process(true)
	Input.action_press(&"move_right")
	await _settle(2)
	Input.action_release(&"move_right")
	await _settle()

	Input.action_press(&"attack")
	var waited := 0
	while not connected[0] and waited < 120:
		await physics_frame
		waited += 1
	Input.action_release(&"attack")

	_context.check(connected[0], "el impacto se conecta al golpear")
	_context.check(_presenter().is_hit_stopped(), "y el presentador queda congelado")
	_context.check(layer.get_child_count() > 0, "y la capa de efectos tiene el burst")
	var impact: Node = null
	for child: Node in layer.get_children():
		if child is ImpactEffect:
			impact = child
			break
	_context.check(impact != null, "y entre los efectos hay uno de impacto")

	# El congelamiento se agota solo con el reloj del presentador encendido.
	var drained := 0
	while _presenter().is_hit_stopped() and drained < 120:
		await physics_frame
		drained += 1
	_presenter().set_physics_process(false)

	_context.check(not _presenter().is_hit_stopped(), "y se descongela solo al agotarse")
	await _drain_fx(layer)
	_cleanup()


## Deja la zona sin enemigos vivos, para que los casos que miden al jugador no se
## peleen con la IA: un NPC que golpee al jugador dispara `impact_struck` por el
## lado que recibe, y un caso que mida el golpe que da el jugador lo confundiría.
func _pacify_npcs() -> void:
	var session: RefCounted = _game().session
	if session == null or session.get("npcs") == null:
		return
	for agent in session.get("npcs").agents:
		if not agent.npc.is_dead:
			agent.npc.take_damage(agent.npc.health.maximum)