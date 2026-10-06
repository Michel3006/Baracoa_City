extends SceneTree

## Tests de integración del inventario (secciones 12 y 13).
##
## Uso: godot --headless --script res://tests/integration/inventory_runner.gd
##
## Monta lo que monta el juego (autoload `Game` + escena principal, igual que
## F5) y comprueba la cadena real: inventario -> sesión -> combate -> sprite de la
## mano. Sin la escena principal este runner vería el autoload, que es lo mismo
## que veían las otras suites, y la pregunta aquí es justo la de pantalla: lo que
## se equipa tiene que acabar dibujándose en la mano.

var _context: ScriptTestContext
var _total: int = 0
var _failed: int = 0
var _main_scene: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_context = ScriptTestContext.new()
	print("== Tests de integracion (inventario) ==")

	_load_main_scene()
	for _i: int in range(6):
		await physics_frame

	await _check("el jugador arranca con la piedra en la mochila y en la mano", _starting_inventory)
	await _check("equipar desde el inventario cambia el arma en mano y en pantalla", _equip_changes_weapon)
	await _check("des-equipar deja las manos vacías y a puños", _unequip_sends_unarmed)
	await _check("usar un consumible lo consume de la sesión", _use_consumes_from_session)
	await _check("equipar lo que no existe se rechaza y no toca el arma", _equip_missing_fails)
	await _check("la mochila se abre, pausa el mundo y se cierra", _panel_opens_pauses_and_closes)
	await _check("la mochila navega, equipa y usa lo seleccionado", _panel_selects_and_uses)
	await _check("Tab abre y cierra la mochila por la entrada real", _panel_toggles_with_tab)
	await _check("la mochila no se abre con el jugador muerto", _panel_refuses_when_dead)

	_report()
	quit(0 if _failed == 0 else 1)


func _check(label: String, body: Callable) -> void:
	var before := _context.failures.size()
	_total += 1
	await body.call()
	if _context.failures.size() == before:
		print("  [OK]   %s" % label)
	else:
		_failed += 1
		print("  [FAIL] %s" % label)
		for index: int in range(before, _context.failures.size()):
			print("         %s" % _context.failures[index])


func _report() -> void:
	print("")
	print("RESULTADO: %d/%d pruebas correctas" % [_total - _failed, _total])


## La escena principal ya no construye nada (es un nodo vacío a propósito), pero
## montarla mantiene el árbol idéntico al de F5.
func _load_main_scene() -> void:
	var path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if path.is_empty():
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	_main_scene = packed.instantiate()
	root.add_child(_main_scene)


# --- acceso ---

func _game() -> Node:
	return root.get_node_or_null("Game")


func _session() -> GameSession:
	var game := _game()
	if game == null:
		return null
	return game.session


func _view() -> PlayerView:
	var game := _game()
	if game == null or game.world_view == null:
		return null
	return game.world_view.player


# --- casos ---

func _starting_inventory() -> void:
	var session := _session()
	_context.check(session != null, "la sesión existe")
	if session == null:
		return
	_context.check_equal(session.player.inventory.slots_used(), 1, "una casilla al arrancar")
	_context.check(session.player.inventory.has_item(ItemCatalog.STONE), "tiene la piedra")
	_context.check_equal(session.player.equipped_item, ItemCatalog.STONE, "la piedra está en la mano")
	_context.check_equal(
		session.combat.weapon.id, WeaponCatalog.STONE,
		"el combate golpea con la piedra"
	)
	_context.check(
		not session.player.inventory.has_item(ItemCatalog.BERRY), "y no hay nada más"
	)


func _equip_changes_weapon() -> void:
	var session := _session()
	var view := _view()
	if session == null:
		_context.check(false, "sin sesión")
		return
	var added := session.player.inventory.add_item(ItemCatalog.knife(), 1)
	_context.check_equal(added, 1, "cae un cuchillo")
	_context.check(
		session.player.inventory.equip_item(ItemCatalog.KNIFE), "se equipa"
	)
	for _i: int in range(4):
		await physics_frame
	_context.check_equal(
		session.combat.weapon.id, WeaponCatalog.KNIFE, "el combate cambia al cuchillo"
	)
	_context.check_equal(
		session.player.equipped_item, ItemCatalog.KNIFE,
		"el inventario dice que va el cuchillo"
	)
	if view == null:
		_context.check(false, "sin vista del jugador")
		return
	_context.check(view.is_armed, "se dibuja un arma en la mano")
	var sprite := view.get_node_or_null("Weapon") as Sprite2D
	if sprite == null or sprite.texture == null:
		_context.check(false, "no hay sprite de arma en la mano")
		return
	_context.check(
		sprite.texture.resource_path.ends_with("blade.png"),
		"el sprite de la mano es la hoja del cuchillo (%s)" % sprite.texture.resource_path
	)


