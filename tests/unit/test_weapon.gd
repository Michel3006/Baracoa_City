extends RefCounted

## Pruebas del catálogo de armas y su durabilidad (secciones 7 y 10).
##
## El MVP solo tiene piedra y cuchillo; las armas de fuego están prohibidas.


func register() -> Array:
	return [
		["el catálogo solo ofrece piedra y cuchillo", _catalog_scope],
		["la piedra es el arma inicial", _default_weapon],
		["el cuchillo pega más y llega menos", _knife_tradeoff],
		["un identificador desconocido no crea arma", _unknown_id],
		["el daño del arma pasa por la fórmula", _damage_goes_through_rules],
		["el desgaste rompe el arma y deja de pegar", _wear_breaks_weapon],
		["reparar recupera durability", _repair_restores],
		["cada copia es independiente", _copies_are_independent],
	]


func _catalog_scope(ctx: ScriptTestContext) -> void:
	ctx.check_equal(WeaponCatalog.ids().size(), 2, "número de armas del MVP")
	ctx.check(WeaponCatalog.exists(WeaponCatalog.STONE), "existe la piedra")
	ctx.check(WeaponCatalog.exists(WeaponCatalog.KNIFE), "existe el cuchillo")
	ctx.check(not WeaponCatalog.exists(&"pistol"), "no hay armas de fuego")


func _default_weapon(ctx: ScriptTestContext) -> void:
	ctx.check_equal(WeaponCatalog.default_weapon().id, WeaponCatalog.STONE, "arma inicial")


func _knife_tradeoff(ctx: ScriptTestContext) -> void:
	var stone := WeaponCatalog.create(WeaponCatalog.STONE)
	var knife := WeaponCatalog.create(WeaponCatalog.KNIFE)
	ctx.check(knife.attack_damage > stone.attack_damage, "el cuchillo pega más")
	ctx.check(knife.attack_cooldown < stone.attack_cooldown, "el cuchillo golpea antes")
	ctx.check(knife.attack_range < stone.attack_range, "el cuchillo llega menos")
	ctx.check(knife.stamina_cost > stone.stamina_cost, "el cuchillo cuesta más")


func _unknown_id(ctx: ScriptTestContext) -> void:
	ctx.check_equal(WeaponCatalog.create(&"rifle"), null, "arma inexistente")


func _damage_goes_through_rules(ctx: ScriptTestContext) -> void:
	var stone := WeaponCatalog.create(WeaponCatalog.STONE)
	ctx.check_equal(
		stone.damage_against(0.0), GameConfig.WEAPON_STONE_DAMAGE, "sin defensa"
	)
	ctx.check_equal(stone.damage_against(GameConfig.WEAPON_STONE_DAMAGE + 5.0), 1.0, "muy defendida")
	ctx.check(stone.can_attack(), "una piedra nueva puede atacar")


func _wear_breaks_weapon(ctx: ScriptTestContext) -> void:
	var knife := WeaponCatalog.create(WeaponCatalog.KNIFE)
	ctx.check(not knife.wear(knife.max_durability), "desgaste completo deja 0")
	ctx.check(knife.is_broken, "el arma está rota")
	ctx.check(not knife.can_attack(), "un arma rota no ataca")
	ctx.check_equal(knife.effective_damage, 0.0, "un arma rota no pega")
	ctx.check_equal(knife.damage_against(0.0), 0.0, "ni siquiera el mínimo")


func _repair_restores(ctx: ScriptTestContext) -> void:
	var knife := WeaponCatalog.create(WeaponCatalog.KNIFE)
	knife.wear(knife.max_durability)
	ctx.check_equal(knife.repair(10), 10, "repara 10")
	ctx.check(not knife.is_broken, "ya no está rota")
	ctx.check_equal(knife.repair(999), knife.max_durability - 10, "no pasa del máximo")


func _copies_are_independent(ctx: ScriptTestContext) -> void:
	var first := WeaponCatalog.create(WeaponCatalog.KNIFE)
	var second := first.copy()
	first.wear(20)
	ctx.check_equal(second.durability, second.max_durability, "la copia no se desgasta")
	ctx.check_equal(first.id, second.id, "pero es el mismo arma")
