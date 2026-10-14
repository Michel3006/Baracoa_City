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
## (sprite, efecto de golpe, brazo a puños) se coloca respecto a ese punto.
##
## Dependencias: presentation -> application

signal move_performed(moved: Vector2)
signal facing_changed(facing: Vector2)

const BODY_RADIUS := 5.0

## Velocidad de caminar. Sale de `GameConfig` y no de un número aquí: antes la vista
## traía la suya (110 px/s) y el presentador se la copiaba al `MovementController`, así
## que `GameConfig.PLAYER_SPEED` no era el valor con el que se jugaba de verdad.
@export var move_speed: float = GameConfig.PLAYER_SPEED
@export var tint: Color = Color.WHITE

var hitbox: HitboxSensor = null

## Cuerpo de combate al que golpean los enemigos. Es el `MeleeCombat` del jugador,
## no el `Player` de dominio: así el daño pasa por la invulnerabilidad y el
## aturdimiento en vez de saltárselos. Lo inyecta `PlayerPresenter`.
var combat_target: Object = null

var _facing: Vector2 = Vector2.DOWN
var _is_walking: bool = false
var _swing: float = -1.0
## Clip que se reproduce mientras dure el golpe: el estándar o el del ataque
## concreto, si su animación existe en la hoja.
var _attack_clip: StringName = ActorSprite.ATTACK
## Duración conocida del golpe en curso. La decide el ataque (`AttackDefinition`
## vía `begin_attack`); por defecto es la recuperación genérica.
var _swing_duration: float = GameConfig.ATTACK_RECOVERY
var _is_hurt: bool = false
var _is_stunned: bool = false
var _is_dead: bool = false
## Clip de reacción al golpe recibido (`hit_light`, `hit_body`, `hit_head`), o
## `&""` si no hay trance. Lo manda el cuerpo de combate con `reaction_started`.
var _reaction_clip: StringName = &""
## Rodada en curso. Mientras dura, la pose de la rodada manda sobre caminar.
var _is_dodging: bool = false
## Guardia levantada. No hay clip que la dibuje (el pack no trae pose de guardia,
## comprobado sobre las hojas: `Push`/`Pull` no son un bloqueo), así que este dato
## solo existe para que la vista lo recuerde el día que haya arte.
var _is_blocking: bool = false
var _actor: ActorSprite = null
var _punch: PunchArm = null
## Capas de ropa y pelo. Presentación pura: se dibujan encima del cuerpo y leen
## su estado, no lo escriben (plan de ropa y peinados).
var _shirt_layer: GarmentLayer = null
var _hair_layer: GarmentLayer = null
## Qué lleva puesto el jugador. Cosmético: no entra en el dominio ni cambia
## ninguna regla de combate.
var appearance: AppearanceState = null
## Golpe a puños o con arma: a puños el cuerpo usa su propio puñetazo; con arma
## ya no se dibuja nada en la mano (el stick del pack no encaja sobre el Hormelz).
var _is_unarmed: bool = true


## Vuelve a la vida tras morir. La vista no decide el punto de reaparición (eso es
## del caso de uso): solo deshace lo que dejó puesto al morir.
func revive() -> void:
	set_dead(false)
	set_hurt(false)
	set_stun(false)
	end_reaction()
	end_dodge()
	set_blocking(false)
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
	_build_punch()
	_build_customization()


## Capas de personalización (plan de ropa y peinados).
##
## Se añaden después del cuerpo y del brazo para que se dibujen encima, y con
## `z_index` 0 (el del cuerpo): así la camiseta queda sobre el torso pero por
## debajo del brazo y del arco de golpe, que van en el 1 y el 8. No tocan
## colisión, hitbox ni tiempos: son dos `Sprite2D` más que copian el estado del
## cuerpo.
func _build_customization() -> void:
	appearance = AppearanceState.new()
	_shirt_layer = _add_garment_layer("ShirtLayer", GarmentDefinition.Part.SHIRT)
	_hair_layer = _add_garment_layer("HairLayer", GarmentDefinition.Part.HAIR)


func _add_garment_layer(node_name: String, part: int) -> GarmentLayer:
	var layer := GarmentLayer.new()
	layer.name = node_name
	layer.part = part
	layer.actor = _actor
	layer.appearance = appearance
	layer.z_index = 0
	add_child(layer)
	return layer


## Se pone una camiseta (id de `GarmentCatalog`) o `&""` para quitarla.
func set_shirt(id: StringName) -> void:
	if appearance != null:
		appearance.set_shirt(id)


## Se pone un peinado (id de `GarmentCatalog`) o `&""` para quitarlo.
func set_hair(id: StringName) -> void:
	if appearance != null:
		appearance.set_hair(id)


