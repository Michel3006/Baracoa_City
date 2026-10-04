extends RefCounted

## Pruebas de vida, daño y muerte (secciones 8 y 10).


func register() -> Array:
	return [
		["la vida no baja de cero", _damage_clamps_to_zero],
		["el daño nunca es negativo", _negative_damage_ignored],
		["la curación no supera el máximo", _heal_clamps_to_max],
		["el daño en un muerto se ignora", _damage_on_dead_ignored],
		["depleted se emite una sola vez", _depleted_emitted_once],
		["recargar restaura la vida", _refill_restores],
		["el jugador muere al llegar a 0", _player_dies],
		["reaparecer restaura vida y estado", _respawn_resets],
		["reaparecer vuelve a empezar vivo", _respawn_revives],
	]


func _damage_clamps_to_zero(ctx: ScriptTestContext) -> void:
	var health := Health.new(100.0)
	health.apply_damage(150.0)
	ctx.check_equal(health.current, 0.0, "vida tras daño excesivo")
	ctx.check(health.is_dead, "debe estar muerto")


func _negative_damage_ignored(ctx: ScriptTestContext) -> void:
	var health := Health.new(100.0)
	ctx.check_equal(health.apply_damage(-10.0), 0.0, "daño negativo debe inflictir 0")
	ctx.check_equal(health.current, 100.0, "la vida no cambia")


func _heal_clamps_to_max(ctx: ScriptTestContext) -> void:
	var health := Health.new(100.0)
	health.apply_damage(30.0)
	var healed := health.heal(80.0)
	ctx.check_almost_equal(healed, 30.0, "curación real")
	ctx.check_equal(health.current, 100.0, "no debe superar el máximo")


func _damage_on_dead_ignored(ctx: ScriptTestContext) -> void:
	var health := Health.new(10.0)
	health.apply_damage(100.0)
	ctx.check_equal(health.apply_damage(5.0), 0.0, "daño sobre un cuerpo muerto")


func _depleted_emitted_once(ctx: ScriptTestContext) -> void:
	var health := Health.new(10.0)
	var emitted: Array[int] = []
	health.depleted.connect(func() -> void: emitted.append(1))
	health.apply_damage(10.0)
	health.apply_damage(5.0)
	ctx.check_equal(emitted.size(), 1, "depleted debe emitirse una vez")


func _refill_restores(ctx: ScriptTestContext) -> void:
	var health := Health.new(50.0)
	health.apply_damage(25.0)
	health.refill()
	ctx.check_equal(health.current, 50.0, "vida tras recargar")
	ctx.check(not health.is_dead, "no debe estar muerto")


func _player_dies(ctx: ScriptTestContext) -> void:
	var player := Player.new()
	var died: Array[int] = []
	player.died.connect(func() -> void: died.append(1))
	player.take_damage(player.health.maximum)
	ctx.check_equal(died.size(), 1, "se debe emitir died")
	ctx.check(player.is_dead, "el jugador debe estar muerto")
	ctx.check_equal(player.state, PlayerState.Kind.DEAD, "estado tras morir")


func _respawn_resets(ctx: ScriptTestContext) -> void:
	var player := Player.new()
	player.take_damage(player.health.maximum)
	player.respawn_at(Vector2(64, 96))
	ctx.check_equal(player.position, Vector2(64, 96), "posición tras reaparecer")
	ctx.check_equal(player.state, PlayerState.Kind.IDLE, "estado tras reaparecer")
	ctx.check_equal(player.health.current, player.health.maximum, "vida tras reaparecer")


func _respawn_revives(ctx: ScriptTestContext) -> void:
	var player := Player.new()
	player.take_damage(player.health.maximum)
	ctx.check(not player.take_damage(5.0) > 0.0, "un muerto no recibe daño")
	player.respawn_at(Vector2.ZERO)
	ctx.check(player.is_alive, "tras reaparecer debe estar vivo")