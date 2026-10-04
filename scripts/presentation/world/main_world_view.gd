class_name MainWorldView
extends Node2D

## Escena raíz del mundo jugable (secciones 14 y 17).
##
## Compone la zona activa, instancia al jugador y conecta la vista con los casos de
## uso. No decide reglas: traduce estado en píxeles.
##
## Dependencias: presentation -> application

signal player_spawned(player: PlayerView)

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@export var zone_scene: PackedScene = WORLD_SCENE
@export var player_scene: PackedScene = PLAYER_SCENE

var world: Node2D = null
var player: PlayerView = null
var presenter: PlayerPresenter = null
var camera: WorldCamera = null


func _ready() -> void:
	_build_world()
	_build_camera()
	_spawn_player(GameConfig.PLAYER_SPAWN)


func _build_world() -> void:
	world = zone_scene.instantiate() as Node2D
	add_child(world)


func _build_camera() -> void:
	camera = WorldCamera.new()
	camera.name = "WorldCamera"
	add_child(camera)
	if world is ZoneView:
		camera.apply_zone_bounds((world as ZoneView).bounds)


func _spawn_player(spawn_position: Vector2) -> void:
	player = player_scene.instantiate() as PlayerView
	player.global_position = spawn_position
	add_child(player)
	presenter = player.get_node_or_null("Presenter") as PlayerPresenter
	camera.follow(player)
	player_spawned.emit(player)


## Inyecta los casos de uso del jugador. Lo llama la capa Application.
##
## El presentador necesita los dos: el movimiento para traducir la intención de
## entrada y el combate para el golpe. Se pasan juntos porque se conectan en el
## mismo momento, al aparecer el jugador.
func connect_cases(movement: MovementController, combat: MeleeCombat = null) -> void:
	if presenter == null:
		GameLogger.warning("El jugador no tiene presentador de entrada", "MainWorldView")
		return
	presenter.setup(player, movement, combat)


## Desplaza al jugador. En Fase 2 sustituir por cambio de zona validado en servidor.
func move_player_to(target: Vector2) -> void:
	if player == null:
		return
	player.global_position = target