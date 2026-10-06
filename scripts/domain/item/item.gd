class_name Item
extends RefCounted

## Objeto genérico (sección 12).
##
## Es una **definición**, no una instancia "en el mundo": no sabe cuántas unidades
## hay (eso lo lleva el inventario) ni cómo dibujarse (eso lo decide la UI). Un
## mismo id comparte definición entre todas las pilas, así que `metadata` no puede
## guardar estado por copia.
##
## Dependencias: domain

var id: StringName
var name: String
var type: ItemKind.Kind
var stackable: bool
var max_stack: int
var metadata: Dictionary


func _init(
	item_id: StringName,
	item_name: String,
	item_type: ItemKind.Kind,
	can_stack: bool,
	stack_limit: int,
	extra: Dictionary = {}
) -> void:
	id = item_id
	name = item_name
	type = item_type
	stackable = can_stack
	max_stack = stack_limit
	metadata = extra


## ¿Se puede apilar con otra copia del mismo objeto? Dos condiciones: la propia
## definición y que quepa en la pila.
func can_stack_with(other: Item, current_quantity: int) -> bool:
	if not stackable or other == null or other.id != id:
		return false
	return current_quantity < max_stack