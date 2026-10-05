class_name MainWorldView
extends Node2D

## Escena raíz del mundo jugable (secciones 14 y 17).
##
## Compone la zona activa, instancia al jugador, levanta el HUD y conecta la vista con
## los casos de uso. No decide reglas: traduce estado en píxeles.
##
## ## Las vistas de efecto cuelgan de aquí
##
## Los golpes sueltan un `SlashEffect` en un nodo aparte y no sobre el jugador. La
## razón es concreta: el efecto se borra solo al terminar su ciclo, y si colgara del
## jugador se llevaría por delante el resto de hijos cada vez que se reubicara.
##
## Dependencias: presentation -> application

signal player_spawned(player: PlayerView)

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Z_FX := 8

@export var zone_scene: PackedScene = WORLD_SCENE
@export var player_scene: PackedScene = PLAYER_SCENE

var world: Node2D = null
var player: PlayerView = null
var presenter: PlayerPresenter = null
var camera: WorldCamera = null
var hud: Hud = null
var npc_spawner: NpcSpawner = null

## Nodo contenedor de los efectos de golpe. Vive aquí y no dentro del jugador.
var fx_layer: Node2D = null


func _ready() -> void:
	_build_world()
	_build_camera()
	_build_fx_layer()
	_build_hud()
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


## Capa de efectos. Por encima del mundo y de los NPC, por debajo del HUD.
func _build_fx_layer() -> void:
	fx_layer = Node2D.new()
	fx_layer.name = "Fx"
	fx_layer.z_index = Z_FX
	add_child(fx_layer)


## El HUD vive en una `CanvasLayer` aparte para que no se mueva con la cámara: si
## colgara del mundo, las barras saldrían disparadas al desplazarse el jugador.
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	add_child(layer)
	hud = Hud.new()
	hud.name = "Hud"
	layer.add_child(hud)


func _spawn_player(spawn_position: Vector2) -> void:
	player = player_scene.instantiate() as PlayerView
	player.global_position = spawn_position
	add_child(player)
	presenter = player.get_node_or_null("Presenter") as PlayerPresenter
	if presenter != null:
		presenter.set_fx_parent(fx_layer)
	camera.follow(player)
	player_spawned.emit(player)


## Levanta la capa de NPC y la conecta con su director.
##
## Lo llama la capa Application: la lista de enemigos sale de `NpcDirector`, no de
## aquí. Esta función solo monta el sitio donde van a vivir los cuerpos.
func setup_npcs(director: NpcDirector) -> void:
	if npc_spawner == null:
		npc_spawner = NpcSpawner.new()
		npc_spawner.name = "NpcSpawner"
		add_child(npc_spawner)
	npc_spawner.bind(director)


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
	if presenter != null and combat != null:
		# El HUD enseña el arma del golpe en curso, que puede ser a puños aunque la
		# equipada siga en la mano.
		combat.attack_started.connect(_on_attack_started)
	presenter.set_fx_parent(fx_layer)
	if hud != null and combat != null:
		hud.set_weapon(combat.weapon)


## Desplaza al jugador. En Fase 2 sustituir por cambio de zona validado en servidor.
func move_player_to(target: Vector2) -> void:
	if player == null:
		return
	player.global_position = target
	if presenter == null:
		return
	# La vista vuelve a la vida: `GameSession.respawn()` ha movido el dominio y el
	# cuerpo tenía que enterarse para volver a dibujar y a aceptar golpes.
	if not presenter.is_dead():
		player.revive()


func _on_attack_started(weapon: Weapon, _direction: Vector2, _window: float) -> void:
	if hud != null:
		hud.set_weapon(weapon)