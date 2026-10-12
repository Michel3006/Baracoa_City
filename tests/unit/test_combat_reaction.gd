extends RefCounted

## Pruebas del sistema de reacciones al golpe (secciones 25-27 y 19).
##
## Todo aquí es dominio puro: `CombatReaction` traduce un ataque (o un daño suelto)
## a clip, tiempo, empuje y multiplicador de marcha, y `CombatResult` pone nombre a
## lo que le ha pasado al golpe. No hay nodos ni relojes, así que el resultado no
## depende de la escena.

const FPS := GameConfig.ATTACK_COMBAT_FPS


func register() -> Array:
	return [
		["cada reacción tiene su clip y su tiempo", _reactions_have_clip_and_time],
		["los tiers cambian aturdimiento, marcha y empuje", _tiers_change_stagger_and_push],
		["sin ataque el trance sale del daño", _reaction_follows_damage_without_attack],
		["el plan reúne clip, tiempo, empuje y marcha", _plan_gathers_everything],
		["el empuje sale del que pega al que recibe", _push_goes_from_attacker_to_target],
		["de frente se para con la guardia", _front_hits_can_be_blocked],
		["los resultados del combate tienen nombre", _results_have_names],
	]


## Los tres clips del pack están asignados y su tiempo es el de su hoja medida a
## `ATTACK_COMBAT_FPS`: son 12, 21 y 18 fotogramas (ver `HormelzVisualData`). Si
## alguien cambia un fotograma ahí, este caso lo dice.
func _reactions_have_clip_and_time(ctx: ScriptTestContext) -> void:
	ctx.check_equal(
		CombatReaction.clip_of(CombatReaction.REACTION_LIGHT), &"hit_light", "clip de la ligera"
	)
	ctx.check_equal(
		CombatReaction.clip_of(CombatReaction.REACTION_BODY), &"hit_body", "clip de la corporal"
	)
	ctx.check_equal(
		CombatReaction.clip_of(CombatReaction.REACTION_HEAD), &"hit_head", "clip de la de cabeza"
	)
	ctx.check_almost_equal(
		CombatReaction.time_of(CombatReaction.REACTION_LIGHT), 12.0 / FPS, "la ligera dura 12 fotogramas"
	)
	ctx.check_almost_equal(
		CombatReaction.time_of(CombatReaction.REACTION_BODY), 21.0 / FPS, "la corporal dura 21"
	)
	ctx.check_almost_equal(
		CombatReaction.time_of(CombatReaction.REACTION_HEAD), 18.0 / FPS, "la de cabeza dura 18"
	)
	ctx.check_equal(CombatReaction.clip_of(&"no_existe"), &"", "una reacción desconocida no tiene clip")


## La sección 29 reparte tiers, y cada tier cambia tres cosas: si el trance es
## aturdimiento de verdad, cuánto deja andar y con cuánta fuerza empuja. El bajo no
## es un stagger: es un tambaleo del que se sale andando.
func _tiers_change_stagger_and_push(ctx: ScriptTestContext) -> void:
	ctx.check(not CombatReaction.is_stagger(CombatReaction.TIER_LOW), "el tier bajo no aturde")
	ctx.check(CombatReaction.is_stagger(CombatReaction.TIER_MEDIUM), "el medio sí")
	ctx.check(CombatReaction.is_stagger(CombatReaction.TIER_HIGH), "y el alto también")

	ctx.check_almost_equal(
		CombatReaction.stagger_extra(CombatReaction.TIER_LOW), 0.0, "el bajo no añade tiempo"
	)
	ctx.check_almost_equal(
		CombatReaction.stagger_extra(CombatReaction.TIER_MEDIUM),
		GameConfig.STAGGER_EXTRA_MEDIUM,
		"el medio añade su sobretiempo"
	)
	ctx.check_almost_equal(
		CombatReaction.stagger_extra(CombatReaction.TIER_HIGH),
		GameConfig.STAGGER_EXTRA_HIGH,
		"y el alto el suyo"
	)

	ctx.check_almost_equal(
		CombatReaction.movement_multiplier(CombatReaction.TIER_LOW),
		GameConfig.REACTION_MOVE_MULT,
		"tambaleando todavía se camina algo"
	)
	ctx.check(
		CombatReaction.movement_multiplier(CombatReaction.TIER_HIGH)
		< CombatReaction.movement_multiplier(CombatReaction.TIER_MEDIUM),
		"y cuanto más duro el golpe, menos se anda"
	)

	ctx.check(
		CombatReaction.force_of(CombatReaction.TIER_LOW)
		< CombatReaction.force_of(CombatReaction.TIER_MEDIUM),
		"el empuje bajo es menor que el medio"
	)
	ctx.check(
		CombatReaction.force_of(CombatReaction.TIER_MEDIUM)
		< CombatReaction.force_of(CombatReaction.TIER_HIGH),
		"y el medio menor que el alto"
	)


