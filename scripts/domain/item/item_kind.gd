class_name ItemKind
extends RefCounted

## Taxonomía de objetos (sección 12).
##
## Ocho tipos posibles; el MVP no implementa todos. La lista vive aquí para que
## ningún otro archivo invente un tipo nuevo a mitad de camino: un `MISC` genérico
## sirve para lo que no encaje, y ampliar la taxonomía es tocar esta única tabla.
##
## Dependencias: domain

enum Kind {
	WEAPON,
	CONSUMABLE,
	MATERIAL,
	QUEST,
	CURRENCY,
	CLOTHING,
	TOOL,
	MISC,
}

const ALL: Array = [
	Kind.WEAPON,
	Kind.CONSUMABLE,
	Kind.MATERIAL,
	Kind.QUEST,
	Kind.CURRENCY,
	Kind.CLOTHING,
	Kind.TOOL,
	Kind.MISC,
]


static func is_valid(kind: Kind) -> bool:
	return kind in ALL


static func name_of(kind: Kind) -> String:
	match kind:
		Kind.WEAPON:
			return "WEAPON"
		Kind.CONSUMABLE:
			return "CONSUMABLE"
		Kind.MATERIAL:
			return "MATERIAL"
		Kind.QUEST:
			return "QUEST"
		Kind.CURRENCY:
			return "CURRENCY"
		Kind.CLOTHING:
			return "CLOTHING"
		Kind.TOOL:
			return "TOOL"
		_:
			return "MISC"