func _unequip_sends_unarmed() -> void:
	var session := _session()
	var view := _view()
	if session == null:
		_context.check(false, "sin sesión")
		return
	_context.check(session.player.inventory.unequip_item(), "se des-equipa")
	for _i: int in range(4):
		await physics_frame
	_context.check_equal(
		session.combat.weapon.id, WeaponCatalog.UNARMED,
		"el combate pasa a puños"
	)
	_context.check_equal(
		session.player.equipped_item, &"", "el inventario dice que va a puños"
	)
	if view != null:
		_context.check(not view.is_armed, "no se dibuja nada en la mano")


func _use_consumes_from_session() -> void:
	var session := _session()
	if session == null:
		_context.check(false, "sin sesión")
		return
	var bag := session.player.inventory
	var added := bag.add_item(ItemCatalog.berry(), 2)
	_context.check_equal(added, 2, "cayeron dos bayas")
	_context.check(bag.use_item(ItemCatalog.BERRY), "se usa una")
	_context.check_equal(bag.get_quantity(ItemCatalog.BERRY), 1, "queda una")
	_context.check(bag.use_item(ItemCatalog.BERRY), "se usa la otra")
	_context.check(not bag.has_item(ItemCatalog.BERRY), "la pila se agota")
	_context.check(not bag.use_item(ItemCatalog.STONE), "la piedra no se usa")


func _equip_missing_fails() -> void:
	var session := _session()
	if session == null:
		_context.check(false, "sin sesión")
		return
	var bag := session.player.inventory
	var before_weapon := session.combat.weapon.id
	var reasons: Array[StringName] = []
	var listen := func(reason: StringName) -> void: reasons.append(reason)
	bag.rejected.connect(listen)
	var ok := bag.equip_item(&"inexistente")
	bag.rejected.disconnect(listen)
	_context.check(not ok, "no se equipa lo que no existe")
	_context.check_equal(
		session.combat.weapon.id, before_weapon, "el arma no cambia"
	)
	_context.check_equal(reasons, [Inventory.REASON_NOT_FOUND], "con su motivo")


func _panel() -> InventoryPanel:
	var game := _game()
	if game == null or game.world_view == null:
		return null
	return game.world_view.inventory_panel


## La mochila es la pantalla del remate: existe en el árbol, arranca cerrada, y al
## abrirla pausa el mundo (el jugador no avanza mientras gestiona el equipo) y lo
## reanuda al cerrarla. Se comprueba también que la rejilla tiene el tamaño
## configurado y que no se puede abrir dos veces.
func _panel_opens_pauses_and_closes() -> void:
	var panel := _panel()
	_context.check(panel != null, "la mochila existe en el árbol")
	if panel == null:
		return
	_context.check(not panel.is_open, "arranca cerrada")
	_context.check(not panel.visible, "y oculta")
	_context.check(panel.open(), "se abre")
	_context.check(panel.is_open, "está abierta")
	_context.check(panel.visible, "y se ve")
	_context.check(self.paused, "y pausa el mundo")
	_context.check_equal(
		panel.slot_rect(0).size,
		Vector2(GameConfig.INVENTORY_SLOT, GameConfig.INVENTORY_SLOT),
		"las casillas son del tamaño configurado"
	)
	_context.check(not panel.open(), "una segunda apertura se rechaza")
	panel.close()
	_context.check(not panel.is_open, "se cierra")
	_context.check(not self.paused, "y reanuda el mundo")


