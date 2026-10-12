class_name NpcCombat
extends RefCounted

## Combate cuerpo a cuerpo de un NPC (secciones 7, 9, 10 y 18).
##
## Es el equivalente de `MeleeCombat` para el otro lado del golpe. No hereda de él a
## propósito: los dos son caso de uso y el NPC no tiene inventario, ni armas
## intercambiables, ni stamina. Lo que sí comparte con el jugador son las reglas de
## daño, y eso ya vive en `DamageRules`, que es el sitio correcto.
##
## Lo que decide, y es exactamente lo mismo que decide `MeleeCombat`: si un golpe
## sale, cuándo puede volver a salir, cuánto hace y con qué invulnerabilidad.
##
## También como `MeleeCombat`, es el cuerpo de combate que la vista expone a la
## hitbox del otro lado: el golpe del jugador entra por `take_damage`, que es lo
## único que concede invulnerabilidad y aturdimiento. Esa es la ley del juego:
## todo ser que recibe daño se tiñe de rojo mientras dura su invulnerabilidad, y
## eso solo pasa si el daño entra por aquí y no por el `Npc` pelado.
##
## El tiempo lo mueve quien lo llama con `advance(delta)`, igual que en el resto de
## casos de uso, para que sea determinista y probable sin escena.
##
## Dependencias: application -> domain, infrastructure/configuration

signal attack_started(direction: Vector2, window: float)
signal attack_window_closed()
signal attack_finished()
signal target_hit(target: Object, damage: float)
signal damaged(amount: float, source: Object)
signal invulnerability_changed(active: bool)
signal died()
## Sube al aturdir y baja al expirar, igual que en `MeleeCombat`. La vista lo
## usa para teñir el cuerpo con `STUN_TINT` mientras el NPC está aturdido.
signal stun_changed(active: bool)
## Reacción al recibir un golpe (sección 25): qué clip hay que reproducir y cuánto
## dura. Gemela de la señal de `MeleeCombat`: el sistema de reacciones es el mismo
## para las dos puntas del golpe.
signal reaction_started(clip: StringName, duration: float)
signal reaction_finished()

var npc: Npc
var behavior: NpcBehavior

var _cooldown_remaining: float = 0.0
var _attack_remaining: float = 0.0
var _window_remaining: float = 0.0
var _invulnerable_remaining: float = 0.0
var _stun_remaining: float = 0.0

## Trance por golpe recibido (secciones 25-26). El reloj es del cuerpo que recibe,
## igual que en el jugador: la señal de fin no puede depender de la IA.
var _reaction_remaining: float = 0.0
var _reaction_clip: StringName = &""
var _reaction_move_mult: float = 1.0

## Empuje del knockback (sección 27), con el mismo decaimiento lineal que el del
## jugador. La IA no lo escribe: solo lo lee el presentador para sumarlo.
var _push_velocity: Vector2 = Vector2.ZERO
var _push_remaining: float = 0.0

## Velocidad externa del fotograma (solo empuje: los NPC no ruedan). La lee
## `NpcPresenter` y la suma a la intención de la IA.
var external_velocity: Vector2 = Vector2.ZERO


func _init(body: Npc = null) -> void:
	npc = body
	behavior = npc.behavior if npc != null else NpcBehavior.new()


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


## ¿Está en trance por un golpe recibido? Mientras dure, la IA no lo mueve ni
## ataca: el cuerpo responde al golpe, no a la persecución.
var is_reacting: bool:
	get:
		return _reaction_remaining > 0.0


## Clip de golpe que la vista debe reproducir, o `&""`.
var reaction_clip: StringName:
	get:
		return _reaction_clip if is_reacting else &""


## Cuánto deja moverse la reacción, para que `NpcPresenter` lo aplique a la
## intención de la IA.
var movement_multiplier: float:
	get:
		return _reaction_move_mult if is_reacting else 1.0


## Posición del cuerpo que pelea: la lee el atacante para saber hacia dónde sale
## el empuje, igual que en `MeleeCombat`.
var position: Vector2:
	get:
		return Vector2.ZERO if npc == null else npc.position


var is_dead: bool:
	get:
		return npc == null or npc.is_dead


## Estadísticas de quien pelea. `DamageRules` las busca para leer la defensa, de
## modo que el cuerpo de combate del NPC sirve como objetivo válido igual que el
## del jugador.
var stats: CharacterStats:
	get:
		return null if npc == null else npc.stats


## Para la UI de depuración: cuánto le falta al próximo golpe.
var cooldown_ratio: float:
	get:
		if behavior.attack_cooldown <= 0.0:
			return 0.0
		return clampf(_cooldown_remaining / behavior.attack_cooldown, 0.0, 1.0)


