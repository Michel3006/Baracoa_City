class_name PlayerView
extends CharacterBody2D

## Presentación del jugador (secciones 7, 8 y 17).
##
## Solo dibuja y aplica el movimiento que le pide el caso de uso. No decide reglas:
## el daño, la vida y el estado viven en el dominio.
##
## El cuerpo se dibuja con la hoja de sprites del pack a través de `ActorSprite`
## (sección 25: los placeholders ya están validados). Los estados que hay son los
## de la sección 8: quieto, caminando en cuatro direcciones, golpeando y
## aturdido.
##
## El origen del nodo está en los pies del personaje. Todo lo que se dibuja encima
## (sprite, arma, efecto de golpe) se coloca respecto a ese punto.
##
## Dependencias: presentation -> application

signal move_performed(moved: Vector2)
signal facing_changed(facing: Vector2)

const SPEED := 110.0
const BODY_RADIUS := 5.0

## Radio de la mano: distancia al origen a la que se dibuja el arma, en la dirección
## hacia la que mira el jugador.
const HAND_REACH := 5.0

## Altura de la mano sobre los pies. El origen del cuerpo esta en los pies y el actor
## mide `ACTOR_FRAME_SIZE` hacia arriba, asi que sin este margen el arma se dibujaria a
## la altura del suelo mirando hacia abajo y por encima de la cabeza mirando hacia
## arriba. Se toma de la altura del cuadro para que siga siendo coherente si cambia el
## tamaño del fotograma.
const HAND_HEIGHT := float(GameConfig.ACTOR_FRAME_SIZE) * 0.375

@export var move_speed: float = SPEED
@export var tint: Color = Color.WHITE

var hitbox: HitboxSensor = null

## Cuerpo de combate al que golpean los enemigos. Es el `MeleeCombat` del jugador,
## no el `Player` de dominio: así el daño pasa por la invulnerabilidad y el
## aturdimiento en vez de saltárselos. Lo inyecta `PlayerPresenter`.
var combat_target: Object = null

var _facing: Vector2 = Vector2.DOWN
var _is_walking: bool = false
var _swing: float = -1.0
var _is_hurt: bool = false
var _is_dead: bool = false
var _weapon_texture: Texture2D = null
var _weapon_sprite: Sprite2D = null
var _actor: ActorSprite = null
## Golpe a puños o con arma: decide si la mano lleva algo.
var _is_unarmed: bool = true


## Vuelve a la vida tras morir. La vista no decide el punto de reaparición (eso es
## del caso de uso): solo deshace lo que dejó puesto al morir.
func revive() -> void:
	set_dead(false)
	set_hurt(false)
	_swing = -1.0
	stop_hitbox()
	_refresh_animation()


func _ready() -> void:
	_build_collision()
	_build_actor()
	_build_hitbox()
	_refresh_animation()


func _build_collision() -> void:
	collision_layer = CollisionLayers.PLAYER
	collision_mask = CollisionLayers.WORLD
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	shape.name = "Body"
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	shape.shape = circle
	add_child(shape)


## Sprite del cuerpo. Es hijo del nodo y no la hoja entera: `ActorSprite` recorta
## el fotograma que toca.
func _build_actor() -> void:
	_actor = ActorSprite.new()
	_actor.name = "Actor"
	add_child(_actor)
	if not ActorVisualCatalog.apply_to(ActorVisualCatalog.PLAYER, _actor):
		GameLogger.warning("El jugador se queda sin sprite", "PlayerView")


func _build_hitbox() -> void:
	hitbox = HitboxSensor.new()
	hitbox.name = "Hitbox"
	add_child(hitbox)
	hitbox.exclude_body(self)


## Aplica el desplazamiento resuelto por la física.
##
## Solo decide si el actor está caminando o quieto; el ciclo de la animación lo
## lleva `ActorSprite` con su propio reloj. La vista no lleva la cuenta de los
## fotogramas: eso sería duplicar una animación que ya sabe moverse sola.
func apply_motion(moved: Vector2) -> void:
	var walking := not moved.is_zero_approx()
	if walking != _is_walking:
		_is_walking = walking
		_refresh_animation()
	move_performed.emit(moved)


func set_facing(facing: Vector2) -> void:
	if facing == _facing:
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


## Inicia la pose de golpe y enciende la hitbox. La duración la lleva
## `MeleeCombat`; aquí solo se guarda el progreso 0..1 que se dibuja.
func begin_attack(weapon: Weapon = null) -> void:
	_swing = 0.0
	if weapon != null:
		set_weapon(weapon)
	if hitbox != null:
		hitbox.face(_facing)
		hitbox.set_active(true)
	if _actor != null:
		_actor.play(ActorSprite.ATTACK, true)
	_refresh_animation()


