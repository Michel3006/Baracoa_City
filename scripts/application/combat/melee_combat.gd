class_name MeleeCombat
extends RefCounted

## Caso de uso: combate cuerpo a cuerpo (secciones 7, 10, 11, 20-23 y 29).
##
## Es el único sitio que decide si un golpe sale, cuándo puede volver a salir,
## qué ataque concreto es y cuánto daño hace. No sabe nada de sprites ni de
## nodos: la capa Presentation le dice qué ha encontrado la hitbox y esta clase
## aplica las reglas.
##
## Un golpe no es un bloque de tiempo homogéneo: son las tres fases de la
## sección 10 (`WINDUP -> ACTIVE -> RECOVERY`) dentro del estado `ATTACKING` del
## jugador, y la ventana de impacto coincide exactamente con `ACTIVE`. Quien
## manda sobre el reloj es este caso de uso con `advance(delta)`, igual que
## `MovementController`: el golpe termina aunque el jugador se mueva o reciba un
## golpe, porque una señal de fin no puede depender del estado que otro sistema
## escribe cada fotograma.
##
## Las entradas se agrupan en cadenas (sección 23) y se guardan en un buffer
## corto (sección 22): una pulsación dentro de los últimos
## `COMBO_BUFFER_TIME` segundos del golpe se guarda en silencio y arranca sola
## al terminar, que es lo que hace que encadenar se sienta a cuartos de segundo
## y no a pulsaciones exactas.
##
## Dependencias: application -> domain, infrastructure/configuration

signal attack_started(weapon: Weapon, direction: Vector2, window: float)
signal attack_window_opened()
signal attack_window_closed()
signal attack_finished()
signal attack_rejected(reason: StringName)
## Eventos de animación (sección 11): cada cruce de fase, con la anterior y la
## nueva. `WINDUP -> ACTIVE` es el momento en el que se abre la hitbox.
signal phase_changed(previous: int, current: int)
## Índice de la cadena en curso, para que HUD o música reaccionen (sección 16).
signal combo_changed(index: int, family: StringName)
signal target_hit(target: Object, damage: float)
signal damaged(amount: float, source: Object)
signal invulnerability_changed(active: bool)
signal weapon_changed(weapon: Weapon)
signal stun_applied(duration: float)
## Sube al aturdir y baja al expirar. Es la lectura de la vista: quien la conecta
## tiñe el sprite con `STUN_TINT` mientras vale `true`, sin tener que consultar
## el reloj en cada fotograma.
signal stun_changed(active: bool)
## Reacción al recibir un golpe (sección 25): qué clip hay que reproducir y
## cuánto dura el trance. Lo emite el cuerpo que recibe, no el que pega.
signal reaction_started(clip: StringName, duration: float)
signal reaction_finished()
## Esquive (sección 30): dirección de la rodada y duración total del gesto.
signal dodge_started(direction: Vector2, duration: float)
signal dodge_finished()
## Guardia (sección 31): sube al levantarla y baja al soltarla o al romperse.
signal block_changed(active: bool)
## Resultado de un golpe recibido (sección 19), con el ataque que lo causó (puede
## ser `null` cuando el atacante no traía uno). El atacante ve `target_hit`; el
## defensor ve esto.
signal attack_received(result: StringName, attack: AttackDefinition)
## Impacto conectado (secciones 36-38): lo emite este cuerpo tanto al dar como
## al recibir, con el tier del golpe (`low`/`medium`/`high`). La presentación lo
## usa para el hit stop, la sacudida de cámara y el burst de partículas. Solo se
## emite cuando el golpe entra de verdad: bloqueado, esquivado o invulnerable no
## se emite, porque no hay nada que congelar ni que celebrar.
signal impact_struck(tier: StringName)

const REASON_DEAD := &"dead"
const REASON_BUSY := &"busy"
const REASON_COOLDOWN := &"cooldown"
const REASON_NO_STAMINA := &"no_stamina"
const REASON_BROKEN := &"broken_weapon"
const REASON_STUNNED := &"stunned"

var player: Player
var weapon: Weapon

## Golpe sin arma. Vive aquí para que la presentación no tenga que crear armas:
## el presentador solo dice "sin arma" y este caso de uso decide con cuál pega.
var unarmed: Weapon

## Ataque en curso, o `null` cuando el combate está en `FREE`. Es la fuente de
## verdad de las tres fases: `phase` se deriva de él con `AttackDefinition.phase_at()`.
var current_attack: AttackDefinition = null
## Fase del combate (sección 7). En F4 se recorren FREE, WINDUP, ACTIVE y
## RECOVERY; las demás están en la enum esperando a F5.
var phase: int = CombatState.Kind.FREE
## Familia e índice de la cadena que se está encadenando (sección 23).
var combo_family: StringName = &""
var combo_index: int = 0

## Entrada guardada en el buffer (sección 22). Vacía = no hay nada pendiente.
var _buffered: Dictionary = {}

var _cooldown_remaining: float = 0.0
## Cooldown total del último golpe, para que la barra de la UI mida contra el arma
## que se usó y no contra la que se lleva encima ahora.
var _cooldown_total: float = 0.0
var _attack_elapsed: float = 0.0
var _invulnerable_remaining: float = 0.0
var _stun_remaining: float = 0.0
var _regen_delay_remaining: float = 0.0