## Qué lleva puesto el jugador. Lo usa la interfaz de personalización.
func appearance_state() -> AppearanceState:
	return appearance


func _build_hitbox() -> void:
	hitbox = HitboxSensor.new()
	hitbox.name = "Hitbox"
	add_child(hitbox)
	hitbox.exclude_body(self)


func _build_punch() -> void:
	_punch = PunchArm.new()
	_punch.name = "PunchArm"
	_punch.z_index = 1
	add_child(_punch)
	var def := ActorVisualCatalog.definition_of(ActorVisualCatalog.PLAYER)
	if def != null:
		_punch.configure(def)
	_punch.end()


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


## Inicia la pose de golpe. La duración la lleva `MeleeCombat`; aquí solo se
## guarda el progreso 0..1 que se dibuja.
##
## NO enciende la hitbox: el golpe empieza en WINDUP y la ventana de impacto
## llega después, al entrar en ACTIVE (sección 10). Quien enciende es el
## presentador con `start_hitbox()` cuando el caso de uso emite
## `attack_window_opened`. Así un golpe lento no está pegando durante todo su
## arranque.
##
## `attack_id` es el ataque concreto (izquierda, cruzada, patada...): si la hoja
## trae su animación, se reproduce esa; si no, cae al clip estándar de ataque.
## `duration` es lo que la pose debe durar en segundos (negativo = la
## recuperación genérica). Los dos son opcionales para que llamar a
## `begin_attack()` sin más siga haciendo lo de siempre.
func begin_attack(weapon: Weapon = null, attack_id: StringName = &"", duration: float = -1.0) -> void:
	_swing = 0.0
	_swing_duration = duration if duration > 0.0 else GameConfig.ATTACK_RECOVERY
	if weapon != null:
		set_weapon(weapon)
	if hitbox != null:
		hitbox.face(_facing)
	# El brazo dibujado no pinta nada en ninguna hoja: el cuerpo tiene su propio
	# puñetazo. Se cierra por si acaso quedó activo de una versión anterior.
	if _punch != null:
		_punch.end()
	_attack_clip = ActorSprite.ATTACK
	if attack_id != &"" and _actor != null and _actor.has_clip(attack_id):
		_attack_clip = attack_id
	if _actor != null:
		_actor.play(_attack_clip, true)
	_refresh_animation()


## Enciende la hitbox: es la señal de que la ventana de impacto está abierta.
##
## La llama el presentador con `attack_window_opened` y se apaga con
## `stop_hitbox()` al cerrarse la ventana, de modo que la hitbox y la ventana
## del caso de uso son la misma cosa vista desde los dos lados.
func start_hitbox() -> void:
	if hitbox != null:
		hitbox.set_active(true)


## Apaga la hitbox sin cortar la animación: el golpe ya se ha registrado.
func stop_hitbox() -> void:
	if hitbox != null:
		hitbox.set_active(false)


## Cierra la pose de golpe y vuelve a lo que hubiera: caminar o quieto.
##
## Lo normal es que la llame el presentador al recibir `attack_finished`. Es pública
## para que también se pueda cerrar a mano desde un test: `_physics_process()` la vuelve
## a llamar al cumplirse la recuperación, así que el reloj de la vista es una segunda
## red y este cierre manual no se nota en el juego. Lo que sí se nota es que sobre la
## vista se puede comprobar el reloj sin el caso de uso.
func end_attack() -> void:
	_swing = -1.0
	stop_hitbox()
	if _punch != null:
		_punch.end()
	_refresh_animation()


## Cambia el arma del combate: el alcance de la hitbox y si el golpe es a puños.
##
## No se dibuja ningún sprite en la mano: el stick del pack (la piedra, un palo
## de 3x16 px) no encaja sobre el cuerpo del Hormelz y al atacar quedaba flotando
## fuera de la mano, rompiendo la lectura de la animación. El arma sigue
## existiendo para pegar (daño y alcance); lo único que desaparece es su dibujo.
func set_weapon(weapon: Weapon) -> void:
	if weapon == null:
		return
	_is_unarmed = WeaponCatalog.is_unarmed(weapon)
	if hitbox != null:
		hitbox.set_reach(weapon.attack_range)


## Aturdimiento: parpadeo rojo para que el golpe se note.
func set_hurt(active: bool) -> void:
	if _is_hurt == active:
		return
	_is_hurt = active
	_apply_tint()


## Aturdimiento: tinte propio (`STUN_TINT`) mientras dura, distinto del rojo de la
## invulnerabilidad. La señal la emite el cuerpo de combate al aturdir y al expirar.
func set_stun(active: bool) -> void:
	if _is_stunned == active:
		return
	_is_stunned = active
	_apply_tint()