## ¿Puede iniciar un golpe ahora mismo? No consume nada: solo consulta.
func can_attack() -> bool:
	return rejection_reason().is_empty()


## Motivo por el que no se puede atacar, o cadena vacía si sí se puede. Los mismos
## motivos que usa `MeleeCombat`, con los mismos nombres: son las reglas del
## combate, no del jugador.
func rejection_reason() -> StringName:
	if npc == null or npc.is_dead:
		return MeleeCombat.REASON_DEAD
	if is_attacking:
		return MeleeCombat.REASON_BUSY
	if is_stunned or is_reacting:
		return MeleeCombat.REASON_STUNNED
	if _cooldown_remaining > 0.0:
		return MeleeCombat.REASON_COOLDOWN
	return &""


## Inicia un golpe. Devuelve `true` si sale.
func try_attack(direction: Vector2) -> bool:
	if not rejection_reason().is_empty():
		return false
	_cooldown_remaining = behavior.attack_cooldown
	_attack_remaining = GameConfig.ATTACK_RECOVERY
	_window_remaining = behavior.attack_cooldown * GameConfig.HITBOX_ACTIVE_RATIO
	npc.direction = direction
	attack_started.emit(direction, _window_remaining)
	return true


## Aplica el golpe a los objetivos que la hitbox ha encontrado. Devuelve cuántos han
## recibido daño.
##
## Entra por la misma puerta que el golpe del jugador (`take_attack` si el objetivo
## la tiene): así un NPC también puede chocar contra la guardia o la rodada del
## jugador, y el trance del que recibe se deduce de su propio daño. Sin ataque que
## enseñar (`null`), el defensor saca los tiers de la cantidad.
func strike(targets: Array) -> int:
	if not is_window_open:
		return 0
	var hits := 0
	for target in targets:
		if not DamageRules.is_damageable(target):
			continue
		var damageable := target as Object
		var defense := DamageRules.defense_of(damageable)
		var damage := DamageRules.compute(behavior.attack_damage, defense)
		var dealt := _apply_to(damageable, damage)
		if dealt > 0.0:
			hits += 1
			target_hit.emit(damageable, dealt)
	return hits


## Mete el golpe en un objetivo, por `take_attack` si sabe de reacciones y por
## `take_damage` si no. La cantidad va con la defensa ya aplicada.
func _apply_to(damageable: Object, damage: float) -> float:
	if damageable.has_method(&"take_attack"):
		return float(damageable.call(&"take_attack", null, damage, _impact_of(damageable)))
	return float(damageable.call(&"take_damage", damage))


## Dirección del empuje: del NPC hacia el objetivo. Si el objetivo no expone dónde
## está, se usa la mirada del NPC.
func _impact_of(target: Object) -> Vector2:
	var from := position
	var to := from
	if "position" in target:
		var value: Variant = target.get(&"position")
		if value is Vector2:
			to = value
	var fallback := npc.direction if npc != null else Vector2.DOWN
	return CombatReaction.impact_direction(from, to, fallback)


## Daño recibido. Aplica la fórmula con la defensa del NPC y concede
## invulnerabilidad para que seis enemigos no maten al jugador en el mismo frame.
func receive_damage(raw_damage: float, source: Object = null) -> float:
	if npc == null or npc.is_dead or is_invulnerable:
		return 0.0
	return _receive_computed(
		DamageRules.compute(raw_damage, behavior.defense), Vector2.ZERO, source
	)


## Entrada rica del golpe recibido (secciones 25-27), para que el jugador pueda
## empujar y hacer reaccionar a un enemigo: `amount` ya viene calculado por el
## atacante, así que aquí no se vuelve a aplicar la defensa.
func take_attack(
	_attack: AttackDefinition, amount: float, impact: Vector2 = Vector2.ZERO
) -> float:
	if npc == null or npc.is_dead or is_invulnerable:
		return 0.0
	return _receive_computed(amount, impact, null)


## La misma entrada de daño, con el nombre que espera `DamageRules`.
##
## Existe para que el cuerpo de combate del NPC sea un objetivo válido tal cual:
## el jugador no debería conocer `Npc` ni saltarse la invulnerabilidad llamando a
## `take_damage` directamente. La cantidad ya viene calculada por el atacante
## (`DamageRules.compute` contra la defensa de este cuerpo, en
## `MeleeCombat.strike`), así que aquí no se vuelve a aplicar la defensa: lo que
## hace este método es respetar la ventana de invulnerabilidad, aturdir y avisar.
## Sin esta entrada el golpe del jugador quitaba vida sin tinte rojo: el NPC nunca
## se enteraba de que le habían pegado.
func take_damage(amount: float) -> float:
	if npc == null or npc.is_dead or is_invulnerable:
		return 0.0
	return _receive_computed(amount, Vector2.ZERO, null)


