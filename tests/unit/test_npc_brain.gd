extends RefCounted

## Pruebas de la IA y el combate de los NPC (secciones 9, 10 y 18).
##
## Estas dos piezas son la parte que decide, así que se prueban por separado: la IA
## dice qué quiere hacer y el combate decide si puede. Si se mezclaran, un fallo en el
## ritmo de golpes no se distinguiría de un fallo de percepción.

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


## NPC con el comportamiento que se le pase, en el origen.
func _npc(behavior: NpcBehavior = null) -> Npc:
	var body := Npc.new(1, "Prueba", behavior if behavior != null else NpcBehavior.weak())
	body.home = Vector2.ZERO
	body.position = Vector2.ZERO
	body.move_to(Vector2.ZERO, Vector2.DOWN)
	return body


func _brain(body: Npc) -> NpcBrain:
	return NpcBrain.new(body)


func _combat(body: Npc) -> NpcCombat:
	return NpcCombat.new(body)


func register() -> Array:
	return [
		["sin objetivo el NPC descansa o pasea", _idle_without_target],
		["el objetivo cercano pasa a persecución", _chases_close_target],
		["el objetivo lejos no se persigue", _ignores_far_target],
		["a distancia de golpe pasa a ataque", _attacks_in_range],
		["fuera de la correa vuelve a su puesto", _leash_returns_home],
		["poca vida hace huir", _flee_on_low_health],
		["huir significa alejarse del objetivo", _flee_moves_away],
		["perseguir se acerca pero no se pasa", _chase_keeps_range],
		["un golpe entra en cooldown", _attack_cooldown],
		["el NPC no puede atacar dos veces seguidas", _attack_is_busy],
		["el golpe usa la fórmula del daño", _strike_uses_formula],
		["recibir daño da invulnerabilidad", _hurt_invulnerable],
		["el aturdimiento impide atacar", _stun_blocks_attack],
		["un NPC muerto no ataca", _dead_cannot_attack],
		["el director solo manda un perseguidor", _one_hunter],
		["el director respeta el radio de detección", _director_aggro_radius],
		["la tabla de aparición no excede el máximo", _spawn_table_limit],
	]


