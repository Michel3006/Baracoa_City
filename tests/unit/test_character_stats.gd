extends RefCounted

## Pruebas de estadísticas de personaje (sección 9).


func register() -> Array:
	return [
		["valores por defecto razonables", _defaults],
		["se puede modificar una estadística", _set_stat],
		["una estadística inexistente se rechaza", _unknown_stat_rejected],
		["la instantánea contiene todas las estadísticas", _snapshot_complete],
	]


func _defaults(ctx: ScriptTestContext) -> void:
	var stats := CharacterStats.new()
	ctx.check(stats.max_health > 0.0, "max_health debe ser positivo")
	ctx.check(stats.move_speed > 0.0, "move_speed debe ser positivo")
	ctx.check_equal(stats.defense, 0.0, "defense inicial")


func _set_stat(ctx: ScriptTestContext) -> void:
	var stats := CharacterStats.new()
	var changes: Array[int] = []
	stats.changed.connect(func() -> void: changes.append(1))
	stats.set_stat(&"base_damage", 12.0)
	ctx.check_equal(stats.base_damage, 12.0, "base_damage tras cambiar")
	ctx.check_equal(changes.size(), 1, "debe notificarse un cambio")


func _unknown_stat_rejected(ctx: ScriptTestContext) -> void:
	var stats := CharacterStats.new()
	stats.set_stat(&"hambre", 50.0)
	ctx.check(not stats.has_stat(&"hambre"), "hambre aún no existe")
	ctx.check_equal(stats.stat_value(&"hambre"), 0.0, "una estadística desconocida vale 0")


func _snapshot_complete(ctx: ScriptTestContext) -> void:
	var stats := CharacterStats.new({"max_health": 80.0})
	var snapshot := stats.snapshot()
	ctx.check_equal(snapshot.size(), CharacterStats.STAT_NAMES.size(), "tamaño de la instantánea")
	ctx.check_equal(snapshot["max_health"], 80.0, "valor inicial aplicado desde el constructor")