class_name ImpactEffect
extends Node2D

## Burst de impacto del golpe (sección 38): un fogonazo en el punto de contacto
## y unas chispas de píxel que salen disparadas en la dirección del golpe.
##
## Aparece cuando el golpe conecta, no al empezar la pose: un golpe fallado no
## tiene nada que celebrar. El número de partículas sale del tier
## (`CombatImpact.particle_count_of`), y heavy además hace el fogonazo más
## grande (`FLASH_RADIUS`). Se borra solo al cumplir `IMPACT_LIFE`, igual que el
## arco, y vive en la misma capa de efectos para no colgar de nadie.
##
## El dibujo es determinista en lo que se comprueba: el número de partículas y
## su vida son datos consultables, y no hace falta una captura para saber que un
## golpe light suelta menos chispas que uno heavy.
##
## Dependencias: presentation -> domain, infrastructure/configuration

## Radio del fogonazo en el primer fotograma, en píxeles. Decae hacia cero
## durante `IMPACT_FLASH_TIME`.
const FLASH_RADIUS := 5.0

var _tier: StringName = CombatReaction.TIER_LOW
var _particles: Array[Dictionary] = []
var _life: float = GameConfig.IMPACT_LIFE
var _flash_remaining: float = GameConfig.IMPACT_FLASH_TIME


## Crea un burst en el mundo, en el punto del golpe y con las chispas volando
## hacia donde apunta la dirección (con algo de abanico, para que no parezca
## una línea).
static func spawn(
	parent: Node2D, point: Vector2, direction: Vector2, tier: StringName
) -> ImpactEffect:
	if parent == null or not is_instance_valid(parent):
		return null
	var effect := ImpactEffect.new()
	effect.global_position = point
	effect._tier = tier
	effect._build_particles(direction)
	parent.add_child(effect)
	return effect


## Cuántas partículas tiene el burst. Lo miden los tests: es lo que distingue
## un golpe ligero de uno pesado sin tener que mirar la pantalla.
func particle_count() -> int:
	return _particles.size()


## Vida que le queda al efecto, en segundos. Se borra solo al llegar a cero.
func life_remaining() -> float:
	return _life


func _build_particles(direction: Vector2) -> void:
	var count := CombatImpact.particle_count_of(_tier)
	var base := direction.normalized() if not direction.is_zero_approx() else Vector2.DOWN
	for index: int in count:
		# Las chispas no salen todas en línea: un abanico fijo alrededor de la
		# dirección del golpe y una velocidad distinta por chispa.
		var angle := base.angle() + randf_range(-1.4, 1.4)
		_particles.append({
			"dir": Vector2.from_angle(angle),
			"speed": randf_range(22.0, 55.0),
			"size": 2.0 if index % 3 == 0 else 1.0,
		})


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	queue_redraw()


func _draw() -> void:
	if _flash_remaining > 0.0:
		var ratio := _flash_remaining / GameConfig.IMPACT_FLASH_TIME
		var radius := FLASH_RADIUS * (0.4 + 0.6 * ratio)
		draw_circle(Vector2.ZERO, radius, GameConfig.IMPACT_FLASH_COLOR)
	for particle: Dictionary in _particles:
		var traveled: float = (GameConfig.IMPACT_LIFE - _life) * float(particle["speed"])
		var point := Vector2(particle["dir"]) * traveled
		var size := float(particle["size"])
		draw_rect(
			Rect2(point - Vector2(size, size) * 0.5, Vector2(size, size)),
			GameConfig.IMPACT_PARTICLE_COLOR
		)