## La cadena de pantalla: la rejilla enseña lo que hay (piedra equipada, cuchillo,
## bayas por cantidad), la selección navega y el confirmar equipa las armas y
## consume los consumibles por la misma vía que pediría la tecla.
func _panel_selects_and_uses() -> void:
	var session := _session()
	var panel := _panel()
	_context.check(session != null and panel != null, "mochila y sesión presentes")
	if session == null or panel == null:
		return
	var bag := session.player.inventory
	# La suite corre sobre el mismo mundo y los casos anteriores dejan cosas en la
	# mochila (el cuchillo del caso de equipar, de hecho): se la deja en un estado
	# conocido para que el caso no dependa de lo que dejen los demás.
	bag.remove_item(ItemCatalog.STONE, 99)
	bag.remove_item(ItemCatalog.KNIFE, 99)
	bag.add_item(ItemCatalog.stone(), 1)
	bag.equip_item(ItemCatalog.STONE)
	_context.check_equal(bag.add_item(ItemCatalog.knife(), 1), 1, "cae un cuchillo")
	_context.check_equal(bag.add_item(ItemCatalog.berry(), 3), 3, "cayeron tres bayas")
	_context.check(panel.open(), "se abre la mochila")

	var stone := panel.entry_at(0)
	_context.check_equal(stone.get("id", &""), ItemCatalog.STONE, "la primera casilla es la piedra")
	_context.check(stone.get("equipped", false), "y está marcada como equipada")
	_context.check_equal(panel.entry_at(1).get("id", &""), ItemCatalog.KNIFE, "la segunda es el cuchillo")
	_context.check_equal(panel.entry_at(2).get("quantity", 0), 3, "la tercera son tres bayas")

	panel.move_selection(Vector2i(1, 0))
	_context.check(panel.confirm_selected(), "se confirma el cuchillo")
	_context.check_equal(session.player.equipped_item, ItemCatalog.KNIFE, "el inventario lo equipa")
	for _i: int in range(4):
		await physics_frame
	_context.check_equal(session.combat.weapon.id, WeaponCatalog.KNIFE, "el combate pasa al cuchillo")

	panel.move_selection(Vector2i(1, 0))
	_context.check(panel.confirm_selected(), "se confirma una baya")
	_context.check_equal(bag.get_quantity(ItemCatalog.BERRY), 2, "y una baya se consume")
	panel.close()
	_context.check(not self.paused, "al cerrar reanuda el mundo")


## La entrada de verdad: un `InputEventKey` sintético entra por `_unhandled_input`
## igual que lo mandaría el motor con una pulsación real. Es la red que ata la
## acción del proyecto con el panel: si la acción desaparece o el panel deja de
## leerla, esto lo dice.
func _panel_toggles_with_tab() -> void:
	var panel := _panel()
	_context.check(panel != null, "mochila presente")
	if panel == null:
		return
	_context.check(InputMap.has_action(&"toggle_inventory"), "la acción existe en el proyecto")
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	panel._unhandled_input(tab)
	_context.check(panel.is_open, "Tab abre la mochila")
	_context.check(panel.visible, "y la enseña")
	_context.check(self.paused, "pausando el mundo")
	var confirm := InputEventKey.new()
	confirm.physical_keycode = KEY_E
	confirm.pressed = true
	panel._unhandled_input(confirm)
	_context.check(not Input.is_key_pressed(KEY_E), "el confirmar se come la pulsación")
	panel._unhandled_input(tab)
	_context.check(not panel.is_open, "Tab la cierra")
	_context.check(not self.paused, "y reanuda el mundo")


## No tiene sentido gestionar el equipo desde la pantalla de muerte, y pausar el
## mundo detrás de ella rompería la reaparición: la mochila se niega a abrirse.
func _panel_refuses_when_dead() -> void:
	var session := _session()
	var panel := _panel()
	_context.check(session != null and panel != null, "mochila y sesión presentes")
	if session == null or panel == null:
		return
	session.player.take_damage(session.player.health.maximum)
	_context.check(session.player.is_dead, "el jugador está sin vida")
	_context.check(not panel.open(), "la mochila no se abre muerto")
	_context.check(not self.paused, "y el mundo sigue en marcha")
	session.respawn()
	_context.check(not session.player.is_dead, "y revive")
	_context.check(panel.open(), "revivido ya puede abrirla")
	panel.close()