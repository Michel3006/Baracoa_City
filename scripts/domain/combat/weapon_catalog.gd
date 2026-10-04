class_name WeaponCatalog
extends RefCounted

## Catálogo de armas del MVP (sección 7).
##
## Solo piedra y cuchillo. Las armas de fuego están prohibidas en el MVP, así que
## no hay forma de añadir una sin tocar esta tabla a propósito.
##
## Todos los valores vienen de `GameConfig`: el catálogo decide qué arma existe, no
## cuánto pega.
##
## Dependencias: domain, infrastructure/configuration

const STONE := &"stone"
const KNIFE := &"knife"

const KNIFE_TEXTURE := "res://assets/weapons/knife.png"


static func ids() -> Array[StringName]:
	return [STONE, KNIFE]


static func exists(id: StringName) -> bool:
	return id in ids()


## Crea un arma nueva por identificador. Devuelve `null` si no existe.
static func create(id: StringName) -> Weapon:
	match id:
		STONE:
			return Weapon.new({
				"id": STONE,
				"display_name": GameConfig.WEAPON_STONE_NAME,
				"attack_damage": GameConfig.WEAPON_STONE_DAMAGE,
				"attack_range": GameConfig.WEAPON_STONE_RANGE,
				"attack_cooldown": GameConfig.WEAPON_STONE_COOLDOWN,
				"stamina_cost": GameConfig.WEAPON_STONE_STAMINA,
				"durability": GameConfig.WEAPON_STONE_DURABILITY,
				"max_durability": GameConfig.WEAPON_STONE_DURABILITY,
				"texture_path": "",
			})
		KNIFE:
			return Weapon.new({
				"id": KNIFE,
				"display_name": GameConfig.WEAPON_KNIFE_NAME,
				"attack_damage": GameConfig.WEAPON_KNIFE_DAMAGE,
				"attack_range": GameConfig.WEAPON_KNIFE_RANGE,
				"attack_cooldown": GameConfig.WEAPON_KNIFE_COOLDOWN,
				"stamina_cost": GameConfig.WEAPON_KNIFE_STAMINA,
				"durability": GameConfig.WEAPON_KNIFE_DURABILITY,
				"max_durability": GameConfig.WEAPON_KNIFE_DURABILITY,
				"texture_path": KNIFE_TEXTURE,
			})
		_:
			GameLogger.warning("Arma desconocida: %s" % id, "WeaponCatalog")
			return null


## Arma con la que empieza el jugador: la piedra, porque está en la mochila.
static func default_weapon() -> Weapon:
	return create(STONE)