## --- F5: reacciones, empuje, esquive y guardia ---

## Reacción en curso (secciones 25-26). `_reaction_remaining > 0` es el trance;
## `_reaction_stagger` distingue la reacción corta (`HIT_REACTION`) del aturdimiento
## que además limita el movimiento (`STAGGERED`). El reloj lo lleva el combate, no
## la vista: la señal de fin no puede depender de lo que escriba otro sistema.
var _reaction_remaining: float = 0.0
var _reaction_clip: StringName = &""
var _reaction_move_mult: float = 1.0
var _reaction_stagger: bool = false

## Empuje del knockback (sección 27). `_push_velocity` es la velocidad inicial y
## `_push_remaining` el trozo que queda de `KNOCKBACK_TIME`: la fuerza decae en
## línea recta hasta cero. Se aplica como velocidad externa aditiva en el
## movimiento, así que respeta las paredes.
var _push_velocity: Vector2 = Vector2.ZERO
var _push_remaining: float = 0.0

## Rodada (sección 30). `_dodge_remaining` es el reloj del gesto completo, que
## arranca en `DODGE_TOTAL_TIME`; la ventana de invulnerabilidad se abre tras el
## arranque y dura `DODGE_INVULN_TIME`, contadas desde que empezó la rodada.
var _dodge_remaining: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _dodge_cooldown_remaining: float = 0.0

## Guardia levantada (sección 31). No consume stamina por mantenerla: la paga
## cada golpe que aguanta.
var is_blocking: bool = false

## Velocidad externa del fotograma (empuje o rodada). La lee el presentador y la
## copia a `MovementController.external_velocity`.
var external_velocity: Vector2 = Vector2.ZERO


func _init(body: Player, starting_weapon: Weapon = null) -> void:
	player = body
	weapon = starting_weapon if starting_weapon != null else WeaponCatalog.default_weapon()
	unarmed = WeaponCatalog.unarmed()


var is_attacking: bool:
	get:
		return current_attack != null


var is_window_open: bool:
	get:
		return CombatState.is_window_open(phase)


var is_invulnerable: bool:
	get:
		return _invulnerable_remaining > 0.0


var is_stunned: bool:
	get:
		return _stun_remaining > 0.0


## ¿Está en trance por un golpe recibido? Cubre la reacción corta y el stagger.
var is_reacting: bool:
	get:
		return _reaction_remaining > 0.0


## ¿El trance es de los que limitan el movimiento y prohíben atacar (sección 26)?
var is_staggered: bool:
	get:
		return is_reacting and _reaction_stagger


## Clip de golpe que la vista debe reproducir mientras dura la reacción, o `&""`.
var reaction_clip: StringName:
	get:
		return _reaction_clip if is_reacting else &""


## ¿Está rodando? (sección 30)
var is_dodging: bool:
	get:
		return _dodge_remaining > 0.0


## ¿La rodada cubre ahora mismo su ventana de invulnerabilidad? (sección 30)
##
## La ventana no arranca al pulsar: primero hay que hacer el gesto
## (`DODGE_STARTUP_TIME`) y luego cubre `DODGE_INVULN_TIME`. Un golpe que llega
## durante la rodada pero fuera de la ventana entra igual, que es lo que impide
## que la rodada sea un botón de inmortalidad.
var is_dodge_invulnerable: bool:
	get:
		if not is_dodging:
			return false
		var elapsed := GameConfig.DODGE_TOTAL_TIME - _dodge_remaining
		return (
			elapsed >= GameConfig.DODGE_STARTUP_TIME
			and elapsed < GameConfig.DODGE_STARTUP_TIME + GameConfig.DODGE_INVULN_TIME
		)


## Cuánto lleva la rodada en curso, en segundos. 0 si no hay rodada.
var dodge_elapsed: float:
	get:
		if not is_dodging:
			return 0.0
		return GameConfig.DODGE_TOTAL_TIME - _dodge_remaining


## Progreso de la espera entre esquives, de 0 (listo) a 1 (recién rodado).
var dodge_cooldown_ratio: float:
	get:
		if GameConfig.DODGE_COOLDOWN <= 0.0:
			return 0.0
		return clampf(_dodge_cooldown_remaining / GameConfig.DODGE_COOLDOWN, 0.0, 1.0)


## Posición del cuerpo que pelea. La lee quien ataca para saber por dónde sale el
## empuje del golpe: el ataque se resuelve entre dos cuerpos de combate, y este es
## el único dato de sitio que un cuerpo de combate expone.
var position: Vector2:
	get:
		return Vector2.ZERO if player == null else player.position


## Id del ataque en curso, o `&""`. La vista lo usa para elegir clip.
var current_attack_id: StringName:
	get:
		return current_attack.animation_id if current_attack != null else &""


## Duración total del golpe en curso. La decide `AttackDefinition` y la vista la
## usa como reloj de respaldo de la pose.
var current_duration: float:
	get:
		return current_attack.duration if current_attack != null else GameConfig.ATTACK_RECOVERY


## Cuánto deja pasar el movimiento (secciones 14 y 26). Con un golpe manda el
## ataque; en trance, lo que deje la reacción; rodando, la rodada avanza sola y la
## intención no aporta; en guardia, se camina despacio.
var movement_multiplier: float:
	get:
		if current_attack != null:
			return current_attack.movement_multiplier
		if is_reacting:
			return _reaction_move_mult
		if is_dodging:
			return GameConfig.DODGE_MOVE_MULT
		if is_blocking:
			return GameConfig.BLOCK_MOVE_MULT
		return 1.0


