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


func _ready() -> void:
	zoom = Vector2.ONE * zoom_level
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false


func follow(target: Node2D) -> void:
	_target = target
	if _target != null:
		global_position = _target.global_position
		make_current()


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