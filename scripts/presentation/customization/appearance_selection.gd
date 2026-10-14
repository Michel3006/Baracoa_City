class_name AppearanceSelection
extends RefCounted

## Qué fila del vestuario está elegida y por qué opción va cada una (plan de ropa y
## peinados, Fase 4).
##
## Datos puros, sin nodos y sin entrada: la pantalla (`AppearancePanel`) lo dibuja
## y lo mueve, y el resultado acaba en `PlayerView`. Separarlo del panel es lo que
## permite probar el menú (opciones, vueltas, nombres) sin montar una escena.
##
## La opción 0 de cada parte es "nada puesto", y no es un caso aparte: el jugador
## del pack va con el torso desnudo, así que arranca sin camiseta y quitarse la ropa
## tiene que estar en la lista como una opción más.

## Partes del cuerpo que se visten, en el orden en que las recorre el eje vertical.
## Solo dos: la camiseta y el peinado.
const PARTS: Array[int] = [
	GarmentDefinition.Part.SHIRT, GarmentDefinition.Part.HAIR,
]

## Opción elegida de cada parte: índice dentro de `options()`, con la 0 = nada.
var _index: Dictionary = {}
## Fila sobre la que está el cursor.
var part: int = GarmentDefinition.Part.SHIRT


func _init() -> void:
	for part_id: int in PARTS:
		_index[part_id] = 0


## Las opciones de una parte: primero "nada" y después el catálogo, en su orden.
##
## El orden sale del catálogo y no se copia aquí, así que añadir una camiseta a
## `GarmentCatalog` la añade al menú sin tocar esto.
func options(part_id: int) -> Array[StringName]:
	var ids: Array[StringName] = [&""]
	if part_id == GarmentDefinition.Part.HAIR:
		ids.append_array(GarmentCatalog.hair_ids())
	else:
		ids.append_array(GarmentCatalog.shirt_ids())
	return ids


## Cuántas opciones tiene una parte, contando "nada".
func count(part_id: int) -> int:
	return options(part_id).size()


## Índice elegido de una parte.
func index_of(part_id: int) -> int:
	return int(_index.get(part_id, 0))


## Id de la opción `index` de una parte, o `&""` si el índice se sale.
##
## Fuera de rango devuelve "nada", que es lo que se dibuja y lo que se pone: un
## índice imposible nunca debe acabar en una prenda que no existe.
func id_at(part_id: int, index: int) -> StringName:
	var ids := options(part_id)
	if index < 0 or index >= ids.size():
		return &""
	return ids[index]


## Id de la opción elegida de una parte.
func selected_id(part_id: int) -> StringName:
	return id_at(part_id, index_of(part_id))


## Nombre legible de una opción: el del catálogo, o el de "nada" de esa parte. Un
## id que no esté en el catálogo se enseña tal cual en vez de mentir con otro
## nombre.
func label_of(part_id: int, id: StringName) -> String:
	if id == &"":
		return (
			GameConfig.APPEARANCE_NONE_HAIR
			if part_id == GarmentDefinition.Part.HAIR
			else GameConfig.APPEARANCE_NONE_SHIRT
		)
	var definition := GarmentCatalog.definition(part_id, id)
	return definition.label if definition != null else str(id)


## Nombre legible de la opción elegida de una parte.
func selected_label(part_id: int) -> String:
	return label_of(part_id, selected_id(part_id))


## Nombre de la parte del cuerpo que se está vistiendo, para el menú.
func part_label(part_id: int) -> String:
	return (
		GameConfig.APPEARANCE_LABEL_HAIR
		if part_id == GarmentDefinition.Part.HAIR
		else GameConfig.APPEARANCE_LABEL_SHIRT
	)


## Mueve el cursor a una fila. Sin vuelta por los extremos: en un menú de dos filas
## subir estando arriba no debe dar la vuelta, que deja al jugador en la otra punta
## sin haber visto las de en medio.
func select_part(part_id: int) -> bool:
	if not _index.has(part_id) or part_id == part:
		return false
	part = part_id
	return true


## Sube o baja una fila, con tope.
func switch_part(delta: int) -> bool:
	var current := PARTS.find(part)
	if current < 0:
		current = 0
	var next := clampi(current + delta, 0, PARTS.size() - 1)
	return select_part(PARTS[next])


## Pasa a la opción siguiente (`delta > 0`) o a la anterior, con vuelta por los
## extremos: con siete camisetas, seguir hacia delante desde la última vuelve a
## "nada", que es lo que se espera de un carrusel. Solo retroceder o avanzar de
## verdad cuenta: en una lista de una sola opción no hay nada que mover.
func cycle(delta: int) -> bool:
	if delta == 0:
		return false
	var total := count(part)
	if total <= 1:
		return false
	var next := posmod(index_of(part) + delta, total)
	if next == index_of(part):
		return false
	_index[part] = next
	return true


## Coloca el cursor en la opción que ya lleva puesta el jugador. Un id que no esté
## en el catálogo cae en "nada" en vez de dejar el cursor en un sitio imposible.
func sync(part_id: int, id: StringName) -> void:
	_index[part_id] = maxi(0, options(part_id).find(id))