## Estadísticas de quien pelea. `DamageRules` las busca para leer la defensa, de
## modo que el cuerpo de combate del jugador sirve como objetivo válido.
var stats: CharacterStats:
	get:
		return null if player == null else player.stats


var is_dead: bool:
	get:
		return player == null or player.is_dead


## Progreso del cooldown, de 0 (listo) a 1 (recién golpeado). Para la UI.
var cooldown_ratio: float:
	get:
		if _cooldown_total <= 0.0:
			return 0.0
		return clampf(_cooldown_remaining / _cooldown_total, 0.0, 1.0)


## ¿Puede iniciar un golpe ahora mismo? No consume nada: solo consulta.
func can_attack() -> bool:
	return rejection_reason().is_empty()


## Motivo por el que no se puede atacar, o cadena vacía si sí se puede.
##
## Responde para un golpe suelto de la cadena ligera, que es lo que pregunta la
## UI: la cadena y el buffer pueden cambiar lo que cuesta, y eso se comprueba
## igualmente dentro de `try_attack()`, que es quien decide de verdad.
## Consultar y luego atacar son dos llamadas, así que `try_attack()` vuelve a
## comprobarlo: el caso de uso es la única autoridad.
func rejection_reason() -> StringName:
	if player == null or player.is_dead:
		return REASON_DEAD
	var active := active_weapon(false)
	if active == null or not active.can_attack():
		return REASON_BROKEN
	if is_attacking or is_dodging:
		return REASON_BUSY
	# Un trance por golpe recibido bloquea atacar igual que el aturdimiento: con
	# el cuerpo respondiendo al golpe no hay sitio para pedirle un gesto nuevo.
	if is_stunned or is_reacting:
		return REASON_STUNNED
	if _cooldown_remaining > 0.0:
		return REASON_COOLDOWN
	var reference := AttackCatalog.of(AttackCatalog.LEFT_JAB)
	var cost := active.stamina_cost if reference == null else AttackCatalog.stamina_of(active, reference)
	if not player.has_stamina(cost):
		return REASON_NO_STAMINA
	return &""


## El arma con la que se va a pegar: la equipada, o los puños si se pide sin arma.
## `try_attack()` es quien llama a esto, así que durante un golpe siempre devuelve
## el arma que ya está en la mano y no vuelve a cambiar a mitad de animación.
func active_weapon(wants_unarmed: bool) -> Weapon:
	if wants_unarmed and unarmed != null:
		return unarmed
	return weapon


## Inicia un golpe de la cadena ligera (J / ratón izquierdo / `attack`).
##
## `attack_id != &""` salta a un ataque concreto del catálogo; con `&""` empieza
## por el primero de la cadena. `unarmed = true` pega a puños sin tocar el arma
## equipada. Las tres cadenas se piden con `try_attack_family()`.
##
## Devuelve `false` si no sale, y en ese caso emite `attack_rejected` salvo una
## excepción: una pulsación dentro de la ventana de buffer se guarda en silencio.
## Quejarse ahí sería mentir (el jugador pulsó bien, solo que aún no toca) y
## llenaría la cola de rechazos de ruido.
func try_attack(
	direction: Vector2 = Vector2.DOWN,
	unarmed: bool = false,
	attack_id: StringName = &""
) -> bool:
	var family := AttackCatalog.FAMILY_LIGHT
	if attack_id != &"":
		var own_family := AttackCatalog.family_of(attack_id)
		if own_family != &"":
			family = own_family
	return _request(family, attack_id, direction, unarmed)


## El mismo golpe, eligiendo cadena: `FAMILY_HEAVY` (K), `FAMILY_KICK` (L) o
## `FAMILY_LIGHT`. Una entrada guardada que apunta a otra cadena empieza esa
## cadena por su primer ataque en vez de continuar la anterior.
func try_attack_family(
	direction: Vector2 = Vector2.DOWN,
	family: StringName = AttackCatalog.FAMILY_LIGHT,
	unarmed: bool = false
) -> bool:
	return _request(family, &"", direction, unarmed)


## Núcleo de la entrada: comprueba, guarda en buffer o arranca.
func _request(
	family: StringName,
	attack_id: StringName,
	direction: Vector2,
	unarmed: bool
) -> bool:
	var reason := rejection_reason()
	if reason == REASON_BUSY:
		if _in_buffer_window():
			_buffer(family, attack_id, direction, unarmed)
			return false
		attack_rejected.emit(REASON_BUSY)
		return false
	if not reason.is_empty():
		attack_rejected.emit(reason)
		return false

	var plan := _plan_attack(family, attack_id, &"", 0, false)
	var attack: AttackDefinition = plan["attack"]
	if attack == null:
		attack_rejected.emit(REASON_BROKEN)
		return false
	var active := active_weapon(unarmed)
	# La cadena puede costar más que el jab: `rejection_reason()` solo pregunta
	# por el golpe suelto barato, así que aquí se paga el precio real.
	if not player.has_stamina(AttackCatalog.stamina_of(active, attack)):
		attack_rejected.emit(REASON_NO_STAMINA)
		return false
	_start(attack, plan["family"], plan["index"], direction, unarmed)
	return true


