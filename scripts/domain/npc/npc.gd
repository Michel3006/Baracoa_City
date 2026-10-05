class_name Npc
extends RefCounted

## Modelo de dominio de un NPC (secciones 9 y 18).
##
## `stats`, `state`, `position` y `behavior`, que es la estructura que pide la
## especificación. Como el jugador, son datos puros: sin nodos, sin sprites y sin
## red. `Health` y `CharacterStats` son los mismos que usa el jugador, así que un
## enemigo y el jugador se comportan igual ante el mismo daño.
##
## La IA no está aquí: el estado lo decide `NpcBrain`, que vive en Application.
##
## Dependencias: domain

signal state_changed(previous: NpcState.Kind, current: NpcState.Kind)
signal health_changed(current: float, maximum: float)
signal died()
signal moved(position: Vector2, direction: Vector2)

var id: int = 0
var display_name: String = "NPC"
## Id del tipo de enemigo. Lo usa la presentación para elegir hoja de sprites.
var kind: StringName = &"slime"
## Puesto de arranque y límite hasta el que se aleja de él. La correa es lo que
## impide que un enemigo deje al NPC persiguiendo al jugador hasta el otro mapa.
var home: Vector2 = Vector2.ZERO
var position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.DOWN
var stats: CharacterStats
var health: Health
var state: NpcState.Kind = NpcState.Kind.IDLE
## Comportamiento: estadísticas de IA, no lógica. Ver `NpcBehavior`.
var behavior: NpcBehavior


func _init(npc_id: int = 0, display_name: String = "NPC", behavior: NpcBehavior = null) -> void:
	id = npc_id
	self.display_name = display_name
	self.behavior = behavior if behavior != null else NpcBehavior.new()
	stats = CharacterStats.new({
		"max_health": self.behavior.max_health,
		"move_speed": self.behavior.move_speed,
		"defense": self.behavior.defense,
	})
	health = Health.new(stats.max_health)
	health.changed.connect(_on_health_changed)
	health.depleted.connect(_on_health_depleted)


var is_dead: bool:
	get:
		return health.is_dead or state == NpcState.Kind.DEAD


var is_alive: bool:
	get:
		return not is_dead


var health_ratio: float:
	get:
		return health.ratio


## Distancia al punto de origen. Sirve para la correa de la IA.
var distance_from_home: float:
	get:
		return position.distance_to(home)


## Aplica daño. Devuelve el daño infligido. Sin efecto si ya estaba muerto.
func take_damage(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	return health.apply_damage(amount)


func heal(amount: float) -> float:
	return health.heal(amount)


## Cambia de estado validando la transición (sección 18).
func transition_to(next: NpcState.Kind) -> bool:
	if state == next:
		return false
	if not NpcState.can_transition_to(state, next):
		GameLogger.debug(
			"Transición ilegal %s -> %s" % [NpcState.name_of(state), NpcState.name_of(next)],
			"Npc"
		)
		return false
	var previous := state
	state = next
	state_changed.emit(previous, next)
	return true


## Fija la posición lógica. En Fase 2 la sobrescribe la autoridad del servidor.
func move_to(new_position: Vector2, new_direction: Vector2 = direction) -> void:
	if position.is_equal_approx(new_position) and direction.is_equal_approx(new_direction):
		return
	position = new_position
	direction = new_direction
	moved.emit(position, direction)


func respawn_at(new_position: Vector2) -> void:
	position = new_position
	home = new_position
	direction = Vector2.DOWN
	health.refill()
	state = NpcState.Kind.IDLE


func snapshot() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"kind": kind,
		"position": position,
		"direction": direction,
		"health": health.current,
		"max_health": health.maximum,
		"state": state,
	}


func _on_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)


func _on_health_depleted() -> void:
	transition_to(NpcState.Kind.DEAD)
	died.emit()
