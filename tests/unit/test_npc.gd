extends RefCounted

## Pruebas del dominio de NPC: modelo, estados y comportamientos (secciones 9 y 18).
##
## Sin escena y sin reloj: todo se prueba con llamadas directas, así que el resultado
## no depende de la tasa de fotogramas.

## Un NPC de prueba en el origen, con la vida que se le pida.
func _npc(max_health: float = 24.0) -> Npc:
	var behavior := NpcBehavior.new()
	behavior.max_health = max_health
	var body := Npc.new(1, "Prueba", behavior)
	body.home = Vector2.ZERO
	body.position = Vector2.ZERO
	body.move_to(Vector2.ZERO, Vector2.DOWN)
	return body


func register() -> Array:
	return [
		["un NPC nuevo nace vivo, en su casa y en reposo", _starts_alive],
		["recibir daño avisa y puede matar", _damage_and_death],
		["un NPC muerto ya no recibe daño", _dead_takes_nothing],
		["la distancia a casa alimenta la correa", _distance_from_home],
		["el grafo de estados acepta lo legal", _state_graph_allows],
		["el grafo de estados rechaza lo ilegal", _state_graph_refuses],
		["un enemigo quieto también puede atacar", _attack_from_rest],
		["DEAD no tiene salida", _dead_is_terminal],
		["reaparecer devuelve la vida y el puesto", _respawn],
		["los tipos de enemigo son identificadores de dominio", _kinds_are_data],
		["el comportamiento sale de la configuración", _behavior_from_config],
		["el comportamiento fuerte es más duro", _strong_behavior],
	]


func _starts_alive(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	ctx.check(npc.is_alive, "nace vivo")
	ctx.check(not npc.is_dead, "no nace muerto")
	ctx.check_equal(npc.state, NpcState.Kind.IDLE, "nace en reposo")
	ctx.check_equal(npc.health.ratio, 1.0, "nace con la vida llena")
	ctx.check_equal(npc.health.maximum, 24.0, "la vida viene del comportamiento")
	ctx.check_equal(npc.stats.defense, GameConfig.NPC_WEAK_DEFENSE, "la defensa también")
	ctx.check_equal(npc.home, npc.position, "nace en su puesto")


## El señal de muerte tiene que salir solo, sin que nadie lo pida: es lo que permite
## que la presentación se entere de que deje de golpear.
func _damage_and_death(ctx: ScriptTestContext) -> void:
	var npc := _npc(20.0)
	var died := [false]
	npc.died.connect(func() -> void: died[0] = true)

	ctx.check_equal(npc.take_damage(5.0), 5.0, "quita lo pedido")
	ctx.check_equal(npc.health.current, 15.0, "la vida baja")
	ctx.check(not died[0], "aún no ha muerto")

	var seen := [0.0]
	npc.health_changed.connect(func(current: float, _max: float) -> void: seen[0] = current)
	npc.take_damage(100.0)
	ctx.check(npc.is_dead, "la vida a cero es muerte")
	ctx.check(died[0], "avisa de la muerte")
	ctx.check_equal(seen[0], 0.0, "avisa del nuevo valor de vida")
	ctx.check_equal(npc.state, NpcState.Kind.DEAD, "y pasa a DEAD")


func _dead_takes_nothing(ctx: ScriptTestContext) -> void:
	var npc := _npc(10.0)
	npc.take_damage(10.0)
	ctx.check_equal(npc.take_damage(5.0), 0.0, "un NPC muerto no recibe daño")
	ctx.check(not npc.heal(5.0) > 0.0, "y tampoco se cura solo")


func _distance_from_home(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	npc.move_to(Vector2(30.0, 40.0), Vector2.RIGHT)
	ctx.check_equal(npc.distance_from_home, 50.0, "distancia a casa")
	ctx.check(
		npc.distance_from_home <= npc.behavior.leash_radius,
		"a 50 px de casa todavía está dentro de la correa"
	)
	npc.move_to(Vector2(0.0, npc.behavior.leash_radius + 1.0), Vector2.UP)
	ctx.check(
		npc.distance_from_home > npc.behavior.leash_radius,
		"un paso más allá ya está fuera de la correa"
	)


func _state_graph_allows(ctx: ScriptTestContext) -> void:
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.IDLE, NpcState.Kind.WANDER),
		"reposo puede pasearse"
	)
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.WANDER, NpcState.Kind.CHASE),
		"el paseo puede volverse persecución"
	)
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.CHASE, NpcState.Kind.ATTACK),
		"la persecución puede volverse ataque"
	)
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.ATTACK, NpcState.Kind.CHASE),
		"el ataque puede volverse persecución"
	)
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.CHASE, NpcState.Kind.FLEE),
		"la persecución puede volverse huida"
	)
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.FLEE, NpcState.Kind.IDLE),
		"la huida puede acabar en reposo"
	)
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.IDLE, NpcState.Kind.DEAD),
		"cualquier estado vivo puede morir"
	)
	ctx.check(NpcState.is_alive(NpcState.Kind.CHASE), "perseguir es estar vivo")
	ctx.check(not NpcState.is_alive(NpcState.Kind.DEAD), "muerto no es estar vivo")


