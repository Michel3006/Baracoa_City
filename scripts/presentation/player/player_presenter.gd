class_name PlayerPresenter
extends Node

## Puente entre la entrada del usuario y los casos de uso de movimiento y combate
## (secciones 4.1 "entrada del usuario", 4.2 "moverse" y "combatir").
##
## La entrada vive en Presentation porque depende del dispositivo. Las decisiones
## (hacia dónde, si puede golpear, cuánto daño) viven en Application. Este nodo solo
## conecta ambos y mantiene el reloj de la física.
##
## Dependencias: presentation -> application

## Acción de entrada del golpe con arma. Se lee aquí y no en el dominio porque el
## teclado es cosa del dispositivo.
const ACTION_ATTACK := &"attack"

## Acción de entrada del golpe a puños. Son dos teclas distintas y no un modificador
## del mismo golpe: es la diferencia entre "ataco con lo que llevo" y "ataco con las
## manos", y el caso de uso necesita saber cuál de las dos es.
const ACTION_ATTACK_UNARMED := &"attack_unarmed"

## Las otras dos cadenas (sección 23): K pega la pesada y L las patadas. Van
## como acciones aparte y no como modificadores, por la misma razón que
## `ACTION_ATTACK_UNARMED`: el caso de uso necesita saber qué cadena es.
const ACTION_ATTACK_HEAVY := &"attack_heavy"
const ACTION_ATTACK_KICK := &"attack_kick"

## Defensa (secciones 30 y 31): esquive y guardia. Se leen aquí por la misma razón
## que el ataque: el teclado es cosa del dispositivo, no del caso de uso.
const ACTION_DODGE := &"dodge"
const ACTION_BLOCK := &"block"

var _view: PlayerView = null
var _movement: MovementController = null
var _combat: MeleeCombat = null

## Velocidad del jugador sin ningún multiplicador. Se guarda al enchufar porque
## mientras dura un golpe el presentador escribe `move_speed` cada fotograma
## (sección 14) y multiplicar dos veces sobre el valor ya multiplicado acabaría
## con el jugador clavado en el segundo golpe.
var _base_move_speed: float = GameConfig.PLAYER_SPEED

## Cuerpos ya golpeados en el swing actual, para no machacar al mismo objetivo
## mientras la hitbox sigue encendida.
var _struck: Array[Object] = []

## Si el golpe en curso se dio a puños. Lo consulta `MeleeCombat.strike()` para
## aplicar el daño del arma correcta.
var _struck_unarmed: bool = false


## Nodo donde se sueltan los efectos de golpe. Puede ser nulo: los tests no montan
## mundo, y una presentación que necesita un nodo para poder probarse está mal.
var _fx_parent: Node2D = null

## Hit stop (sección 36): mientras dura, este presentador no mueve el reloj del
## combate ni el cuerpo. Lo pone la señal `impact_struck` del propio combate,
## que se emite tanto al dar como al recibir un golpe que entra, y se agota en
## el `_physics_process` sin dejar que nada avance. No se congela el dominio:
## los unitarios siguen moviendo el reloj a mano.
var _hit_stop_remaining: float = 0.0


func setup(view: PlayerView, movement: MovementController, combat: MeleeCombat = null) -> void:
	_view = view
	_movement = movement
	_combat = combat
	if _movement != null:
		_movement.bind(view)
		_movement.move_speed = view.move_speed
		_base_move_speed = view.move_speed
		_movement.move_performed.connect(_on_move_performed)
		_movement.direction_changed.connect(_on_direction_changed)
	if _combat != null:
		_combat.attack_started.connect(_on_attack_started)
		_combat.attack_window_opened.connect(_on_attack_window_opened)
		_combat.attack_window_closed.connect(_on_attack_window_closed)
		_combat.attack_finished.connect(_on_attack_finished)
		_combat.weapon_changed.connect(_on_weapon_changed)
		_combat.stun_applied.connect(_on_stun_applied)
		_combat.stun_changed.connect(_on_stun_changed)
		_combat.invulnerability_changed.connect(_on_invulnerability_changed)
		_combat.reaction_started.connect(_on_reaction_started)
		_combat.reaction_finished.connect(_on_reaction_finished)
		_combat.dodge_started.connect(_on_dodge_started)
		_combat.dodge_finished.connect(_on_dodge_finished)
		_combat.block_changed.connect(_on_block_changed)
		_combat.impact_struck.connect(_on_impact_struck)
		# Los enemigos golpean a este nodo a través de la capa PLAYER, así que
		# necesita saber a quién avisa. El objetivo es el cuerpo de combate y no el
		# `Player` del dominio: así el daño respeta la invulnerabilidad.
		if _view != null:
			_view.combat_target = _combat
		if _view != null:
			_view.set_weapon(_combat.weapon)


## Dónde se sueltan los efectos de golpe. Lo inyecta la escena del mundo para no
## tener que adivinar el padre del nodo.
func set_fx_parent(node: Node2D) -> void:
	_fx_parent = node


