class_name InventoryPanel
extends Control

## Pantalla de la mochila (sección 13).
##
## Es una `Control` a pantalla completa dentro de su propia `CanvasLayer`, encima
## del HUD. Se dibuja entera con `draw_rect` y la mini fuente del proyecto, igual
## que el HUD: la del sistema sale borrosa a 384x216.
##
## ## Qué hace y qué no
##
## No decide reglas: consulta `Inventory.get_entries()` y llama a
## `equip_item()`/`use_item()`. Los efectos (que el arma cambie, que la baya cure)
## los decide `GameSession` escuchando las señales del inventario, como ya hacía
## con el cableado del arma. Este panel solo enseña y confirma.
##
## ## Pausa
##
## Abrir la mochila pausa el árbol (`get_tree().paused`): el mundo se queda
## quieto mientras se gestiona el equipamiento. El panel va en
## `PROCESS_MODE_ALWAYS` para seguir recibiendo la entrada con el árbol pausado,
## y al cerrar se reanuda.
##
## ## Entrada
##
## Abre y cierra con `toggle_inventory`; navega con los ejes de movimiento
## (WASD/flechas) y confirma con `interact`. Los ejes y el confirmar se comen la
## pulsación (handled) para que el jugador no avance ni ataque mientras gestiona
## la mochila. La entrada de cierre no es `ui_cancel` a propósito: `Esc` sigue
## cerrando el juego desde el autoload `Game`, que recibe el evento antes.
##
## Dependencias: presentation -> application, domain (solo consulta)

const ACTION_TOGGLE := &"toggle_inventory"
const ACTION_CONFIRM := &"interact"
const ACTION_UP := &"move_up"
const ACTION_DOWN := &"move_down"
const ACTION_LEFT := &"move_left"
const ACTION_RIGHT := &"move_right"

## Icono provisional de la baya, dibujado con rectángulos como el decorado del
## mundo: no hay textura de objeto consumible en el pack.
const BERRY_BODY := Color("c23b3b")
const BERRY_LEAF := Color("4f9a4f")

## Tamaño máximo del icono dentro de una casilla. Las texturas de armas son
## alargadas (la piedra 3x16, el cuchillo 6x11): se escalan para caber.
const ICON_MAX := 12

var session: GameSession = null

var is_open: bool = false