## Los NPC no llevan catálogo de ataques: su golpe entra sin `AttackDefinition`, y
## aun así el defensor tiene que reaccionar de forma legible. El trance se deduce
## del daño, con los umbrales de `GameConfig`.
func _reaction_follows_damage_without_attack(ctx: ScriptTestContext) -> void:
	ctx.check_equal(
		CombatReaction.reaction_of(null, GameConfig.REACTION_DAMAGE_MEDIUM - 1.0),
		CombatReaction.REACTION_LIGHT,
		"un golpe flojo tambalea"
	)
	ctx.check_equal(
		CombatReaction.reaction_of(null, GameConfig.REACTION_DAMAGE_MEDIUM),
		CombatReaction.REACTION_BODY,
		"uno medio dobla el cuerpo"
	)
	ctx.check_equal(
		CombatReaction.reaction_of(null, GameConfig.REACTION_DAMAGE_HIGH),
		CombatReaction.REACTION_HEAD,
		"y uno fuerte va a la cabeza"
	)

	ctx.check_equal(
		CombatReaction.stagger_of(null, GameConfig.REACTION_DAMAGE_HIGH),
		CombatReaction.TIER_HIGH,
		"el daño alto aturde de verdad"
	)
	ctx.check_equal(
		CombatReaction.stagger_of(null, GameConfig.REACTION_DAMAGE_MEDIUM),
		CombatReaction.TIER_LOW,
		"y el medio, con un cuerpo sin tiers propios, todavía no"
	)
	ctx.check_equal(
		CombatReaction.knockback_of(null, GameConfig.REACTION_DAMAGE_MEDIUM),
		CombatReaction.TIER_MEDIUM,
		"el empuje sí sube con el daño medio"
	)


## El ataque manda: si trae reacción y tiers, el daño no los pisa. Es lo que
## permite que un jab (poco daño) y una patada lateral (mucho) empujen distinto
## aunque los dos quiten vida parecida.
func _plan_gathers_everything(ctx: ScriptTestContext) -> void:
	var jab := AttackCatalog.of(AttackCatalog.LEFT_JAB)
	var plan := CombatReaction.plan(jab, 6.0)

	ctx.check_equal(plan["reaction"], CombatReaction.REACTION_LIGHT, "el jab usa la reacción ligera")
	ctx.check_equal(plan["clip"], &"hit_light", "y su clip")
	ctx.check_almost_equal(plan["time"], 12.0 / FPS, "sin sobretiempo: el tier es bajo")
	ctx.check(not bool(plan["stagger"]), "el jab no aturde")
	ctx.check_equal(plan["knockback"], CombatReaction.TIER_LOW, "y empuja poco")
	ctx.check_almost_equal(
		plan["force"], GameConfig.KNOCKBACK_FORCE_LOW, "con la fuerza del tier bajo"
	)

	var high_kick := AttackCatalog.of(AttackCatalog.HIGH_KICK)
	var heavy := CombatReaction.plan(high_kick, 15.0)
	ctx.check_equal(heavy["reaction"], CombatReaction.REACTION_HEAD, "la patada alta va a la cabeza")
	ctx.check(bool(heavy["stagger"]), "y aturde")
	ctx.check_almost_equal(
		heavy["time"],
		18.0 / FPS + GameConfig.STAGGER_EXTRA_HIGH,
		"el trance dura su clip más el sobretiempo del stagger"
	)
	ctx.check_almost_equal(
		heavy["movement_multiplier"],
		GameConfig.STAGGER_MOVE_MULT_HIGH,
		"y deja al defensor sin moverse"
	)

	# El empuje es del ataque, no del daño: la lateral empuja fuerte (sección 29)
	# aunque la alta, que quita más vida, empuje flojo.
	var side_kick := AttackCatalog.of(AttackCatalog.SIDE_KICK)
	var push := CombatReaction.plan(side_kick, 14.0)
	ctx.check_equal(push["knockback"], CombatReaction.TIER_HIGH, "la lateral empuja alto")
	ctx.check_almost_equal(
		push["force"], GameConfig.KNOCKBACK_FORCE_HIGH, "con la fuerza de la sección 29"
	)
	ctx.check(
		float(push["force"]) > float(plan["force"]),
		"y más que el jab, que empuja flojo"
	)