## ¿Estamos en los últimos `combo_window` segundos del golpe? (sección 22)
func _in_buffer_window() -> bool:
	if current_attack == null:
		return false
	return _attack_elapsed >= current_attack.duration - current_attack.combo_window


func _buffer(family: StringName, attack_id: StringName, direction: Vector2, unarmed: bool) -> void:
	_buffered = {
		"family": family,
		"attack_id": attack_id,
		"direction": direction,
		"unarmed": unarmed,
	}


## Qué ataque arranca en cada caso:
##
## - id pedido explícitamente: ese, en el índice que ocupe de su cadena;
## - entrada guardada de la misma cadena: el siguiente de la cadena, envolviendo
##   al final (si la cadena se acaba, la secuencia empieza de nuevo);
## - cualquier otra entrada nueva o guardada de otra cadena: el primero.
##
## Un id que no está en el catálogo se ignora y se cae al primero: con `posmod`
## un id desconocido habría acabado en el último golpe de la cadena, que es un
## fallo imposible de ver a simple vista.
func _plan_attack(
	family: StringName,
	attack_id: StringName,
	finished_family: StringName,
	finished_index: int,
	from_buffer: bool
) -> Dictionary:
	var id := attack_id
	if id != &"" and AttackCatalog.of(id) == null:
		id = &""
	var target_family := family
	if id != &"":
		var own := AttackCatalog.family_of(id)
		if own != &"":
			target_family = own
	if AttackCatalog.chain(target_family).is_empty():
		target_family = AttackCatalog.FAMILY_LIGHT

	var index := 0
	if id != &"":
		index = maxi(AttackCatalog.index_of(target_family, id), 0)
	elif from_buffer and target_family == finished_family:
		index = finished_index + 1
	# Envolver aquí y no en `attack_at` para que `combo_index` sea siempre un
	# índice de cadena real: lo lee el HUD.
	index = posmod(index, AttackCatalog.chain(target_family).size())
	return {
		"attack": AttackCatalog.attack_at(target_family, index),
		"family": target_family,
		"index": index,
	}


## Arranca un golpe: paga, entra en ATTACKING y abre la ventana de fases.
func _start(
	attack: AttackDefinition,
	family: StringName,
	index: int,
	direction: Vector2,
	unarmed: bool
) -> void:
	var active := active_weapon(unarmed)
	# Atacar baja la guardia: no se pega con el brazo ocupado en el escudo.
	_set_blocking(false)
	current_attack = attack
	combo_family = family
	combo_index = index
	_attack_elapsed = 0.0

	player.spend_stamina(AttackCatalog.stamina_of(active, attack))
	_regen_delay_remaining = GameConfig.STAMINA_REGEN_DELAY
	_cooldown_remaining = active.attack_cooldown
	_cooldown_total = active.attack_cooldown

	player.direction = direction
	if not player.transition_to(PlayerState.Kind.ATTACKING):
		# ATTACKING no es legal desde DEAD, pero un HURT reciente puede dejar al
		# jugador en un estado raro: el golpe ya se ha pagado, así que se acepta
		# y solo se avisa.
		GameLogger.debug(
			"No se pudo entrar en ATTACKING desde %s" % PlayerState.name_of(player.state),
			"MeleeCombat"
		)

	_set_phase(CombatState.Kind.WINDUP)
	# El `window` que se lleva la señal es la duración de la ventana de impacto,
	# no la del golpe: la hitbox se enciende con `attack_window_opened`.
	attack_started.emit(active, direction, attack.active_time)
	combo_changed.emit(index, family)


func _set_phase(next: int) -> void:
	if phase == next:
		return
	var previous := phase
	phase = next
	phase_changed.emit(previous, next)


## Recorre las fases hasta la que toca para el tiempo transcurrido.
##
## Avanza de una en una aunque un solo `delta` se las salte todas, para que las
## señales salgan siempre en orden (la ventana se abre y se cierra aunque el
## golpe entero quepa en un frame de simulación, que es lo que pasa en los
## tests que avanzan el reloj a mano).
func _sync_phase() -> void:
	if current_attack == null:
		return
	var target := current_attack.phase_at(_attack_elapsed)
	while phase != target:
		match phase:
			CombatState.Kind.WINDUP:
				_set_phase(CombatState.Kind.ACTIVE)
				attack_window_opened.emit()
			CombatState.Kind.ACTIVE:
				_set_phase(CombatState.Kind.RECOVERY)
				attack_window_closed.emit()
			CombatState.Kind.RECOVERY:
				# El golpe termina aquí mismo y el buffer, si lo hay, arranca otro:
				# hay que salir del bucle con el ataque ya cambiado.
				_set_phase(CombatState.Kind.FREE)
				_finish_attack()
				return
			_:
				return


## El reloj del golpe es la autoridad de "ha terminado", y la señal sale siempre.
##
## La transición del estado del jugador sí es condicional: a mitad de golpe se
## puede haber metido `HURT` al recibir daño, y sobreescribirlo pondría al
## jugador en IDLE tumbado. Antes esta condición estaba al revés (solo se
## emitía `attack_finished` si seguía en `ATTACKING`) y como el movimiento
## sacaba de `ATTACKING` al fotograma siguiente, la señal no salía nunca.
func _finish_attack() -> void:
	var finished_family := combo_family
	var finished_index := combo_index
	current_attack = null
	_attack_elapsed = 0.0
	if player.state == PlayerState.Kind.ATTACKING:
		player.transition_to(PlayerState.Kind.IDLE)
	attack_finished.emit()

	if _buffered.is_empty():
		combo_family = &""
		combo_index = 0
		return
	_flush_buffer(finished_family, finished_index)


