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

## Acción de entrada del golpe. Se lee aquí y no en el dominio porque el teclado
## es cosa del dispositivo.
const ACTION_ATTACK := &"attack"

var _view: PlayerView = null
var _movement: MovementController = null
var _combat: MeleeCombat = null

## Cuerpos ya golpeados en el swing actual, para no machacar al mismo objetivo
## mientras la hitbox sigue encendida.
var _struck: Array[Object] = []


func setup(view: PlayerView, movement: MovementController, combat: MeleeCombat = null) -> void:
	_view = view
	_movement = movement
	_combat = combat
	if _movement != null:
		_movement.bind(view)
		_movement.move_speed = view.move_speed
		_movement.move_performed.connect(_on_move_performed)
		_movement.direction_changed.connect(_on_direction_changed)
	if _combat != null:
		_combat.attack_started.connect(_on_attack_started)
		_combat.attack_window_closed.connect(_on_attack_window_closed)
		_combat.attack_finished.connect(_on_attack_finished)
		_combat.weapon_changed.connect(_on_weapon_changed)
		_combat.stun_applied.connect(_on_stun_applied)
		_combat.invulnerability_changed.connect(_on_invulnerability_changed)
		if _view != null:
			_view.set_weapon(_combat.weapon)


func _physics_process(delta: float) -> void:
	if _movement != null:
		_movement.move(delta, _movement.intent_from_input())
	if _combat == null:
		return
	_combat.advance(delta)
	if Input.is_action_just_pressed(ACTION_ATTACK):
		_combat.try_attack(_facing())
	_strike_visible_targets()


func _facing() -> Vector2:
	if _movement != null:
		return _movement.facing()
	if _view != null:
		return _view.facing()
	return Vector2.DOWN


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
		_combat.strike([target])


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
	if _view != null:
		_view.set_facing(direction)
		_view.begin_attack(weapon)


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
