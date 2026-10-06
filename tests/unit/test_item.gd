extends RefCounted

## Pruebas del sistema de objetos (sección 12).
##
## El objeto es una definición, no una copia "en el mundo": la cantidad la lleva
## el inventario y aquí solo se mira qué es cada objeto y con qué reglas apila.

func register() -> Array:
	return [
		["el catálogo ofrece piedra, cuchillo y baya", _catalog_scope],
		["un identificador desconocido no crea objeto", _unknown_id],
		["las armas son objetos WEAPON no apilables", _weapons_are_single],
		["la baya es consumible y apila hasta diez", _berry_stacks],
		["el objeto de arma apunta al arma que representa", _weapon_item_points_to_weapon],
		["la taxonomía tiene los ocho tipos de la especificación", _taxonomy_complete],
	]


func _catalog_scope(ctx: ScriptTestContext) -> void:
	ctx.check_equal(ItemCatalog.ids().size(), 3, "número de objetos del MVP")
	ctx.check(ItemCatalog.exists(ItemCatalog.STONE), "existe la piedra")
	ctx.check(ItemCatalog.exists(ItemCatalog.KNIFE), "existe el cuchillo")
	ctx.check(ItemCatalog.exists(ItemCatalog.BERRY), "existe la baya")
	ctx.check_equal(ItemCatalog.create(&"rifle"), null, "no hay armas de fuego")


func _unknown_id(ctx: ScriptTestContext) -> void:
	ctx.check_equal(ItemCatalog.create(&"corazon"), null, "objeto inexistente")


func _weapons_are_single(ctx: ScriptTestContext) -> void:
	var stone := ItemCatalog.stone()
	ctx.check_equal(stone.id, ItemCatalog.STONE, "es la piedra")
	ctx.check_equal(stone.type, ItemKind.Kind.WEAPON, "es un arma")
	ctx.check(not stone.stackable, "un arma no apila")
	ctx.check_equal(stone.max_stack, 1, "una casilla por arma")
	ctx.check_equal(stone.name, GameConfig.ITEM_STONE_NAME, "el nombre viene de la configuración")


func _berry_stacks(ctx: ScriptTestContext) -> void:
	var berry := ItemCatalog.berry()
	ctx.check_equal(berry.type, ItemKind.Kind.CONSUMABLE, "es consumible")
	ctx.check(berry.stackable, "apila")
	ctx.check_equal(berry.max_stack, 10, "hasta diez por pila")


func _weapon_item_points_to_weapon(ctx: ScriptTestContext) -> void:
	ctx.check_equal(
		ItemCatalog.stone().metadata.get("weapon"), WeaponCatalog.STONE,
		"la piedra del inventario es la piedra del combate"
	)
	ctx.check_equal(
		ItemCatalog.knife().metadata.get("weapon"), WeaponCatalog.KNIFE,
		"el cuchillo del inventario es el cuchillo del combate"
	)


func _taxonomy_complete(ctx: ScriptTestContext) -> void:
	ctx.check_equal(ItemKind.ALL.size(), 8, "ocho tipos")
	for kind: int in ItemKind.ALL:
		ctx.check(ItemKind.is_valid(kind), "el tipo %s es válido" % ItemKind.name_of(kind))
	ctx.check(ItemKind.is_valid(ItemKind.Kind.MISC), "MISC cierra la lista")