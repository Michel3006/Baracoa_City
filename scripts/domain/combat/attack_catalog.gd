class_name AttackCatalog
extends RefCounted

## Catálogo de ataques cuerpo a cuerpo (secciones 9, 12, 20 y 29).
##
## Los doce ataques de la sección 9, calibrados contra las hojas del pack
## Hormelz: `clip_frames` y `contact_frame` son los recuentos medidos sobre las
## hojas horneadas (no hay un "más o menos"), y de ellos salen las tres fases
## con la fórmula de la sección 12 que aplica `AttackDefinition`.
##
## También reparte las tres cadenas de entrada (sección 23) y resuelve la
## composición de daño y stamina entre arma y ataque, para que la fórmula tenga
## un solo sitio y no se repita en el presentador ni en los enemigos.
##
## Dependencias: domain, infrastructure/configuration (solo constantes)

## --- Los doce (sección 9) ---
const LEFT_JAB := &"left_jab"
const RIGHT_JAB := &"right_jab"
const LEFT_HOOK := &"left_hook"
const RIGHT_HOOK := &"right_hook"
const STRAIGHT := &"straight"
const ELBOW := &"elbow"
const FRONT_KICK := &"front_kick"
const FRONT_KICK_2 := &"front_kick2"
const HIGH_KICK := &"high_kick"
const SIDE_KICK := &"side_kick"
const STOMP_KICK := &"stomp_kick"
const COMBO := &"combo"

## --- Familias de entrada (sección 23) ---
## J / ratón izquierdo / `attack`: la cadena de siempre.
const FAMILY_LIGHT := &"light"
## K / `attack_heavy`: cruzada y gancho derecho, más compromiso.
const FAMILY_KICK := &"kick"
## L / `attack_kick`: las patadas.
const FAMILY_HEAVY := &"heavy"

const FAMILIES: Array[StringName] = [FAMILY_LIGHT, FAMILY_HEAVY, FAMILY_KICK]

## Las tres cadenas. El índice 0 es el que sale de un golpe suelto; el resto
## solo se alcanza con una entrada guardada en el buffer (sección 22), y al
## terminar sin entrada guardada la cadena se reinicia.
const _CHAINS := {
	FAMILY_LIGHT: [LEFT_JAB, RIGHT_JAB, LEFT_HOOK, ELBOW],
	FAMILY_HEAVY: [STRAIGHT, RIGHT_HOOK, COMBO],
	FAMILY_KICK: [FRONT_KICK, FRONT_KICK_2, HIGH_KICK, SIDE_KICK, STOMP_KICK],
}

## Frames medidos por hoja y frame de contacto, a 68 fps (la hoja del pack se
## calibró a ese ritmo: ver `HormelzVisualData`). El daño y la stamina son los
## de la sección 29; FRONT_KICK_2 y COMBO no aparecen en esa tabla y se les dio
## el de su familia como decisión de calibración (sección 65).
const _DATA: Array[Dictionary] = [
	{
		"id": LEFT_JAB, "display_name": "Jab izquierdo", "family": FAMILY_LIGHT,
		"clip_frames": 15, "contact_frame": 8,
		"damage": 6, "stamina_cost": 4,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_JAB,
		"knockback": &"low", "stagger": &"low",
	},
	{
		"id": RIGHT_JAB, "display_name": "Jab derecho", "family": FAMILY_LIGHT,
		"clip_frames": 11, "contact_frame": 5,
		"damage": 6, "stamina_cost": 4,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_JAB,
		"knockback": &"low", "stagger": &"low",
	},
	{
		"id": LEFT_HOOK, "display_name": "Gancho izquierdo", "family": FAMILY_LIGHT,
		"clip_frames": 16, "contact_frame": 8,
		"damage": 9, "stamina_cost": 7,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_HOOK,
		"knockback": &"medium", "stagger": &"low",
	},
	{
		"id": ELBOW, "display_name": "Codo", "family": FAMILY_LIGHT,
		"clip_frames": 23, "contact_frame": 6,
		"damage": 12, "stamina_cost": 10,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_HEAVY,
		"knockback": &"low", "stagger": &"high",
	},
	{
		"id": STRAIGHT, "display_name": "Cruzada", "family": FAMILY_HEAVY,
		"clip_frames": 25, "contact_frame": 16,
		"damage": 10, "stamina_cost": 8,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_HEAVY,
		"knockback": &"medium", "stagger": &"low",
	},
	{
		"id": RIGHT_HOOK, "display_name": "Gancho derecho", "family": FAMILY_HEAVY,
		"clip_frames": 14, "contact_frame": 6,
		"damage": 9, "stamina_cost": 7,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_HOOK,
		"knockback": &"medium", "stagger": &"low",
	},
	{
		"id": COMBO, "display_name": "Combo", "family": FAMILY_HEAVY,
		"clip_frames": 27, "contact_frame": 7,
		"damage": 13, "stamina_cost": 12,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_KICK,
		"knockback": &"medium", "stagger": &"medium",
	},
	{
		"id": FRONT_KICK, "display_name": "Patada frontal", "family": FAMILY_KICK,
		"clip_frames": 29, "contact_frame": 15,
		"damage": 11, "stamina_cost": 10,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_KICK,
		"knockback": &"medium", "stagger": &"low",
	},
	{
		"id": FRONT_KICK_2, "display_name": "Patada frontal 2", "family": FAMILY_KICK,
		"clip_frames": 25, "contact_frame": 14,
		"damage": 11, "stamina_cost": 10,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_KICK,
		"knockback": &"medium", "stagger": &"low",
	},
	{
		"id": HIGH_KICK, "display_name": "Patada alta", "family": FAMILY_KICK,
		"clip_frames": 33, "contact_frame": 16,
		"damage": 15, "stamina_cost": 14,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_KICK,
		"knockback": &"low", "stagger": &"high",
	},
	{
		"id": SIDE_KICK, "display_name": "Patada lateral", "family": FAMILY_KICK,
		"clip_frames": 20, "contact_frame": 9,
		"damage": 14, "stamina_cost": 13,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_KICK,
		"knockback": &"high", "stagger": &"low",
	},
	{
		"id": STOMP_KICK, "display_name": "Patada al suelo", "family": FAMILY_KICK,
		"clip_frames": 29, "contact_frame": 18,
		"damage": 16, "stamina_cost": 15,
		"movement_multiplier": GameConfig.ATTACK_MOVE_MULT_KICK,
		"knockback": &"low", "stagger": &"high",
	},
]

