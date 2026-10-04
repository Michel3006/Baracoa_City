class_name Player
extends RefCounted

## Modelo de dominio del jugador (sección 8).
##
## Contiene datos y reglas de datos. No sabe nada de sprites, ni de nodos, ni de
## red. La capa Application opera sobre esta clase; la capa Presentation la lee.
##
## Dependencias: domain

signal state_changed(previous: PlayerState.Kind, current: PlayerState.Kind)
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal died()
signal respawned(position: Vector2)
signal moved(position: Vector2, direction: Vector2)

var id: int = 0
var player_name: String = "Player"
var position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.DOWN
var stats: CharacterStats
var health: Health
var stamina: float
var state: PlayerState.Kind = PlayerState.Kind.IDLE


func _init(player_id: int = 0, display_name: String = "Player") -> void:
	id = player_id
	player_name = display_name
	stats = CharacterStats.new({
		"max_health": GameConfig.PLAYER_MAX_HEALTH,
		"max_stamina": GameConfig.PLAYER_MAX_STAMINA,
	})
	health = Health.new(stats.max_health)
	stamina = GameConfig.PLAYER_START_STAMINA
	health.changed.connect(_on_health_changed)
	health.depleted.connect(_on_health_depleted)


var is_dead: bool:
	get:
		return health.is_dead


var is_alive: bool:
	get:
		return not health.is_dead


var stamina_ratio: float:
	get:
		return 0.0 if stats.max_stamina <= 0.0 else stamina / stats.max_stamina


## Aplica daño. Devuelve el daño infligido. Sin efecto si ya estaba muerto.
func take_damage(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	return health.apply_damage(amount)


func heal(amount: float) -> float:
	return health.heal(amount)


## ¿Hay stamina suficiente para pagar `amount`?
func has_stamina(amount: float) -> bool:
	return not is_dead and stamina >= amount


## Gasta stamina. Devuelve lo realmente gastado, que es menos si no había tanto.
func spend_stamina(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var spent := minf(stamina, amount)
	if is_zero_approx(spent):
		return 0.0
	_write_stamina(stamina - spent)
	return spent


## Recupera stamina sin pasar del máximo. Devuelve lo realmente recuperado.
func restore_stamina(amount: float) -> float:
	if amount <= 0.0 or is_dead:
		return 0.0
	var before := stamina
	_write_stamina(minf(stats.max_stamina, stamina + amount))
	return stamina - before


## Cambia de estado validando la transición (sección 8).
## Devuelve `true` si la transición se realizó.
func transition_to(next: PlayerState.Kind) -> bool:
	if state == next:
		return false
	if not PlayerState.can_transition_to(state, next):
		GameLogger.debug(
			"Transición ilegal %s -> %s" % [PlayerState.name_of(state), PlayerState.name_of(next)],
			"Player"
		)
		return false
	var previous := state
	state = next
	state_changed.emit(previous, next)
	return true


## Fija la posición lógica. La versión de red arrival se reemplaza en Fase 2.
func move_to(new_position: Vector2, new_direction: Vector2) -> void:
	if position.is_equal_approx(new_position) and direction.is_equal_approx(new_direction):
		return
	position = new_position
	direction = new_direction
	moved.emit(position, direction)


func respawn_at(new_position: Vector2) -> void:
	position = new_position
	direction = Vector2.DOWN
	health.refill()
	_write_stamina(stats.max_stamina)
	state = PlayerState.Kind.IDLE
	respawned.emit(position)


func snapshot() -> Dictionary:
	return {
		"id": id,
		"name": player_name,
		"position": position,
		"direction": direction,
		"health": health.current,
		"max_health": health.maximum,
		"stamina": stamina,
		"state": state,
	}


func _on_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)


func _on_health_depleted() -> void:
	transition_to(PlayerState.Kind.DEAD)
	died.emit()


## Escribe la stamina y avisa solo si ha cambiado de verdad, como hace `Health`.
func _write_stamina(value: float) -> void:
	var clamped := clampf(value, 0.0, stats.max_stamina)
	if is_equal_approx(clamped, stamina):
		return
	stamina = clamped
	stamina_changed.emit(stamina, stats.max_stamina)