class_name WeaponCatalog
extends RefCounted

## Catálogo de armas del MVP (sección 7).
##
## Tres entradas: la piedra, el cuchillo y los puños. Las armas de fuego están
## prohibidas en el MVP, así que no hay forma de añadir una sin tocar esta tabla a
## propósito.
##
## Los puños no son un arma del inventario: es la opción de combate cuerpo a
## cuerpo **sin arma**, siempre disponible. Se modela como un arma degenerada
## (sin textura, sin durabilidad) para que todo el sistema de combate funcione
## igual sin tocar una sola regla: si los puños son un caso especial, el golpe
## con arma y el golpe a puños divergirían en cuanto uno de los dos cres.
##
## Todos los valores vienen de `GameConfig`: el catálogo decide qué arma existe, no
## cuánto pega.
##
## Dependencias: domain, infrastructure/configuration

const UNARMED := &"unarmed"
const STONE := &"stone"
const KNIFE := &"knife"

const KNIFE_TEXTURE := "res://assets/weapons/blade.png"
const STONE_TEXTURE := "res://assets/weapons/rock.png"


static func ids() -> Array[StringName]:
	return [UNARMED, STONE, KNIFE]


static func exists(id: StringName) -> bool:
	return id in ids()


## ¿Este "arma" son en realidad los puños? La presentación lo pregunta para
## decidir si dibuja algo en la mano.
static func is_unarmed(weapon: Weapon) -> bool:
	return weapon != null and weapon.id == UNARMED


## Crea un arma nueva por identificador. Devuelve `null` si no existe.
static func create(id: StringName) -> Weapon:
	match id:
		UNARMED:
			return Weapon.new({
				"id": UNARMED,
				"display_name": GameConfig.WEAPON_UNARMED_NAME,
				"attack_damage": GameConfig.WEAPON_UNARMED_DAMAGE,
				"attack_range": GameConfig.WEAPON_UNARMED_RANGE,
				"attack_cooldown": GameConfig.WEAPON_UNARMED_COOLDOWN,
				"stamina_cost": GameConfig.WEAPON_UNARMED_STAMINA,
				"durability": 0,
				"max_durability": GameConfig.WEAPON_UNARMED_DURABILITY,
				"texture_path": "",
			})
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
				"texture_path": STONE_TEXTURE,
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


## Golpe sin arma. Se crea una vez y se comparte: no tiene estado propio, así que
## que todos los puños apunten al mismo objeto no puede desincronizar nada.
static func unarmed() -> Weapon:
	return create(UNARMED)
