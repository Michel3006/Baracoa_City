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


## Id del ataque en curso, o `&""`. La vista lo usa para elegir clip.
var current_attack_id: StringName:
	get:
		return current_attack.animation_id if current_attack != null else &""


## Duración total del golpe en curso. La decide `AttackDefinition` y la vista la
## usa como reloj de respaldo de la pose.
var current_duration: float:
	get:
		return current_attack.duration if current_attack != null else GameConfig.ATTACK_RECOVERY


## Cuánto deja pasar el movimiento mientras dura el golpe (sección 14). 1.0
## cuando no hay golpe: la marcha normal no se toca.
var movement_multiplier: float:
	get:
		return 1.0 if current_attack == null else current_attack.movement_multiplier


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
	if is_attacking:
		return REASON_BUSY
	if is_stunned:
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
	var power := AttackCatalog.power_of(active, current_attack)
	if not DamageRules.is_valid_attack(power):
		return 0
	var hits := 0
	for target in targets:
		if not DamageRules.is_damageable(target):
			continue
		var damageable := target as Object
		var defense := DamageRules.defense_of(damageable)
		var dealt := float(damageable.call(&"take_damage", DamageRules.compute(power, defense)))
		if dealt > 0.0:
			hits += 1
			target_hit.emit(damageable, dealt)
	return hits


## Daño recibido. Aplica la fórmula con la defensa del jugador, aturde y concede
## invulnerabilidad para que un golpe no se repita cada frame.
## Devuelve el daño realmente infligido.
func receive_damage(raw_damage: float, source: Object = null) -> float:
	if player == null or player.is_dead or is_invulnerable:
		return 0.0
	var dealt := player.take_damage(DamageRules.compute(raw_damage, player.stats.defense))
	if dealt <= 0.0:
		return 0.0
	grant_invulnerability()
	apply_stun()
	damaged.emit(dealt, source)
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

	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)

	if current_attack != null:
		_attack_elapsed += delta
		_sync_phase()

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