## El empuje nace del atacante y va hacia el defensor: es lo que hace que un golpe
## desde la izquierda desplace hacia la derecha. A bocajarro (mismo píxel) no hay
## dirección que sacar, y se usa la mirada del atacante como respaldo.
func _push_goes_from_attacker_to_target(ctx: ScriptTestContext) -> void:
	ctx.check_equal(
		CombatReaction.impact_direction(Vector2.ZERO, Vector2.RIGHT * 10.0, Vector2.DOWN),
		Vector2.RIGHT,
		"si el objetivo está a la derecha, empuja a la derecha"
	)
	ctx.check_equal(
		CombatReaction.impact_direction(Vector2(5.0, 5.0), Vector2(5.0, 5.0), Vector2.UP),
		Vector2.UP,
		"a bocajarro manda la mirada del atacante"
	)
	ctx.check_equal(
		CombatReaction.impact_direction(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO),
		Vector2.DOWN,
		"y sin mirada, hacia abajo"
	)


## La guardia solo para lo que viene de frente: `impact` es la dirección del empuje
## y `facing` la del defensor, así que de frente van en sentidos opuestos. Un golpe
## por la espalda entra siempre.
func _front_hits_can_be_blocked(ctx: ScriptTestContext) -> void:
	ctx.check(
		CombatReaction.is_from_front(Vector2.UP, Vector2.DOWN),
		"si me miran y me empujan al revés de mi mirada, es de frente"
	)
	ctx.check(
		not CombatReaction.is_from_front(Vector2.DOWN, Vector2.DOWN),
		"un golpe por la espalda no es de frente"
	)
	ctx.check(
		not CombatReaction.is_from_front(Vector2.RIGHT, Vector2.ZERO),
		"sin mirada no se para nada"
	)


## El vocabulario de la sección 19 tiene nombre legible y no se inventa valores:
## los cuatro resultados que se emiten como señal existen, y lo desconocido no
## revienta.
func _results_have_names(ctx: ScriptTestContext) -> void:
	ctx.check_equal(CombatResult.name_of(CombatResult.MISS), "MISS", "el fallo se llama MISS")
	ctx.check_equal(CombatResult.name_of(CombatResult.HIT), "HIT", "el impacto, HIT")
	ctx.check_equal(CombatResult.name_of(CombatResult.BLOCKED), "BLOCKED", "la guardia, BLOCKED")
	ctx.check_equal(CombatResult.name_of(CombatResult.DODGED), "DODGED", "la rodada, DODGED")
	ctx.check_equal(
		CombatResult.name_of(CombatResult.INTERRUPTED), "INTERRUPTED", "la interrupción, INTERRUPTED"
	)
	ctx.check_equal(CombatResult.name_of(&"otra_cosa"), "UNKNOWN", "lo desconocido es UNKNOWN")
