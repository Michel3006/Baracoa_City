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
