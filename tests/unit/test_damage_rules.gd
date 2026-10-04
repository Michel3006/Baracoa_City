extends RefCounted

## Pruebas de la fórmula de daño (sección 10).
##
## La fórmula es `max(1, ataque - defensa)`. Si algún día cambia, estas pruebas
## avisan de qué se ha roto.

## Objetivo de mentira: solo necesita saber recibir daño y exponer su defensa.
class Dummy extends RefCounted:
	var stats: CharacterStats
	var received: Array[float] = []
	var is_dead: bool = false

	func _init(defense: float = 0.0) -> void:
		stats = CharacterStats.new({"defense": defense})

	func take_damage(amount: float) -> float:
		received.append(amount)
		return amount


## Enemigo con la defensa en un método propio en vez de en `stats`.
class Scripted extends RefCounted:
	var armor: float = 0.0

	func _init(defense: float = 0.0) -> void:
		armor = defense

	func get_defense() -> float:
		return armor

	func take_damage(amount: float) -> float:
		return amount


func register() -> Array:
	return [
		["el daño resta la defensa", _subtracts_defense],
		["nunca hay un golpe por debajo de 1", _minimum_damage],
		["sin ataque válido no hay daño", _zero_attack],
		["la defensa nunca resta por debajo de 1", _min_one_with_zero_defense],
		["la defensa se lee de stats o de un método", _reads_defense],
		["un objetivo sin take_damage no es dañable", _not_damageable],
		["un objetivo muerto no es dañable", _dead_not_damageable],
	]


func _subtracts_defense(ctx: ScriptTestContext) -> void:
	ctx.check_equal(DamageRules.compute(10.0, 3.0), 7.0, "10 contra 3 de defensa")


func _minimum_damage(ctx: ScriptTestContext) -> void:
	ctx.check_equal(DamageRules.compute(4.0, 9.0), DamageRules.MINIMUM_DAMAGE, "4 contra 9")


func _min_one_with_zero_defense(ctx: ScriptTestContext) -> void:
	ctx.check_equal(DamageRules.compute(2.0, 0.0), 2.0, "sin defensa el daño es el ataque")


func _zero_attack(ctx: ScriptTestContext) -> void:
	ctx.check_equal(DamageRules.compute(0.0, 0.0), 0.0, "un ataque de 0 no hace daño")
	ctx.check_equal(DamageRules.compute(-3.0, 0.0), 0.0, "un ataque negativo no hace daño")
	ctx.check(not DamageRules.is_valid_attack(0.0), "0 no es un ataque válido")


func _reads_defense(ctx: ScriptTestContext) -> void:
	ctx.check_equal(DamageRules.defense_of(Dummy.new(2.0)), 2.0, "defensa en stats")
	ctx.check_equal(DamageRules.defense_of(Scripted.new(5.0)), 5.0, "defensa en get_defense")
	ctx.check_equal(DamageRules.defense_of(null), 0.0, "sin objetivo no hay defensa")
	ctx.check_equal(DamageRules.defense_of(Dummy.new(-4.0)), 0.0, "la defensa negativa se ignora")


func _not_damageable(ctx: ScriptTestContext) -> void:
	ctx.check(DamageRules.is_damageable(Dummy.new()), "un dummy sí es dañable")
	ctx.check(not DamageRules.is_damageable(null), "null no es dañable")
	ctx.check(not DamageRules.is_damageable(RefCounted.new()), "sin take_damage no es dañable")
	ctx.check(not DamageRules.is_damageable(42), "un entero no es dañable")


func _dead_not_damageable(ctx: ScriptTestContext) -> void:
	var dummy := Dummy.new()
	dummy.is_dead = true
	ctx.check(not DamageRules.is_damageable(dummy), "un objetivo muerto no es dañable")
