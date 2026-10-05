extends Node

## Autoload `Game`: composition root y punto de entrada de la capa Application.
##
## Responsabilidades (secciones 4.2 y 34):
## - configurar logging y configuración;
## - construir el bus de eventos;
## - construir los casos de uso y enchufar la escena del mundo.
##
## NO contiene reglas de juego. No es un `GameManager` que controle todo: solo
## conoce las piezas en el momento de ensamblarlas y después suelta las referencias.
##
## ## Qué se engancha aquí y por qué
##
## Tres piezas nuevas: el director de NPC, el repartidor de objetivos y el botón de
## revivir. Las tres están aquí porque son cableado puro: quién depende de quién ya
## está decidido en las clases, y aquí solo se conectan los cables. Si cualquiera de
## estas tres decisiones viviera aquí, esto sería un `GameManager` y no un raíz de
## composición.
##
## Dependencias: infrastructure/configuration, infrastructure/logging,
##               domain/events, application, presentation/world

const GameSession := preload("res://scripts/application/game_session.gd")
const MovementController := preload("res://scripts/application/player/movement_controller.gd")
const MainWorldView := preload("res://scripts/presentation/world/main_world_view.gd")

## Versión del contenido. Se incrementa cuando los datos guardados dejan de ser válidos.
const CONTENT_VERSION := 1

## Acción de entrada que pide la reaparición. Es la tecla de reaparición: la de
## interactuar, porque en una pantalla de muerte no hay nada con lo que interactuar.
const ACTION_RESPAWN := &"interact"

var events: GameEvents
var session: GameSession
var movement: MovementController
var world_view: MainWorldView
var respawn_input: RespawnInput
var target_refresh: Timer


func _ready() -> void:
	GameLogger.configure()
	GameLogger.info("Game iniciado (contenido v%d)" % CONTENT_VERSION, "Game")

	events = GameEvents.new()
	add_child(events)

	session = GameSession.new()
	movement = MovementController.new()
	movement.move_performed.connect(_on_move_performed)
	session.player_died.connect(_on_player_died)
	session.player_respawned.connect(_on_player_respawned)
	session.start()

	# Los enemigos se crean antes que la escena del mundo: `MainWorldView` avisa de
	# que el jugador está listo mientras se construye, y para ese aviso ya tiene que
	# saber cuántos enemigos hay en la zona.
	_build_npcs()
	_build_world_view()
	_build_respawn_input()
	_build_target_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().quit()


## Suelta las referencias al terminar. Sin esto, el dominio sigue vivo cuando el
## proceso termina y Godot reporta fugas en cada ejecución headless.
func _exit_tree() -> void:
	if session != null:
		# El director de NPC primero: sus señales apuntan al presentador, que a su
		# vez apunta al dominio. Sueltarlos en orden inverso es lo que evita el ciclo.
		if session.npcs != null:
			session.npcs.shutdown()
		session.shutdown()
	session = null
	movement = null
	world_view = null
	respawn_input = null
	target_refresh = null
	events = null


## Ensambla la escena del mundo. La señal se conecta antes de añadir el nodo al
## árbol, porque `_ready()` emite `player_spawned` al construirse el jugador.
func _build_world_view() -> void:
	world_view = MainWorldView.new()
	world_view.name = "MainWorldView"
	world_view.player_spawned.connect(_on_player_spawned)
	add_child(world_view)
	# Los cuerpos de los enemigos cuelgan de la escena del mundo, así que se
	# conectan después de que exista: aquí es donde Application y Presentation se
	# tocan, y en ningún otro sitio.
	if session.npcs != null:
		world_view.setup_npcs(session.npcs)


## Crea los enemigos. El director es de Application y no sabe nada de vistas: se
## guarda para conectarlo a la escena en cuanto exista.
func _build_npcs() -> void:
	session.setup_npcs()


func _build_respawn_input() -> void:
	respawn_input = RespawnInput.new()
	respawn_input.name = "RespawnInput"
	respawn_input.bind(session)
	add_child(respawn_input)


## Reparte el objetivo entre los enemigos cada `NPC_TARGET_REFRESH` segundos.
##
## Va con un reloj propio y no atado al movimiento del jugador porque el reparto tiene
## que pasar también mientras el jugador está quieto. Con el reparto colgado del
## movimiento, quedarse parado en mitad de la zona hacía que ningún enemigo lo
## persiguiera: no es que fueran pacíficos, es que nadie les decía a quién.
func _build_target_refresh() -> void:
	target_refresh = Timer.new()
	target_refresh.name = "TargetRefresh"
	target_refresh.wait_time = GameConfig.NPC_TARGET_REFRESH
	target_refresh.autostart = true
	target_refresh.timeout.connect(_distribute_target)
	add_child(target_refresh)


## Dice a los enemigos quién es el jugador y a cuál le toca perseguir ahora. Solo
## reparte: el reloj de cada enemigo lo mueve su propio presentador.
func _distribute_target() -> void:
	if session == null or session.npcs == null or world_view == null:
		return
	if world_view.npc_spawner == null:
		return
	# La posición del dominio es la fuente de verdad: la vista no la inventa.
	world_view.npc_spawner.distribute_target(session.player.position)


func _on_player_spawned(player: PlayerView) -> void:
	movement.bind(player)
	session.bind_view(world_view)
	world_view.connect_cases(movement, session.combat)
	if player.combat_target == null:
		player.combat_target = session.combat
	if world_view.hud != null:
		world_view.hud.bind(session)
	GameLogger.info(
		"Jugador listo en %s (%d NPC en la zona)" % [
			player.global_position,
			session.npcs.count() if session.npcs != null else 0,
		],
		"Game"
	)


## El dominio es la fuente de verdad de la posición: la vista no la inventa.
func _on_move_performed(_velocity: Vector2, moved: Vector2) -> void:
	session.apply_motion(moved, movement.facing())
	# El reparto también ocurre en cada vuelta del reloj de objetivos: atado solo al
	# movimiento, un jugador quieto no lo perseguiría nadie. Se hace aquí además para
	# que el enemigo reaccione en el mismo fotograma en que el jugador entra en su
	# radio de detección, sin esperar al siguiente tic del reloj.
	_distribute_target()


func _on_player_died() -> void:
	movement.set_enabled(false)
	GameLogger.info("Jugador muerto: movimiento bloqueado", "Game")


func _on_player_respawned(_spawn: Vector2) -> void:
	movement.set_enabled(true)
	# El jugador ha cambiado de sitio de golpe: los enemigos tienen que recalcular al
	# instante quién lo persigue, no dentro de un tenth de segundo con un enemigo
	# todavía girado hacia donde estaba el cadáver.
	_distribute_target()