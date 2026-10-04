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
## Dependencias: infrastructure/configuration, infrastructure/logging,
##               domain/events, application, presentation/world

const GameSession := preload("res://scripts/application/game_session.gd")
const MovementController := preload("res://scripts/application/player/movement_controller.gd")
const MainWorldView := preload("res://scripts/presentation/world/main_world_view.gd")

## Versión del contenido. Se incrementa cuando los datos guardados dejan de ser válidos.
const CONTENT_VERSION := 1

var events: GameEvents
var session: GameSession
var movement: MovementController
var world_view: MainWorldView


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

	_build_world_view()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().quit()


## Suelta las referencias al terminar. Sin esto, el dominio sigue vivo cuando el
## proceso termina y Godot reporta fugas en cada ejecución headless.
func _exit_tree() -> void:
	if session != null:
		session.shutdown()
	session = null
	movement = null
	world_view = null
	events = null


## Ensambla la escena del mundo. La señal se conecta antes de añadir el nodo al
## árbol, porque `_ready()` emite `player_spawned` al construirse el jugador.
func _build_world_view() -> void:
	world_view = MainWorldView.new()
	world_view.name = "MainWorldView"
	world_view.player_spawned.connect(_on_player_spawned)
	add_child(world_view)


func _on_player_spawned(player: PlayerView) -> void:
	movement.bind(player)
	session.bind_view(world_view)
	world_view.connect_movement(movement)
	GameLogger.info(
		"Jugador listo en %s" % player.global_position, "Game"
	)


## El dominio es la fuente de verdad de la posición: la vista no la inventa.
func _on_move_performed(_velocity: Vector2, moved: Vector2) -> void:
	session.apply_motion(moved, movement.facing())


func _on_player_died() -> void:
	movement.set_enabled(false)
	GameLogger.info("Jugador muerto: movimiento bloqueado", "Game")


func _on_player_respawned(_spawn: Vector2) -> void:
	movement.set_enabled(true)