var _inventory: Inventory = null
var _selected: int = 0
var _cols: int = GameConfig.INVENTORY_COLS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Igual que el HUD: bajo una `CanvasLayer` los anchors no dan tamaño (queda
	# 0x0), y el panel se dibujaría con el origen en números negativos. Se fija el
	# tamaño del viewport de entrada; el proyecto es de resolución fija.
	size = get_viewport_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# La mochila gestiona el mundo pausado: tiene que seguir recibiendo la entrada
	# cuando el resto del árbol está parado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _exit_tree() -> void:
	# Si la mochila se queda abierta al abandonar la escena, no dejar el mundo
	# pausado para siempre.
	if is_open:
		close(false)


## Conecta con la sesión como hace el HUD: el dominio se consulta a través de
## `session.player.inventory` y las señales redibujan el panel.
func bind(session_to_use: GameSession) -> void:
	session = session_to_use
	if session == null or session.player == null or session.player.inventory == null:
		return
	_inventory = session.player.inventory
	_inventory.changed.connect(queue_redraw)
	_inventory.quantity_changed.connect(_on_quantity_changed)
	# No se conecta `queue_redraw` directo: `equipped_changed` lleva un argumento
	# (el id) y un método de 0 argumentos no lo acepta, y Godot lo grita por
	# consola, que aquí es un error como cualquier otro.
	_inventory.equipped_changed.connect(_on_equipped_changed)
	queue_redraw()


func _on_quantity_changed(_item_id: StringName, _delta: int) -> void:
	queue_redraw()


func _on_equipped_changed(_item_id: StringName) -> void:
	queue_redraw()


## Abre la mochila. Devuelve `false` y no hace nada si ya está abierta o si el
## jugador está muerto (gestionar el equipamiento desde la pantalla de muerte no
## tiene sentido, y pausar el mundo detrás de ella rompería la reaparición).
func open() -> bool:
	if is_open or _inventory == null or session == null or session.player == null:
		return false
	if session.player.is_dead:
		return false
	is_open = true
	_selected = 0
	visible = true
	_pause_world(true)
	queue_redraw()
	return true


func close(unpause: bool = true) -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if unpause:
		_pause_world(false)
	queue_redraw()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## Navega la selección por la rejilla, con tope en las filas que caben.
func move_selection(delta: Vector2i) -> void:
	if not is_open or _inventory == null:
		return
	var rows := _rows()
	var col := _selected % _cols
	var row := _selected / _cols
	col = clampi(col + delta.x, 0, _cols - 1)
	row = clampi(row + delta.y, 0, rows - 1)
	var next := row * _cols + col
	if next != _selected:
		_selected = next
		queue_redraw()


## Confirma la casilla seleccionada: equipa si es arma, usa si es consumible.
## Devuelve `false` si la casilla está vacía o el inventario rechaza la acción.
func confirm_selected() -> bool:
	if not is_open or _inventory == null:
		return false
	var entry := entry_at(_selected)
	if entry.is_empty():
		return false
	var item: Item = entry.item
	match item.type:
		ItemKind.Kind.WEAPON:
			return _inventory.equip_item(item.id)
		ItemKind.Kind.CONSUMABLE:
			return _inventory.use_item(item.id)
	return false


## La entrada de una casilla (id, item, quantity, equipped), o `{}` si está vacía.
## El orden es el del inventario: primera casilla = primer objeto recogido.
func entry_at(index: int) -> Dictionary:
	if _inventory == null:
		return {}
	var entries := _inventory.get_entries()
	if index < 0 or index >= entries.size():
		return {}
	return entries[index]


## El rectángulo de la casilla `index` en coordenadas locales del panel.
func slot_rect(index: int) -> Rect2:
	var geometry := _geometry()
	if index < 0 or index >= _inventory.capacity:
		return Rect2()
	var col := index % _cols
	var row := index / _cols
	var step := GameConfig.INVENTORY_SLOT + GameConfig.INVENTORY_GAP
	return Rect2(
		geometry.origin + Vector2i(
			GameConfig.INVENTORY_PAD + col * step,
			GameConfig.INVENTORY_PAD + GameConfig.INVENTORY_HEADER + row * step
		),
		Vector2i(GameConfig.INVENTORY_SLOT, GameConfig.INVENTORY_SLOT)
	)


## Cuántas filas necesita la rejilla para la capacidad actual.
func _rows() -> int:
	if _inventory == null:
		return 0
	return ceili(float(_inventory.capacity) / float(_cols))


## La rejilla completa: origen del panel centrado y tamaño del panel.
func _geometry() -> Dictionary:
	var rows := _rows()
	var step := GameConfig.INVENTORY_SLOT + GameConfig.INVENTORY_GAP
	var grid := Vector2i(
		_cols * GameConfig.INVENTORY_SLOT + (_cols - 1) * GameConfig.INVENTORY_GAP,
		rows * GameConfig.INVENTORY_SLOT + (rows - 1) * GameConfig.INVENTORY_GAP
	)
	var panel_size := grid + Vector2i(
		GameConfig.INVENTORY_PAD * 2,
		GameConfig.INVENTORY_PAD * 2 + GameConfig.INVENTORY_HEADER
	)
	var origin: Vector2i = (Vector2i(size) - panel_size) / 2
	return {
		"origin": origin,
		"panel": Rect2(Vector2(origin), Vector2(panel_size)),
	}


func _pause_world(paused: bool) -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = paused


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_TOGGLE, false):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	var delta := _selection_delta(event)
	if delta != Vector2i.ZERO:
		move_selection(delta)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION_CONFIRM, false):
		confirm_selected()
		get_viewport().set_input_as_handled()


