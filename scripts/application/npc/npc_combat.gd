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

var npc: Npc
var behavior: NpcBehavior

var _cooldown_remaining: float = 0.0
var _attack_remaining: float = 0.0
var _window_remaining: float = 0.0
var _invulnerable_remaining: float = 0.0
var _stun_remaining: float = 0.0


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
	if is_stunned:
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
func strike(targets: Array) -> int:
	if not is_window_open:
		return 0
	var hits := 0
	for target in targets:
		if not DamageRules.is_damageable(target):
			continue
		var damageable := target as Object
		var defense := DamageRules.defense_of(damageable)
		var dealt := float(
			damageable.call(&"take_damage", DamageRules.compute(behavior.attack_damage, defense))
		)
		if dealt > 0.0:
			hits += 1
			target_hit.emit(damageable, dealt)
	return hits


## Daño recibido. Aplica la fórmula con la defensa del NPC y concede
## invulnerabilidad para que seis enemigos no maten al jugador en el mismo frame.
func receive_damage(raw_damage: float, source: Object = null) -> float:
	if npc == null or npc.is_dead or is_invulnerable:
		return 0.0
	var dealt := npc.take_damage(DamageRules.compute(raw_damage, behavior.defense))
	if dealt <= 0.0:
		return 0.0
	grant_invulnerability()
	apply_stun()
	damaged.emit(dealt, source)
	return dealt


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
	if amount <= 0.0:
		return 0.0
	var dealt := npc.take_damage(amount)
	if dealt <= 0.0:
		return 0.0
	grant_invulnerability()
	apply_stun()
	damaged.emit(dealt, null)
	return dealt


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
	_stun_remaining = maxf(_stun_remaining, time)


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
	if _invulnerable_remaining > 0.0:
		_invulnerable_remaining = maxf(0.0, _invulnerable_remaining - delta)
		if _invulnerable_remaining <= 0.0:
			invulnerability_changed.emit(false)
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)