static var _attacks: Dictionary = {}
static var _order: Array[StringName] = []


static func _build() -> void:
	if not _attacks.is_empty():
		return
	for row: Dictionary in _DATA:
		var attack := AttackDefinition.new(row)
		_attacks[attack.id] = attack
		_order.append(attack.id)


## El ataque con ese id, o `null` si no existe.
static func of(id: StringName) -> AttackDefinition:
	_build()
	return _attacks.get(id, null)


## Todos los ataques del catálogo, en el orden de la sección 9.
static func all() -> Array[AttackDefinition]:
	_build()
	var result: Array[AttackDefinition] = []
	for id: StringName in _order:
		result.append(_attacks[id])
	return result


## Los doce ids del catálogo, para comparar con lo que la hoja trae.
static func ids() -> Array[StringName]:
	_build()
	return _order.duplicate()


## ¿Este ataque existe?
static func has(id: StringName) -> bool:
	return of(id) != null


## ¿Este id es la animación de algún ataque del catálogo?
static func has_animation(id: StringName) -> bool:
	var attack := of(id)
	return attack != null and attack.animation_id == id


## Familia a la que pertenece un ataque; `&""` si no está en el catálogo.
static func family_of(id: StringName) -> StringName:
	var attack := of(id)
	return attack.family if attack != null else &""


## Cadena de una familia, en orden. Vacía para una familia desconocida.
static func chain(family: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _CHAINS.get(family, []):
		ids.append(id)
	return ids


## Ataque que ocupa `index` en la cadena de `family`, envolviendo al final: si
## la cadena se acaba y el jugador sigue pulsando, la secuencia empieza de nuevo
## en el jab en vez de quedarse clavada en el último golpe (sección 23).
static func attack_at(family: StringName, index: int) -> AttackDefinition:
	var ids := chain(family)
	if ids.is_empty():
		return null
	return of(ids[posmod(index, ids.size())])


## Índice de un ataque dentro de su cadena; -1 si no está.
static func index_of(family: StringName, id: StringName) -> int:
	return chain(family).find(id)


## Daño bruto de un golpe: el arma manda y el ataque suma su diferencia
## respecto al jab de referencia (secciones 9 y 29).
##
## Así una piedra (daño de arma) pegando un jab sigue quitando lo de la piedra
## — que es lo que asumen todos los tests que ya existían — y la cruzada le
## añade los 4 puntos de la sección 29. Si el arma desaparece, no pega nada.
static func power_of(weapon: Weapon, attack: AttackDefinition) -> float:
	if weapon == null or attack == null:
		return 0.0
	var reference := of(LEFT_JAB)
	var bonus := 0.0
	if reference != null:
		bonus = maxf(0.0, attack.damage - reference.damage)
	return weapon.effective_damage + bonus


## Stamina total: lo que cuesta el arma más lo que cuesta el ataque por encima
## del jab de referencia (sección 20). El arma desnuda cuesta 2 y el jab cuesta
## 4, de modo que a puños el jugador paga lo del arma y nada más.
static func stamina_of(weapon: Weapon, attack: AttackDefinition) -> float:
	if weapon == null or attack == null:
		return 0.0
	var reference := of(LEFT_JAB)
	var extra := 0.0
	if reference != null:
		extra = maxf(0.0, attack.stamina_cost - reference.stamina_cost)
	return weapon.stamina_cost + extra
