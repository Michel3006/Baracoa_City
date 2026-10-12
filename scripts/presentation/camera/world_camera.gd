class_name WorldCamera
extends Camera2D

## Cámara que sigue al jugador dentro de los límites de la zona (sección 17).
##
## Los límites se derivan del tamaño de la zona, así que añadir un mapa mayor no
## requiere tocar la cámara. El zoom es configurable para futura vista de
## interiores o vehículos.
##
## Dependencias: presentation, infrastructure/configuration

const FOLLOW_SMOOTHING := 8.0

@export var zoom_level: float = GameConfig.CAMERA_ZOOM
@export var use_limits: bool = true

var _target: Node2D = null

## Sacudida de imacto (sección 37): intensidad y tiempo restante. El
## desplazamiento se aplica al `offset` de la cámara y se disuelve a cero, para
## que el mundo vuelva donde estaba sin que el suavizado del seguimiento se
## entere.
var _shake_intensity: float = 0.0
var _shake_time: float = 0.0


func _ready() -> void:
	zoom = Vector2.ONE * zoom_level
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false


func follow(target: Node2D) -> void:
	_target = target
	if _target != null:
		global_position = _target.global_position
		make_current()


## Sacudida breve de la cámara. Se fusiona con `max`: cuando un golpe conecta,
## el atacante y el que recibe emiten `impact_struck` en el mismo fotograma, y
## las dos llamadas seguidas no deben temblar dos veces ni sumar la sacudida.
## La que manda es la mayor de las dos.
func shake(intensity: float) -> void:
	if intensity <= 0.0:
		return
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_time = GameConfig.CAMERA_SHAKE_TIME


## ¿La cámara está temblando ahora mismo?
func is_shaking() -> bool:
	return _shake_time > 0.0


## Fuerza actual del temblor, de 0 a la intensidad con la que empezó. Decae en
## línea recta hasta cero: al principio sacude de verdad y el final es un temblor
## leve que no corta la lectura.
func shake_strength() -> float:
	return _shake_intensity * (_shake_time / GameConfig.CAMERA_SHAKE_TIME)


## El temblor avanza con el reloj de la física (delta fijo), no con el de
## render: es lo que permite a los tests esperar `physics_frame` un número
## fijo de veces y saber cuánto ha menguado la sacudida.
func _physics_process(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time = maxf(0.0, _shake_time - delta)
	if _shake_time <= 0.0:
		_shake_intensity = 0.0
		offset = Vector2.ZERO
		return
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength()


func apply_zone_bounds(area: Rect2) -> void:
	use_limits = area.size.x > 0.0 and area.size.y > 0.0
	if not use_limits:
		limit_left = 0
		limit_top = 0
		limit_right = 0
		limit_bottom = 0
		return
	limit_left = int(area.position.x)
	limit_top = int(area.position.y)
	limit_right = int(area.end.x)
	limit_bottom = int(area.end.y)
	_reset_smoothing()


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	global_position = global_position.lerp(
		_target.global_position,
		clampf(FOLLOW_SMOOTHING * delta, 0.0, 1.0)
	)


## Al cambiar los límites hay que forzar un nuevo cálculo de suavizado,
## porque Godot los aplica en diferido un frame.
func _reset_smoothing() -> void:
	reset_smoothing()