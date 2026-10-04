class_name Weapon
extends RefCounted

## Arma cuerpo a cuerpo (secciones 7 y 10).
##
## Solo datos y sus propias reglas: cuánto pega, hasta dónde llega, cuánto tarda
## entre golpes, qué stamina cuesta y cuánto aguanta. El sistema de combate decide
## cuándo se usa; la presentación decide cómo se ve.
##
## Las armas de fuego están prohibidas en el MVP (sección 7): el catálogo solo
## ofrece piedra y cuchillo.
##
## Dependencias: domain

signal changed()

var id: StringName = &"stone"
var display_name: String = "Piedra"
## Potencia antes de aplicar la defensa del objetivo.
var attack_damage: float = 1.0
## Distancia máxima del golpe, en píxeles de mundo.
var attack_range: float = 16.0
## Segundos entre dos golpes seguidos.
var attack_cooldown: float = 0.45
var stamina_cost: float = 0.0
var durability: int = 0
var max_durability: int = 0
## Textura de la hoja. Vacío para armas que se dibujan a mano.
var texture_path: String = ""

## Campos que `Weapon.new({...})` acepta.
const FIELDS: PackedStringArray = [
	"id",
	"display_name",
	"attack_damage",
	"attack_range",
	"attack_cooldown",
	"stamina_cost",
	"durability",
	"max_durability",
	"texture_path",
]


func _init(values: Dictionary = {}) -> void:
	for field: String in FIELDS:
		if values.has(field):
			set(field, values[field])


## Un arma sin durability (`max_durability` a 0) no se rompe nunca.
var is_broken: bool:
	get:
		return max_durability > 0 and durability <= 0


## Daño que realmente inflige: un arma rota no pega.
var effective_damage: float:
	get:
		return 0.0 if is_broken else attack_damage


## ¿Se puede iniciar un golpe con este arma ahora mismo?
func can_attack() -> bool:
	return not is_broken and DamageRules.is_valid_attack(attack_damage)


## Daño final contra una defensa concreta. Delega en `DamageRules`.
func damage_against(defense: float) -> float:
	return DamageRules.compute(effective_damage, defense)


## Desgasta el arma. Devuelve la durabilidad restante.
## Un arma sin durability no se desgasta.
func wear(amount: int = 1) -> int:
	if max_durability <= 0 or amount <= 0:
		return durability
	durability = maxi(0, durability - amount)
	changed.emit()
	return durability


## Repara el arma hasta su máximo. Devuelve lo reparado.
func repair(amount: int) -> int:
	if max_durability <= 0 or amount <= 0:
		return 0
	var before := durability
	durability = mini(max_durability, durability + amount)
	if durability != before:
		changed.emit()
	return durability - before


func snapshot() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"damage": attack_damage,
		"range": attack_range,
		"cooldown": attack_cooldown,
		"stamina_cost": stamina_cost,
		"durability": durability,
		"max_durability": max_durability,
		"broken": is_broken,
	}


## Copia independiente: dos jugadores no pueden compartir la misma durability.
func copy() -> Weapon:
	var clone := Weapon.new()
	clone.id = id
	clone.display_name = display_name
	clone.attack_damage = attack_damage
	clone.attack_range = attack_range
	clone.attack_cooldown = attack_cooldown
	clone.stamina_cost = stamina_cost
	clone.durability = durability
	clone.max_durability = max_durability
	clone.texture_path = texture_path
	return clone
