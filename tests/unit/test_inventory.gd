extends RefCounted

## Pruebas del inventario (sección 13).
##
## Todo es dominio puro: no hay escena ni reloj. La capacidad se mide en pilas
## (una casilla por objeto distinto); las señales entre `RefCounted` crean ciclos,
## así que cada caso que escucha una señal la desconecta antes de terminar.

func register() -> Array:
	return [
		["recoger un objeto ocupa una casilla", _add_opens_slot],
		["apilar suma en la misma casilla", _stack_same_cell],
		["no se pasa del máximo de una pila", _stack_capped],
		["cada copia de un objeto no apilable exige casilla", _non_stackable_takes_slots],
		["la capacidad limita los objetos distintos", _capacity_limits],
		["quitar reduce y al vaciarse libera la casilla", _remove_frees_slot],
		["quitar lo que no existe no quita nada", _remove_unknown_is_zero],
		["equipar un arma la pone en la mano", _equip_weapon],
		["equipar un objeto que no es arma falla", _equip_non_weapon_fails],
		["des-equipar deja las manos vacías", _unequip_clears],
		["quitar el arma equipada des-equipa", _removing_equipped_unequips],
		["usar un consumible lo consume", _use_consumes],
		["usar lo que no es consumible falla", _use_non_consumable_fails],
		["usar lo que no existe falla", _use_unknown_fails],
		["la capacidad viene de la configuración", _capacity_from_config],
		["get_entries da una vista de solo lectura para la UI", _entries_are_read_only],
	]