## El caso que se olvidó el primer diseño: un enemigo quieto al que el jugador se le
## echa encima tiene que poder golpear. Si de IDLE no se pasa a ATTACK, ese enemigo se
## queda indefenso justo cuando más lo necesitan sus reglas.
func _attack_from_rest(ctx: ScriptTestContext) -> void:
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.IDLE, NpcState.Kind.ATTACK),
		"un enemigo quieto puede atacar"
	)
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.WANDER, NpcState.Kind.ATTACK),
		"uno que pasea también"
	)
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.ATTACK, NpcState.Kind.IDLE),
		"y el ataque puede volver a reposo"
	)
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.FLEE, NpcState.Kind.CHASE),
		"al que huía y se repone puede volver a perseguir"
	)


func _state_graph_refuses(ctx: ScriptTestContext) -> void:
	ctx.check(
		not NpcState.can_transition_to(NpcState.Kind.IDLE, NpcState.Kind.IDLE),
		"no se repite estado"
	)
	ctx.check(
		NpcState.can_transition_to(NpcState.Kind.IDLE, NpcState.Kind.FLEE),
		"el reposo sí puede volverse huida"
	)
	ctx.check(
		not NpcState.can_transition_to(NpcState.Kind.ATTACK, NpcState.Kind.WANDER),
		"el ataque no salta a un paseo"
	)
	ctx.check(
		not NpcState.can_transition_to(NpcState.Kind.WANDER, NpcState.Kind.WANDER),
		"ni a sí mismo"
	)


func _dead_is_terminal(ctx: ScriptTestContext) -> void:
	for kind: NpcState.Kind in NpcState.ALIVE:
		ctx.check(
			NpcState.can_transition_to(kind, NpcState.Kind.DEAD),
			"todo estado vivo puede llegar a DEAD"
		)
		for other: NpcState.Kind in NpcState.ALIVE:
			ctx.check(
				not NpcState.can_transition_to(NpcState.Kind.DEAD, other),
				"DEAD no vuelve a %s" % NpcState.name_of(other)
			)


func _respawn(ctx: ScriptTestContext) -> void:
	var npc := _npc(20.0)
	npc.move_to(Vector2(200.0, 200.0), Vector2.RIGHT)
	npc.take_damage(20.0)
	ctx.check(npc.is_dead, "primero muere")

	npc.respawn_at(Vector2(64.0, 64.0))
	ctx.check(npc.is_alive, "reaparece vivo")
	ctx.check_equal(npc.health.current, 20.0, "con la vida llena")
	ctx.check_equal(npc.home, Vector2(64.0, 64.0), "y en el puesto nuevo")


## Los tipos de enemigo no son rutas de archivo: si lo fueran, el dominio dependería
## de la capa de presentación.
func _kinds_are_data(ctx: ScriptTestContext) -> void:
	ctx.check(NpcKind.exists(NpcKind.VANDAL), "el vándalo existe")
	ctx.check(NpcKind.exists(NpcKind.GANGSTER), "el pandillero existe")
	ctx.check(not NpcKind.exists(&"dragon"), "no hay dragones")
	ctx.check_equal(
		NpcKind.display_name(NpcKind.BRUTE), "Matón", "el matón tiene nombre"
	)
	ctx.check(
		NpcKind.display_name(&"lo-que-sea") == "Individuo",
		"un tipo desconocido tiene nombre genérico"
	)


func _behavior_from_config(ctx: ScriptTestContext) -> void:
	var weak := NpcBehavior.weak()
	ctx.check_equal(weak.max_health, GameConfig.NPC_WEAK_HEALTH, "vida")
	ctx.check_equal(weak.attack_damage, GameConfig.NPC_WEAK_DAMAGE, "daño")
	ctx.check_equal(weak.attack_range, GameConfig.NPC_WEAK_RANGE, "alcance")
	ctx.check_equal(weak.attack_cooldown, GameConfig.NPC_WEAK_COOLDOWN, "cooldown")
	ctx.check_equal(weak.move_speed, GameConfig.NPC_WEAK_SPEED, "velocidad")
	ctx.check_equal(weak.defense, GameConfig.NPC_WEAK_DEFENSE, "defensa")
	ctx.check_equal(weak.aggro_radius, GameConfig.NPC_AGGRO_RADIUS, "radio de detección")
	ctx.check_equal(weak.leash_radius, GameConfig.NPC_LEASH_RADIUS, "correa")
	ctx.check(weak.flee_health_ratio < 1.0, "el umbral de huida es una fracción")


## El enemigo duro tiene que ser duro en todo, no solo en vida: si su golpe fuera más
## lento que el del débil, el combate sería un intercambio en el que aguanta más quien
## pega menos.
func _strong_behavior(ctx: ScriptTestContext) -> void:
	var weak := NpcBehavior.weak()
	var strong := NpcBehavior.strong()
	ctx.check(strong.max_health > weak.max_health, "aguanta más")
	ctx.check(strong.attack_damage > weak.attack_damage, "pega más")
	ctx.check(strong.move_speed > weak.move_speed, "es más rápido")
	ctx.check(strong.attack_cooldown > weak.attack_cooldown, "pero golpea menos a menudo")
	ctx.check(strong.attack_range > weak.attack_range, "y llega más lejos")
	ctx.check(strong.defense > weak.defense, "y aguanta más el golpe")