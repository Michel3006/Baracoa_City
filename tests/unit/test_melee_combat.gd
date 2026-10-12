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


## Objetivo de mentira que además sabe de la entrada rica: expone dónde está (para
## el empuje) y guarda lo que le ha llegado con `take_attack`. Sirve para comprobar
## que el golpe del jugador elige esa puerta cuando existe.
class RichDummy extends RefCounted:
	var stats: CharacterStats
	var health: Health
	var is_dead: bool = false
	var position: Vector2 = Vector2.ZERO
	var received: Array = []

	func _init(health: float = 30.0, defense: float = 0.0) -> void:
		stats = CharacterStats.new({"defense": defense})
		self.health = Health.new(health)

	func take_damage(amount: float) -> float:
		return health.apply_damage(amount)

	func take_attack(attack: AttackDefinition, amount: float, impact: Vector2) -> float:
		received.append({"attack": attack, "amount": amount, "impact": impact})
		return health.apply_damage(amount)


func _combat(weapon_id: StringName = WeaponCatalog.STONE) -> MeleeCombat:
	return MeleeCombat.new(Player.new(1, "Jugador"), WeaponCatalog.create(weapon_id))


## Deja la ventana de impacto abierta, avanzando el reloj a mano.
##
## Con las fases de la sección 10 un golpe no pega al empezar: arranca en
## WINDUP y la hitbox se abre al entrar en ACTIVE. Un test que golpeara nada más
## llamar a `try_attack()` no estaría probando el daño, estaría probando que la
## ventana estaba cerrada.
func _open_window(combat: MeleeCombat) -> void:
	var guard := 0
	while not combat.is_window_open and combat.is_attacking and guard < 200:
		combat.advance(DELTA)
		guard += 1


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
		["la señal de aturdimiento sube y baja", _stun_signal_sube_y_baja],
		["un aturdimiento ya activo no repite el aviso", _stun_repetido_no_duplica],
		["la invulnerabilidad expira", _invulnerability_expires],
		["mientras es invulnerable no recibe daño", _invulnerable_blocks],
		["un objetivo muerto no recibe golpe", _dead_target_ignored],
		["un arma rota no permite atacar", _broken_weapon_blocks],
		["cambiar de arma cambia el alcance", _equip_changes_range],
		["un golpe tras cooldown vuelve a entrar", _recovers_after_cooldown],
		["pegar a puños no toca el arma equipada", _unarmed_keeps_weapon],
		["el golpe a puños usa las reglas de los puños", _unarmed_uses_own_rules],
		["el golpe a puños pega menos que con arma", _unarmed_hits_softer],
		["el golpe a puños también se bloquea", _unarmed_is_blocked_too],
		["la barra de golpe mide contra el golpe en curso", _cooldown_ratio_follows_strike],
		["el fin del golpe no depende del estado del jugador", _finished_survives_a_state_change],
		["el golpe recorre sus tres fases en orden", _phases_run_in_order],
		["la ventana se abre y se cierra una sola vez", _window_events_fire_once],
		["una pulsación temprana es BUSY, no se guarda", _early_press_is_busy],
		["una pulsación al final encadena sola", _buffered_input_continues_the_combo],
		["sin entrada guardada la cadena se reinicia", _chain_resets_without_buffer],
		["las tres familias empiezan por su primer ataque", _families_start_with_their_own_attack],
		["los ataques caros cuestan y pegan más", _stronger_attacks_cost_and_hit_more],
		["el movimiento se limita mientras dura el golpe", _movement_multiplier_follows_the_attack],
		["una guardia de frente para el golpe y paga stamina", _blocking_soaks_a_front_hit],
		["un golpe por la espalda entra aunque haya guardia", _blocking_does_not_stop_a_back_hit],
		["sin stamina la guardia se rompe y el golpe entra entero", _guard_break_hurts_and_staggers],
		["la guardia no sube atacando, rodando ni aturdido", _block_refuses_when_busy],
		["la rodada abre su ventana y cuesta stamina", _dodge_has_a_window_and_a_cost],
		["rodando el golpe pasa de largo", _dodge_evades_the_hit],
		["la rodada no sale aturdido, sin stamina ni en cadena", _dodge_refuses_when_busy],
		["recibir un ataque levanta su reacción", _attack_raises_a_hit_reaction],
		["un ataque que aturde deja al jugador sin andar", _heavy_attack_staggers],
		["el golpe empuja y el empuje se apaga solo", _knockback_pushes_and_decays],
		["un golpe a mitad de ataque corta el ataque", _a_hit_interrupts_the_attack],
		["golpear prefiere la entrada rica del objetivo", _strike_prefers_rich_targets],
	]