func _add_opens_slot(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	var added := bag.add_item(ItemCatalog.stone(), 1)
	ctx.check_equal(added, 1, "la piedra entra")
	ctx.check(bag.has_item(ItemCatalog.STONE), "se ve en el inventario")
	ctx.check_equal(bag.get_quantity(ItemCatalog.STONE), 1, "una unidad")
	ctx.check_equal(bag.slots_used(), 1, "una casilla ocupada")
	ctx.check(not bag.is_full(), "no está lleno")


func _stack_same_cell(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	bag.add_item(ItemCatalog.berry(), 2)
	var added := bag.add_item(ItemCatalog.berry(), 3)
	ctx.check_equal(added, 3, "las tres entran en la pila")
	ctx.check_equal(bag.get_quantity(ItemCatalog.BERRY), 5, "la pila suma")
	ctx.check_equal(bag.slots_used(), 1, "sigue siendo una casilla")


func _stack_capped(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	bag.add_item(ItemCatalog.berry(), 8)
	var added := bag.add_item(ItemCatalog.berry(), 5)
	ctx.check_equal(added, 2, "solo entra hasta el máximo de la pila")
	ctx.check_equal(bag.get_quantity(ItemCatalog.BERRY), 10, "la pila queda al máximo")
	ctx.check_equal(bag.add_item(ItemCatalog.berry(), 1), 0, "llena, no entra más")
	ctx.check_equal(bag.slots_used(), 1, "una casilla sigue ocupada")


func _non_stackable_takes_slots(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	bag.add_item(ItemCatalog.stone(), 1)
	var added := bag.add_item(ItemCatalog.stone(), 1)
	ctx.check_equal(added, 0, "una segunda piedra no apila con la primera")
	ctx.check_equal(bag.slots_used(), 1, "sigue ocupando su casilla")
	ctx.check_equal(bag.add_item(ItemCatalog.knife(), 2), 1, "un arma distinta abre casilla con una sola copia")
	ctx.check_equal(bag.slots_used(), 2, "dos casillas")


func _capacity_limits(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new(2)
	ctx.check_equal(bag.add_item(ItemCatalog.stone(), 1), 1, "primera casilla")
	ctx.check_equal(bag.add_item(ItemCatalog.knife(), 1), 1, "segunda casilla")
	ctx.check(bag.is_full(), "el inventario está lleno")
	var rejected: Array[StringName] = []
	var listen := func(reason: StringName) -> void: rejected.append(reason)
	bag.rejected.connect(listen)
	ctx.check_equal(bag.add_item(ItemCatalog.berry(), 1), 0, "la tercera casilla no existe")
	bag.rejected.disconnect(listen)
	ctx.check_equal(rejected, [Inventory.REASON_CAPACITY], "y lo dice el motivo")


func _remove_frees_slot(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	bag.add_item(ItemCatalog.berry(), 5)
	ctx.check_equal(bag.remove_item(ItemCatalog.BERRY, 2), 2, "quita dos")
	ctx.check_equal(bag.get_quantity(ItemCatalog.BERRY), 3, "quedan tres")
	ctx.check_equal(bag.remove_item(ItemCatalog.BERRY, 3), 3, "quita el resto")
	ctx.check(not bag.has_item(ItemCatalog.BERRY), "la casilla se libera")
	ctx.check_equal(bag.slots_used(), 0, "inventario vacío")


func _remove_unknown_is_zero(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	ctx.check_equal(bag.remove_item(&"tesoro"), 0, "no quita nada")
	ctx.check_equal(bag.get_quantity(&"tesoro"), 0, "nada que consultar")


func _equip_weapon(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	bag.add_item(ItemCatalog.stone(), 1)
	var events: Array[StringName] = []
	var listen := func(item_id: StringName) -> void: events.append(item_id)
	bag.equipped_changed.connect(listen)
	ctx.check(bag.equip_item(ItemCatalog.STONE), "la piedra se equipa")
	bag.equipped_changed.disconnect(listen)
	ctx.check_equal(bag.equipped(), ItemCatalog.STONE, "está en la mano")
	ctx.check_equal(events, [ItemCatalog.STONE], "la señal avisa del cambio")
	ctx.check(bag.equip_item(ItemCatalog.STONE), "equipar lo ya equipado también vale")
	ctx.check_equal(events.size(), 1, "y no repite la señal")


func _equip_non_weapon_fails(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	bag.add_item(ItemCatalog.berry(), 2)
	var reasons: Array[StringName] = []
	var listen := func(reason: StringName) -> void: reasons.append(reason)
	bag.rejected.connect(listen)
	ctx.check(not bag.equip_item(ItemCatalog.BERRY), "una baya no se equipa")
	bag.rejected.disconnect(listen)
	ctx.check_equal(bag.equipped(), &"", "las manos siguen vacías")
	ctx.check_equal(reasons, [Inventory.REASON_NOT_WEAPON], "con su motivo")
	ctx.check(not bag.equip_item(&"inexistente"), "ni lo que no está")
	ctx.check_equal(bag.equipped(), &"", "sigue vacío")


func _unequip_clears(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	bag.add_item(ItemCatalog.stone(), 1)
	bag.equip_item(ItemCatalog.STONE)
	var events: Array[StringName] = []
	var listen := func(item_id: StringName) -> void: events.append(item_id)
	bag.equipped_changed.connect(listen)
	ctx.check(bag.unequip_item(), "des-equipa")
	bag.equipped_changed.disconnect(listen)
	ctx.check_equal(bag.equipped(), &"", "manos vacías")
	ctx.check_equal(events, [&""], "la señal avisa de las manos vacías")
	ctx.check(not bag.unequip_item(), "ya estaban vacías")


func _removing_equipped_unequips(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	bag.add_item(ItemCatalog.stone(), 1)
	bag.equip_item(ItemCatalog.STONE)
	var events: Array[StringName] = []
	var listen := func(item_id: StringName) -> void: events.append(item_id)
	bag.equipped_changed.connect(listen)
	bag.remove_item(ItemCatalog.STONE, 1)
	bag.equipped_changed.disconnect(listen)
	ctx.check_equal(bag.equipped(), &"", "quitar el arma deja las manos vacías")
	ctx.check_equal(events, [&""], "y la señal lo dice")


func _use_consumes(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	bag.add_item(ItemCatalog.berry(), 2)
	var used_events: Array[StringName] = []
	var used_listen := func(item_id: StringName) -> void: used_events.append(item_id)
	bag.used.connect(used_listen)
	ctx.check(bag.use_item(ItemCatalog.BERRY), "la baya se usa")
	bag.used.disconnect(used_listen)
	ctx.check_equal(bag.get_quantity(ItemCatalog.BERRY), 1, "se consumió una")
	ctx.check_equal(used_events, [ItemCatalog.BERRY], "la señal avisa de qué se usó")
	bag.use_item(ItemCatalog.BERRY)
	ctx.check(not bag.has_item(ItemCatalog.BERRY), "la última consume la pila entera")
	ctx.check_equal(bag.slots_used(), 0, "inventario vacío")


func _use_non_consumable_fails(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	bag.add_item(ItemCatalog.stone(), 1)
	var reasons: Array[StringName] = []
	var listen := func(reason: StringName) -> void: reasons.append(reason)
	bag.rejected.connect(listen)
	ctx.check(not bag.use_item(ItemCatalog.STONE), "una piedra no se usa")
	bag.rejected.disconnect(listen)
	ctx.check_equal(bag.get_quantity(ItemCatalog.STONE), 1, "sigue ahí")
	ctx.check_equal(reasons, [Inventory.REASON_NOT_USABLE], "con su motivo")


func _use_unknown_fails(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	ctx.check(not bag.use_item(&"inexistente"), "no se usa lo que no existe")
	ctx.check_equal(bag.slots_used(), 0, "nada cambia")


func _capacity_from_config(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	ctx.check_equal(bag.capacity, GameConfig.PLAYER_INVENTORY_CAPACITY, "la capacidad de la configuración")
	ctx.check_equal(bag.capacity, 20, "veinte casillas para el jugador")


func _entries_are_read_only(ctx: ScriptTestContext) -> void:
	var bag := Inventory.new()
	bag.add_item(ItemCatalog.stone(), 1)
	bag.equip_item(ItemCatalog.STONE)
	bag.add_item(ItemCatalog.berry(), 2)
	var entries := bag.get_entries()
	ctx.check_equal(entries.size(), 2, "una entrada por casilla")
	var found := {}
	for entry: Dictionary in entries:
		found[entry.id] = entry
	ctx.check(found.has(ItemCatalog.STONE), "hay entrada para la piedra")
	ctx.check(found.has(ItemCatalog.BERRY), "hay entrada para la baya")
	if not found.has(ItemCatalog.STONE) or not found.has(ItemCatalog.BERRY):
		return
	ctx.check_equal(found[ItemCatalog.BERRY].quantity, 2, "cantidad de la pila")
	ctx.check(not found[ItemCatalog.BERRY].equipped, "una baya no está en la mano")
	ctx.check(found[ItemCatalog.STONE].equipped, "la piedra está en la mano")
	# La UI no puede mutar el inventario desde la vista: solo es una copia plana.
	ctx.check_equal(bag.get_quantity(ItemCatalog.BERRY), 2, "la copia no toca las pilas")