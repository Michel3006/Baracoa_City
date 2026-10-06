class_name Inventory
extends RefCounted

## Inventario de objetos (sección 13).
##
## Almacena definiciones (`Item`) con su cantidad. La capacidad se mide en **pilas**:
## una casilla por id de objeto, y cada pila se llena hasta `max_stack` de su
## definición. Un objeto no apilable ocupa una casilla entera por copia.
##
## No sabe nada de gráficos: la UI lo consulta con `get_entries()` y las señales.
## Tampoco sabe qué hace cada objeto: `use_item()` consume, `equip_item()` marca la
## mano, y el efecto (curar, pegar, etc.) lo decide la capa Application escuchando
## las señales. Aquí solo viven las reglas de la pila.
##
## Dependencias: domain

signal changed()
signal quantity_changed(item_id: StringName, delta: int)
signal equipped_changed(item_id: StringName)
signal used(item_id: StringName)
signal rejected(reason: StringName)

const REASON_BAD_QUANTITY := &"bad_quantity"
const REASON_NOT_FOUND := &"not_found"
const REASON_STACK_FULL := &"stack_full"
const REASON_CAPACITY := &"capacity"
const REASON_NOT_WEAPON := &"not_weapon"
const REASON_NOT_USABLE := &"not_usable"

## Nº de casillas. Con `max_slots <= 0` se toma el de la configuración.
var capacity: int

var _stacks: Dictionary = {}
var _slot_count: int = 0
var _equipped: StringName = &""


func _init(max_slots: int = -1) -> void:
	capacity = GameConfig.PLAYER_INVENTORY_CAPACITY if max_slots <= 0 else max_slots


## Lo que el jugador lleva en la mano, o `&""` si va a puños.
func equipped() -> StringName:
	return _equipped


func slots_used() -> int:
	return _slot_count


func is_full() -> bool:
	return _slot_count >= capacity


func has_item(item_id: StringName) -> bool:
	return _stacks.has(item_id)


func get_quantity(item_id: StringName) -> int:
	if not _stacks.has(item_id):
		return 0
	return int(_stacks[item_id].quantity)


## El objeto (definición) que ocupa la casilla, o `null`.
func get_item(item_id: StringName) -> Item:
	if not _stacks.has(item_id):
		return null
	return _stacks[item_id].item


## Vista de solo lectura para la UI: una entrada por casilla.
func get_entries() -> Array:
	var out: Array = []
	for item_id: StringName in _stacks:
		var entry: Dictionary = _stacks[item_id]
		out.append({
			"id": item_id,
			"item": entry.item,
			"quantity": entry.quantity,
			"equipped": item_id == _equipped,
		})
	return out


## Recoge `quantity` unidades del objeto. Devuelve cuántas entraron de verdad: 0
## si la pila está llena o no queda casilla. Si el objeto ya estaba, apila hasta
## `max_stack`; si no, abre una casilla (una sola copia si no es apilable).
func add_item(item: Item, quantity: int = 1) -> int:
	if item == null or quantity <= 0:
		_reject(REASON_BAD_QUANTITY)
		return 0
	if _stacks.has(item.id):
		var entry: Dictionary = _stacks[item.id]
		var room := int(entry.item.max_stack) - int(entry.quantity)
		if not entry.item.stackable or room <= 0:
			_reject(REASON_STACK_FULL)
			return 0
		var added := mini(quantity, room)
		entry.quantity += added
		_emit_change(item.id, added)
		return added
	if is_full():
		_reject(REASON_CAPACITY)
		return 0
	_stacks[item.id] = {
		"item": item,
		"quantity": mini(quantity, item.max_stack if item.stackable else 1),
	}
	_slot_count += 1
	_emit_change(item.id, get_quantity(item.id))
	return get_quantity(item.id)


## Quita `quantity` unidades. Devuelve cuántas quitó de verdad. Al vaciarse la pila
## se libera la casilla, y si lo que se quita era lo equipado, las manos quedan
## vacías.
func remove_item(item_id: StringName, quantity: int = 1) -> int:
	if quantity <= 0:
		_reject(REASON_BAD_QUANTITY)
		return 0
	if not _stacks.has(item_id):
		_reject(REASON_NOT_FOUND)
		return 0
	var entry: Dictionary = _stacks[item_id]
	var removed := mini(quantity, int(entry.quantity))
	entry.quantity -= removed
	if int(entry.quantity) <= 0:
		if _equipped == item_id:
			_unequip()
		_stacks.erase(item_id)
		_slot_count -= 1
	_emit_change(item_id, -removed)
	return removed


## Usa un objeto. Por ahora solo los consumibles se pueden usar, y usarlos
## consume una unidad: el efecto (curar, etc.) lo decide quien escuche `used`.
## Cualquier otro tipo responde `false`.
func use_item(item_id: StringName) -> bool:
	if not _stacks.has(item_id):
		_reject(REASON_NOT_FOUND)
		return false
	var entry: Dictionary = _stacks[item_id]
	if entry.item.type != ItemKind.Kind.CONSUMABLE:
		_reject(REASON_NOT_USABLE)
		return false
	remove_item(item_id, 1)
	used.emit(item_id)
	return true


## Equipa lo que haya en la casilla. Solo los objetos WEAPON se pueden llevar en
## la mano; los demás se rechazan. Equipar algo ya equipado es un no-op exitoso.
func equip_item(item_id: StringName) -> bool:
	if not _stacks.has(item_id):
		_reject(REASON_NOT_FOUND)
		return false
	var entry: Dictionary = _stacks[item_id]
	if entry.item.type != ItemKind.Kind.WEAPON:
		_reject(REASON_NOT_WEAPON)
		return false
	if _equipped == item_id:
		return true
	_equipped = item_id
	equipped_changed.emit(item_id)
	return true


## Deja las manos vacías. Devuelve `false` si ya lo estaban.
func unequip_item() -> bool:
	if _equipped == &"":
		return false
	_unequip()
	return true


func _unequip() -> void:
	_equipped = &""
	equipped_changed.emit(&"")


func _emit_change(item_id: StringName, delta: int) -> void:
	changed.emit()
	quantity_changed.emit(item_id, delta)


func _reject(reason: StringName) -> void:
	rejected.emit(reason)