## `attack_finished` sale del reloj del golpe, nunca del estado del jugador.
##
## Antes la señal solo se emitía si al cumplirse la recuperación el jugador seguía en
## `ATTACKING`, y eso nunca pasaba: el movimiento sincronizaba el estado en cada
## fotograma (`GameSession._sync_motion_state()`) y ponía `MOVING` encima en el
## fotograma siguiente al golpe. La señal no salía, la vista se quedaba en la pose de
## golpe para siempre y el jugador caminaba con el cuerpo congelado.
##
## Aquí se reproduce esa situación sin más que un `transition_to()`: es exactamente lo
## que le pasaba al estado desde fuera del caso de uso, y el reloj no se debe enterar.
func _finished_survives_a_state_change(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var events: Array[String] = []
	combat.attack_finished.connect(func() -> void: events.append("golpe"))

	ctx.check(combat.try_attack(), "el golpe sale")
	# Alguien se lleva al jugador de ATTACKING antes de que venza la recuperación.
	combat.player.transition_to(PlayerState.Kind.MOVING)
	combat.advance(GameConfig.ATTACK_RECOVERY + DELTA)

	ctx.check_equal(events, ["golpe"], "la señal sale aunque el estado ya no sea ATTACKING")
	ctx.check(
		combat.player.state == PlayerState.Kind.MOVING,
		"el reloj no pisa el estado que puso otro sistema (%s)" % PlayerState.name_of(combat.player.state)
	)


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
	_open_window(combat)
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


## La vista pinta el aturdimiento con su propio tinte siguiendo esta señal: si no
## avisara de la bajada, el cuerpo se quedaría violeta para siempre.
func _stun_signal_sube_y_baja(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var changes: Array[bool] = []
	combat.stun_changed.connect(func(active: bool) -> void: changes.append(active))

	combat.receive_damage(5.0)
	ctx.check_equal(changes, [true], "al aturdir avisa de que sube")
	ctx.check(combat.is_stunned, "y el reloj lo confirma")

	combat.advance(GameConfig.HURT_STUN_TIME + DELTA)
	ctx.check_equal(changes, [true, false], "al expirar avisa de que baja")
	ctx.check(not combat.is_stunned, "y ya no está aturdido")


## La señal solo avisa del cruce: un segundo `apply_stun` mientras el primero
## sigue vigente no puede repetir el `true`, o la vista repintaría sin necesidad
## y los tests que cuentan avisos empezarían a fallar sin saber por qué.
func _stun_repetido_no_duplica(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var changes: Array[bool] = []
	combat.stun_changed.connect(func(active: bool) -> void: changes.append(active))

	combat.receive_damage(5.0)
	combat.apply_stun()
	combat.apply_stun()
	ctx.check_equal(changes, [true], "un solo aviso de subida")
	ctx.check(combat.is_stunned, "sigue aturdido")


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
	# La ventana abierta, para que el test mire el filtro de objetivos y no el
	# cierre de la hitbox: si no se abre, el 0 del `strike` no dice nada de
	# los muertos.
	_open_window(combat)
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


## Pegar a puños tiene que ser una forma de golpear, no cambiar el arma de la mano.
## Si el golpe a puños des-equipara lo que llevas, el jugador pierde su arma cada vez
## que le da un puñetazo, y eso no es "combate sin arma" sino perder el equipo.
func _unarmed_keeps_weapon(ctx: ScriptTestContext) -> void:
	var combat := _combat(WeaponCatalog.KNIFE)
	var knife := combat.weapon

	ctx.check(combat.try_attack(Vector2.RIGHT, true), "el golpe a puños sale")
	ctx.check_equal(combat.weapon, knife, "el arma sigue siendo la de antes")
	ctx.check_equal(combat.weapon.id, WeaponCatalog.KNIFE, "y no ha cambiado de id")
	ctx.check(
		WeaponCatalog.is_unarmed(combat.active_weapon(true)),
		"pero el golpe en curso es a puños"
	)
	ctx.check(
		not WeaponCatalog.is_unarmed(combat.active_weapon(false)),
		"y con el interruptor apagado vuelve a ser el arma"
	)


## Los puños tienen su propio cooldown, su propia stamina y su propio alcance. Si
## cogieran los del arma, serían un golpe mal etiquetado en vez de otra decisión.
func _unarmed_uses_own_rules(ctx: ScriptTestContext) -> void:
	var combat := _combat(WeaponCatalog.KNIFE)
	var stamina_before := combat.player.stamina
	# La ventana llega en la señal de aviso: es la forma de leerla sin abrir el caso de
	# uso por dentro, que es justo lo que no debe hacer un test.
	var windows: Array[float] = []
	combat.attack_started.connect(
		func(_weapon: Weapon, _direction: Vector2, window: float) -> void:
			windows.append(window)
	)

	ctx.check(combat.try_attack(Vector2.RIGHT, true), "el golpe a puños sale")
	ctx.check_equal(windows.size(), 1, "avisa del golpe")
	ctx.check_almost_equal(
		windows[0] if not windows.is_empty() else 0.0,
		AttackCatalog.of(AttackCatalog.LEFT_JAB).active_time,
		"la ventana la pone el ataque (sección 10), no el cooldown del arma"
	)
	ctx.check_almost_equal(
		combat.cooldown_ratio, 1.0, "el cooldown es el de los puños"
	)
	ctx.check_equal(
		stamina_before - combat.player.stamina,
		GameConfig.WEAPON_UNARMED_STAMINA,
		"y la stamina es la de los puños"
	)


## Puños tienen que pegar menos que cualquier arma del MVP. Si no, no habría motivo
## para llevar nada en la mano.
func _unarmed_hits_softer(ctx: ScriptTestContext) -> void:
	var target := Dummy.new(60.0, 0.0)
	var combat := _combat(WeaponCatalog.KNIFE)
	combat.try_attack(Vector2.RIGHT, true)
	_open_window(combat)
	combat.strike([target], true)
	var fists := 60.0 - target.health.current

	var armed_combat := _combat(WeaponCatalog.KNIFE)
	armed_combat.try_attack(Vector2.RIGHT)
	_open_window(armed_combat)
	armed_combat.strike([Dummy.new(60.0, 0.0)], false)
	var with_knife := GameConfig.WEAPON_KNIFE_DAMAGE

	ctx.check_equal(fists, GameConfig.WEAPON_UNARMED_DAMAGE, "el daño es el de los puños")
	ctx.check(fists < with_knife, "y es menor que el del cuchillo")
	ctx.check(
		GameConfig.WEAPON_UNARMED_DAMAGE < GameConfig.WEAPON_STONE_DAMAGE,
		"y menor que el de la piedra"
	)


## Las reglas del combate valen igual para las dos manos: un puñetazo con la stamina
## agotada, en cooldown o sin arma rota tiene que rechazarse con el mismo motivo.
func _unarmed_is_blocked_too(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	ctx.check(combat.try_attack(Vector2.RIGHT, true), "el primer puñetazo sale")

	# En cooldown: el motivo es el del cooldown, no uno propio de los puños.
	var reasons: Array[StringName] = []
	combat.attack_rejected.connect(func(reason: StringName) -> void: reasons.append(reason))
	ctx.check(not combat.try_attack(Vector2.RIGHT, true), "el segundo se rechaza")
	ctx.check(
		not reasons.is_empty() and reasons[0] != &"",
		"y avisa de por qué: %s" % reasons[0]
	)

	# Agotado el cooldown y la stamina, también se rechaza.
	combat.advance(GameConfig.WEAPON_UNARMED_COOLDOWN + GameConfig.ATTACK_RECOVERY)
	combat.player.spend_stamina(combat.player.stamina)
	ctx.check(not combat.try_attack(Vector2.RIGHT, true), "sin stamina tampoco")


## La barra de golpe de la UI tiene que medir contra lo que se está usando ahora, no
## contra el arma que puede llevarse en la mano: los puños recuperan antes.
func _cooldown_ratio_follows_strike(ctx: ScriptTestContext) -> void:
	var combat := _combat(WeaponCatalog.KNIFE)
	ctx.check(combat.try_attack(Vector2.RIGHT, true), "puñetazo")
	ctx.check_almost_equal(
		combat.cooldown_ratio, 1.0, "al empezar el golpe la barra está llena"
	)
	combat.advance(GameConfig.WEAPON_UNARMED_COOLDOWN * 0.5)
	ctx.check_almost_equal(
		combat.cooldown_ratio, 0.5, "y baja con el cooldown de los puños"
	)


## Las tres fases de la sección 10 son lo que hace que un golpe no pegue desde
## el primer fotograma. Se comprueban con el reloj a mano y por los dos lados:
## la fase que dice el código y la hitbox que se abre y se cierra.
func _phases_run_in_order(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var phases: Array[String] = []
	combat.phase_changed.connect(
		func(previous: int, current: int) -> void:
			phases.append("%s->%s" % [CombatState.name_of(previous), CombatState.name_of(current)])
	)

	ctx.check(combat.try_attack(), "el golpe sale")
	ctx.check_equal(combat.phase, CombatState.Kind.WINDUP, "empieza en WINDUP")
	ctx.check(not combat.is_window_open, "y con la hitbox todavía apagada")

	var jab := AttackCatalog.of(AttackCatalog.LEFT_JAB)
	combat.advance(jab.startup_time - 0.001)
	ctx.check_equal(combat.phase, CombatState.Kind.WINDUP, "dentro del arranque sigue en WINDUP")
	ctx.check(not combat.is_window_open, "la ventana no se adelanta")

	combat.advance(0.002)
	ctx.check_equal(combat.phase, CombatState.Kind.ACTIVE, "cumplido el arranque pasa a ACTIVE")
	ctx.check(combat.is_window_open, "y ahí se abre la hitbox")

	combat.advance(jab.active_time)
	ctx.check_equal(combat.phase, CombatState.Kind.RECOVERY, "después viene RECOVERY")
	ctx.check(not combat.is_window_open, "con la ventana ya cerrada")

	combat.advance(jab.recovery_time)
	ctx.check_equal(combat.phase, CombatState.Kind.FREE, "y acaba en FREE")
	ctx.check(not combat.is_attacking, "sin golpe en curso")
	ctx.check_equal(
		phases,
		["FREE->WINDUP", "WINDUP->ACTIVE", "ACTIVE->RECOVERY", "RECOVERY->FREE"],
		"las cuatro fases, en orden y sin saltos"
	)


## Una sola apertura y un solo cierre por golpe, aunque el avance del reloj se
## salte enteras las fases: si un delta enorme salta WINDUP -> FREE, la ventana
## tiene que abrirse y cerrarse dentro del mismo `advance()` o un golpe rápido
## registrado contra el enemigo habría quedado sin encender la hitbox.
func _window_events_fire_once(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var opens: Array[String] = []
	var closes: Array[String] = []
	combat.attack_window_opened.connect(func() -> void: opens.append("abierta"))
	combat.attack_window_closed.connect(func() -> void: closes.append("cerrada"))

	ctx.check(combat.try_attack(), "el golpe sale")
	combat.advance(
		AttackCatalog.of(AttackCatalog.LEFT_JAB).duration + GameConfig.WEAPON_STONE_COOLDOWN
	)

	ctx.check_equal(opens, ["abierta"], "una sola apertura por golpe")
	ctx.check_equal(closes, ["cerrada"], "y un solo cierre")
	ctx.check(not combat.is_attacking, "y el golpe ha terminado")


## Una pulsación lejos del final del golpe es un intento de atacar ahora mismo, no
## una entrada para más tarde (sección 22). Guardarla sería aceptar pulsaciones
## a ciegas y encadenarían por accidente.
func _early_press_is_busy(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var reasons: Array[StringName] = []
	combat.attack_rejected.connect(func(reason: StringName) -> void: reasons.append(reason))

	ctx.check(combat.try_attack(), "el primer golpe sale")
	combat.advance(0.02)

	ctx.check(not combat.try_attack(), "una pulsación temprana no encadena")
	ctx.check_equal(reasons, [MeleeCombat.REASON_BUSY], "se rechaza como BUSY en vez de guardarse")
	ctx.check_equal(combat.combo_index, 0, "y el índice no se mueve")


## El corazón del buffer: pulsar en los últimos 0,12 s guarda la entrada en
## silencio y el golpe siguiente sale solo, con el cooldown saltado. Si esto
## falla, encadenar se convierte en un timing de milisegundos.
func _buffered_input_continues_the_combo(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var reasons: Array[StringName] = []
	# Se mira `combo_changed` y no `attack_started` dentro de una lambda: una
	# lambda que captura `combat` deja a `combat` colgando de su propia señal, y
	# ese ciclo no lo recolecta nadie (la suite entera se iría con 17 objetos
	# fugados por una sola conexión). Aquí solo se captura el array de pasos.
	var steps: Array[String] = []
	combat.attack_rejected.connect(func(reason: StringName) -> void: reasons.append(reason))
	combat.combo_changed.connect(
		func(index: int, family: StringName) -> void:
			steps.append("%s:%d" % [family, index])
	)

	ctx.check(combat.try_attack(), "el jab izquierdo sale")
	ctx.check_equal(combat.current_attack_id, AttackCatalog.LEFT_JAB, "y es el primero de la cadena")
	ctx.check_equal(steps, ["light:0"], "y lo avisa con su índice")

	var jab := AttackCatalog.of(AttackCatalog.LEFT_JAB)
	combat.advance(jab.duration - GameConfig.COMBO_BUFFER_TIME + 0.01)
	ctx.check(combat.is_attacking, "el primer golpe sigue en curso")
	ctx.check(not combat.try_attack(), "la pulsación guardada no arranca sola")
	ctx.check_equal(reasons, [], "y no se queja: se guarda en silencio")

	combat.advance(GameConfig.COMBO_BUFFER_TIME + DELTA)
	ctx.check_equal(
		combat.current_attack_id, AttackCatalog.RIGHT_JAB, "al terminar arranca el segundo"
	)
	ctx.check_equal(combat.combo_index, 1, "con el índice avanzado")
	ctx.check_equal(steps, ["light:0", "light:1"], "los dos pasos de la cadena, en orden")
	ctx.check_equal(reasons, [], "sin ningún rechazo")


## Sin entrada guardada, la cadena se reinicia a cero (sección 22). Si no,
## dejar de pulsar y volver a empezar pegaría un gancho suelto de cuatro
## golpes más adelante en la secuencia.
func _chain_resets_without_buffer(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	ctx.check(combat.try_attack(), "el jab sale")

	var jab := AttackCatalog.of(AttackCatalog.LEFT_JAB)
	combat.advance(jab.duration + GameConfig.WEAPON_STONE_COOLDOWN + DELTA)

	ctx.check(not combat.is_attacking, "el golpe terminó sin nadie esperando")
	ctx.check_equal(combat.combo_index, 0, "la cadena volvió al principio")
	ctx.check_equal(combat.combo_family, &"", "y no se quedó fijada a la familia")

	ctx.check(combat.try_attack(), "vuelve a poder pegar")
	ctx.check_equal(combat.current_attack_id, AttackCatalog.LEFT_JAB, "y empieza por el jab")


## Cada tecla es una cadena con su primer ataque (sección 23): J abre con el
## jab, K con la cruzada y L con la patada frontal. Si una cadena empezara por
## el golpe de otra, pulsar K daría la sensación de haber pulsado mal.
func _families_start_with_their_own_attack(ctx: ScriptTestContext) -> void:
	var combat := _combat()

	ctx.check(combat.try_attack_family(Vector2.RIGHT, AttackCatalog.FAMILY_LIGHT), "ligera")
	ctx.check_equal(combat.current_attack_id, AttackCatalog.LEFT_JAB, "abre con el jab izquierdo")
	ctx.check_equal(combat.combo_family, AttackCatalog.FAMILY_LIGHT, "y guarda su familia")

	_finish_and_recover(combat)
	ctx.check(combat.try_attack_family(Vector2.RIGHT, AttackCatalog.FAMILY_HEAVY), "pesada")
	ctx.check_equal(combat.current_attack_id, AttackCatalog.STRAIGHT, "abre con la cruzada")
	ctx.check_equal(combat.combo_family, AttackCatalog.FAMILY_HEAVY, "y guarda su familia")

	_finish_and_recover(combat)
	ctx.check(combat.try_attack_family(Vector2.RIGHT, AttackCatalog.FAMILY_KICK), "patadas")
	ctx.check_equal(combat.current_attack_id, AttackCatalog.FRONT_KICK, "abre con la frontal")
	ctx.check_equal(combat.combo_family, AttackCatalog.FAMILY_KICK, "y guarda su familia")


## La sección 29 se paga en stamina y se cobra en vida: un ataque caro cuesta
## más de la del arma y quita más que el jab, con la misma arma y el mismo
## objetivo. Si no, todas las cadenas serían intercambiables.
func _stronger_attacks_cost_and_hit_more(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var before := combat.player.stamina
	ctx.check(combat.try_attack_family(Vector2.RIGHT, AttackCatalog.FAMILY_HEAVY), "cruzada")
	var spent := before - combat.player.stamina
	var jab := AttackCatalog.of(AttackCatalog.LEFT_JAB)
	var straight := AttackCatalog.of(AttackCatalog.STRAIGHT)
	ctx.check_almost_equal(
		spent,
		GameConfig.WEAPON_STONE_STAMINA + (straight.stamina_cost - jab.stamina_cost),
		"la stamina es la del arma más la del ataque (sección 20)"
	)

	var light := _combat()
	light.try_attack()
	_open_window(light)
	var soft := Dummy.new(60.0, 0.0)
	light.strike([soft])
	var light_damage := 60.0 - soft.health.current

	var heavy := _combat()
	heavy.try_attack_family(Vector2.RIGHT, AttackCatalog.FAMILY_HEAVY)
	_open_window(heavy)
	var hard := Dummy.new(60.0, 0.0)
	heavy.strike([hard])
	var heavy_damage := 60.0 - hard.health.current

	ctx.check(
		heavy_damage > light_damage,
		"la cruzada quita más vida que el jab (%.1f > %.1f)" % [heavy_damage, light_damage]
	)
	ctx.check(straight.damage > jab.damage, "y sus números de la sección 29 son mayores")


## El movimiento no se corta del todo mientras se golpea: la sección 14 pide un
## multiplicador por familia, y con la cruzada casi no se avanza mientras con
## el jab se mantiene la mayor parte del paso.
func _movement_multiplier_follows_the_attack(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	ctx.check_almost_equal(combat.movement_multiplier, 1.0, "sin golpe no se limita nada")

	ctx.check(combat.try_attack(), "el jab sale")
	ctx.check_almost_equal(
		combat.movement_multiplier,
		GameConfig.ATTACK_MOVE_MULT_JAB,
		"con el jab se conserva la mayor parte del paso (sección 14)"
	)

	_finish_and_recover(combat)
	ctx.check(combat.try_attack_family(Vector2.RIGHT, AttackCatalog.FAMILY_HEAVY), "la cruzada")
	ctx.check_almost_equal(
		combat.movement_multiplier,
		GameConfig.ATTACK_MOVE_MULT_HEAVY,
		"y con la cruzada casi no se arrastra el pie"
	)


## Deja el combate en FREE y con el cooldown consumido, para poder pegar otra
## vez sin esperar a mano cuánto dura cada golpe.
func _finish_and_recover(combat: MeleeCombat) -> void:
	var wait := GameConfig.WEAPON_STONE_COOLDOWN + DELTA
	if combat.current_attack != null:
		wait = maxf(wait, combat.current_attack.duration + wait)
	combat.advance(wait)


# --- F5: defensa y reacciones ---

## La guardia solo para lo que viene de frente (sección 31) y se paga con stamina,
## no con vida. `impact` es la dirección del empuje (atacante -> defensor), así que
## de frente va contra la mirada.
func _blocking_soaks_a_front_hit(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	combat.player.direction = Vector2.DOWN
	var results: Array[StringName] = []
	combat.attack_received.connect(
		func(result: StringName, _attack: AttackDefinition) -> void: results.append(result)
	)

	combat.set_blocking(true)
	ctx.check(combat.is_blocking, "la guardia sube")

	var stamina_before := combat.player.stamina
	var health_before := combat.player.health.current
	var dealt := combat.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.UP)

	ctx.check_equal(dealt, 0.0, "de frente el golpe no entra")
	ctx.check_equal(combat.player.health.current, health_before, "no se pierde vida")
	ctx.check_equal(
		stamina_before - combat.player.stamina,
		GameConfig.BLOCK_STAMINA_COST,
		"aguantar cuesta stamina, no vida"
	)
	ctx.check_equal(results, [CombatResult.BLOCKED], "y el intercambio se anota como bloqueado")
	ctx.check(combat.is_blocking, "la guardia sigue arriba")


## Un golpe por la espalda no se puede parar: la mirada y el empuje apuntan en el
## mismo sentido, así que no es "de frente" y la guardia no lo cubre.
func _blocking_does_not_stop_a_back_hit(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	combat.player.direction = Vector2.DOWN
	combat.set_blocking(true)

	var dealt := combat.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.DOWN)

	ctx.check_equal(dealt, 6.0, "por la espalda entra")
	ctx.check_equal(combat.player.health.current, 94.0, "y quita vida")
	ctx.check(not combat.is_blocking, "el golpe tira la guardia")


## Sin stamina no hay guardia que aguante: el golpe entra entero y además deja al
## defensor abierto más tiempo. Es lo que convierte insistir en la guardia en una
## decisión y no en un muro.
func _guard_break_hurts_and_staggers(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	combat.player.direction = Vector2.DOWN
	combat.player.spend_stamina(combat.player.stamina)
	combat.set_blocking(true)

	var dealt := combat.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.UP)

	ctx.check(dealt > 0.0, "sin stamina la guardia no para nada")
	ctx.check_equal(combat.player.health.current, 100.0 - dealt, "la vida baja")
	ctx.check(not combat.is_blocking, "la guardia cae")
	ctx.check(combat.is_staggered, "y queda abierto, no solo tambaleando")
	ctx.check_almost_equal(
		combat.movement_multiplier, GameConfig.STAGGER_MOVE_MULT_HIGH, "sin poder andar"
	)
	ctx.check_equal(combat.reaction_clip, &"hit_light", "con la pose del golpe recibido")

	# El guard break dura más que el clip: todavía sigue abierto a mitad del
	# sobretiempo y se cierra al agotarlo.
	combat.advance(GameConfig.BLOCK_BREAK_TIME - DELTA)
	ctx.check(combat.is_reacting, "sigue abierto casi hasta el final del tiempo extra")
	combat.advance(DELTA * 2.0)
	ctx.check(not combat.is_reacting, "y se recupera")


## La guardia no es un interruptor de mano libre: no sube a mitad de un golpe, ni
## rodando, ni con el cuerpo respondiendo a otro golpe.
func _block_refuses_when_busy(ctx: ScriptTestContext) -> void:
	var attacking := _combat()
	ctx.check(attacking.try_attack(Vector2.RIGHT), "el golpe sale")
	attacking.set_blocking(true)
	ctx.check(not attacking.is_blocking, "no se levanta la guardia atacando")
	ctx.check_equal(
		attacking.phase, CombatState.Kind.WINDUP, "ni se pisa la fase del ataque"
	)

	var stunned := _combat()
	stunned.apply_stun()
	stunned.set_blocking(true)
	ctx.check(not stunned.is_blocking, "ni aturdido")

	var dodging := _combat()
	ctx.check(dodging.try_dodge(Vector2.RIGHT), "la rodada sale")
	dodging.set_blocking(true)
	ctx.check(not dodging.is_blocking, "ni rodando")
	ctx.check_equal(dodging.phase, CombatState.Kind.DODGING, "la rodada sigue su curso")


## La rodada (sección 30) no es invulnerable durante todo el gesto: primero hay que
## hacer el arranque y luego se abre una ventana. Cuesta stamina y no se encadena.
func _dodge_has_a_window_and_a_cost(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var starts: Array[Vector2] = []
	combat.dodge_started.connect(
		func(direction: Vector2, _duration: float) -> void: starts.append(direction)
	)
	var stamina_before := combat.player.stamina

	ctx.check(combat.try_dodge(Vector2.RIGHT), "la rodada sale")
	ctx.check_equal(starts, [Vector2.RIGHT], "avisa de hacia dónde rueda")
	ctx.check_equal(combat.player.state, PlayerState.Kind.DODGING, "el estado es DODGING")
	ctx.check_equal(
		stamina_before - combat.player.stamina, GameConfig.DODGE_STAMINA, "cuesta su stamina"
	)
	ctx.check(not combat.is_dodge_invulnerable, "al empezar el gesto aún no es invulnerable")
	ctx.check_almost_equal(
		combat.movement_multiplier, GameConfig.DODGE_MOVE_MULT, "la intención no mueve: rueda el gesto"
	)
	ctx.check(not combat.try_dodge(Vector2.RIGHT), "no se encadenan dos rodadas")

	combat.advance(GameConfig.DODGE_STARTUP_TIME + DELTA)
	ctx.check(combat.is_dodge_invulnerable, "pasado el arranque se abre la ventana")

	combat.advance(GameConfig.DODGE_TOTAL_TIME)
	ctx.check(not combat.is_dodging, "la rodada termina")
	ctx.check_equal(combat.player.state, PlayerState.Kind.IDLE, "y el cuerpo vuelve a estar libre")
	ctx.check(combat.external_velocity.is_zero_approx(), "sin empuje residual")


## Dentro de la ventana de la rodada el golpe no entra y el intercambio lo dice:
## es lo que permite distinguir "lo esquivé" de "no me tocó".
func _dodge_evades_the_hit(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var results: Array[StringName] = []
	combat.attack_received.connect(
		func(result: StringName, _attack: AttackDefinition) -> void: results.append(result)
	)

	ctx.check(combat.try_dodge(Vector2.RIGHT), "la rodada sale")
	combat.advance(GameConfig.DODGE_STARTUP_TIME + DELTA)

	var health_before := combat.player.health.current
	var dealt := combat.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.RIGHT)

	ctx.check_equal(dealt, 0.0, "el golpe pasa de largo")
	ctx.check_equal(combat.player.health.current, health_before, "sin perder vida")
	ctx.check_equal(results, [CombatResult.DODGED], "y se anota como esquivado")
	ctx.check(not combat.is_stunned, "y sin aturdirse")


## Fuera de la ventana la rodada no protege (si no sería un botón de
## inmortalidad), y tampoco sale aturdido, sin stamina ni por debajo de su espera.
func _dodge_refuses_when_busy(ctx: ScriptTestContext) -> void:
	var stunned := _combat()
	stunned.apply_stun()
	ctx.check(not stunned.try_dodge(Vector2.RIGHT), "aturdido no se rueda")

	var tired := _combat()
	tired.player.spend_stamina(tired.player.stamina)
	ctx.check(not tired.try_dodge(Vector2.RIGHT), "sin stamina tampoco")

	var waiting := _combat()
	ctx.check(waiting.try_dodge(Vector2.RIGHT), "la primera rodada sale")
	waiting.advance(GameConfig.DODGE_TOTAL_TIME + DELTA)
	ctx.check(not waiting.is_dodging, "y ha terminado")
	ctx.check(waiting.dodge_cooldown_ratio > 0.0, "pero la espera no ha pasado")
	ctx.check(not waiting.try_dodge(Vector2.RIGHT), "así que no sale la segunda")

	# Fuera de la ventana de invulnerabilidad el golpe entra igual.
	var rolling := _combat()
	ctx.check(rolling.try_dodge(Vector2.RIGHT), "la rodada sale")
	ctx.check(not rolling.is_dodge_invulnerable, "durante el arranque no protege")
	ctx.check(
		rolling.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.UP) > 0.0,
		"y el golpe entra antes de que la ventana se abra"
	)


## Un golpe con ataque levanta el clip de reacción que le toca: el jab deja la
## reacción ligera, que tambalea pero deja andar un poco. El trance lo lleva el
## combate con su propio reloj, no la vista.
func _attack_raises_a_hit_reaction(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	combat.player.direction = Vector2.DOWN
	var started: Array[StringName] = []
	combat.reaction_started.connect(
		func(clip: StringName, _duration: float) -> void: started.append(clip)
	)
	var finished: Array[String] = []
	combat.reaction_finished.connect(func() -> void: finished.append("fin"))

	var dealt := combat.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.UP)

	ctx.check_equal(dealt, 6.0, "el golpe entra")
	ctx.check_equal(combat.reaction_clip, &"hit_light", "y deja la reacción ligera")
	ctx.check(not combat.is_staggered, "el jab tambalea, no aturde")
	ctx.check_equal(combat.player.state, PlayerState.Kind.HURT, "el jugador queda en HURT")
	ctx.check_equal(started, [&"hit_light"], "y lo avisa una sola vez")
	ctx.check_almost_equal(
		combat.movement_multiplier, GameConfig.REACTION_MOVE_MULT, "tambaleando todavía se anda"
	)

	combat.advance(GameConfig.REACTION_LIGHT_TIME + DELTA)
	ctx.check(not combat.is_reacting, "el trance dura lo que dura su clip")
	ctx.check_equal(combat.reaction_clip, &"", "y la vista ya no tiene clip que reproducir")
	ctx.check_equal(finished, ["fin"], "y avisa del fin")

	# El aturdimiento del daño dura más que la reacción: el cuerpo no vuelve a
	# IDLE hasta que expira el más largo.
	ctx.check_equal(combat.player.state, PlayerState.Kind.HURT, "el aturdimiento sigue mandando")
	combat.advance(GameConfig.HURT_STUN_TIME)
	ctx.check_equal(combat.player.state, PlayerState.Kind.IDLE, "y al expirar queda libre")


## Un ataque que aturde de verdad (sección 26) deja al defensor sin andar y su
## trance dura el clip más el sobretiempo del tier.
func _heavy_attack_staggers(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var dealt := combat.take_attack(AttackCatalog.of(AttackCatalog.ELBOW), 12.0, Vector2.UP)

	ctx.check_equal(dealt, 12.0, "el codo entra")
	ctx.check(combat.is_staggered, "y aturde de verdad")
	ctx.check_equal(combat.reaction_clip, &"hit_body", "con la reacción corporal")
	ctx.check_almost_equal(
		combat.movement_multiplier, GameConfig.STAGGER_MOVE_MULT_HIGH, "sin poder andar"
	)

	ctx.check(
		GameConfig.REACTION_BODY_TIME + GameConfig.STAGGER_EXTRA_HIGH > GameConfig.REACTION_BODY_TIME,
		"el trance dura más que el clip a secas"
	)
	combat.advance(GameConfig.REACTION_BODY_TIME + GameConfig.STAGGER_EXTRA_HIGH * 0.5)
	ctx.check(combat.is_reacting, "a mitad del sobretiempo sigue aturdido")
	combat.advance(GameConfig.STAGGER_EXTRA_HIGH)
	ctx.check(not combat.is_reacting, "y se recupera al agotarlo")


## El empuje del knockback (sección 27) es una velocidad que decae en línea recta
## hasta cero: no un teletransporte. Se escribe en `external_velocity` para que el
## movimiento la sume y la resuelva contra las paredes.
func _knockback_pushes_and_decays(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	ctx.check(combat.external_velocity.is_zero_approx(), "sin golpes no hay velocidad externa")

	combat.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.UP)
	ctx.check(combat.external_velocity.y < 0.0, "el empuje va hacia donde venía el golpe")
	ctx.check_almost_equal(
		combat.external_velocity.length(), GameConfig.KNOCKBACK_FORCE_LOW, "con la fuerza del tier"
	)

	combat.advance(GameConfig.KNOCKBACK_TIME * 0.5)
	ctx.check_almost_equal(
		combat.external_velocity.length(),
		GameConfig.KNOCKBACK_FORCE_LOW * 0.5,
		"a mitad del tiempo queda la mitad del empuje"
	)

	combat.advance(GameConfig.KNOCKBACK_TIME)
	ctx.check(combat.external_velocity.is_zero_approx(), "y al agotarse se apaga del todo")


## Un golpe recibido a mitad de ataque corta el ataque: el trance manda. La ventana
## de la hitbox se cierra y el fin del golpe se avisa como cualquier otro.
func _a_hit_interrupts_the_attack(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	var events: Array[String] = []
	var results: Array[StringName] = []
	combat.attack_window_closed.connect(func() -> void: events.append("ventana"))
	combat.attack_finished.connect(func() -> void: events.append("golpe"))
	combat.attack_received.connect(
		func(result: StringName, _attack: AttackDefinition) -> void: results.append(result)
	)

	ctx.check(combat.try_attack(Vector2.RIGHT), "el golpe sale")
	_open_window(combat)
	ctx.check(combat.is_window_open, "con la ventana abierta")

	var dealt := combat.take_attack(AttackCatalog.of(AttackCatalog.LEFT_JAB), 6.0, Vector2.UP)

	ctx.check(dealt > 0.0, "el golpe entra")
	ctx.check(not combat.is_attacking, "y corta el ataque en curso")
	ctx.check(not combat.is_window_open, "cerrando la ventana de la hitbox")
	ctx.check_equal(events, ["ventana", "golpe"], "en el orden de siempre")
	ctx.check_equal(results, [CombatResult.INTERRUPTED], "y se anota como interrumpido")
	ctx.check_equal(combat.combo_index, 0, "la cadena se pierde con el ataque")


## El golpe del jugador prefiere la entrada rica del objetivo: así el enemigo reacciona
## y es empujado. Si el objetivo solo sabe `take_damage`, se cae a esa puerta; las dos
## formas tienen que seguir valiendo.
func _strike_prefers_rich_targets(ctx: ScriptTestContext) -> void:
	var combat := _combat()
	combat.player.direction = Vector2.DOWN
	var rich := RichDummy.new(30.0, 2.0)
	rich.position = combat.player.position + Vector2.DOWN * 20.0

	ctx.check(combat.try_attack(Vector2.DOWN), "el golpe sale")
	_open_window(combat)
	var count := combat.strike([rich])

	ctx.check_equal(count, 1, "el objetivo rico recibe el golpe")
	ctx.check_equal(rich.received.size(), 1, "por su entrada de ataque")
	ctx.check_equal(
		rich.received[0]["attack"], AttackCatalog.of(AttackCatalog.LEFT_JAB), "con el ataque entero"
	)
	ctx.check_equal(
		rich.received[0]["amount"],
		GameConfig.WEAPON_STONE_DAMAGE - 2.0,
		"y la defensa ya aplicada por el atacante"
	)
	ctx.check_equal(rich.received[0]["impact"], Vector2.DOWN, "y la dirección del empuje")

	var plain := Dummy.new(30.0, 2.0)
	var other := _combat()
	other.try_attack(Vector2.DOWN)
	_open_window(other)
	ctx.check_equal(other.strike([plain]), 1, "y un objetivo del montón sigue funcionando")
	ctx.check_equal(
		plain.health.current, 30.0 - (GameConfig.WEAPON_STONE_DAMAGE - 2.0), "por `take_damage`"
	)
