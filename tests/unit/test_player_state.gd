extends RefCounted

## Pruebas de la máquina de estados del jugador (sección 8).


func register() -> Array:
	return [
		["transición IDLE -> MOVING permitida", _idle_to_moving],
		["transición a un estado igual se rechaza", _same_state_rejected],
		["transición ilegal desde DEAD se rechaza", _dead_is_terminal],
		["transición HURT -> DEAD permitida", _hurt_to_dead],
		["el estado solo cambia por una transición válida", _player_state_integrity],
	]


func _idle_to_moving(ctx: ScriptTestContext) -> void:
	ctx.check(PlayerState.can_transition_to(PlayerState.Kind.IDLE, PlayerState.Kind.MOVING), "IDLE->MOVING debe permitirse")


func _same_state_rejected(ctx: ScriptTestContext) -> void:
	ctx.check(not PlayerState.can_transition_to(PlayerState.Kind.IDLE, PlayerState.Kind.IDLE), "IDLE->IDLE no es una transición")


func _dead_is_terminal(ctx: ScriptTestContext) -> void:
	ctx.check(not PlayerState.can_transition_to(PlayerState.Kind.DEAD, PlayerState.Kind.IDLE), "DEAD no tiene salida")
	ctx.check(not PlayerState.can_transition_to(PlayerState.Kind.DEAD, PlayerState.Kind.MOVING), "DEAD no puede volver a MOVING")


func _hurt_to_dead(ctx: ScriptTestContext) -> void:
	ctx.check(PlayerState.can_transition_to(PlayerState.Kind.HURT, PlayerState.Kind.DEAD), "HURT->DEAD debe permitirse")


func _player_state_integrity(ctx: ScriptTestContext) -> void:
	var player := Player.new()
	var seen: Array[int] = []
	player.state_changed.connect(func(previous: PlayerState.Kind, current: PlayerState.Kind) -> void:
		seen.append(current)
	)

	ctx.check(player.transition_to(PlayerState.Kind.MOVING), "IDLE->MOVING debe realizarse")
	ctx.check(player.transition_to(PlayerState.Kind.IDLE), "MOVING->IDLE debe realizarse")
	ctx.check(player.state == PlayerState.Kind.IDLE, "el estado debe quedar en IDLE")
	ctx.check_equal(seen.size(), 2, "se deben emitir dos cambios de estado")