class_name NpcBrain
extends RefCounted

## IA sencilla de un NPC (sección 18).
##
## Decide el estado y hacia dónde quiere andar; no mueve nada. La física la resuelve
## el cuerpo que le inyecta la capa Presentation, igual que `MovementController` con
## el jugador.
##
## Sin árbol de comportamiento ni máquina de estadosmontada a medida: una función
## que decide el estado y una que produce la intención. La sección 18 dice "no
## implementar IA avanzada inicialmente", y esto es exactamente eso.
##
## Reglas, en el orden en que se miran:
## 1. Sin vida: DEAD y no hace nada.
## 2. Poca vida: FLEE, y se aleja del jugador.
## 3. El jugador está dentro del alcance: ATTACK.
## 4. El jugador está cerca: CHASE.
## 5. Fuera de la correa, o sin objetivo: vuelve a casa y pasea.
##
## Dependencias: application -> domain, infrastructure/configuration

signal state_changed(previous: NpcState.Kind, current: NpcState.Kind)

var npc: Npc

## Objetivo actual. Lo fija la capa Application con la posición del jugador; el
## cerebro no busca al jugador por el mundo, se lo dan.
var target_position: Vector2 = Vector2.ZERO
## Si hay un objetivo que perseguir. Sin objetivo, el NPC no reacciona.
var has_target: bool = false

## Momento en el que al NPC le apetece volver a pasearse. Lo mueve el reloj.
var _wander_remaining: float = 0.0
## Destino del paseo actual.
var _wander_target: Vector2 = Vector2.ZERO
## En qué sentido gira el NPC al marcharse, para que no vaya siempre en línea recta.
var _wander_phase: float = 0.0


func _init(body: Npc = null) -> void:
	npc = body
	if npc != null:
		_wander_target = npc.home
		_wander_remaining = npc.behavior.wander_interval


var state: NpcState.Kind:
	get:
		return npc.state if npc != null else NpcState.Kind.DEAD


## Fija (o quita) el objetivo. Cambiar de objetivo reinicia el paseo: un NPC al que
## acaban de perder de vista no debe seguir yendo a donde iba antes.
func set_target(position: Vector2) -> void:
	target_position = position
	has_target = true


func clear_target() -> void:
	has_target = false


## Consume el reloj y recalcula el estado.
func advance(delta: float) -> void:
	if npc == null or npc.is_dead:
		return
	if _wander_remaining > 0.0:
		_wander_remaining = maxf(0.0, _wander_remaining - delta)
	_evaluate()


## Decide el estado que corresponde a la situación actual. Público para poder
## probarlo sin reloj.
func _evaluate() -> void:
	if npc.health_ratio <= npc.behavior.flee_health_ratio:
		_transition(NpcState.Kind.FLEE)
		return
	if not has_target:
		_transition(NpcState.Kind.IDLE if _wander_remaining > 0.0 else NpcState.Kind.WANDER)
		return

	var distance := npc.position.distance_to(target_position)
	# Fuera de la correa el NPC se rinde y vuelve a su puesto: es lo que evita que
	# un enemigo persiga al jugador hasta el borde del mapa.
	if npc.distance_from_home > npc.behavior.leash_radius:
		_transition(NpcState.Kind.IDLE)
		return
	if distance <= npc.behavior.attack_range:
		_transition(NpcState.Kind.ATTACK)
		return
	if distance <= npc.behavior.aggro_radius:
		_transition(NpcState.Kind.CHASE)
		return
	_transition(NpcState.Kind.IDLE)


## Intención de desplazamiento en píxeles por segundo. La consume el cuerpo.
func intent() -> Vector2:
	if npc == null or npc.is_dead:
		return Vector2.ZERO
	match npc.state:
		NpcState.Kind.CHASE:
			return _towards(target_position)
		NpcState.Kind.FLEE:
			return _away_from(target_position)
		NpcState.Kind.WANDER:
			return _wander_step()
		_:
			# IDLE y ATTACK no se mueven: en ATTACK, quieto, es exactamente lo que
			# hace falta para que el golpe no salga de largo.
			return Vector2.ZERO


## Se acerca al objetivo sin entrar en su propio alcance de golpe: si no, el NPC
## llegaría encima y sus golpes nunca alcanzarían.
func _towards(destination: Vector2) -> Vector2:
	var offset := destination - npc.position
	var distance := offset.length()
	if distance <= npc.behavior.attack_range:
		return Vector2.ZERO
	return offset.normalized() * npc.behavior.move_speed


func _away_from(origin: Vector2) -> Vector2:
	var offset := npc.position - origin
	if offset.is_zero_approx():
		return Vector2.ZERO
	return offset.normalized() * npc.behavior.move_speed


## Paseo en reposo: un destino nuevo cada `wander_interval`, dentro del radio.
func _wander_step() -> Vector2:
	if _wander_remaining <= 0.0:
		_pick_wander_target()
	var offset := _wander_target - npc.position
	if offset.length() <= 1.0:
		_pick_wander_target()
		return Vector2.ZERO
	return offset.normalized() * npc.behavior.move_speed * GameConfig.NPC_WANDER_SPEED_RATIO


func _pick_wander_target() -> void:
	# Un ángulo que avanza de forma determinista reparte los destinos: multiplicar
	# por el número dorado reparte los puntos mejor que un aleatorio y siempre da
	# el mismo mapa en cada partida, que es lo que necesitan los tests.
	_wander_phase = fposmod(_wander_phase + GameConfig.NPC_WANDER_GOLDEN_ANGLE, TAU)
	var radius := npc.behavior.wander_radius
	var distance := radius * (0.35 + 0.65 * absf(sin(_wander_phase * 2.0)))
	_wander_target = npc.home + Vector2(cos(_wander_phase), sin(_wander_phase)) * distance
	_wander_remaining = npc.behavior.wander_interval


## Aplica la transición solo si cambia, y avisa. `Npc.transition_to()` ya valida el
## grafo y no hace nada si el estado es el mismo, así que llegar aquí significa que
## el estado ha cambiado de verdad.
func _transition(next: NpcState.Kind) -> void:
	if not npc.transition_to(next):
		return
	state_changed.emit(npc.state, next)