## Apaga la hitbox sin cortar la animación: el golpe ya se ha registrado.
func stop_hitbox() -> void:
	if hitbox != null:
		hitbox.set_active(false)


## Cierra la pose de golpe y vuelve a lo que hubiera: caminar o quieto.
func end_attack() -> void:
	_swing = -1.0
	stop_hitbox()
	_refresh_animation()


## Cambia el arma visible y, con ella, el alcance de la hitbox.
##
## Los puños no tienen textura: es lo que distingue a simple vista el golpe sin
## arma del golpe con arma, y `WeaponCatalog` es quien lo decide.
func set_weapon(weapon: Weapon) -> void:
	if weapon == null:
		return
	_is_unarmed = WeaponCatalog.is_unarmed(weapon)
	if hitbox != null:
		hitbox.set_reach(weapon.attack_range)
	if _is_unarmed or weapon.texture_path.is_empty() or not ResourceLoader.exists(weapon.texture_path):
		_weapon_texture = null
		_ensure_weapon_sprite().visible = false
		return
	_weapon_texture = load(weapon.texture_path) as Texture2D
	var sprite := _ensure_weapon_sprite()
	sprite.texture = _weapon_texture
	sprite.visible = true


## Aturdimiento: parpadeo rojo para que el golpe se note.
func set_hurt(active: bool) -> void:
	if _is_hurt == active:
		return
	_is_hurt = active
	_apply_tint()


## Muerte: el cuerpo queda congelado en el ultimo fotograma.
func set_dead(active: bool) -> void:
	if _is_dead == active:
		return
	_is_dead = active
	if active:
		if hitbox != null:
			stop_hitbox()
		if _actor != null:
			_actor.play(ActorSprite.DEAD, true)
	_ensure_weapon_sprite().visible = false
	_apply_tint()
	_refresh_animation()


## El tinte es como se nota el aturdimiento: el sprite se tiñe entero en vez de
## parpadear, que a 16 px y a 60Hz sería ilegible.
func _apply_tint() -> void:
	var flash := Color("ff6b6b")
	if _is_hurt:
		modulate = flash
	elif _is_dead:
		modulate = Color(0.45, 0.45, 0.5, 0.85)
	else:
		modulate = tint


func _ensure_weapon_sprite() -> Sprite2D:
	if _weapon_sprite != null:
		return _weapon_sprite
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.name = "Weapon"
	_weapon_sprite.centered = true
	_weapon_sprite.z_index = 1
	_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_weapon_sprite)
	return _weapon_sprite


func _physics_process(delta: float) -> void:
	if _swing < 0.0:
		return
	_swing += delta
	_place_weapon()


## Elige la animación que toca: la muerte no cede, y el golpe manda sobre el
## desplazamiento para que no se interrupta a mitad de arco.
func _refresh_animation() -> void:
	if _actor == null:
		return
	if _is_dead:
		_actor.play(ActorSprite.DEAD)
		return
	if _swing >= 0.0:
		_actor.play(ActorSprite.ATTACK)
		return
	if _is_walking:
		_actor.play(ActorSprite.WALK)
		return
	_actor.play(ActorSprite.IDLE)
	_place_weapon()


## Coloca el arma en la mano y la orienta con el arco del golpe.
##
## Sin arma no se dibuja nada: es la diferencia visible entre el golpe a puños y el
## golpe con arma.
func _place_weapon() -> void:
	var sprite := _weapon_sprite
	if sprite == null or not sprite.visible or _weapon_texture == null:
		return
	var ratio := _swing_ratio()
	var angle := _facing.angle() + lerpf(-1.1, 1.1, ratio)
	sprite.position = hand_position()
	sprite.rotation = angle


## Posición de la mano en el cuerpo, sin depender del estado del golpe. Lo consulta el
## HUD para dibujar el icono del arma en el sitio que le corresponde, y los tests para
## comprobar que el arma cae sobre el cuerpo y no fuera de el.
func hand_position(direction: Vector2 = _facing) -> Vector2:
	return (
		Vector2(direction.x * HAND_REACH, direction.y * HAND_REACH)
		- Vector2(0.0, HAND_HEIGHT)
	)


## Avance del swing, de 0 a 1, sobre el tiempo de recuperación configurado.
func _swing_ratio() -> float:
	if _swing <= 0.0:
		return 0.0
	return clampf(_swing / GameConfig.ATTACK_RECOVERY, 0.0, 1.0)
