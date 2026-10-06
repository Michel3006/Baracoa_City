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


func _combat() -> NpcCombat:
	return NpcCombat.new(Npc.new(1, "Slime", NpcBehavior.new()))


func register() -> Array:
	return [
		["el golpe del jugador entra por take_damage y da invulnerabilidad", _take_damage_grants_invulnerability],
		["take_damage respeta la ventana de invulnerabilidad", _take_damage_respects_invulnerability],
		["el cuerpo de combate es un objetivo válido para DamageRules", _combat_body_is_damageable],
		["un cuerpo de combate muerto ya no es objetivo", _dead_combat_body_ignored],
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