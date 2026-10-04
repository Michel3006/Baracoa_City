class_name MovementController
extends RefCounted

## Caso de uso: mover al jugador (sección 4.2, "moverse").
##
## Translacional: no implementa física ni dibuja nada. Calcula la intención a
## partir de la entrada y aplica el desplazamiento sobre el cuerpo físico que le
## inyecta la capa Presentation. Es el punto único donde se decide la velocidad.
##
## Dependencias: application -> domain, infrastructure/configuration

signal move_performed(velocity: Vector2, moved: Vector2)
signal direction_changed(direction: Vector2)
signal blocked_started(duration: float)

const DIRECTION_UP := Vector2.UP
const DIRECTION_DOWN := Vector2.DOWN
const DIRECTION_LEFT := Vector2.LEFT
const DIRECTION_RIGHT := Vector2.RIGHT

var move_speed: float = GameConfig.PLAYER_SPEED
var is_blocked: bool = false
var is_enabled: bool = true

var _body: CharacterBody2D = null
var _facing: Vector2 = DIRECTION_DOWN
var _block_remaining: float = 0.0


func _init(body: CharacterBody2D = null) -> void:
	_body = body


func bind(body: CharacterBody2D) -> void:
	_body = body


func facing() -> Vector2:
	return _facing


## Traduce la entrada del jugador a un vector de intención normalizado.
## Retorna Vector2.ZERO si no hay entrada.
func intent_from_input() -> Vector2:
	var intent := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	return intent.normalized() if intent.length_squared() > 1.0 else intent


## Desplaza al jugador un delta concreto. Devuelve el vector realmente recorrido.
##
## El desplazamiento lo resuelve Godot; este método solo decide la velocidad y
## avisa del resultado. Es el punto que reemplazará el servidor en la Fase 2.
func move(delta: float, intent: Vector2) -> Vector2:
	if _body == null:
		return Vector2.ZERO
	advance(delta)
	var velocity := Vector2.ZERO
	if is_enabled and not is_blocked:
		velocity = intent * move_speed
	_body.velocity = velocity
	_body.move_and_slide()
	if not velocity.is_zero_approx():
		update_facing(intent)
	var moved := _body.velocity * delta
	move_performed.emit(velocity, moved)
	return moved


## Habilita o inhibe el movimiento (muerte, carga de zona, transición de escena).
func set_enabled(value: bool) -> void:
	is_enabled = value
	if not value and _body != null:
		_body.velocity = Vector2.ZERO


## Bloquea el movimiento durante `seconds` (aturdimiento, combate pesado).
func block_for(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_block_remaining = maxf(_block_remaining, seconds)
	is_blocked = true
	blocked_started.emit(seconds)


## Consume el reloj del bloqueo. Puede llamarse aunque el jugador no se mueva.
func advance(delta: float) -> void:
	if _block_remaining <= 0.0:
		is_blocked = false
		return
	_block_remaining = maxf(0.0, _block_remaining - delta)
	is_blocked = _block_remaining > 0.0


## Traduce una dirección de intención a la orientación de cuatro direcciones.
func update_facing(intent: Vector2) -> Vector2:
	var candidate := _facing
	if absf(intent.x) > absf(intent.y):
		candidate = DIRECTION_RIGHT if intent.x > 0.0 else DIRECTION_LEFT
	elif absf(intent.y) > 0.0:
		candidate = DIRECTION_DOWN if intent.y > 0.0 else DIRECTION_UP
	if candidate != _facing:
		_facing = candidate
		direction_changed.emit(candidate)
	return _facing