## Trance por golpe recibido (sección 25): reproduce el clip del trance una vez.
##
## Si la hoja no trae ese clip (el humano clásico y el ninja solo tienen el golpe
## genérico), la vista se queda con lo que hubiera en vez de avisar por consola:
## un clip que no existe no es un error del juego, es arte que falta.
func begin_reaction(clip: StringName) -> void:
	if _actor == null or not _actor.has_clip(clip):
		_reaction_clip = &""
		return
	_reaction_clip = clip
	_actor.play(clip, true)
	_refresh_animation()


## Fin del trance: la pose vuelve a lo que toque (caminar, quieto o atacar).
func end_reaction() -> void:
	if _reaction_clip == &"":
		return
	_reaction_clip = &""
	_refresh_animation()


## Rodada (sección 30): reproduce el clip del gesto mirando hacia donde rueda.
##
## La orientación la fija la rodada, no la marcha: la pose es direccional y girar
## mientras el cuerpo rueda hacia otro lado se ve como un patinaje.
func begin_dodge(direction: Vector2) -> void:
	_is_dodging = true
	if not direction.is_zero_approx():
		set_facing(direction)
	if _actor != null and _actor.has_clip(GameConfig.DODGE_CLIP):
		_actor.play(GameConfig.DODGE_CLIP, true)
	_refresh_animation()


func end_dodge() -> void:
	if not _is_dodging:
		return
	_is_dodging = false
	_refresh_animation()


## Guardia levantada o suelta (sección 31). Sin clip propio: el pack no trae pose
## de guardia. La vista lo recuerda para que, cuando llegue el arte, solo haya que
## añadir el `play` aquí.
func set_blocking(active: bool) -> void:
	if _is_blocking == active:
		return
	_is_blocking = active
	_refresh_animation()


## ¿Se está dibujando la pose de guardia? (hoy siempre `false` en el dibujo, pero
## el estado existe y los tests pueden comprobarlo)
func is_blocking() -> bool:
	return _is_blocking


## Clip de reacción que se está reproduciendo, o `&""`. Lo leen los tests para
## comprobar que el golpe que recibe el cuerpo tiene pose.
func reaction_clip() -> StringName:
	return _reaction_clip


## ¿El cuerpo está dibujando la rodada?
func is_dodging() -> bool:
	return _is_dodging


## ¿El cuerpo está dibujando la muerte? Lo consultan la mochila y el vestuario para
## no abrirse encima de la pantalla de muerte: pausar el mundo detrás de ella
## rompería la reaparición, y elegir ropa no es algo que se haga muerto.
func is_dead() -> bool:
	return _is_dead


## Muerte: el cuerpo queda congelado en el ultimo fotograma.
func set_dead(active: bool) -> void:
	if _is_dead == active:
		return
	_is_dead = active
	if active:
		if hitbox != null:
			stop_hitbox()
		if _punch != null:
			_punch.end()
		if _actor != null:
			_actor.play(ActorSprite.DEAD, true)
	_apply_tint()
	_refresh_animation()


## El tinte es como se nota el aturdimiento: el sprite se tiñe entero en vez de
## parpadear, que a 16 px y a 60Hz sería ilegible.
##
## Prioridad: muerto > aturdido > herido > normal. El aturdimiento va por delante
## del rojo porque dura menos que la invulnerabilidad: si el rojo ganara, el
## aturdimiento no se leería; y cuando el aturdimiento acaba, el rojo vuelve
## durante lo que quede de la ventana.
func _apply_tint() -> void:
	if _is_dead:
		modulate = Color(0.45, 0.45, 0.5, 0.85)
	elif _is_stunned:
		modulate = GameConfig.STUN_TINT
	elif _is_hurt:
		modulate = GameConfig.HURT_TINT
	else:
		modulate = tint


func _physics_process(delta: float) -> void:
	if _swing >= 0.0:
		_swing += delta
		if _swing >= _swing_duration:
			# El caso de uso cierra el golpe con `attack_finished`, pero la vista no
			# puede quedarse clavada en la pose si esa señal no llega: el ataque tiene
			# una duración conocida y aquí se cierra al cumplirse. Con las dos cosas el
			# cuerpo vuelve a caminar pase lo que pase.
			end_attack()
	if _punch != null and _punch.is_active():
		_punch.end()
	# El dibujo de depuración sigue al cuerpo: mientras está activo se refresca
	# cada fotograma, como cualquier overlay que persigue a un actor.
	if CombatDebug.show:
		queue_redraw()


