extends RefCounted

## Pruebas del muñeco de entrenamiento (sección 33).
##
## El muñeco es un `Npc` pasivo: la sección 33 pide salud, hitbox de daño, visual,
## reacción al golpe, aturdimiento, retroceso y muerte, y todo eso lo dan los
## sistemas que ya existen (`Npc` + `NpcCombat`), no un sistema nuevo. Lo que sí
## es propio del muñeco es que no responde: el comportamiento pasivo y el hecho de
## que su cuerpo de combate reciba la cadena completa del golpe sin devolver nada.

const DELTA := 1.0 / 60.0


func register() -> Array:
	return [
		["el muñeco es un NPC pasivo con identidad propia", _dummy_is_a_passive_npc],
		["el comportamiento del muñeco sale de la configuración", _dummy_behavior_is_passive],
		["recibe golpes hasta morir y reaparece", _damage_death_and_respawn],
		["el golpe completo entra por su cuerpo de combate", _combat_receives_the_full_hit],
		["morir por el cuerpo de combate avisa a la reaparición", _death_via_combat_announces],
		["el cerebro pasivo nunca mueve ni ataca", _brain_keeps_it_idle],
	]


func _dummy() -> CombatDummy:
	var body := CombatDummy.new(7)
	body.home = Vector2(200.0, 224.0)
	body.position = body.home
	body.move_to(body.home, Vector2.DOWN)
	return body


func _dummy_is_a_passive_npc(ctx: ScriptTestContext) -> void:
	var body := _dummy()
	ctx.check(body is Npc, "es un NPC: usa el mismo sistema de estados y salud")
	ctx.check_equal(body.kind, CombatDummy.KIND, "con su propio identificador visual")
	ctx.check_equal(body.display_name, "MUÑECO", "con nombre propio")
	ctx.check(body.is_alive, "nace vivo")
	ctx.check_equal(body.health.maximum, GameConfig.DUMMY_HEALTH, "con la vida de la configuración")
	ctx.check_equal(body.stats.defense, GameConfig.DUMMY_DEFENSE, "y la defensa")
	ctx.check_equal(body.behavior.attack_damage, 0.0, "y sin ganas de pegar")


## El comportamiento pasivo es cero en todo lo que mueve o ataca, y los números que
## importan vienen de `GameConfig` (regla 5: nada de números mágicos).
func _dummy_behavior_is_passive(ctx: ScriptTestContext) -> void:
	var behavior := NpcBehavior.dummy()
	ctx.check_equal(behavior.max_health, GameConfig.DUMMY_HEALTH, "vida de la configuración")
	ctx.check_equal(behavior.defense, GameConfig.DUMMY_DEFENSE, "defensa también")
	ctx.check_equal(behavior.attack_damage, 0.0, "no pega")
	ctx.check_equal(behavior.attack_range, 0.0, "su golpe no alcanza nada")
	ctx.check_equal(behavior.move_speed, 0.0, "no se mueve")
	ctx.check_equal(behavior.aggro_radius, 0.0, "no detecta al jugador")
	ctx.check_equal(behavior.leash_radius, 0.0, "nada que atar")
	ctx.check_equal(behavior.wander_radius, 0.0, "no pasea")
	ctx.check_equal(behavior.flee_health_ratio, 0.0, "y no huye jamás")


func _damage_death_and_respawn(ctx: ScriptTestContext) -> void:
	var body := _dummy()
	var died := [false]
	body.died.connect(func() -> void: died[0] = true)

	ctx.check_equal(body.take_damage(10.0), 10.0, "quita la vida pedida")
	ctx.check(body.is_alive, "sigue vivo")
	body.take_damage(body.health.maximum)
	ctx.check(body.is_dead, "con la vida a cero muere")
	ctx.check(died[0], "y avisa de la muerte")
	ctx.check_equal(body.take_damage(5.0), 0.0, "muerto ya no recibe más")

	body.respawn_at(Vector2(200.0, 224.0))
	ctx.check(body.is_alive, "reaparece vivo")
	ctx.check_equal(body.health.current, body.health.maximum, "con la vida llena")
	ctx.check_equal(body.state, NpcState.Kind.IDLE, "y en reposo")


