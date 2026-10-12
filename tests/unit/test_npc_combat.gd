extends RefCounted

## Pruebas del caso de uso de combate de un NPC (secciones 9, 10 y 18).
##
## La ley del juego: todo ser que recibe daño se tiñe de rojo mientras dura su
## invulnerabilidad. Eso solo funciona si el daño entra por el cuerpo de combate
## (`NpcCombat.take_damage`) y no por el `Npc` pelado, igual que al jugador le
## entra por `MeleeCombat.take_damage`. Aquí se prueba que el cuerpo de combate del
## NPC es un objetivo válido para `DamageRules` y que `take_damage` concede la
## ventana en vez de saltársela.

const DELTA := 1.0 / 60.0


## Objetivo de mentira para los golpes del NPC, con la misma piel que el de
## `test_melee_combat`: vida y defensa, solo `take_damage`.
class Dummy extends RefCounted:
	var stats: CharacterStats
	var health: Health
	var is_dead: bool = false

	func _init(health_value: float = 40.0, defense: float = 0.0) -> void:
		stats = CharacterStats.new({"defense": defense})
		health = Health.new(health_value)

	func take_damage(amount: float) -> float:
		return health.apply_damage(amount)


func _combat() -> NpcCombat:
	return NpcCombat.new(Npc.new(1, "Slime", NpcBehavior.new()))


## Deja la ventana de impacto del NPC abierta, avanzando el reloj a mano.
func _open_window(combat: NpcCombat) -> void:
	var guard := 0
	while not combat.is_window_open and combat.is_attacking and guard < 300:
		combat.advance(DELTA)
		guard += 1


func register() -> Array:
	return [
		["el golpe del jugador entra por take_damage y da invulnerabilidad", _take_damage_grants_invulnerability],
		["take_damage respeta la ventana de invulnerabilidad", _take_damage_respects_invulnerability],
		["el cuerpo de combate es un objetivo válido para DamageRules", _combat_body_is_damageable],
		["un cuerpo de combate muerto ya no es objetivo", _dead_combat_body_ignored],
		["la señal de aturdimiento sube y baja", _stun_signal_sube_y_baja],
		["el golpe del NPC que entra emite el impacto con su tier", _strike_announces_the_impact],
		["recibir daño emite el impacto deducido del daño", _receiving_damage_announces_impact],
		["un golpe a un invulnerable no emite impacto", _silent_hits_emit_nothing],
	]


## El golpe del jugador llama a `take_damage` sobre lo que la vista expone como
## objetivo. Si además de quitar vida no concede invulnerabilidad ni avisa, el tinte
## rojo no sale en pantalla: es el fallo que este caso existe para no repetir.
func _take_damage_grants_invulnerability(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var entered_invulnerability := [false]
	combat.invulnerability_changed.connect(
		func(active: bool) -> void: entered_invulnerability[0] = active
	)

	ctx.check_equal(combat.take_damage(3.0), 3.0, "el golpe quita la vida pedida")
	ctx.check(combat.is_invulnerable, "y concede invulnerabilidad")
	ctx.check(
		entered_invulnerability[0], "la señal avisa (es lo que pinta el rojo en la vista)"
	)
	ctx.check_equal(combat.take_damage(3.0), 0.0, "el segundo golpe inmediato no entra")


func _take_damage_respects_invulnerability(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	ctx.check(combat.take_damage(3.0) > 0.0, "el primer golpe entra")
	ctx.check_equal(
		combat.take_damage(3.0), 0.0, "mientras dura la ventana, el segundo no entra"
	)
	combat.advance(combat.npc.behavior.invulnerability_time + DELTA)
	ctx.check(combat.take_damage(3.0) > 0.0, "pasada la ventana, vuelve a entrar")


## La vista expone el cuerpo de combate, no el `Npc`: `DamageRules` tiene que
## aceptarlo como objetivo y leer su defensa por `stats`, igual que hace con el
## cuerpo de combate del jugador.
func _combat_body_is_damageable(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	ctx.check(DamageRules.is_damageable(combat), "el cuerpo de combate es objetivo")
	ctx.check_equal(
		DamageRules.defense_of(combat),
		combat.npc.behavior.defense,
		"y su defensa se lee por la propiedad stats"
	)


## `DamageRules.is_damageable` lee `is_dead`: un cuerpo de combate de un enemigo
## muerto no cuenta como objetivo y tampoco recibe daño.
func _dead_combat_body_ignored(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	combat.npc.take_damage(combat.npc.health.maximum)
	ctx.check(combat.npc.is_dead, "el enemigo parte muerto")
	ctx.check(not DamageRules.is_damageable(combat), "un cuerpo de combate muerto no es objetivo")
	ctx.check_equal(combat.take_damage(5.0), 0.0, "y tampoco recibe daño")


## La señal es lo que pinta el tinte violeta en la vista del NPC: sube al aturdir
## y baja al expirar, igual que en `MeleeCombat`.
func _stun_signal_sube_y_baja(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var changes: Array[bool] = []
	combat.stun_changed.connect(func(active: bool) -> void: changes.append(active))

	combat.take_damage(3.0)
	ctx.check_equal(changes, [true], "al aturdir avisa de que sube")
	ctx.check(combat.is_stunned, "y el reloj lo confirma")

	combat.advance(combat.npc.behavior.hurt_stun_time + DELTA)
	ctx.check_equal(changes, [true, false], "al expirar avisa de que baja")
	ctx.check(not combat.is_stunned, "y ya no está aturdido")


## La señal de impacto del NPC es la gemela de la del jugador: sale al golpear,
## con el tier deducido del daño que hace (los NPC no llevan catálogo de ataques,
## igual que deducen el de los golpes que reciben).
func _strike_announces_the_impact(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var tiers: Array[StringName] = []
	combat.impact_struck.connect(func(tier: StringName) -> void: tiers.append(tier))

	ctx.check(combat.try_attack(Vector2.RIGHT), "el golpe del NPC sale")
	_open_window(combat)
	ctx.check_equal(combat.strike([Dummy.new()]), 1, "y entra en el muñeco")
	ctx.check_equal(
		tiers,
		[CombatReaction.TIER_LOW],
		"con el tier del daño que hace (4 < 8 -> low)"
	)


## Recibir daño también avisa, igual que en `MeleeCombat`.
func _receiving_damage_announces_impact(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var tiers: Array[StringName] = []
	combat.impact_struck.connect(func(tier: StringName) -> void: tiers.append(tier))

	ctx.check_equal(combat.take_damage(10.0), 10.0, "el golpe entra")
	ctx.check_equal(tiers, [CombatReaction.TIER_MEDIUM], "deducido del daño (10 -> medium)")


## Invulnerable no se emite: el golpe no entró y no hay nada que congelar. La
## señal se cuenta, no solo se comprueba su valor, porque un falso aviso temblaría
## sin golpe.
func _silent_hits_emit_nothing(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var tiers: Array[StringName] = []
	combat.impact_struck.connect(func(tier: StringName) -> void: tiers.append(tier))

	ctx.check_equal(combat.take_damage(5.0), 5.0, "el primer golpe entra")
	ctx.check_equal(tiers.size(), 1, "y avisa una vez")
	ctx.check_equal(combat.take_damage(5.0), 0.0, "el segundo cae en la invulnerabilidad")
	ctx.check_equal(tiers.size(), 1, "y no vuelve a avisar")