## Suelta la entrada guardada al terminar el golpe (sección 22).
##
## Se salta el cooldown: encadenar no espera al del arma, o la cadena se pegaría
## a cuentagotas. Sí se comprueban vida, arma, aturdimiento y stamina, porque
## ahí ya no es un problema de ritmo sino de poder pegar. Si algo falla, el
## rechazo se emite ahora, que es cuando el jugador puede hacer algo.
func _flush_buffer(finished_family: StringName, finished_index: int) -> void:
	var request := _buffered
	_buffered = {}
	var plan := _plan_attack(
		request.get("family", AttackCatalog.FAMILY_LIGHT),
		request.get("attack_id", &""),
		finished_family,
		finished_index,
		true
	)
	var attack: AttackDefinition = plan["attack"]
	var family: StringName = plan["family"]
	if attack == null:
		combo_family = &""
		combo_index = 0
		return

	var wants_unarmed: bool = request.get("unarmed", false)
	var active := active_weapon(wants_unarmed)
	var reason := &""
	if player == null or player.is_dead:
		reason = REASON_DEAD
	elif is_stunned:
		reason = REASON_STUNNED
	elif active == null or not active.can_attack():
		reason = REASON_BROKEN
	elif not player.has_stamina(AttackCatalog.stamina_of(active, attack)):
		reason = REASON_NO_STAMINA

	if not reason.is_empty():
		attack_rejected.emit(reason)
		combo_family = &""
		combo_index = 0
		return
	_start(
		attack, family, plan["index"], request.get("direction", Vector2.DOWN), wants_unarmed
	)


## Aplica el golpe a los objetivos que la hitbox ha encontrado.
##
## Recibe objetos de dominio, no nodos: la física solo decide a quién ha tocado la
## hitbox, nunca cuánto daño se le hace. Devuelve cuántos han recibido daño.
##
## El daño sale de la fórmula combinada: el arma pone su poder base y el ataque
## suma su diferencia sobre el jab de referencia (`AttackCatalog.power_of`), y
## sobre eso aplica la defensa `DamageRules`. Si el último golpe fue a puños, lo
## que se aplica son los puños.
func strike(targets: Array, used_unarmed: bool = false) -> int:
	if not is_window_open or current_attack == null:
		return 0
	var active := active_weapon(used_unarmed)
	if active == null:
		return 0
	var attack := current_attack
	var power := AttackCatalog.power_of(active, attack)
	if not DamageRules.is_valid_attack(power):
		return 0
	var hits := 0
	for target in targets:
		if not DamageRules.is_damageable(target):
			continue
		var damageable := target as Object
		var defense := DamageRules.defense_of(damageable)
		var dealt := _apply_to(damageable, attack, DamageRules.compute(power, defense))
		if dealt > 0.0:
			hits += 1
			target_hit.emit(damageable, dealt)
			impact_struck.emit(attack.knockback)
	return hits


## Mete el golpe en un objetivo.
##
## Prefiere `take_attack`, que además del daño sabe de reacciones, de por dónde
## viene el empuje y de guardias; si el objetivo solo sabe `take_damage` (un
## objetivo de mentira, un cuerpo de una versión antigua) se cae a esa entrada.
## El atacante no decide el trance del otro: solo dice qué ataque y por dónde
## salió. Lo que el defensor haga con eso es suyo.
##
## La cantidad va ya con la defensa aplicada: la calcula el atacante, y el
## defensor no la vuelve a pasar por la fórmula.
func _apply_to(damageable: Object, attack: AttackDefinition, damage: float) -> float:
	if damageable.has_method(&"take_attack"):
		return float(damageable.call(&"take_attack", attack, damage, _impact_of(damageable)))
	return float(damageable.call(&"take_damage", damage))


## Dirección en la que sale empujado un objetivo: del atacante hacia él.
##
## El objetivo puede no exponer dónde está (los objetivos de mentira de los tests
## son solo un contador de daño), y entonces se usa la mirada del atacante: el
## empuje sale hacia donde mira quien pega, que es el respaldo razonable.
func _impact_of(target: Object) -> Vector2:
	var from := position
	var to := from
	if "position" in target:
		var value: Variant = target.get(&"position")
		if value is Vector2:
			to = value
	var fallback := player.direction if player != null else Vector2.DOWN
	return CombatReaction.impact_direction(from, to, fallback)


## Daño recibido. Aplica la fórmula con la defensa del jugador, aturde y concede
## invulnerabilidad para que un golpe no se repita cada frame.
## Devuelve el daño realmente infligido.
func receive_damage(raw_damage: float, source: Object = null) -> float:
	if player == null or player.is_dead or is_invulnerable:
		return 0.0
	return _receive_computed(DamageRules.compute(raw_damage, player.stats.defense), null, Vector2.ZERO, source)