func _idle_without_target(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	npc.behavior.wander_interval = 0.1
	var brain := _brain(npc)
	brain.clear_target()
	brain.advance(DELTA)
	ctx.check_equal(npc.state, NpcState.Kind.IDLE, "sin objetivo y sin ganas de pasearse, quieto")
	ctx.check_equal(brain.intent(), Vector2.ZERO, "y no se mueve")

	brain.advance(1.0)
	ctx.check_equal(npc.state, NpcState.Kind.WANDER, "pasado el intervalo, pasea")
	ctx.check(not brain.intent().is_zero_approx(), "y el paseo tiene intención")


func _chases_close_target(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	var brain := _brain(npc)
	brain.set_target(Vector2(40.0, 0.0))
	brain.advance(DELTA)
	ctx.check_equal(npc.state, NpcState.Kind.CHASE, "el jugador cerca se persigue")


func _ignores_far_target(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	var brain := _brain(npc)
	brain.set_target(Vector2(500.0, 0.0))
	brain.advance(DELTA)
	ctx.check_equal(npc.state, NpcState.Kind.IDLE, "el jugador lejos no se persigue")


func _attacks_in_range(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	var brain := _brain(npc)
	brain.set_target(Vector2(npc.behavior.attack_range - 1.0, 0.0))
	brain.advance(DELTA)
	ctx.check_equal(npc.state, NpcState.Kind.ATTACK, "a distancia de golpe, ataque")


## La correa es lo que evita que un enemigo deje al NPC persiguiendo al jugador por
## todo el mapa y se acabe la partida en otra zona.
func _leash_returns_home(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	npc.move_to(Vector2(npc.behavior.leash_radius + 20.0, 0.0), Vector2.RIGHT)
	var brain := _brain(npc)
	brain.set_target(Vector2(npc.behavior.leash_radius + 30.0, 0.0))
	brain.advance(DELTA)
	ctx.check_equal(npc.state, NpcState.Kind.IDLE, "fuera de la correa, se rinde")
	ctx.check_equal(brain.intent(), Vector2.ZERO, "y deja de andar")


func _flee_on_low_health(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	npc.take_damage(npc.health.maximum * (1.0 - npc.behavior.flee_health_ratio) + 1.0)
	var brain := _brain(npc)
	brain.set_target(Vector2(30.0, 0.0))
	brain.advance(DELTA)
	ctx.check_equal(npc.state, NpcState.Kind.FLEE, "con poca vida huye")


## Huir tiene que significar alejarse: si se quedara quieto, un enemigo herido sería
## un blanco fácil. Se deja un pelo de vida por encima del umbral, porque un NPC
## muerto ni huye ni se mueve.
func _flee_moves_away(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	npc.take_damage(npc.health.maximum * (1.0 - npc.behavior.flee_health_ratio) + 1.0)
	ctx.check(
		npc.health.ratio < npc.behavior.flee_health_ratio,
		"vive, pero con poca vida"
	)
	var brain := _brain(npc)
	brain.set_target(Vector2(30.0, 0.0))
	brain.advance(DELTA)
	var intent := brain.intent()
	ctx.check(intent.x < 0.0, "la huida va en sentido contrario al objetivo")
	ctx.check_almost_equal(
		intent.length(),
		npc.behavior.move_speed,
		"y a la velocidad de persecución, no a la de paseo"
	)


## Si el enemigo anduviera hasta la posición del objetivo, sus golpes nunca alcanzarían
## porque la distancia se quedaría en cero.
func _chase_keeps_range(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	var brain := _brain(npc)
	brain.set_target(Vector2(10.0, 0.0))
	brain.advance(DELTA)
	ctx.check_equal(brain.intent(), Vector2.ZERO, "dentro del alcance no se mueve más")
	ctx.check_equal(npc.state, NpcState.Kind.ATTACK, "y pasa a golpear")


func _attack_cooldown(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	var combat := _combat(npc)
	ctx.check(combat.try_attack(Vector2.RIGHT), "el primer golpe sale")
	ctx.check(combat.is_window_open, "y abre la ventana de hitbox")
	ctx.check(combat.can_attack() == false, "inmediatamente no puede repetir")

	combat.advance(npc.behavior.attack_cooldown)
	ctx.check(combat.can_attack(), "pasado el cooldown, puede repetir")
	ctx.check(not combat.is_window_open, "la ventana se cerró antes")


func _attack_is_busy(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	var combat := _combat(npc)
	combat.try_attack(Vector2.RIGHT)
	# Un golpe en curso es un estado ocupado, no solo un cooldown: aunque el cooldown
	# ya no estuviera, no se puede abrir una segunda ventana encima.
	ctx.check_equal(combat.rejection_reason(), MeleeCombat.REASON_BUSY, "ocupado durante el golpe")
	ctx.check(not combat.try_attack(Vector2.LEFT), "y no sale otro")


func _strike_uses_formula(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	var combat := _combat(npc)
	var soft := Dummy.new(30.0, 0.0)
	var hard := Dummy.new(30.0, 10.0)

	combat.try_attack(Vector2.RIGHT)
	ctx.check_equal(combat.strike([soft, hard]), 2, "ambos reciben el golpe")
	ctx.check_equal(
		soft.health.current,
		30.0 - DamageRules.compute(npc.behavior.attack_damage, 0.0),
		"sin defensa quita el daño entero"
	)
	ctx.check_equal(
		hard.health.current,
		30.0 - DamageRules.compute(npc.behavior.attack_damage, 10.0),
		"con defensa quita menos"
	)


## Sin invulnerabilidad, seis enemigos pegando en el mismo frame matan al jugador de
## un tirón y no hay combate que leer.
func _hurt_invulnerable(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	var combat := _combat(npc)
	ctx.check_equal(combat.receive_damage(5.0), 5.0, "el primer golpe quita vida")
	ctx.check(combat.is_invulnerable, "y da invulnerabilidad")
	ctx.check_equal(combat.receive_damage(5.0), 0.0, "el segundo no quita nada")
	ctx.check(combat.is_stunned, "el primer golpe además aturde")

	combat.advance(npc.behavior.invulnerability_time)
	ctx.check(not combat.is_invulnerable, "la invulnerabilidad expira")
	ctx.check(combat.receive_damage(5.0) > 0.0, "y entonces vuelve a entrar daño")


func _stun_blocks_attack(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	var combat := _combat(npc)
	combat.apply_stun(0.5)
	ctx.check(combat.is_stunned, "aturdido")
	ctx.check_equal(combat.rejection_reason(), MeleeCombat.REASON_STUNNED, "no puede atacar")
	ctx.check(not combat.try_attack(Vector2.RIGHT), "el golpe no sale")

	combat.advance(0.5)
	ctx.check(not combat.is_stunned, "el aturdimiento pasa")
	ctx.check(combat.try_attack(Vector2.RIGHT), "y entonces sí")


func _dead_cannot_attack(ctx: ScriptTestContext) -> void:
	var npc := _npc()
	npc.take_damage(npc.health.maximum)
	var combat := _combat(npc)
	ctx.check_equal(combat.rejection_reason(), MeleeCombat.REASON_DEAD, "muerto no ataca")
	ctx.check(not combat.try_attack(Vector2.RIGHT), "ni aunque se insista")
	ctx.check_equal(combat.strike([Dummy.new()]), 0, "ni pega")


func _one_hunter(ctx: ScriptTestContext) -> void:
	var director := NpcDirector.new()
	director.populate(NpcSpawnTable.demo())
	ctx.check(director.count() > 1, "hay varios enemigos")

	# El jugador se pone encima del primero: así hay exactamente uno en su radio de
	# detección y la prueba no depende de dónde nazcan los demás.
	director.distribute_target(director.agents[0].npc.home)
	var chasing := 0
	for agent in director.agents:
		if agent.brain.has_target:
			chasing += 1
	ctx.check_equal(chasing, 1, "solo uno persigue a la vez")
	ctx.check(
		director.agents[0].brain.has_target, "y es el más cercano"
	)
	director.shutdown()


func _director_aggro_radius(ctx: ScriptTestContext) -> void:
	var director := NpcDirector.new()
	director.populate(NpcSpawnTable.demo())
	# Lejos de todos, ninguno debe terse objetivo: si lo tuvieran, cruzarían el mapa
	# en línea recta sin que el jugador los viera nunca.
	director.distribute_target(Vector2(-10000.0, -10000.0))
	for agent in director.agents:
		ctx.check(not agent.brain.has_target, "NPC %d sin objetivo lejos" % agent.npc.id)
	director.shutdown()


func _spawn_table_limit(ctx: ScriptTestContext) -> void:
	var table := NpcSpawnTable.demo()
	ctx.check(table.size() > 0, "hay enemigos en la tabla")
	ctx.check_equal(
		NpcSpawnTable.count(),
		mini(table.size(), GameConfig.NPC_SPAWN_COUNT),
		"elSpawner no pasa del máximo configurado"
	)
	for entry: NpcSpawnTable.Entry in table:
		ctx.check(NpcKind.exists(entry.kind), "el enemigo %s es de tipo conocido" % entry.kind)
	# Las posiciones se dan en tiles y tienen que caer dentro de la zona de prueba.
	var tiles := Vector2i(GameConfig.WORLD_ZONE_SIZE)
	for entry: NpcSpawnTable.Entry in table:
		var inside := (
			entry.tile.x > 0 and entry.tile.y > 0
			and entry.tile.x < tiles.x and entry.tile.y < tiles.y
		)
		ctx.check(inside, "el enemigo %s nace dentro de la zona" % entry.kind)