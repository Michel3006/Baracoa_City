extends RefCounted

## Pruebas del catálogo de armas y su durabilidad (secciones 7 y 10).
##
## El MVP tiene piedra, cuchillo y puños; las armas de fuego están prohibidas.
##
## Los puños son el caso que más conviene fijar aquí: no son un arma del inventario,
## es la opción de golpe sin arma, y por eso tienen reglas propias.


func register() -> Array:
	return [
		["el catálogo ofrece piedra, cuchillo y puños", _catalog_scope],
		["la piedra es el arma inicial", _default_weapon],
		["el cuchillo pega más y llega menos", _knife_tradeoff],
		["un identificador desconocido no crea arma", _unknown_id],
		["los puños no tienen textura ni desgaste", _unarmed_has_no_texture],
		["los puños pega menos que cualquier arma", _unarmed_is_weaker],
		["el daño del arma pasa por la fórmula", _damage_goes_through_rules],
		["el desgaste rompe el arma y deja de pegar", _wear_breaks_weapon],
		["reparar recupera durability", _repair_restores],
		["cada copia es independiente", _copies_are_independent],
	]


func _catalog_scope(ctx: ScriptTestContext) -> void:
	ctx.check_equal(WeaponCatalog.ids().size(), 3, "número de armas del MVP")
	ctx.check(WeaponCatalog.exists(WeaponCatalog.STONE), "existe la piedra")
	ctx.check(WeaponCatalog.exists(WeaponCatalog.KNIFE), "existe el cuchillo")
	ctx.check(WeaponCatalog.exists(WeaponCatalog.UNARMED), "existen los puños")
	ctx.check(not WeaponCatalog.exists(&"pistol"), "no hay armas de fuego")


## Los puños no se dibujan en la mano y no se rompen: si tuvieran textura, la mano
## vacía del jugador no significaría nada, y si tuvieran durabilidad habría que
## reponerlos.
func _unarmed_has_no_texture(ctx: ScriptTestContext) -> void:
	var fists := WeaponCatalog.unarmed()
	ctx.check_equal(fists.id, WeaponCatalog.UNARMED, "son los puños")
	ctx.check(WeaponCatalog.is_unarmed(fists), "el catálogo los reconoce")
	ctx.check(fists.texture_path.is_empty(), "no hay nada que dibujar")
	ctx.check(fists.can_attack(), "los puños no se rompen")
	ctx.check(
		fists.damage_against(0.0) > 0.0, "los puños pegan aunque no se gasten"
	)
	ctx.check(
		not WeaponCatalog.is_unarmed(WeaponCatalog.create(WeaponCatalog.STONE)),
		"la piedra no es golpe a puños"
	)


## Un arma siempre tiene que poder con más que un puño, o el combate sin arma sería
## un error de diseño en lugar de una decisión.
func _unarmed_is_weaker(ctx: ScriptTestContext) -> void:
	var fists := WeaponCatalog.unarmed()
	var stone := WeaponCatalog.create(WeaponCatalog.STONE)
	ctx.check(
		fists.damage_against(0.0) < stone.damage_against(0.0),
		"los puños pegan menos que la piedra"
	)
	ctx.check(
		fists.attack_range <= stone.attack_range, "los puños no llegan más lejos"
	)


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
