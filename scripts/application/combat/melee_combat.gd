class_name MeleeCombat
extends RefCounted

## Caso de uso: combate cuerpo a cuerpo (secciones 4.2, 9 y 10).
##
## Es el único sitio que decide si un golpe sale, cuándo puede volver a salir y
## cuánto daño hace. No sabe nada de sprites ni de nodos: la capa Presentation le
## dice qué ha encontrado la hitbox y esta clase aplica las reglas.
##
## El tiempo lo mueve quien lo llama con `advance(delta)`, igual que
## `MovementController`. Así el caso de uso es determinista y se puede probar sin
## escena.
##
## Dependencias: application -> domain, infrastructure/configuration

signal attack_started(weapon: Weapon, direction: Vector2, window: float)
signal attack_window_closed()
signal attack_finished()
signal attack_rejected(reason: StringName)
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


var _cooldown_remaining: float = 0.0
## Cooldown total del último golpe, para que la barra de la UI mida contra el arma
## que se usó y no contra la que se lleva encima ahora.
var _cooldown_total: float = 0.0
var _attack_remaining: float = 0.0
var _window_remaining: float = 0.0
var _invulnerable_remaining: float = 0.0
var _stun_remaining: float = 0.0
var _regen_delay_remaining: float = 0.0


func _init(body: Player, starting_weapon: Weapon = null) -> void:
	player = body
	weapon = starting_weapon if starting_weapon != null else WeaponCatalog.default_weapon()
	unarmed = WeaponCatalog.unarmed()


var is_attacking: bool:
	get:
		return _attack_remaining > 0.0


var is_window_open: bool:
	get:
		return _window_remaining > 0.0


var is_invulnerable: bool:
	get:
		return _invulnerable_remaining > 0.0


var is_stunned: bool:
	get:
		return _stun_remaining > 0.0


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
	if not player.has_stamina(active.stamina_cost):
		return REASON_NO_STAMINA
	return &""


## El arma con la que se va a pegar: la equipada, o los puños si se pide sin arma.
## `try_attack()` es quien llama a esto, así que durante un golpe siempre devuelve
## el arma que ya está en la mano y no vuelve a cambiar a mitad de animación.
func active_weapon(wants_unarmed: bool) -> Weapon:
	if wants_unarmed and unarmed != null:
		return unarmed
	return weapon


## Inicia un golpe. Devuelve `true` si sale.
##
## Paga stamina, entra en ATTACKING y abre la ventana de hitbox durante una
## fracción del cooldown. La hitbox la enciende Presentation con la señal
## `attack_started`.
##
## `unarmed = true` pega a puños sin tocar el arma equipada: es la vía del
## combate cuerpo a cuerpo sin arma. Los dos caminos comparten exactamente las
## mismas reglas, así que no hay dos versiones del combate que mantener.
func try_attack(direction: Vector2 = Vector2.DOWN, unarmed: bool = false) -> bool:
	var reason := rejection_reason()
	if not reason.is_empty():
		attack_rejected.emit(reason)
		return false
	var active := active_weapon(unarmed)

	player.spend_stamina(active.stamina_cost)
	_regen_delay_remaining = GameConfig.STAMINA_REGEN_DELAY
	_cooldown_remaining = active.attack_cooldown
	_cooldown_total = active.attack_cooldown
	_attack_remaining = GameConfig.ATTACK_RECOVERY
	_window_remaining = active.attack_cooldown * GameConfig.HITBOX_ACTIVE_RATIO

	player.direction = direction
	if not player.transition_to(PlayerState.Kind.ATTACKING):
		# ATTACKING no es legal desde DEAD, pero un HURT reciente puede dejar al
		# jugador en un estado raro: el golpe ya se ha pagado, así que se acepta
		# y solo se avisa.
		GameLogger.debug(
			"No se pudo entrar en ATTACKING desde %s" % PlayerState.name_of(player.state),
			"MeleeCombat"
		)

	attack_started.emit(active, direction, _window_remaining)
	return true


## Aplica el golpe a los objetivos que la hitbox ha encontrado.
##
## Recibe objetos de dominio, no nodos: la física solo decide a quién ha tocado la
## hitbox, nunca cuánto daño se le hace. Devuelve cuántos han recibido daño.
##
## El daño usa el arma del golpe en curso, no `weapon`: si el último golpe fue a
## puños, lo que se aplica son los puños.
func strike(targets: Array, used_unarmed: bool = false) -> int:
	if not is_window_open or weapon == null:
		return 0
	var active := active_weapon(used_unarmed)
	if active == null:
		return 0
	var hits := 0
	for target in targets:
		if not DamageRules.is_damageable(target):
			continue
		var damageable := target as Object
		var defense := DamageRules.defense_of(damageable)
		var dealt := float(damageable.call(&"take_damage", active.damage_against(defense)))
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


## Consume el reloj: cooldown, ventana de golpe, aturdimiento, invulnerabilidad y
## regeneración de stamina.
func advance(delta: float) -> void:
	if delta <= 0.0:
		return

	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)

	if _window_remaining > 0.0:
		_window_remaining = maxf(0.0, _window_remaining - delta)
		if _window_remaining <= 0.0:
			attack_window_closed.emit()

	if _attack_remaining > 0.0:
		_attack_remaining = maxf(0.0, _attack_remaining - delta)
		if _attack_remaining <= 0.0:
			# El reloj es la autoridad de "el golpe ha terminado", y la señal sale
			# siempre. Antes solo salía si el jugador seguía en `ATTACKING`, pero el
			# movimiento lo sacaba de `ATTACKING` en el fotograma siguiente al golpe
			# (`GameSession._sync_motion_state()`), así que la señal no salía nunca:
			# la vista se quedaba en la pose de golpe para siempre y el jugador, ya de
			# pie, caminaba con el cuerpo congelado en el arco y el arma torcida. La
			# transición del estado sí es condicional, porque ahi puede haberse metido
			# otro sistema (por ejemplo `HURT` al recibir daño a mitad de golpe).
			if player.state == PlayerState.Kind.ATTACKING:
				player.transition_to(PlayerState.Kind.IDLE)
			attack_finished.emit()

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
