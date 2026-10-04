class_name PlayerView
extends CharacterBody2D

## Presentación del jugador (secciones 7, 8 y 17).
##
## Solo dibuja y aplica el movimiento que le pide el caso de uso. No decide reglas:
## el daño, la vida y el estado viven en el dominio.
##
## El personaje se dibuja a código porque el atlas de Tiny Dungeon solo trae
## tiles: no hay hoja de personaje que recortar. Estados que hay (sección 8):
## quieto, caminando en cuatro direcciones, golpeando y aturdido.
##
## Dependencias: presentation -> application

signal move_performed(moved: Vector2)
signal facing_changed(facing: Vector2)

const SPEED := 110.0
const BODY_RADIUS := 5.0

## Píxeles recorridos por un ciclo completo de paso.
const WALK_CYCLE := 14.0

const SKIN := Color("e0b089")
const HAIR := Color("6b3f1d")
const SHIRT := Color("3f7fbf")
const PANTS := Color("2b3f63")
const OUTLINE := Color("1a1a1a")
const FLASH := Color("ff6b6b")

## Alturas del cuerpo en píxeles de mundo, con los pies en el origen.
const LEG_TOP := -4.0
const BODY_BOTTOM := -3.0
const BODY_TOP := -11.0
const HEAD_TOP := -17.0
const HEAD_BOTTOM := -11.0

@export var move_speed: float = SPEED
@export var tint: Color = Color.WHITE

var hitbox: HitboxSensor = null

var _facing: Vector2 = Vector2.DOWN
var _walk_phase: float = 0.0
var _swing: float = -1.0
var _is_hurt: bool = false
var _weapon_texture: Texture2D = null
var _weapon_sprite: Sprite2D = null


func _ready() -> void:
	_build_collision()
	_build_hitbox()
	queue_redraw()


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


func _build_hitbox() -> void:
	hitbox = HitboxSensor.new()
	hitbox.name = "Hitbox"
	add_child(hitbox)
	hitbox.exclude_body(self)


## Aplica el desplazamiento resuelto por la física y hace avanzar la animación.
func apply_motion(moved: Vector2) -> void:
	if not moved.is_zero_approx():
		_walk_phase = fposmod(_walk_phase + moved.length() / WALK_CYCLE, 1.0)
		queue_redraw()
	move_performed.emit(moved)


func set_facing(facing: Vector2) -> void:
	if facing == _facing:
		return
	_facing = facing
	if hitbox != null:
		hitbox.face(facing)
	queue_redraw()
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
	queue_redraw()


## Apaga la hitbox sin cortar la animación: el golpe ya se ha registrado.
func stop_hitbox() -> void:
	if hitbox != null:
		hitbox.set_active(false)


## Cierra la pose de golpe.
func end_attack() -> void:
	_swing = -1.0
	stop_hitbox()
	queue_redraw()


## Cambia el arma visible. Sin textura se dibuja a mano.
func set_weapon(weapon: Weapon) -> void:
	if weapon == null:
		return
	if hitbox != null:
		hitbox.set_reach(weapon.attack_range)
	if weapon.texture_path.is_empty() or not ResourceLoader.exists(weapon.texture_path):
		_weapon_texture = null
		_ensure_weapon_sprite().visible = false
		queue_redraw()
		return
	_weapon_texture = load(weapon.texture_path) as Texture2D
	var sprite := _ensure_weapon_sprite()
	sprite.texture = _weapon_texture
	sprite.visible = true
	queue_redraw()


## Aturdimiento: parpadeo rojo para que el golpe se note.
func set_hurt(active: bool) -> void:
	if _is_hurt == active:
		return
	_is_hurt = active
	queue_redraw()


func _ensure_weapon_sprite() -> Sprite2D:
	if _weapon_sprite != null:
		return _weapon_sprite
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.name = "Weapon"
	_weapon_sprite.centered = false
	_weapon_sprite.z_index = 1
	add_child(_weapon_sprite)
	return _weapon_sprite


