class_name HitboxSensor
extends Area2D

## Hitbox del golpe cuerpo a cuerpo (secciones 7 y 10).
##
## Solo física: avisa de qué cuerpos ha tocado y cuánto se extiende. Cuánto daño
## hace ese contacto lo decide `MeleeCombat`; esta clase no sabe nada de reglas
## ni de daño.
##
## Vive apagada y se enciende solo durante la ventana de golpe, porque un sensor
## siempre activo detectaría cuerpos detrás del jugador.
##
## Dependencias: presentation -> application

## Capa que detecta. El jugador se excluye a mano para no golpearse a sí mismo.
const DETECTED_LAYERS: Array[int] = [CollisionLayers.NPC, CollisionLayers.PLAYER]

## Avisa de un cuerpo que ha entrado en el área.
signal body_found(body: Node)

## Alcance en píxeles de mundo, heredado del arma equipada.
@export var reach: float = 16.0

var _circle: CircleShape2D
var _direction: Vector2 = Vector2.DOWN
var _is_active: bool = false
## Cuerpos que nunca deben contar como objetivo, típicamente el dueño de la
## hitbox. Vive aquí porque el motor no ofrece excepciones para `Area2D`.
var _ignored: Array[CollisionObject2D] = []


func _ready() -> void:
	collision_layer = CollisionLayers.HITBOX
	collision_mask = CollisionLayers.mask(DETECTED_LAYERS)
	monitorable = false
	monitoring = false
	_build_shape()
	set_reach(reach)
	face(_direction)


func _build_shape() -> void:
	_circle = CircleShape2D.new()
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	shape.shape = _circle
	add_child(shape)


## Cambia el alcance según el arma equipada.
func set_reach(value: float) -> void:
	reach = maxf(1.0, value)
	if _circle != null:
		_circle.radius = reach * GameConfig.HITBOX_RADIUS_RATIO
	_place()


## Orienta la hitbox hacia donde mira el personaje.
func face(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	_direction = direction.normalized()
	_place()


## Enciende o apaga el sensor. El uso diferido es obligatorio: cambiar
## `monitoring` dentro de la física avisa de error.
func set_active(value: bool) -> void:
	if _is_active == value:
		return
	_is_active = value
	set_deferred(&"monitoring", value)


var is_active: bool:
	get:
		return _is_active


## Ignora un cuerpo propio. Sin esto la hitbox detectaría al propio jugador,
## que está en la misma capa.
##
## Ojo: en Godot 4 `Area2D` **no** tiene lista de excepciones. Solo
## `PhysicsBody2D` ofrece `add_collision_exception_with()`, y una `Area2D` no es
## un cuerpo físico. Por eso la exclusión se filtra aquí, al recoger los
## solapamientos, en vez de delegar en el motor.
func exclude_body(body: CollisionObject2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not _ignored.has(body):
		_ignored.append(body)


## ¿Este cuerpo se ha marcado como ignorado?
func is_ignored(body: Object) -> bool:
	return body != null and is_instance_valid(body) and _ignored.has(body)


## Cuerpos que la hitbox tiene encima ahora mismo, ya filtrados.
func overlapping_bodies() -> Array[Node2D]:
	var found: Array[Node2D] = []
	if not _is_active:
		return found
	for body: Node2D in get_overlapping_bodies():
		if is_ignored(body):
			continue
		found.append(body)
	return found


func _place() -> void:
	position = _direction * reach * GameConfig.HITBOX_FORWARD_RATIO
