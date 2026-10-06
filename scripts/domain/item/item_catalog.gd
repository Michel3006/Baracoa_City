class_name ItemCatalog
extends RefCounted

## Objetos concretos del MVP (secciones 7, 12 y 13).
##
## Solo concreta objetos: dónde aparecen, cómo se recogen y qué efectos tienen es
## de otras capas. Las armas llevan `metadata.weapon` con el id del arma del
## `WeaponCatalog` que representan: esa es la llave que usa la capa Application
## para equiparlas (`combat.equip()` sin tocar su API).
##
## Dependencias: domain, infrastructure/configuration

## Id de objeto. Coinciden con los del `WeaponCatalog` para las armas, a
## propósito: así equipar un objeto de arma es traducir su metadata sin tablas
## intermedias.
const STONE := &"stone"
const KNIFE := &"knife"
const BERRY := &"berry"


static func ids() -> Array[StringName]:
	return [STONE, KNIFE, BERRY]


static func exists(id: StringName) -> bool:
	return id in ids()


static func create(id: StringName) -> Item:
	match id:
		STONE:
			return stone()
		KNIFE:
			return knife()
		BERRY:
			return berry()
		_:
			return null


## La piedra: el arma con la que el jugador empieza, y la única que lleva en la
## mochila al arrancar. No apila: cada piedra es una casilla.
static func stone() -> Item:
	return Item.new(
		STONE,
		GameConfig.ITEM_STONE_NAME,
		ItemKind.Kind.WEAPON,
		false,
		1,
		{"weapon": WeaponCatalog.STONE}
	)


static func knife() -> Item:
	return Item.new(
		KNIFE,
		GameConfig.ITEM_KNIFE_NAME,
		ItemKind.Kind.WEAPON,
		false,
		1,
		{"weapon": WeaponCatalog.KNIFE}
	)


## Un consumible de ejemplo para fijar la taxonomía. No tiene efecto todavía: la
## señal `used` del inventario es la vía por la que llegará cuando exista.
static func berry() -> Item:
	return Item.new(
		BERRY,
		GameConfig.ITEM_BERRY_NAME,
		ItemKind.Kind.CONSUMABLE,
		true,
		10
	)