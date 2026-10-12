extends RefCounted

## Pruebas del traductor de impacto (secciones 36-38).
##
## Los tiers (`low`/`medium`/`high`) son el vocabulario que ya usan las
## reacciones para el empuje, y `CombatImpact` los traduce a los tres efectos de
## un golpe que entra: cuánto se congela el mundo (hit stop), cuánto tiembla la
## cámara y cuántas chispas salen del punto de contacto. Los rangos del hit stop
## son los de la sección 36 (30-45 ms light, 45-60 medium, 60-80 heavy) y los
## tres valores viven dentro de ellos.

func register() -> Array:
	return [
		["el hit stop del tier bajo cae en 30-45 ms", _light_hit_stop_in_range],
		["el hit stop del tier medio cae en 45-60 ms", _medium_hit_stop_in_range],
		["el hit stop del tier alto cae en 60-80 ms", _heavy_hit_stop_in_range],
		["un tier desconocido cae a light, como las reacciones", _unknown_tier_falls_to_light],
		["la sacudida crece con el tier", _shake_grows_with_tier],
		["el número de partículas crece con el tier", _particles_grow_with_tier],
		["las propiedades derivadas del ataque siguen a su tier", _attack_derived_fields_follow_tier],
	]


func _light_hit_stop_in_range(ctx: ScriptTestContext) -> void:
	var value := CombatImpact.hit_stop_of(CombatReaction.TIER_LOW)
	ctx.check(value >= 0.030 and value <= 0.045, "el light debe caer en 30-45 ms: %f" % value)


func _medium_hit_stop_in_range(ctx: ScriptTestContext) -> void:
	var value := CombatImpact.hit_stop_of(CombatReaction.TIER_MEDIUM)
	ctx.check(value >= 0.045 and value <= 0.060, "el medium debe caer en 45-60 ms: %f" % value)


func _heavy_hit_stop_in_range(ctx: ScriptTestContext) -> void:
	var value := CombatImpact.hit_stop_of(CombatReaction.TIER_HIGH)
	ctx.check(value >= 0.060 and value <= 0.080, "el high debe caer en 60-80 ms: %f" % value)


func _unknown_tier_falls_to_light(ctx: ScriptTestContext) -> void:
	ctx.check_equal(
		CombatImpact.hit_stop_of(&"improbable"),
		GameConfig.HIT_STOP_LIGHT,
		"un tier desconocido cae al light"
	)


func _shake_grows_with_tier(ctx: ScriptTestContext) -> void:
	var light := CombatImpact.shake_of(CombatReaction.TIER_LOW)
	var medium := CombatImpact.shake_of(CombatReaction.TIER_MEDIUM)
	var heavy := CombatImpact.shake_of(CombatReaction.TIER_HIGH)
	ctx.check(light < medium and medium < heavy, "la sacudida crece: %f / %f / %f" % [light, medium, heavy])
	ctx.check(heavy <= GameConfig.CAMERA_SHAKE_HEAVY, "y no pasa del máximo de GameConfig")


func _particles_grow_with_tier(ctx: ScriptTestContext) -> void:
	var light := CombatImpact.particle_count_of(CombatReaction.TIER_LOW)
	var medium := CombatImpact.particle_count_of(CombatReaction.TIER_MEDIUM)
	var heavy := CombatImpact.particle_count_of(CombatReaction.TIER_HIGH)
	ctx.check(light < medium and medium < heavy, "las partículas crecen: %d / %d / %d" % [light, medium, heavy])


func _attack_derived_fields_follow_tier(ctx: ScriptTestContext) -> void:
	var attack := AttackDefinition.new({
		"id": &"test_impact",
		"knockback": CombatReaction.TIER_HIGH,
	})
	ctx.check_equal(attack.hit_stop, GameConfig.HIT_STOP_HEAVY, "el hit stop sigue al tier del ataque")
	ctx.check_equal(attack.camera_shake, GameConfig.CAMERA_SHAKE_HEAVY, "y la sacudida también")
	var soft := AttackDefinition.new({"id": &"test_impact_soft"})
	ctx.check_equal(soft.hit_stop, GameConfig.HIT_STOP_LIGHT, "sin tier, cae al light")
	ctx.check_equal(soft.camera_shake, GameConfig.CAMERA_SHAKE_LIGHT, "y la sacudida al suave")