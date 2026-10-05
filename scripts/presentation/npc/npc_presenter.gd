class_name NpcPresenter
extends Node

## Puente de un NPC entre su caso de uso y su cuerpo físico.
##
## Es el equivalente de `PlayerPresenter` para un enemigo, y hace lo mismo en el
## mismo orden: mueve el reloj, mueve el cuerpo por donde manda la IA, enciende la
## hitbox al golpear y convierte lo que la hitbox ha tocado en objetivos del caso de
## uso.
##
## Lo inyecta `NpcSpawner`. No lee el teclado ni busca al jugador: la posición del
## objetivo se la pasa quien lo dirige, porque en Fase 2 vendrá del servidor.
##
## Dependencias: presentation -> application

var _view: NpcView = null
var _npc: Npc = null
var _brain: NpcBrain = null
var _combat: NpcCombat = null

## Objetivos ya golpeados en el swing actual, para no machacar al mismo en cada
## frame mientras la hitbox sigue encendida.
var _struck: Array[Object] = []


func setup(view: NpcView, npc: Npc, brain: NpcBrain, combat: NpcCombat) -> void:
	_view = view
	_npc = npc
	_brain = brain
	_combat = combat
	if _view == null or _npc == null:
		return
	# La hitbox del jugador busca cuerpos en la capa NPC y lee `combat_target`:
	# sin esto el golpe del jugador no encontraría a quién golpear.
	_view.combat_target = _npc
	_view.set_kind(_npc.kind)
	_view.global_position = _npc.position
	_view.move_speed = _npc.behavior.move_speed
	_view.hitbox.set_reach(_npc.behavior.attack_range)

	if _combat != null:
		_combat.attack_started.connect(_on_attack_started)
		_combat.attack_window_closed.connect(_on_attack_window_closed)
		_combat.attack_finished.connect(_on_attack_finished)
		_combat.invulnerability_changed.connect(_on_invulnerability_changed)
		_combat.died.connect(_on_died)


func npc() -> Npc:
	return _npc


func _physics_process(delta: float) -> void:
	if _view == null or _npc == null:
		return
	_combat.advance(delta)
	_brain.advance(delta)
	_sync_state()
	_move(delta)
	_try_attack()
	_strike_visible_targets()


## Refleja en la vista el estado que acaba de decidir la IA.
func _sync_state() -> void:
	if _npc.is_dead:
		_view.set_dead(true)
		return
	_view.set_dead(false)
	_view.set_hurt(_combat.is_invulnerable and not _combat.is_stunned)
	# El NPC mira al objetivo mientras lo persigue o lo ataca, y adonde va mientras
	# pasea. Sin esto seguiría mirando al frente mientras se aleja.
	if _brain.has_target and _npc.state in [NpcState.Kind.CHASE, NpcState.Kind.ATTACK]:
		_view.set_facing(_towards_target())


## Aplica el desplazamiento y lo devuelve al dominio. El dominio es la fuente de
## verdad de la posición, igual que con el jugador.
func _move(delta: float) -> void:
	var intent := Vector2.ZERO
	if not _npc.is_dead and not _combat.is_stunned and not _combat.is_attacking:
		intent = _brain.intent()
	_view.velocity = intent
	_view.move_and_slide()
	var moved := _view.velocity * delta
	_view.apply_motion(moved)
	_npc.move_to(_view.global_position, _view.facing())


## Intenta golpear si la IA está en ATTACK y el golpe está disponible.
func _try_attack() -> void:
	if _npc.is_dead or _npc.state != NpcState.Kind.ATTACK:
		return
	_combat.try_attack(_towards_target())


## Encuentra lo que la hitbox del NPC tiene encima y se lo pasa al caso de uso.
##
## El objetivo legítimo es el cuerpo de combate del jugador: es `MeleeCombat`, no el
## `Player` del dominio, para que el daño pase por la invulnerabilidad y el
## aturdimiento en vez de saltárselos.
func _strike_visible_targets() -> void:
	if not _combat.is_window_open or _view == null or _view.hitbox == null:
		return
	for body: Node2D in _view.hitbox.overlapping_bodies():
		var target := _domain_target_of(body)
		if target == null or target in _struck:
			continue
		_struck.append(target)
		_combat.strike([target])


## Igual que en el jugador: la física solo dice a quién ha tocado, y el cuerpo
## expone el objeto de dominio al que hay que pegarle.
func _domain_target_of(body: Node) -> Object:
	if body == null or not ("combat_target" in body):
		return null
	var target: Variant = (body as Object).get(&"combat_target")
	return target as Object if target is Object else null


func _towards_target() -> Vector2:
	var offset := _brain.target_position - _npc.position
	if offset.is_zero_approx():
		return _npc.direction
	return offset.normalized()


func _on_attack_started(_direction: Vector2, _window: float) -> void:
	_struck.clear()
	_view.begin_attack(_npc.behavior.attack_range)


func _on_attack_window_closed() -> void:
	_view.stop_hitbox()
	_struck.clear()


func _on_attack_finished() -> void:
	_view.end_attack()
	_struck.clear()


func _on_invulnerability_changed(active: bool) -> void:
	_view.set_hurt(active)


func _on_died() -> void:
	_view.set_dead(true)
	_struck.clear()