## La sección 33 pide reacción, aturdimiento y retroceso; aquí se comprueba la
## cadena entera entrando por el cuerpo de combate, que es la única entrada legal:
## misma ley que el enemigo, misma que el jugador.
func _combat_receives_the_full_hit(ctx: ScriptTestContext) -> void:
	var body := _dummy()
	var combat := NpcCombat.new(body)
	var hit_tiers: Array[StringName] = []
	var stuns: Array[bool] = []
	combat.impact_struck.connect(func(tier: StringName) -> void: hit_tiers.append(tier))
	combat.stun_changed.connect(func(active: bool) -> void: stuns.append(active))

	var dealt := combat.take_attack(
		AttackCatalog.of(AttackCatalog.LEFT_JAB), 12.0, Vector2.UP
	)
	ctx.check(dealt > 0.0, "el golpe entra (12 de daño ya calculado, defensa cero)")
	ctx.check_equal(body.health.current, body.health.maximum - dealt, "y la vida baja")
	ctx.check(combat.is_invulnerable, "concede la ventana de invulnerabilidad")
	ctx.check(combat.is_stunned, "y aturde (el golpe manda sobre todo)")
	ctx.check_equal(stuns, [true], "la señal de aturdimiento avisa de que sube")
	ctx.check(
		CombatReaction.plan(null, dealt)["clip"] != &"",
		"la reacción tiene clip (es lo que la vista reproduce)"
	)
	ctx.check(
		combat.external_velocity != Vector2.ZERO,
		"y el retroceso empuja (es lo que mueve el cuerpo en pantalla)"
	)
	ctx.check(
		hit_tiers == [CombatReaction.knockback_of(null, dealt)],
		"y el impacto avisa con su tier (es lo que hace temblar la cámara)"
	)


## Morir con un golpe que entra por el cuerpo de combate avisa (`died`): es lo
## que oye el generador del muñeco para contar la reaparición, y el presentador
## para apagar el cuerpo. Estuvo roto en silencio —la señal estaba declarada pero
## nadie la emitía, y las suites seguían verdes porque la vista se entera por
## `_sync_state`— y a nadie le faltaba nada salvo al muñeco, que no reaparecía.
func _death_via_combat_announces(ctx: ScriptTestContext) -> void:
	var body := _dummy()
	var combat := NpcCombat.new(body)
	var deaths := [0]
	var reactions := [0]
	combat.died.connect(func() -> void: deaths[0] += 1)
	combat.reaction_started.connect(
		func(_clip: StringName, _duration: float) -> void: reactions[0] += 1
	)

	var dealt := combat.take_attack(
		AttackCatalog.of(AttackCatalog.LEFT_HOOK), 999.0, Vector2.DOWN
	)
	ctx.check(dealt > 0.0, "el golpe entra")
	ctx.check(body.is_dead, "y mata al muñeco")
	ctx.check_equal(deaths[0], 1, "el combate avisa de la muerte (lo oye la reaparición)")
	ctx.check_equal(
		reactions[0], 0, "y un muerto no reacciona: la muerte no es un trance"
	)

	var again := combat.take_attack(
		AttackCatalog.of(AttackCatalog.LEFT_HOOK), 5.0, Vector2.DOWN
	)
	ctx.check_equal(again, 0.0, "el muerto no vuelve a recibir")
	ctx.check_equal(deaths[0], 1, "ni a avisar dos veces")


## El muñeco no tiene IA: aunque alguien le reparta un objetivo (cosa que aquí
## nadie hace, pero por si acaso), el cerebro se queda en reposo y la intención es
## cero. Es la diferencia entre "muñeco" y "enemigo".
func _brain_keeps_it_idle(ctx: ScriptTestContext) -> void:
	var body := _dummy()
	var brain := NpcBrain.new(body)
	brain.advance(DELTA)
	ctx.check_equal(body.state, NpcState.Kind.IDLE, "sin objetivo se queda en reposo")
	ctx.check_equal(brain.intent(), Vector2.ZERO, "y no se mueve")

	brain.set_target(Vector2(200.0, 224.0) + Vector2(0.0, 60.0))
	brain.advance(DELTA)
	ctx.check_equal(body.state, NpcState.Kind.IDLE, "con objetivo tampoco persigue")
	ctx.check_equal(brain.intent(), Vector2.ZERO, "y sigue sin moverse")