## Un evento no puede ser de dos ejes a la vez: el primero que manda gana.
func _selection_delta(event: InputEvent) -> Vector2i:
	if event.is_action_pressed(ACTION_LEFT, false):
		return Vector2i(-1, 0)
	if event.is_action_pressed(ACTION_RIGHT, false):
		return Vector2i(1, 0)
	if event.is_action_pressed(ACTION_UP, false):
		return Vector2i(0, -1)
	if event.is_action_pressed(ACTION_DOWN, false):
		return Vector2i(0, 1)
	return Vector2i.ZERO


func _draw() -> void:
	if not is_open or _inventory == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), GameConfig.INVENTORY_OVERLAY)
	var geometry := _geometry()
	var panel: Rect2 = geometry.panel
	draw_rect(panel, GameConfig.INVENTORY_BG)
	draw_rect(panel, GameConfig.INVENTORY_BORDER, false, 1.0)
	_draw_title(panel)
	for i in _inventory.capacity:
		_draw_slot(i)


func _draw_title(panel: Rect2) -> void:
	var title := GameConfig.INVENTORY_TITLE
	var size_text := PixelFont.measure(title)
	var origin := Vector2i(panel.position) + Vector2i(
		int((panel.size.x - size_text.x) * 0.5),
		int((GameConfig.INVENTORY_HEADER - size_text.y) * 0.5)
	)
	PixelFont.draw(self, origin, title, GameConfig.INVENTORY_TEXT)


func _draw_slot(index: int) -> void:
	var rect := slot_rect(index)
	draw_rect(rect, GameConfig.INVENTORY_SLOT_BG)
	if index == _selected:
		# El anillo de selección sale por fuera de la casilla para que ambos avisos
		# (selección y equipado) se lean a la vez.
		draw_rect(rect.grow(1.0), GameConfig.INVENTORY_SELECTED, false, 1.0)
	var entry := entry_at(index)
	if entry.is_empty():
		return
	if entry.equipped:
		draw_rect(rect, GameConfig.INVENTORY_EQUIPPED, false, 1.0)
	_draw_item_icon(rect, entry.item)
	if int(entry.quantity) > 1:
		_draw_quantity(rect, int(entry.quantity))


## El icono del objeto: la textura del arma si es un arma con textura, la baya
## dibujada si es una baya, y un cajetín vacío como último recurso.
func _draw_item_icon(rect: Rect2, item: Item) -> void:
	var texture := _weapon_texture(item)
	if texture != null:
		var texture_size: Vector2 = texture.get_size()
		var scale := minf(
			ICON_MAX / maxf(1.0, texture_size.x), ICON_MAX / maxf(1.0, texture_size.y)
		)
		var drawn := texture_size * scale
		draw_texture_rect(
			texture,
			Rect2(rect.get_center() - drawn * 0.5, drawn),
			false,
			Color(1.0, 1.0, 1.0, 1.0)
		)
		return
	if item.id == ItemCatalog.BERRY:
		var center: Vector2 = rect.get_center()
		draw_circle(center + Vector2(0, 1), 3.0, BERRY_BODY)
		draw_rect(Rect2(center + Vector2(-2, -2), Vector2i(3, 2)), BERRY_LEAF)
		return
	var outline := Rect2(rect.get_center() - Vector2(4, 4), Vector2(8, 8))
	draw_rect(outline, GameConfig.INVENTORY_TEXT, false, 1.0)


func _draw_quantity(rect: Rect2, quantity: int) -> void:
	var digits := str(quantity)
	var digits_size := PixelFont.measure(digits)
	var origin := Vector2i(rect.position + rect.size) - Vector2i(digits_size.x, digits_size.y)
	PixelFont.draw(self, origin, digits, GameConfig.INVENTORY_TEXT)


## La textura del arma que lleva el objeto dentro, o `null`.
func _weapon_texture(item: Item) -> Texture2D:
	var weapon_id: Variant = item.metadata.get("weapon", &"")
	if not (weapon_id is StringName) or not WeaponCatalog.exists(weapon_id):
		return null
	var weapon := WeaponCatalog.create(weapon_id)
	if weapon == null or weapon.texture_path.is_empty() or not ResourceLoader.exists(weapon.texture_path):
		return null
	return load(weapon.texture_path) as Texture2D