## Entrada rica del golpe recibido (secciones 19, 25-27 y 31).
##
## La usa el atacante que sí trae su `AttackDefinition`, y con ella el defensor
## sabe qué reacción levantar, con cuánta fuerza lo empujan y si el golpe venía de
## frente (guardia). `amount` viene ya calculado por el atacante: aquí no se vuelve
## a aplicar la defensa.
##
## Orden de comprobaciones, que es la ley del combate: primero la ventana de
## esquive (el golpe pasa de largo, no hay nada que parar), luego la
## invulnerabilidad (ya me han dado), luego la guardia (lo aguanto si viene de
## frente y tengo stamina) y por último el golpe de verdad.
func take_attack(
	attack: AttackDefinition, amount: float, impact: Vector2 = Vector2.ZERO
) -> float:
	if player == null or player.is_dead:
		return 0.0
	if is_dodge_invulnerable:
		attack_received.emit(CombatResult.DODGED, attack)
		return 0.0
	if is_invulnerable:
		return 0.0
	if is_blocking and CombatReaction.is_from_front(impact, player.direction):
		if player.has_stamina(GameConfig.BLOCK_STAMINA_COST):
			player.spend_stamina(GameConfig.BLOCK_STAMINA_COST)
			_regen_delay_remaining = GameConfig.STAMINA_REGEN_DELAY
			_push(impact, GameConfig.KNOCKBACK_FORCE_LOW)
			attack_received.emit(CombatResult.BLOCKED, attack)
			return 0.0
		# Guardia rota: no había stamina para aguantar. Entra el golpe entero y
		# encima deja al defensor abierto, que es lo que convierte insistir en la
		# guardia en una decisión y no en un muro.
		_set_blocking(false)
		var broken := _receive_computed(amount, null, impact, null)
		if broken > 0.0:
			_force_stagger(GameConfig.BLOCK_BREAK_TIME)
		attack_received.emit(CombatResult.HIT, attack)
		return broken
	var was_attacking := is_attacking
	var dealt := _receive_computed(amount, attack, impact, null)
	if dealt > 0.0:
		attack_received.emit(
			CombatResult.INTERRUPTED if was_attacking else CombatResult.HIT, attack
		)
	return dealt


## Núcleo del daño recibido: quita vida, concede invulnerabilidad, aturde, empuja
## y levanta la reacción. `attack` puede ser `null` (el atacante no traía uno) y
## entonces el trance se deduce del daño.
func _receive_computed(
	amount: float, attack: AttackDefinition, impact: Vector2, source: Object
) -> float:
	if player == null or player.is_dead or is_invulnerable or amount <= 0.0:
		return 0.0
	var dealt := player.take_damage(amount)
	if dealt <= 0.0:
		return 0.0
	grant_invulnerability()
	apply_stun()
	damaged.emit(dealt, source)
	# El defensor también avisa del impacto, con el tier deducido del daño si el
	# atacante no traía ataque. Es la misma señal que emite el atacante al
	# conectar: los dos lados del golpe congelan el mundo juntos.
	impact_struck.emit(CombatReaction.knockback_of(attack, dealt))
	if not player.is_dead:
		_start_reaction(attack, dealt, impact)
	return dealt


## La misma entrada de daño, con el nombre que espera `DamageRules`.
##
## Existe para que el cuerpo de combate del jugador sea un objetivo válido tal
## cual: un NPC no debería conocer `Player` ni saltarse la invulnerabilidad
## llamando a `take_damage` directamente. Pedirle daño a `MeleeCombat` es lo que
## hace que un enemigo respete la ventana de invulnerabilidad y el aturdimiento.
func take_damage(amount: float) -> float:
	return receive_damage(amount, null)


## Activa la invulnerabilidad temporal (sección 9).
func grant_invulnerability(duration: float = GameConfig.INVULNERABILITY_TIME) -> void:
	if duration <= 0.0:
		return
	var was_invulnerable := is_invulnerable
	_invulnerable_remaining = maxf(_invulnerable_remaining, duration)
	if not was_invulnerable:
		invulnerability_changed.emit(true)


## Aturdimiento al recibir daño. Mantiene al jugador en HURT durante `duration`
## y lo devuelve a IDLE al expirar. La presentación conecta `stun_applied` a
## `MovementController.block_for()`.
func apply_stun(duration: float = GameConfig.HURT_STUN_TIME) -> void:
	if duration <= 0.0 or player == null or player.is_dead:
		return
	var was_stunned := is_stunned
	_stun_remaining = maxf(_stun_remaining, duration)
	stun_applied.emit(duration)
	if not was_stunned:
		stun_changed.emit(true)
	player.transition_to(PlayerState.Kind.HURT)


## Levanta o suelta la guardia (sección 31).
##
## Se puede pedir cada fotograma sin coste: la guardia solo sube si el cuerpo está
## libre, porque no se levanta el escudo a mitad de un golpe ni de una rodada. Una
## vez arriba se queda hasta que la suelten, se rompa o el jugador ataque. No
## gasta stamina por mantenerse: la paga cada golpe aguantado.
func set_blocking(held: bool) -> void:
	if player == null or player.is_dead:
		held = false
	if not held:
		_set_blocking(false)
		return
	if is_attacking or is_dodging or is_reacting or is_stunned:
		return
	_set_blocking(true)


