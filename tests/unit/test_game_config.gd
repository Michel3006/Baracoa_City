extends RefCounted

## Pruebas de la configuración centralizada (sección 28).


func register() -> Array:
	return [
		["los valores por defecto son coherentes", _defaults_are_sane],
		["un override cambia el valor leído", _override_applies],
		["una clave desconocida cae al valor por defecto", _unknown_key_falls_back],
		["la resolución y la escala son coherentes", _scale_is_consistent],
	]


func _defaults_are_sane(ctx: ScriptTestContext) -> void:
	ctx.check(GameConfig.PLAYER_SPEED > 0.0, "velocidad positiva")
	ctx.check(GameConfig.PLAYER_MAX_HEALTH > 0, "vida máxima positiva")
	ctx.check(GameConfig.PLAYER_MAX_STAMINA > 0, "stamina máxima positiva")
	ctx.check(GameConfig.DEFAULT_ATTACK_COOLDOWN > 0.0, "cooldown positivo")
	ctx.check(GameConfig.INVULNERABILITY_TIME > 0.0, "invulnerabilidad positiva")
	ctx.check(GameConfig.TILE_SIZE > 0, "tile positivo")
	ctx.check(GameConfig.PLAYER_INVENTORY_CAPACITY > 0, "capacidad de inventario positiva")


func _override_applies(ctx: ScriptTestContext) -> void:
	GameConfig.set_override("gameplay/player_speed", 42.0)
	ctx.check_equal(GameConfig.get_float("gameplay/player_speed", 1.0), 42.0, "override leído")
	ctx.check_equal(GameConfig.player_speed(), 42.0, "el accessor usa el override")
	GameConfig.clear_overrides()
	ctx.check_equal(GameConfig.player_speed(), GameConfig.PLAYER_SPEED, "override limpiado")


func _unknown_key_falls_back(ctx: ScriptTestContext) -> void:
	ctx.check_equal(GameConfig.get_int("no/existe", 7), 7, "valor por defecto")


## La resolución base es 16:9 y la escala de ventana es un entero: así no hay
## píxeles intermedios ni stretching fraccionario.
func _scale_is_consistent(ctx: ScriptTestContext) -> void:
	var resolution := Vector2(GameConfig.BASE_RESOLUTION)
	ctx.check_almost_equal(resolution.aspect(), 16.0 / 9.0, "proporción de la resolución")
	ctx.check_equal(GameConfig.WINDOW_SCALE, 3, "escala de ventana entera")
	ctx.check_equal(
		resolution * float(GameConfig.WINDOW_SCALE),
		Vector2(1152.0, 648.0),
		"tamaño de ventana esperado"
	)
	var zone := Vector2(GameConfig.WORLD_ZONE_SIZE) * float(GameConfig.TILE_SIZE)
	ctx.check_almost_equal(fmod(zone.x, float(GameConfig.TILE_SIZE)), 0.0, "la zona encaja en tiles")
	ctx.check(zone.x > resolution.x, "la zona es mayor que la pantalla")