## Elige la animación que toca, en este orden: muerte, rodada, trance, golpe,
## caminar y quieto.
##
## La muerte no cede y la rodada manda sobre todo lo demás porque es un gesto
## completo (se mueve sola, con su propio reloj). El trance va por delante del
## golpe porque al recibir un golpe el ataque en curso se interrumpe. El golpe
## manda sobre el desplazamiento para que no se corte a mitad de arco.
func _refresh_animation() -> void:
	if _actor == null:
		return
	if _is_dead:
		_actor.play(ActorSprite.DEAD)
		return
	if _is_dodging and _actor.has_clip(GameConfig.DODGE_CLIP):
		if _actor.current_clip() != GameConfig.DODGE_CLIP:
			_actor.play(GameConfig.DODGE_CLIP, true)
		return
	if _reaction_clip != &"":
		if _actor.current_clip() != _reaction_clip:
			_actor.play(_reaction_clip, true)
		return
	if _swing >= 0.0:
		if _actor.current_clip() != _attack_clip:
			_actor.play(_attack_clip, true)
		return
	if _is_walking:
		_actor.play(ActorSprite.WALK)
		return
	_actor.play(ActorSprite.IDLE)


## Si el arco del golpe está en marcha. Lo consulta quien necesite saber si toca la pose
## de golpe o la de caminar sin tener que mirar el reloj interno.
func is_swinging() -> bool:
	return _swing >= 0.0


## Segundos que lleva el arco del golpe en marcha. Vale `-1` cuando no hay arco.
func swing_elapsed() -> float:
	return _swing


## Avance del swing, de 0 a 1, sobre la duración del ataque en curso.
func _swing_ratio() -> float:
	if _swing <= 0.0:
		return 0.0
	return clampf(_swing / maxf(_swing_duration, 0.001), 0.0, 1.0)


## Centro del torso del actor dibujado, para situar el arco de golpe.
func torso_offset() -> Vector2:
	if _actor != null:
		return _actor.torso_offset()
	return GameConfig.ACTOR_SPRITE_OFFSET


## Radio de la zona que un golpe puede alcanzar de este cuerpo. Lo lee el dibujo
## de depuración (`CombatDebug`) para pintar la hurtbox sobre el mundo.
func hurtbox_radius() -> float:
	return BODY_RADIUS


## Clip que se está reproduciendo ahora mismo. Lo lee el HUD de depuración
## (sección 34) para enseñar la animación del jugador sin tocar el actor.
func current_animation() -> StringName:
	if _actor == null:
		return &""
	return _actor.current_clip()


## Dibujo de depuración (sección 35): hurtbox, hitbox, dirección, área de ataque
## y objetivos alcanzados, todo desde la geometría que comparte con la física.
## Solo se pinta mientras `CombatDebug.show` está activo; apagado no dibuja ni
## una línea.
func _draw() -> void:
	if not CombatDebug.show:
		return
	var hurtbox := CombatDebug.hurtbox_circle(self)
	draw_arc(Vector2.ZERO, float(hurtbox["radius"]), 0.0, TAU, 24, GameConfig.DEBUG_HURTBOX_COLOR, 1.0)
	var hitbox_shape := CombatDebug.hitbox_circle(self)
	var hitbox_center: Vector2 = Vector2(hitbox_shape["center"]) - global_position
	var hitbox_radius := float(hitbox_shape["radius"])
	draw_arc(hitbox_center, hitbox_radius, 0.0, TAU, 24, GameConfig.DEBUG_HITBOX_COLOR, 1.0)
	if hitbox_radius > 0.0:
		# Área de ataque: el disco de alcance por delante del cuerpo. Lleno cuando
		# la hitbox está encendida (la ventana está abierta), contorno cuando no.
		var reach := hitbox_radius / GameConfig.HITBOX_RADIUS_RATIO
		var area_center := _facing * reach * 0.5
		if hitbox != null and hitbox.is_active:
			draw_circle(area_center, reach * 0.6, Color(GameConfig.DEBUG_ATTACK_AREA_COLOR, 0.25))
		else:
			draw_arc(area_center, reach * 0.6, 0.0, TAU, 24, GameConfig.DEBUG_ATTACK_AREA_COLOR, 1.0)
	if not _facing.is_zero_approx():
		draw_line(
			Vector2.ZERO,
			_facing.normalized() * (float(hurtbox["radius"]) + 8.0),
			GameConfig.DEBUG_DIRECTION_COLOR,
			1.0
		)
	for body: Node2D in CombatDebug.reached_targets(self):
		var point: Vector2 = body.global_position - global_position
		draw_rect(Rect2(point - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), GameConfig.DEBUG_REACHED_COLOR)
