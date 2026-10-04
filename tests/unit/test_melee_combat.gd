extends RefCounted

## Pruebas del caso de uso de combate cuerpo a cuerpo (secciones 4.2, 9 y 10).
##
## Todo aquí va con `advance(delta)` a mano: no hay escena ni reloj, así que el
## resultado no depende de la tasa de fotogramas.

const DELTA := 1.0 / 60.0

## Objetivo de mentira con defensa y vida, para probar el golpe.
class Dummy extends RefCounted:
	var stats: CharacterStats
	var health: Health
	var is_dead: bool = false

	func _init(health: float = 30.0, defense: float = 0.0) -> void:
		stats = CharacterStats.new({"defense": defense})
		self.health = Health.new(health)

	func take_damage(amount: float) -> float:
		return health.apply_damage(amount)


func _combat(weapon_id: StringName = WeaponCatalog.STONE) -> MeleeCombat:
	return MeleeCombat.new(Player.new(1, "Jugador"), WeaponCatalog.create(weapon_id))


func register() -> Array:
	return [
		["un golpe entra en ATTACKING y paga stamina", _attack_enters_state],
		["el cooldown impide repetir", _cooldown_blocks],
		["la ventana de hitbox se cierra antes que el estado", _window_closes_first],
		["el golpe usa la fórmula del daño", _strike_uses_formula],
		["sin ventana abierta no hay golpe", _no_window_no_strike],
		["la stamina se recupera tras el retraso", _stamina_regen],
		["sin stamina no se ataca", _no_stamina_no_attack],
		["recibir daño aturde y da invulnerabilidad", _hurt_stuns],
		["la invulnerabilidad expira", _invulnerability_expires],
		["mientras es invulnerable no recibe daño", _invulnerable_blocks],
		["un objetivo muerto no recibe golpe", _dead_target_ignored],
		["un arma rota no permite atacar", _broken_weapon_blocks],
		["cambiar de arma cambia el alcance", _equip_changes_range],
		["un golpe tras cooldown vuelve a entrar", _recovers_after_cooldown],
	]


