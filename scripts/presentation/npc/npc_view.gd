class_name NpcView
extends CharacterBody2D

## Presentación de un NPC (secciones 7, 9 y 18).
##
## Gemela de `PlayerView`, y a propósito se parecen tanto: mismo cuerpo físico,
## misma hitbox que se enciende solo durante el golpe, mismo sprite con
## `ActorSprite`. Lo que cambia es a quién pegan y quién decide cuándo.
##
## ## Por qué `CharacterBody2D` y no `StaticBody2D`
##
## Comprobado en este proyecto: un `StaticBody2D` añadido en tiempo de ejecución no
## aparece nunca en `Area2D.get_overlapping_bodies()`, ni tras 200 frames de física
## ni reactivando `monitoring`. Un `CharacterBody2D` en el mismo sitio se detecta a
## la primera. Como los objetivos de golpeo se localizan con la hitbox del jugador,
## un NPC estático no recibiría nunca daño: tiene que ser `CharacterBody2D`.
##
## Dependencias: presentation -> application

signal move_performed(moved: Vector2)
signal facing_changed(facing: Vector2)

const BODY_RADIUS := 5.0
## Margen sobre el que alcance el golpe. Golpear a 7 px de distancia con un
## alcance de 13 se ve mal; el NPC se para un poco antes y estira el brazo.
const ATTACK_STOP_MARGIN := 2.0

@export var move_speed: float = GameConfig.NPC_WEAK_SPEED
@export var tint: Color = Color.WHITE

var hitbox: HitboxSensor = null

## Cuerpo de dominio al que pegan. Lo inyecta `NpcPresenter`; sin él la hitbox del
## jugador no encontraría a quién damaging.
var combat_target: Object = null

var _facing: Vector2 = Vector2.DOWN
var _is_walking: bool = false
var _is_attacking: bool = false
var _is_hurt: bool = false
var _is_dead: bool = false
var _actor: ActorSprite = null


func _ready() -> void:
	_build_collision()
	_build_actor()
	_build_hitbox()
	_refresh_animation()


func _build_collision() -> void:
	collision_layer = CollisionLayers.NPC
	# Choca con el mundo y con el jugador, pero no con otros NPC: seis enemigos
	# empujándose en un pasillo se convertían en un muro infranqueable.
	collision_mask = CollisionLayers.mask([CollisionLayers.WORLD, CollisionLayers.PLAYER])
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	shape.name = "Body"
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	shape.shape = circle
	add_child(shape)


func _build_actor() -> void:
	_actor = ActorSprite.new()
	_actor.name = "Actor"
	add_child(_actor)


## Elige la hoja del sprite a partir del tipo de enemigo del dominio, y le pasa la
## velocidad con la que se mueve. La velocidad la decide `NpcBehavior`, que es donde
## vive la estadística: la vista no sabe si un slime es más lento que un lagarto.
func set_kind(kind: StringName) -> void:
	if _actor == null:
		return
	if not ActorVisualCatalog.apply_to(kind, _actor):
		GameLogger.warning("NPC sin sprite: %s" % kind, "NpcView")
		_actor.visible = false
	_refresh_animation()


func _build_hitbox() -> void:
	hitbox = HitboxSensor.new()
	hitbox.name = "Hitbox"
	hitbox.reach = GameConfig.NPC_WEAK_RANGE
	add_child(hitbox)
	hitbox.exclude_body(self)


func apply_motion(moved: Vector2) -> void:
	var walking := not moved.is_zero_approx()
	if walking != _is_walking:
		_is_walking = walking
		_refresh_animation()
	move_performed.emit(moved)


func set_facing(facing: Vector2) -> void:
	if facing.is_zero_approx() or facing == _facing:
		return
	_facing = facing
	if hitbox != null:
		hitbox.face(facing)
	if _actor != null:
		_actor.set_facing(facing)
	_refresh_animation()
	facing_changed.emit(facing)


func facing() -> Vector2:
	return _facing


## Comienza el golpe: enciende la hitbox y lanza la animación.
func begin_attack(reach: float) -> void:
	_is_attacking = true
	if hitbox != null:
		hitbox.set_reach(reach)
		hitbox.face(_facing)
		hitbox.set_active(true)
	if _actor != null:
		_actor.play(ActorSprite.ATTACK, true)
	_refresh_animation()


func stop_hitbox() -> void:
	if hitbox != null:
		hitbox.set_active(false)


## Cierra el golpe y vuelve a lo que hubiera.
func end_attack() -> void:
	_is_attacking = false
	stop_hitbox()
	_refresh_animation()


## Aturdimiento: se tiñe para que se note el golpe.
func set_hurt(active: bool) -> void:
	if _is_hurt == active:
		return
	_is_hurt = active
	_apply_tint()


## Muerte: quieto, apagado y con la hitbox apagada para que no siga golpeando.
func set_dead(active: bool) -> void:
	if _is_dead == active:
		return
	_is_dead = active
	if active:
		_is_attacking = false
		stop_hitbox()
		if _actor != null:
			_actor.play(ActorSprite.DEAD, true)
	_apply_tint()
	_refresh_animation()


func _apply_tint() -> void:
	if _is_hurt:
		modulate = Color("ff6b6b")
	elif _is_dead:
		modulate = Color(0.45, 0.45, 0.5, 0.85)
	else:
		modulate = tint


## Elige la animación: la muerte no cede y el golpe manda sobre el desplazamiento.
func _refresh_animation() -> void:
	if _actor == null:
		return
	if _is_dead:
		_actor.play(ActorSprite.DEAD)
		return
	if _is_attacking:
		_actor.play(ActorSprite.ATTACK)
		return
	if _is_walking:
		_actor.play(ActorSprite.WALK)
		return
	_actor.play(ActorSprite.IDLE)
