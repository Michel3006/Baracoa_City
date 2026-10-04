class_name GameSession
extends RefCounted

## Caso de uso: ciclo de vida de la sesión de juego (sección 4.2).
##
## Es el composition root del dominio: construye `Player`, `Health` y
## `CharacterStats` a partir de la configuración, y traduce sus señales a eventos
## de presentación sin conocer la UI.
##
## Dependencias: application -> domain, infrastructure/configuration

signal player_ready(player: Player)
signal player_state_changed(previous: PlayerState.Kind, current: PlayerState.Kind)
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal player_died()
signal player_respawned(position: Vector2)
signal attack_started(weapon: Weapon, direction: Vector2, window: float)
signal attack_finished()
signal damage_dealt(target: Object, amount: float)
signal player_damaged(amount: float, source: Object)

var player: Player
var combat: MeleeCombat
var view: MainWorldView = null

## Conexiones con el jugador. Se guardan para poder deshacerlas: conectar señales
## entre dos `RefCounted` crea un ciclo que Godot no recolecta, así que hay que
## romperlo a mano en `shutdown()`.
var _links: Array[Array] = []


func _init() -> void:
	player = Player.new(1, "Jugador")
	combat = MeleeCombat.new(player)
	_link(player.state_changed, _forward_state_changed)
	_link(player.health_changed, _forward_health_changed)
	_link(player.stamina_changed, _forward_stamina_changed)
	_link(player.died, _forward_died)
	_link(player.respawned, _forward_respawned)
	_link(combat.attack_started, _forward_attack_started)
	_link(combat.attack_finished, _forward_attack_finished)
	_link(combat.target_hit, _forward_target_hit)
	_link(combat.damaged, _forward_player_damaged)


func _link(source: Signal, target: Callable) -> void:
	source.connect(target)
	_links.append([source, target])


func shutdown() -> void:
	for link: Array in _links:
		(link[0] as Signal).disconnect(link[1] as Callable)
	_links.clear()
	view = null
	combat = null
	player = null


func _forward_state_changed(previous: PlayerState.Kind, current: PlayerState.Kind) -> void:
	player_state_changed.emit(previous, current)


func _forward_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)


func _forward_stamina_changed(current: float, maximum: float) -> void:
	stamina_changed.emit(current, maximum)


func _forward_died() -> void:
	player_died.emit()


func _forward_respawned(spawn: Vector2) -> void:
	player_respawned.emit(spawn)


func _forward_attack_started(weapon: Weapon, direction: Vector2, window: float) -> void:
	attack_started.emit(weapon, direction, window)


func _forward_attack_finished() -> void:
	attack_finished.emit()


func _forward_target_hit(target: Object, amount: float) -> void:
	damage_dealt.emit(target, amount)


func _forward_player_damaged(amount: float, source: Object) -> void:
	player_damaged.emit(amount, source)


## Crea el jugador y lo deja listo para jugar en `spawn_position`.
func start(spawn_position: Vector2 = GameConfig.PLAYER_SPAWN) -> Player:
	player.position = spawn_position
	GameLogger.info(
		" Sesión iniciada: %s (vida %d, stamina %d)" % [
			player.player_name,
			int(player.health.maximum),
			int(player.stats.max_stamina)
		],
		"GameSession"
	)
	player_ready.emit(player)
	return player


## Coloca al jugador en una posición concreta y sincroniza la vista.
##
## Todo teleportación (herramienta de desarrollo, cambio de zona, reaparición)
## pasa por aquí, de modo que dominio y vista nunca quedan desalineados.
func teleport_to(target: Vector2) -> void:
	player.move_to(target, player.direction)
	if view != null:
		view.move_player_to(target)


## Inyecta la vista que esta sesión debe sincronizar al teleportar.
func bind_view(world_view: MainWorldView) -> void:
	view = world_view


## Traduce el desplazamiento resuelto por la física al modelo de dominio.
##
## Es el único punto donde la posición real del jugador entra en el dominio. En
## la Fase 2, el servidor será quien llame a este método en lugar de la física local,
## y ni la vista ni el resto del dominio se enteran del cambio.
func apply_motion(moved: Vector2, direction: Vector2) -> void:
	if player.is_dead:
		return
	player.move_to(player.position + moved, direction)
	_sync_motion_state(moved)


func _sync_motion_state(moved: Vector2) -> void:
	if moved.is_zero_approx():
		player.transition_to(PlayerState.Kind.IDLE)
	else:
		player.transition_to(PlayerState.Kind.MOVING)


## Reaparición tras morir. El caso de uso decide el punto de reaparición;
## la máquina de estados solo refleja el nuevo estado.
func respawn(spawn_position: Vector2 = GameConfig.PLAYER_SPAWN) -> void:
	player.respawn_at(spawn_position)
	GameLogger.info("Jugador reapareció en %s" % spawn_position, "GameSession")