func _attack_enters_state(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var player := combat.player
	var opened: Array[float] = []
	combat.attack_started.connect(func(_w: Weapon, _d: Vector2, window: float) -> void: opened.append(window))

	ctx.check(combat.try_attack(Vector2.UP), "el primer golpe debe salir")
	ctx.check_equal(player.state, PlayerState.Kind.ATTACKING, "estado tras atacar")
	ctx.check_equal(player.direction, Vector2.UP, "dirección del golpe")
	ctx.check_equal(
		player.stamina,
		GameConfig.PLAYER_MAX_STAMINA - GameConfig.WEAPON_STONE_STAMINA,
		"stamina gastada"
	)
	ctx.check_equal(opened.size(), 1, "se abre una ventana")
	ctx.check(
		opened[0] > 0.0 and opened[0] < GameConfig.WEAPON_STONE_COOLDOWN,
		"la ventana es una fracción del cooldown, no el cooldown entero"
	)


func _cooldown_blocks(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var reasons: Array[StringName] = []
	combat.attack_rejected.connect(func(reason: StringName) -> void: reasons.append(reason))

	ctx.check(combat.try_attack(), "primer golpe")
	combat.advance(GameConfig.ATTACK_RECOVERY + DELTA)
	ctx.check(not combat.try_attack(), "el segundo golpe no puede salir")
	ctx.check_equal(reasons[0], MeleeCombat.REASON_COOLDOWN, "motivo del rechazo")
	ctx.check(combat.cooldown_ratio > 0.0, "el cooldown está en curso")


func _window_closes_first(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var events: Array[String] = []
	combat.attack_window_closed.connect(func() -> void: events.append("ventana"))
	combat.attack_finished.connect(func() -> void: events.append("golpe"))

	combat.try_attack()
	# La ventana dura una fracción del cooldown y el estado dura la recuperación:
	# hay que pasar el mayor de los dos para ver el cierre de la ventana primero.
	combat.advance(maxf(GameConfig.ATTACK_RECOVERY, GameConfig.WEAPON_STONE_COOLDOWN) + DELTA)

	ctx.check_equal(events, ["ventana", "golpe"], "la hitbox se apaga antes de terminar el golpe")
	ctx.check(not combat.is_window_open, "ventana cerrada")
	ctx.check_equal(combat.player.state, PlayerState.Kind.IDLE, "vuelve a IDLE")


func _strike_uses_formula(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var target := Dummy.new(30.0, 2.0)
	var hits: Array[float] = []
	combat.target_hit.connect(func(_t: Object, damage: float) -> void: hits.append(damage))

	combat.try_attack()
	var count := combat.strike([target])

	ctx.check_equal(count, 1, "un objetivo golpeado")
	ctx.check_equal(
		hits[0], GameConfig.WEAPON_STONE_DAMAGE - 2.0, "daño tras la defensa"
	)
	ctx.check_equal(target.health.current, 30.0 - (GameConfig.WEAPON_STONE_DAMAGE - 2.0), "vida restante")


func _no_window_no_strike(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var target := Dummy.new()
	combat.try_attack()
	combat.advance(GameConfig.WEAPON_STONE_COOLDOWN + GameConfig.ATTACK_RECOVERY)
	ctx.check_equal(combat.strike([target]), 0, "fuera de la ventana no se golpea")
	ctx.check_equal(target.health.current, 30.0, "el objetivo no pierde vida")


func _stamina_regen(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	combat.try_attack()
	var after_attack := combat.player.stamina

	for _frame: int in range(4):
		combat.advance(DELTA)
	ctx.check_equal(combat.player.stamina, after_attack, "durante el retraso no recupera")

	var expected := after_attack + GameConfig.PLAYER_STAMINA_REGEN * DELTA
	combat.advance(GameConfig.STAMINA_REGEN_DELAY)
	combat.advance(DELTA)
	ctx.check_almost_equal(combat.player.stamina, expected, "recupera tras el retraso")


func _no_stamina_no_attack(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var reasons: Array[StringName] = []
	combat.attack_rejected.connect(func(reason: StringName) -> void: reasons.append(reason))

	combat.player.spend_stamina(GameConfig.PLAYER_MAX_STAMINA)
	ctx.check(not combat.try_attack(), "sin stamina no hay golpe")
	ctx.check_equal(reasons[0], MeleeCombat.REASON_NO_STAMINA, "motivo del rechazo")


func _hurt_stuns(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var stuns: Array[float] = []
	combat.stun_applied.connect(func(duration: float) -> void: stuns.append(duration))

	var dealt := combat.receive_damage(12.0)

	ctx.check_equal(dealt, 12.0, "daño sin defensa")
	ctx.check_equal(stuns, [GameConfig.HURT_STUN_TIME], "aturde el tiempo configurado")
	ctx.check_equal(combat.player.state, PlayerState.Kind.HURT, "estado HURT")
	ctx.check(combat.is_stunned, "el aturdimiento sigue activo")
	ctx.check(combat.is_invulnerable, "gana invulnerabilidad")

	combat.advance(GameConfig.HURT_STUN_TIME + DELTA)
	ctx.check_equal(combat.player.state, PlayerState.Kind.IDLE, "el aturdimiento expira")


func _invulnerability_expires(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var changes: Array[bool] = []
	combat.invulnerability_changed.connect(func(active: bool) -> void: changes.append(active))

	combat.grant_invulnerability(0.2)
	combat.advance(0.25)

	ctx.check(not combat.is_invulnerable, "la invulnerabilidad expira")
	ctx.check_equal(changes, [true, false], "avisa de entrar y de salir")


func _invulnerable_blocks(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	combat.receive_damage(5.0)
	var health_after_first := combat.player.health.current

	ctx.check_equal(combat.receive_damage(5.0), 0.0, "el segundo golpe no hace daño")
	ctx.check_equal(combat.player.health.current, health_after_first, "no pierde más vida")


func _dead_target_ignored(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var target := Dummy.new()
	target.is_dead = true
	combat.try_attack()
	ctx.check_equal(combat.strike([target, null, 7]), 0, "solo se ignoran los inválidos")


func _broken_weapon_blocks(ctx: ScriptTestContext) -> void:
	var combat := _combat(WeaponCatalog.KNIFE)
	combat.weapon.wear(combat.weapon.max_durability)
	var reasons: Array[StringName] = []
	combat.attack_rejected.connect(func(reason: StringName) -> void: reasons.append(reason))

	ctx.check(not combat.try_attack(), "un arma rota no golpea")
	ctx.check_equal(reasons[0], MeleeCombat.REASON_BROKEN, "motivo del rechazo")


func _equip_changes_range(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var changed: Array[Weapon] = []
	combat.weapon_changed.connect(func(weapon: Weapon) -> void: changed.append(weapon))

	ctx.check(combat.equip(WeaponCatalog.create(WeaponCatalog.KNIFE)), "se equipa el cuchillo")
	ctx.check_equal(changed.size(), 1, "avisa del cambio")
	ctx.check_equal(combat.weapon.attack_range, GameConfig.WEAPON_KNIFE_RANGE, "nuevo alcance")
	ctx.check(not combat.equip(null), "no se puede equipar nada")


func _recovers_after_cooldown(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	ctx.check(combat.try_attack(), "primer golpe")
	combat.advance(GameConfig.WEAPON_STONE_COOLDOWN + GameConfig.ATTACK_RECOVERY)
	ctx.check(combat.can_attack(), "tras el cooldown se puede volver a golpear")
	ctx.check(combat.try_attack(), "y el golpe sale")