func _set_blocking(active: bool) -> void:
	if is_blocking == active:
		return
	is_blocking = active
	if active:
		_set_phase(CombatState.Kind.BLOCKING)
	elif phase == CombatState.Kind.BLOCKING:
		_set_phase(CombatState.Kind.FREE)
	block_changed.emit(active)


## Inicia una rodada (sección 30).
##
## El destino es la dirección pedida (la intención del jugador) o, sin ella, hacia
## donde mira. No sale durante una reacción, otra rodada ni el aturdimiento, y
## desde un ataque solo si ese ataque lo permite y ya está en recuperación
## (sección 24: cancelar es la excepción del jab, no la norma).
##
## Devuelve `false` si no sale. No emite rechazo a propósito: pedir una rodada a
## destiempo es lo normal y llenaría la consola de ruido.
func try_dodge(direction: Vector2 = Vector2.ZERO) -> bool:
	if player == null or player.is_dead:
		return false
	if is_dodging or is_reacting or is_stunned:
		return false
	if _dodge_cooldown_remaining > 0.0:
		return false
	if is_attacking:
		if current_attack == null or not current_attack.can_cancel:
			return false
		if phase != CombatState.Kind.RECOVERY:
			return false
	if not player.has_stamina(GameConfig.DODGE_STAMINA):
		return false

	var heading := direction
	if heading.is_zero_approx():
		heading = player.direction
	if heading.is_zero_approx():
		heading = Vector2.DOWN
	heading = heading.normalized()

	if is_attacking:
		_abort_attack()
	_set_blocking(false)

	player.direction = heading
	player.spend_stamina(GameConfig.DODGE_STAMINA)
	_regen_delay_remaining = GameConfig.STAMINA_REGEN_DELAY
	_dodge_cooldown_remaining = GameConfig.DODGE_COOLDOWN
	_dodge_direction = heading
	_dodge_remaining = GameConfig.DODGE_TOTAL_TIME
	# La rodada se lleva por delante cualquier empuje a medias: es un gesto nuevo.
	_push_remaining = 0.0
	_push_velocity = Vector2.ZERO
	_refresh_external_velocity()
	player.transition_to(PlayerState.Kind.DODGING)
	_set_phase(CombatState.Kind.DODGING)
	dodge_started.emit(_dodge_direction, GameConfig.DODGE_TOTAL_TIME)
	return true


## Arranca un trance por golpe recibido (secciones 25-27).
##
## `CombatReaction` decide qué clip, cuánto dura y con qué fuerza empuja; aquí solo
## se copia eso a los relojes del cuerpo. El golpe en curso se pierde (el trance
## manda), la guardia cae y el empuje sale hacia donde venía el golpe.
func _start_reaction(attack: AttackDefinition, damage: float, impact: Vector2) -> void:
	var plan := CombatReaction.plan(attack, damage)
	if is_dodging:
		_dodge_remaining = 0.0
		dodge_finished.emit()
	if is_attacking:
		_abort_attack()
	_set_blocking(false)
	_reaction_remaining = float(plan["time"])
	_reaction_clip = plan["clip"]
	_reaction_move_mult = float(plan["movement_multiplier"])
	_reaction_stagger = bool(plan["stagger"])
	_push(impact, float(plan["force"]))
	player.transition_to(PlayerState.Kind.HURT)
	_set_phase(
		CombatState.Kind.STAGGERED if _reaction_stagger else CombatState.Kind.HIT_REACTION
	)
	reaction_started.emit(_reaction_clip, _reaction_remaining)


## Convierte el trance en curso en un aturdimiento de al menos `seconds`.
##
## La usan la guardia rota y el golpe que entra a medias: el daño ya ha entrado,
## pero además deja al defensor abierto más tiempo del que dura su clip.
func _force_stagger(seconds: float) -> void:
	_reaction_stagger = true
	_reaction_remaining = maxf(_reaction_remaining, seconds)
	_reaction_move_mult = GameConfig.STAGGER_MOVE_MULT_HIGH
	if phase == CombatState.Kind.HIT_REACTION:
		_set_phase(CombatState.Kind.STAGGERED)


## Fin del trance: el cuerpo vuelve a estar disponible, salvo que el aturdimiento
## siga corriendo, que entonces manda él.
func _end_reaction() -> void:
	_reaction_remaining = 0.0
	_reaction_clip = &""
	_reaction_move_mult = 1.0
	_reaction_stagger = false
	if phase == CombatState.Kind.HIT_REACTION or phase == CombatState.Kind.STAGGERED:
		_set_phase(CombatState.Kind.FREE)
	if player != null and player.state == PlayerState.Kind.HURT and not is_stunned:
		player.transition_to(PlayerState.Kind.IDLE)
	reaction_finished.emit()


## Fin de la rodada: se recupera el cuerpo y se para el gesto.
func _end_dodge() -> void:
	_dodge_remaining = 0.0
	if phase == CombatState.Kind.DODGING:
		_set_phase(CombatState.Kind.FREE)
	if player != null and player.state == PlayerState.Kind.DODGING:
		player.transition_to(PlayerState.Kind.IDLE)
	_refresh_external_velocity()
	dodge_finished.emit()


