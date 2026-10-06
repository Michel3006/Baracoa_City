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
## Pide reaparición. Lo emite el caso de uso, no la entrada: el juego decide cuándo y
## la tecla solo lo pide.
signal respawn_requested()
signal attack_started(weapon: Weapon, direction: Vector2, window: float)
signal attack_finished()
signal damage_dealt(target: Object, amount: float)
signal player_damaged(amount: float, source: Object)

var player: Player
var combat: MeleeCombat
var view: MainWorldView = null
var npcs: NpcDirector = null

## Segundos que el juego espera antes de aceptar el pedido de reaparición tras morir.
## Sin esto un botón mantenido resucita al instante y se pierde la lectura de qué ha
## pasado.
var _respawn_delay: float = 0.0

## Conexiones con el jugador. Se guardan para poder deshacerlas: conectar señales
## entre dos `RefCounted` crea un ciclo que Godot no recolecta, así que hay que
## romperlo a mano en `shutdown()`.
var _links: Array[Array] = []


func _init() -> void:
	player = Player.new(1, "Jugador")
	combat = MeleeCombat.new(player)
	# El arranque con la piedra en la mano lo dice el inventario, no el combate:
	# si mañana el jugador empieza con otra cosa, se cambia aquí y no en el caso
	# de uso. El combate, que ya llevaba la piedra por defecto, la recibe por esta
	# vía y se queda igual.
	_link(player.inventory.equipped_changed, _on_inventory_equipped)
	_seed_starting_inventory()
	_link(player.state_changed, _forward_state_changed)
	_link(player.health_changed, _forward_health_changed)
	_link(player.stamina_changed, _forward_stamina_changed)
	_link(player.died, _forward_died)
	_link(player.respawned, _forward_respawned)
	_link(combat.attack_started, _forward_attack_started)
	_link(combat.attack_finished, _forward_attack_finished)
	_link(combat.target_hit, _forward_target_hit)
	_link(combat.damaged, _forward_player_damaged)


## La mochila inicial: la piedra, en la mano. `equip_item` dispara la señal que
## engancha el inventario con el combate (la misma vía que usa un objeto recogido
## luego), así que esto no es una excepción del arranque sino el primer uso.
func _seed_starting_inventory() -> void:
	player.inventory.add_item(ItemCatalog.stone(), 1)
	player.inventory.equip_item(ItemCatalog.STONE)


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
	_respawn_delay = GameConfig.RESPAWN_DELAY
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


## Traduce lo que el inventario equipa al arma en mano del combate. Es el puente
## entre la mochila (dominio) y el caso de uso (application): el inventario marca
## la mano y aquí se decide con qué `Weapon` pega. `MeleeCombat.equip()` no se
## toca: es el gancho que ya existía.
func _on_inventory_equipped(item_id: StringName) -> void:
	if combat == null or player == null or player.inventory == null:
		return
	if item_id == &"":
		combat.equip(WeaponCatalog.unarmed())
		return
	var item := player.inventory.get_item(item_id)
	if item == null:
		return
	var weapon_id: Variant = item.metadata.get("weapon", &"")
	if not (weapon_id is StringName) or not WeaponCatalog.exists(weapon_id):
		GameLogger.warning(
			"El objeto %s no tiene arma que equipar" % item_id, "GameSession"
		)
		return
	combat.equip(WeaponCatalog.create(weapon_id))


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


## Mueve el reloj de la sesión.
##
## Solo lleva la cuenta del tiempo que pasa hasta que se puede revivir. Va aparte de
## `apply_motion()` a propósito: el movimiento es un resultado de la física, que
## puede no venir (el jugador quieto) y en los tests se llama a mano sin `delta`.
func advance(delta: float) -> void:
	if delta <= 0.0 or _respawn_delay <= 0.0:
		return
	_respawn_delay = maxf(0.0, _respawn_delay - delta)


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


## Sincroniza el estado de movimiento con lo que ha hecho la física.
##
## El movimiento es dueño de `IDLE` y `MOVING`, y de nada más. `ATTACKING` lo abre y
## lo cierra el combate con su propio reloj, `HURT` el daño y `DEAD` la reaparición.
## Si el movimiento los pisara en cada fotograma, `ATTACKING` duraría un único
## fotograma y el estado del jugador no diría nada de lo que está pasando: que el
## golpe empiece a terminar sin llegar nunca a `IDLE`.
func _sync_motion_state(moved: Vector2) -> void:
	if player.state != PlayerState.Kind.IDLE and player.state != PlayerState.Kind.MOVING:
		return
	player.transition_to(
		PlayerState.Kind.IDLE if moved.is_zero_approx() else PlayerState.Kind.MOVING
	)


## Reaparición tras morir. El caso de uso decide el punto de reaparición;
## la máquina de estados solo refleja el nuevo estado.
func respawn(spawn_position: Vector2 = GameConfig.PLAYER_SPAWN) -> void:
	player.respawn_at(spawn_position)
	teleport_to(spawn_position)
	GameLogger.info("Jugador reapareció en %s" % spawn_position, "GameSession")


## ¿Se puede pedir la reaparición ahora mismo? Solo si el jugador está muerto y ya ha
## pasado el tiempo de espera: en cualquier otro caso el pedido se ignora, que es lo
## que evita que un botón mantenido devuelva vida.
func can_respawn() -> bool:
	return player != null and player.is_dead and _respawn_delay <= 0.0


## Crea el director de NPC y llena la zona. Lo llama la capa Application al ensamblar
## el mundo; el director no sabe nada de vistas.
func setup_npcs(limit: int = -1) -> NpcDirector:
	npcs = NpcDirector.new()
	npcs.populate(NpcSpawnTable.demo(), limit)
	return npcs


## Pide la reaparición. Es el punto de entrada del botón de revivir: el juego decide
## cuándo y dónde, y esta función solo lo hace explícito para poder probarlo.
func request_respawn(spawn_position: Vector2 = GameConfig.PLAYER_SPAWN) -> bool:
	if not can_respawn():
		return false
	respawn_requested.emit()
	respawn(spawn_position)
	return true