func _physics_process(delta: float) -> void:
	if _swing >= 0.0:
		_swing += delta
		queue_redraw()


func _draw() -> void:
	var step := _walk_phase * TAU
	var bob := 0.0
	if _walk_phase > 0.0:
		bob = absf(sin(step)) * 1.0
	var leg := sin(step) * 2.0 if _walk_phase > 0.0 else 0.0
	var shade := FLASH if _is_hurt else tint

	_draw_legs(leg, shade)
	_draw_torso(bob, shade)
	_draw_head(bob, shade)
	_draw_arm(step, shade)
	_draw_weapon()


## Las piernas van por detrás del torso, así que se dibujan primero.
func _draw_legs(swing: float, shade: Color) -> void:
	for direction: int in [-1, 1]:
		var offset: float = swing * direction
		var leg_rect := Rect2(-3.0 + offset * 0.5, LEG_TOP, 2.0, 0.0 - LEG_TOP)
		draw_rect(leg_rect, PANTS * shade)
		draw_rect(leg_rect, OUTLINE, false, 1.0)


func _draw_torso(bob: float, shade: Color) -> void:
	var body := Rect2(-4.0, BODY_TOP + bob, 8.0, BODY_BOTTOM - BODY_TOP)
	draw_rect(body, SHIRT * shade)
	draw_rect(body, OUTLINE, false, 1.0)


## La cara solo se dibuja de frente y de perfil: de espaldas no hay ojos.
func _draw_head(bob: float, shade: Color) -> void:
	var height := HEAD_BOTTOM - HEAD_TOP
	var top := HEAD_TOP + bob
	var face_offset := _facing.x * 1.0
	var head := Rect2(-3.5 + face_offset, top, 7.0, height)
	draw_rect(head, SKIN * shade)
	draw_rect(head, OUTLINE, false, 1.0)
	var hair := Rect2(-4.0 + face_offset, top - 1.0, 8.0, 3.0)
	draw_rect(hair, HAIR * shade)
	if _facing == Vector2.UP:
		return
	var eye_y := top + 3.0
	if _facing == Vector2.DOWN:
		draw_rect(Rect2(-2.0 + face_offset, eye_y, 1.0, 1.0), OUTLINE)
		draw_rect(Rect2(1.0 + face_offset, eye_y, 1.0, 1.0), OUTLINE)
		return
	var eye_x := 1.5 * _facing.x + face_offset
	draw_rect(Rect2(eye_x, eye_y, 1.0, 1.0), OUTLINE)


## Brazo que golpea: se adelanta al swing y vuelve atrás.
func _draw_arm(step: float, shade: Color) -> void:
	var extension := 0.0
	if _swing >= 0.0:
		extension = sin(_swing_ratio() * PI) * 3.0
	else:
		extension = sin(step) * 1.0
	var hand := Vector2(_facing.x * (4.0 + extension), _facing.y * (1.0 + extension))
	draw_rect(Rect2(hand - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), SKIN * shade)


## El arma: textura del catálogo si la hay, hoja dibujada si no.
func _draw_weapon() -> void:
	if _weapon_texture == null:
		return
	var sprite := _weapon_sprite
	if sprite == null or not sprite.visible:
		return
	var ratio := _swing_ratio() if _swing >= 0.0 else 0.0
	var angle := _facing.angle() + lerpf(-1.1, 1.1, ratio)
	sprite.position = Vector2(_facing.x * 5.0, _facing.y * 2.0) - sprite.texture.get_size() * 0.5
	sprite.rotation = angle


## Avance del swing, de 0 a 1, sobre el tiempo de recuperación configurado.
func _swing_ratio() -> float:
	if _swing <= 0.0:
		return 0.0
	return clampf(_swing / GameConfig.ATTACK_RECOVERY, 0.0, 1.0)
