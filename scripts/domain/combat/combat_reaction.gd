class_name CombatReaction
extends RefCounted

## Reacción de un ser al recibir un golpe (secciones 25-27).
##
## Decide tres cosas a partir del ataque que le ha entrado, sin saber de nodos ni
## de física: qué clip reproduce (`hit_light`, `hit_body` o `hit_head`), cuánto
## dura el trance y con qué fuerza lo empujan. Los tiempos **no se inventan**: son
## los de la hoja de cada clip (`REACTION_*_TIME` en `GameConfig`, medidos a
## `ATTACK_COMBAT_FPS`), de modo que la reacción dura lo que dura su animación,
## igual que las fases de un ataque duran lo que dura su clip.
##
## Los tiers (`low`, `medium`, `high`) son los de la sección 29 y viven en
## `AttackDefinition`. Aquí se traducen a píxeles por segundo y a segundos, para
## que el reparto sea dato y no números sueltos en la máquina de estados.
##
## Un ataque nulo (o un objetivo del montón que solo sabe `take_damage`) cae a unos
## tiers deducidos del daño recibido: un golpe flojo tambalea y uno fuerte tira.
## Así un cuerpo sin catálogo sigue reaccionando de forma legible.
##
## Es `RefCounted` puro: sin `Node`, sin `Input`, sin escenas.
##
## Dependencias: domain, infrastructure/configuration (solo constantes)

## Tiers de la sección 29.
const TIER_LOW := &"low"
const TIER_MEDIUM := &"medium"
const TIER_HIGH := &"high"

## Reacciones de la sección 25, mapeadas a los tres clips de golpe del pack.
const REACTION_LIGHT := &"light"
const REACTION_BODY := &"body"
const REACTION_HEAD := &"head"

const _CLIPS := {
	REACTION_LIGHT: &"hit_light",
	REACTION_BODY: &"hit_body",
	REACTION_HEAD: &"hit_head",
}

const _TIMES := {
	REACTION_LIGHT: GameConfig.REACTION_LIGHT_TIME,
	REACTION_BODY: GameConfig.REACTION_BODY_TIME,
	REACTION_HEAD: GameConfig.REACTION_HEAD_TIME,
}


## Clip de un tipo de reacción; `&""` si el tipo no existe.
static func clip_of(reaction: StringName) -> StringName:
	return _CLIPS.get(reaction, &"")


## Duración del trance sin contar el sobretiempo de stagger: lo que dura el clip.
static func time_of(reaction: StringName) -> float:
	return _TIMES.get(reaction, GameConfig.REACTION_LIGHT_TIME)


## ¿Este ataque deja al defensor en `STAGGERED` (sección 26) en vez de en una
## reacción corta? El stagger medio y alto limitan el movimiento y el ataque; el
## bajo solo tambalea.
static func is_stagger(tier: StringName) -> bool:
	return tier == TIER_MEDIUM or tier == TIER_HIGH


## Sobretiempo que se suma al del clip cuando el ataque aturde de verdad.
static func stagger_extra(tier: StringName) -> float:
	if tier == TIER_HIGH:
		return GameConfig.STAGGER_EXTRA_HIGH
	if tier == TIER_MEDIUM:
		return GameConfig.STAGGER_EXTRA_MEDIUM
	return 0.0


## Cuánto deja moverse al defensor mientras dura la reacción (sección 26).
static func movement_multiplier(tier: StringName) -> float:
	if tier == TIER_HIGH:
		return GameConfig.STAGGER_MOVE_MULT_HIGH
	if tier == TIER_MEDIUM:
		return GameConfig.STAGGER_MOVE_MULT_MEDIUM
	return GameConfig.REACTION_MOVE_MULT


## Fuerza del empuje de un tier de knockback (sección 27), en píxeles por segundo.
static func force_of(tier: StringName) -> float:
	match tier:
		TIER_HIGH:
			return GameConfig.KNOCKBACK_FORCE_HIGH
		TIER_MEDIUM:
			return GameConfig.KNOCKBACK_FORCE_MEDIUM
		_:
			return GameConfig.KNOCKBACK_FORCE_LOW


## Plan completo de una reacción: qué clip, cuánto dura, si es stagger, cuánto
## deja moverse y con qué fuerza empuja.
##
## Devuelve un `Dictionary` y no una clase nueva porque vive lo que dura el golpe:
## el defensor lo copia a sus campos y lo tira.
static func plan(attack: AttackDefinition, damage: float) -> Dictionary:
	var reaction := reaction_of(attack, damage)
	var stagger := stagger_of(attack, damage)
	var knockback := knockback_of(attack, damage)
	var time := time_of(reaction) + stagger_extra(stagger)
	return {
		"reaction": reaction,
		"clip": clip_of(reaction),
		"time": time,
		"stagger": is_stagger(stagger),
		"stagger_tier": stagger,
		"knockback": knockback,
		"movement_multiplier": movement_multiplier(stagger),
		"force": force_of(knockback),
	}


## Tipo de reacción del ataque (sección 25), o deducido del daño si no hay ataque.
static func reaction_of(attack: AttackDefinition, damage: float) -> StringName:
	if attack != null and _CLIPS.has(attack.hit_reaction):
		return attack.hit_reaction
	if damage >= GameConfig.REACTION_DAMAGE_HIGH:
		return REACTION_HEAD
	if damage >= GameConfig.REACTION_DAMAGE_MEDIUM:
		return REACTION_BODY
	return REACTION_LIGHT


## Tier de stagger del ataque, o deducido del daño si no hay ataque.
static func stagger_of(attack: AttackDefinition, damage: float) -> StringName:
	if attack != null and _is_tier(attack.stagger):
		return attack.stagger
	return TIER_HIGH if damage >= GameConfig.REACTION_DAMAGE_HIGH else TIER_LOW


## Tier de knockback del ataque, o deducido del daño si no hay ataque.
static func knockback_of(attack: AttackDefinition, damage: float) -> StringName:
	if attack != null and _is_tier(attack.knockback):
		return attack.knockback
	if damage >= GameConfig.REACTION_DAMAGE_HIGH:
		return TIER_HIGH
	if damage >= GameConfig.REACTION_DAMAGE_MEDIUM:
		return TIER_MEDIUM
	return TIER_LOW


## Dirección en la que sale empujado el defensor: del atacante hacia él.
##
## Si las dos posiciones coinciden (golpe a bocajarro en el mismo píxel) no hay
## dirección que sacar del hueso, así que se usa la de la mirada del atacante.
static func impact_direction(
	from_position: Vector2, to_position: Vector2, fallback: Vector2
) -> Vector2:
	var offset := to_position - from_position
	if offset.length_squared() < 0.0001:
		if fallback.is_zero_approx():
			return Vector2.DOWN
		return fallback.normalized()
	return offset.normalized()


## ¿El golpe viene de delante? `impact` es la dirección del empuje (atacante ->
## defensor) y `facing` la del defensor. De frente, la mirada y el empuje van en
## sentidos opuestos.
static func is_from_front(impact: Vector2, facing: Vector2) -> bool:
	if facing.is_zero_approx():
		return false
	return impact.dot(facing.normalized()) < 0.0


static func _is_tier(tier: StringName) -> bool:
	return tier == TIER_LOW or tier == TIER_MEDIUM or tier == TIER_HIGH