## Corta el golpe en curso sin dejar que el buffer arranque otro.
##
## Pasa cuando un golpe te interrumpe o cuando una rodada cancela una
## recuperación: el ataque termina porque lo han cortado, no porque haya
## encadenado, así que se tira la entrada guardada y se cierra la ventana si
## estaba abierta. La señal de fin sale igual, porque quien la escucha no tiene
## por qué distinguir un final por reloj de uno por interrupción.
func _abort_attack() -> void:
	if not is_attacking:
		return
	if phase == CombatState.Kind.ACTIVE:
		attack_window_closed.emit()
	_buffered = {}
	_finish_attack()


## Arranca un empuje hacia donde venía el golpe, con la fuerza dada en píxeles por
## segundo. El decaimiento lo lleva `_push_remaining`, no la velocidad.
func _push(impact: Vector2, force: float) -> void:
	if force <= 0.0 or impact.is_zero_approx():
		return
	_push_velocity = impact.normalized() * force
	_push_remaining = GameConfig.KNOCKBACK_TIME
	_refresh_external_velocity()


## Recalcula la velocidad externa del fotograma a partir de lo que haya vivo.
##
## La rodada manda: si estás rodando, el gesto te lleva. Si no, queda lo que quede
## del empuje, que decae en línea recta desde `_push_velocity` hasta cero durante
## `KNOCKBACK_TIME`.
func _refresh_external_velocity() -> void:
	if is_dodging:
		external_velocity = _dodge_direction * GameConfig.DODGE_SPEED
		return
	if _push_remaining > 0.0:
		external_velocity = _push_velocity * (_push_remaining / GameConfig.KNOCKBACK_TIME)
		return
	external_velocity = Vector2.ZERO


## Entra en `DEAD`: se corta todo lo que estuviera pasando y el cuerpo se suelta.
##
## El combate no revive a nadie (eso es de la reaparición, que es otro caso de
## uso): solo deja de aceptar entradas mientras el jugador esté muerto. Al
## reaparecer, `player.is_dead` vuelve a ser falso y la fase sale de `DEAD` sola.
func _enter_dead() -> void:
	if is_attacking:
		_abort_attack()
	_reaction_remaining = 0.0
	_reaction_clip = &""
	_reaction_move_mult = 1.0
	_reaction_stagger = false
	_dodge_remaining = 0.0
	_set_blocking(false)
	_push_remaining = 0.0
	_push_velocity = Vector2.ZERO
	external_velocity = Vector2.ZERO
	_set_phase(CombatState.Kind.DEAD)


## Cambia el arma en mano. El sistema de combate no lleva inventario: solo usa
## lo que le dan.
func equip(new_weapon: Weapon) -> bool:
	if new_weapon == null:
		GameLogger.warning("Se intentó equipar un arma nula", "MeleeCombat")
		return false
	if new_weapon == weapon:
		return false
	weapon = new_weapon
	_cooldown_remaining = maxf(_cooldown_remaining, weapon.attack_cooldown)
	weapon_changed.emit(weapon)
	return true


## Consume el reloj: cooldown, fases del golpe, aturdimiento, invulnerabilidad y
## regeneración de stamina.
func advance(delta: float) -> void:
	if delta <= 0.0:
		return

	if player != null and player.is_dead:
		if phase != CombatState.Kind.DEAD:
			_enter_dead()
	elif phase == CombatState.Kind.DEAD:
		# Reaparecer saca la fase de DEAD sin que nadie tenga que avisar: la
		# muerte es un dato del jugador y el combate lo lee, en vez de conectarse
		# a su señal (dos `RefCounted` conectados son un ciclo que Godot no
		# recolecta).
		_set_phase(CombatState.Kind.FREE)

	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)

	if _dodge_cooldown_remaining > 0.0:
		_dodge_cooldown_remaining = maxf(0.0, _dodge_cooldown_remaining - delta)

	if current_attack != null:
		_attack_elapsed += delta
		_sync_phase()

	if _push_remaining > 0.0:
		_push_remaining = maxf(0.0, _push_remaining - delta)

	if is_dodging:
		_dodge_remaining = maxf(0.0, _dodge_remaining - delta)
		if _dodge_remaining <= 0.0:
			_end_dodge()

	# El trance se cierra antes que el aturdimiento para que, cuando los dos
	# expiran en el mismo fotograma, el que devuelve a IDLE sea el aturdimiento:
	# así el orden de los dos relojes no cambia el estado final.
	if is_reacting:
		_reaction_remaining = maxf(0.0, _reaction_remaining - delta)
		if _reaction_remaining <= 0.0:
			_end_reaction()

	if _invulnerable_remaining > 0.0:
		_invulnerable_remaining = maxf(0.0, _invulnerable_remaining - delta)
		if _invulnerable_remaining <= 0.0:
			invulnerability_changed.emit(false)

	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)
		if _stun_remaining <= 0.0:
			stun_changed.emit(false)
			if player.state == PlayerState.Kind.HURT:
				player.transition_to(PlayerState.Kind.IDLE)

	_refresh_external_velocity()
	_advance_stamina(delta)


func _advance_stamina(delta: float) -> void:
	if player == null or player.is_dead:
		return
	if _regen_delay_remaining > 0.0:
		_regen_delay_remaining = maxf(0.0, _regen_delay_remaining - delta)
		return
	# Regenerar más despacio mientras se golpea: atacar tiene que costar algo.
	var rate := GameConfig.PLAYER_STAMINA_REGEN
	if is_attacking:
		rate *= 0.5
	player.restore_stamina(rate * delta)