func _physics_process(delta: float) -> void:
	# La muerte la dibuja la vista: `PlayerView.set_dead()` apaga la hitbox, corta
	# el puñetazo en curso, reproduce el clip de morir y pone el tinte. Hasta ahora
	# nadie lo llamaba, así que el jugador muerto se quedaba de pie con su última
	# animación y `PlayerView.is_dead()` era siempre falso. El NPC y el muñeco de
	# pruebas ya sincronizaban su muerte con la vista; esto los pone de acuerdo.
	#
	# Va antes de los cortes de abajo a propósito: así la muerte se dibuja también
	# durante el hit stop y aunque no haya combate enganchado, en vez de depender de
	# que el fotograma llegue hasta el final. `set_dead` no hace nada si el valor no
	# cambió, así que llamarlo cada fotograma no cuesta.
	if _view != null:
		_view.set_dead(_combat != null and _combat.is_dead)
	# Hit stop (sección 36): el golpe que acaba de entrar o de salir congela un
	# instante el reloj del combate y el cuerpo. No se llama a `advance()` mientras
	# dura, que es lo que de verdad congela el tiempo de combate; la vista sigue en
	# su pose porque el clip apenas avanza en 35-70 ms.
	if _hit_stop_remaining > 0.0:
		_hit_stop_remaining = maxf(0.0, _hit_stop_remaining - delta)
		return
	if _movement != null:
		# El empuje (knockback o rodada) lo escribe el combate en su `advance()` y
		# se copia al movimiento antes de mover: en el fotograma en que llega el
		# golpe el empuje aún vale cero, así que se acepta un fotograma de latencia
		# a cambio de no tener dos relojes para lo mismo.
		if _combat != null:
			_movement.external_velocity = _combat.external_velocity
		_movement.move_speed = _current_move_speed()
		_movement.move(delta, _movement.intent_from_input())
	if _combat == null:
		return
	_combat.advance(delta)
	_read_defense_input()
	_read_attack_input()
	_strike_visible_targets()


## Traduce las teclas de defensa: la guardia se mantiene mientras se pulse, y el
## esquive se dispara con una pulsación.
##
## El esquive sale hacia donde se camina y, sin dirección, hacia donde se mira: es
## la diferencia entre rodar hacia atrás para salir del golpe y rodar hacia
## delante. La guardia se refresca cada fotograma (levantar y soltar) y es el caso
## de uso el que decide si puede subir ahora mismo.
func _read_defense_input() -> void:
	_combat.set_blocking(Input.is_action_pressed(ACTION_BLOCK))
	if Input.is_action_just_pressed(ACTION_DODGE):
		_combat.try_dodge(_dodge_direction())


func _dodge_direction() -> Vector2:
	if _movement != null:
		var intent := _movement.intent_from_input()
		if not intent.is_zero_approx():
			return intent
	return _facing()


## Velocidad a la que se mueve este fotograma (sección 14).
##
## El multiplicador lo manda el ataque en curso: mientras dura un jab el
## jugador conserva el 65 % del paso y con la cruzada apenas arrastra los pies.
## Sin golpe en curso devuelve la marcha normal, que es un 100 % exacto.
func _current_move_speed() -> float:
	if _combat == null:
		return _base_move_speed
	return _base_move_speed * _combat.movement_multiplier


## Traduce las teclas de golpe a una llamada del caso de uso.
##
## Hay tres cadenas y dos formas de pegar a puños, y las cinco cosas se dicen
## con acciones distintas: el presentador solo traduce, la decisión de si sale o
## no (fases, buffer, stamina) es del caso de uso.
##
## Si el jugador pulsa varias en el mismo frame manda la primera que aparezca:
## las patadas, que son las que más comprometen, y después la cadena pesada.
func _read_attack_input() -> void:
	if Input.is_action_just_pressed(ACTION_ATTACK_KICK):
		_combat.try_attack_family(_facing(), AttackCatalog.FAMILY_KICK)
		return
	if Input.is_action_just_pressed(ACTION_ATTACK_HEAVY):
		_combat.try_attack_family(_facing(), AttackCatalog.FAMILY_HEAVY)
		return
	if Input.is_action_just_pressed(ACTION_ATTACK):
		_combat.try_attack(_facing(), false)
		return
	if Input.is_action_just_pressed(ACTION_ATTACK_UNARMED):
		_combat.try_attack(_facing(), true)


func _facing() -> Vector2:
	if _movement != null:
		return _movement.facing()
	if _view != null:
		return _view.facing()
	return Vector2.DOWN


## ¿Está el jugador sin vida? Lo consulta la escena al teleportarlo para decidir si
## la vista tiene que revivir.
func is_dead() -> bool:
	return _combat != null and _combat.is_dead


## Encuentra lo que la hitbox tiene encima y pasa el objetivo al caso de uso.
##
## La física solo decide a quién ha tocado; el daño lo calcula `MeleeCombat`. Un
## cuerpo cuenta como objetivo si expone `combat_target`, su objeto de dominio.
func _strike_visible_targets() -> void:
	if not _combat.is_window_open or _view == null or _view.hitbox == null:
		return
	for body: Node2D in _view.hitbox.overlapping_bodies():
		var target := _domain_target_of(body)
		if target == null or target in _struck:
			continue
		_struck.append(target)
		var hits := _combat.strike([target], _struck_unarmed)
		# El burst de impacto sale en el punto del cuerpo golpeado; aquí es el
		# único sitio donde el presentador sabe dónde cayó el golpe. Solo si el
		# golpe entró: fallar no celebra nada.
		if hits > 0:
			_spawn_impact(body.global_position)