## Núcleo del daño recibido, común a las tres entradas: quita vida, concede
## invulnerabilidad, aturde, empuja y levanta la reacción. La reacción se deduce
## del daño (`attack` nulo) porque los NPC no llevan catálogo de ataques: su
## variedad de golpes es trabajo de más adelante, pero el trance que levantan es
## el mismo sistema que el del jugador.
func _receive_computed(amount: float, impact: Vector2, source: Object) -> float:
	if npc == null or npc.is_dead or is_invulnerable or amount <= 0.0:
		return 0.0
	var dealt := npc.take_damage(amount)
	if dealt <= 0.0:
		return 0.0
	grant_invulnerability()
	apply_stun()
	damaged.emit(dealt, source)
	if not npc.is_dead:
		_start_reaction(dealt, impact)
	return dealt


## Arranca el trance del NPC. Corta su golpe en curso si lo tenía: el que recibe
## manda, y su ataque se pierde como se pierde el del jugador.
func _start_reaction(damage: float, impact: Vector2) -> void:
	var plan := CombatReaction.plan(null, damage)
	if is_attacking:
		_interrupt_attack()
	_reaction_remaining = float(plan["time"])
	_reaction_clip = plan["clip"]
	_reaction_move_mult = float(plan["movement_multiplier"])
	_push(impact, float(plan["force"]))
	reaction_started.emit(_reaction_clip, _reaction_remaining)


## Fin del trance: el NPC vuelve a estar disponible para su IA, que comprueba
## `is_reacting` cada fotograma.
func _end_reaction() -> void:
	_reaction_remaining = 0.0
	_reaction_clip = &""
	_reaction_move_mult = 1.0
	reaction_finished.emit()


## Corta el golpe del NPC sin esperar a su reloj, emitiendo las dos señales en el
## mismo orden que si hubiera terminado solo (ventana y fin), para que la vista y
## la hitbox queden como si el golpe hubiera acabado.
func _interrupt_attack() -> void:
	if _window_remaining > 0.0:
		_window_remaining = 0.0
		attack_window_closed.emit()
	if _attack_remaining > 0.0:
		_attack_remaining = 0.0
		attack_finished.emit()


## Arranca un empuje con la fuerza dada, en píxeles por segundo.
func _push(impact: Vector2, force: float) -> void:
	if force <= 0.0 or impact.is_zero_approx():
		return
	_push_velocity = impact.normalized() * force
	_push_remaining = GameConfig.KNOCKBACK_TIME
	_refresh_external_velocity()


## Recalcula el empuje del fotograma: decae en línea recta hasta cero durante
## `KNOCKBACK_TIME`, y sin empuje pendiente no hay velocidad externa.
func _refresh_external_velocity() -> void:
	if _push_remaining > 0.0:
		external_velocity = _push_velocity * (_push_remaining / GameConfig.KNOCKBACK_TIME)
		return
	external_velocity = Vector2.ZERO


func grant_invulnerability(duration: float = -1.0) -> void:
	var time := behavior.invulnerability_time if duration < 0.0 else duration
	if time <= 0.0:
		return
	var was := is_invulnerable
	_invulnerable_remaining = maxf(_invulnerable_remaining, time)
	if not was:
		invulnerability_changed.emit(true)


## Aturdimiento: el NPC se queda quieto un instante. `NpcBrain` lo consulta para no
## moverse mientras lo están golpeando.
func apply_stun(duration: float = -1.0) -> void:
	var time := behavior.hurt_stun_time if duration < 0.0 else duration
	if time <= 0.0 or npc == null or npc.is_dead:
		return
	var was_stunned := is_stunned
	_stun_remaining = maxf(_stun_remaining, time)
	if not was_stunned:
		stun_changed.emit(true)


## Consume el reloj: cooldown, ventana, aturdimiento e invulnerabilidad.
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
			attack_finished.emit()
	if _push_remaining > 0.0:
		_push_remaining = maxf(0.0, _push_remaining - delta)
	if is_reacting:
		_reaction_remaining = maxf(0.0, _reaction_remaining - delta)
		if _reaction_remaining <= 0.0:
			_end_reaction()
	_refresh_external_velocity()
	if _invulnerable_remaining > 0.0:
		_invulnerable_remaining = maxf(0.0, _invulnerable_remaining - delta)
		if _invulnerable_remaining <= 0.0:
			invulnerability_changed.emit(false)
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)
		if _stun_remaining <= 0.0:
			stun_changed.emit(false)
