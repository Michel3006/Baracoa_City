extends RefCounted

## Pruebas del caso de uso de movimiento (secciones 4.2 y 7).
##
## No requieren escena: prueban la lógica de orientación y de bloqueo, que es la
## parte con reglas. El desplazamiento con colisiones se valida en el test de
## integración del mundo.


func register() -> Array:
	return [
		["la orientación sigue al eje dominante", _facing_uses_dominant_axis],
		["la orientación por defecto mira abajo", _default_facing],
		["el bloqueo impide moverse y expira", _block_expires],
		["sin cuerpo no hay movimiento", _no_body_no_motion],
	]


func _default_facing(ctx: ScriptTestContext) -> void:
	var movement := MovementController.new()
	ctx.check_equal(movement.facing(), Vector2.DOWN, "orientación inicial")


func _facing_uses_dominant_axis(ctx: ScriptTestContext) -> void:
	var movement := MovementController.new()
	var seen: Array[Vector2] = []
	movement.direction_changed.connect(func(direction: Vector2) -> void: seen.append(direction))

	movement.update_facing(Vector2(1.0, 0.2))
	movement.update_facing(Vector2(0.2, 1.0))
	movement.update_facing(Vector2(-0.9, 0.1))
	movement.update_facing(Vector2(0.1, -0.9))

	ctx.check_equal(seen, [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP], "secuencia de orientaciones")


func _block_expires(ctx: ScriptTestContext) -> void:
	var movement := MovementController.new()
	movement.block_for(0.5)
	ctx.check(movement.is_blocked, "debe quedar bloqueado")
	movement.advance(0.25)
	ctx.check(movement.is_blocked, "sigue bloqueado a mitad del tiempo")
	movement.advance(0.30)
	ctx.check(not movement.is_blocked, "el bloqueo debe expirar")


func _no_body_no_motion(ctx: ScriptTestContext) -> void:
	var movement := MovementController.new()
	ctx.check_equal(movement.move(1.0 / 60.0, Vector2.RIGHT), Vector2.ZERO, "sin cuerpo no se mueve")