## Burst de partículas en el punto donde conectó el golpe (sección 38). El tier
## es el del ataque en curso: el mismo que decide el hit stop y la sacudida.
func _spawn_impact(point: Vector2) -> void:
	if _fx_parent == null or _view == null or _combat == null:
		return
	var attack := _combat.current_attack
	var tier: StringName = attack.knockback if attack != null else CombatReaction.TIER_LOW
	ImpactEffect.spawn(_fx_parent, point, _view.facing(), tier)


## ¿Está el mundo congelado por un impacto? Lo consultan los tests.
func is_hit_stopped() -> bool:
	return _hit_stop_remaining > 0.0


## Cuánto le queda al hit stop.
func hit_stop_remaining() -> float:
	return _hit_stop_remaining


## Un golpe ha entrado (por el lado que sea): se congela el presentador los
## milisegundos que manda el tier. La fusión con `max` evita que dos impactos en
## el mismo fotograma sumen su congelación.
func _on_impact_struck(tier: StringName) -> void:
	_hit_stop_remaining = maxf(_hit_stop_remaining, CombatImpact.hit_stop_of(tier))


func _domain_target_of(body: Node) -> Object:
	if body == null or not ("combat_target" in body):
		return null
	var target: Variant = (body as Object).get(&"combat_target")
	return target as Object if target is Object else null


func _on_move_performed(_velocity: Vector2, moved: Vector2) -> void:
	if _view != null:
		_view.apply_motion(moved)


func _on_direction_changed(facing: Vector2) -> void:
	if _view != null:
		_view.set_facing(facing)


func _on_attack_started(weapon: Weapon, direction: Vector2, _window: float) -> void:
	_struck.clear()
	# El golpe en curso puede ser a puños aunque el arma equipada siga en la mano.
	_struck_unarmed = WeaponCatalog.is_unarmed(weapon)
	if _view != null:
		_view.set_facing(direction)
		# La animación la elige el ataque: el clip de su id si la hoja lo trae y,
		# si no, el de golpe genérico. La duración también la pone el ataque
		# (`AttackDefinition.duration`), que es exactamente lo que dura su clip.
		_view.begin_attack(
			weapon, _combat.current_attack_id, _combat.current_duration
		)
	# A puños no sale arco: no hay nada que corte el aire. El arco es de la hoja del
	# arma, así que con las manos vacías lo único que se ve es la animación de golpe
	# del personaje, que es justo la diferencia que se pidió entre las dos formas de
	# pegar.
	if not _struck_unarmed:
		_spawn_slash(direction)


## Enciende la hitbox del jugador (sección 16).
##
## No se enciende en `begin_attack`: el golpe empieza en WINDUP y la ventana de
## impacto llega después, cuando el frame de contacto está a punto de caer. Si
## la hitbox se encendiera al empezar la pose, un golpe lento estaría golpeando
## durante todo su windup, que es justo lo que la sección 10 prohíbe.
func _on_attack_window_opened() -> void:
	_struck.clear()
	if _view != null:
		_view.start_hitbox()


## Suelta el arco por delante del cuerpo, a la altura del torso.
##
## El sitio lo decide `SlashEffect.origin_for`, que es el mismo para el jugador y para
## los enemigos: si cada presentador calculaba su propio origen, las dos animaciones
## acabarían desalineadas sin que ningún número estuviera mal.
func _spawn_slash(direction: Vector2) -> void:
	if _fx_parent == null or _view == null:
		return
	var origin := SlashEffect.origin_for(_view.global_position, direction, _view.torso_offset())
	SlashEffect.spawn(_fx_parent, direction, origin)


func _on_attack_window_closed() -> void:
	if _view != null:
		_view.stop_hitbox()
	_struck.clear()


func _on_attack_finished() -> void:
	if _view != null:
		_view.end_attack()
	_struck.clear()


func _on_weapon_changed(weapon: Weapon) -> void:
	if _view != null:
		_view.set_weapon(weapon)


func _on_stun_applied(duration: float) -> void:
	if _movement != null:
		_movement.block_for(duration)


func _on_invulnerability_changed(active: bool) -> void:
	if _view != null:
		_view.set_hurt(active)


func _on_stun_changed(active: bool) -> void:
	if _view != null:
		_view.set_stun(active)


func _on_reaction_started(clip: StringName, _duration: float) -> void:
	if _view != null:
		_view.begin_reaction(clip)


func _on_reaction_finished() -> void:
	if _view != null:
		_view.end_reaction()


func _on_dodge_started(direction: Vector2, _duration: float) -> void:
	if _view != null:
		_view.begin_dodge(direction)


func _on_dodge_finished() -> void:
	if _view != null:
		_view.end_dodge()


func _on_block_changed(active: bool) -> void:
	if _view != null:
		_view.set_blocking(active)
