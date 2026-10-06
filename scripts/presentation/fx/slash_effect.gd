class_name SlashEffect
extends Node2D

## Efecto visual del golpe cuerpo a cuerpo (sección 25).
##
## Una hoja de cuatro fotogramas cuadrados de 32x32, que se reproduce una vez y se
## borra sola. No decide nada ni comprueba nada: si aparece, es porque alguien ha
## pegado. Por eso es un `Node2D` suelto y no un hijo del actor que golpea, así puede
## morir el actor sin que el efecto se borre a mitad.
##
## Hay dos hojas, con la misma rejilla: la del jugador es la espada curva del pack
## (`FX/Attack/SlashCurved`) y la de las criaturas es el zarpazo (`FX/Attack/Claw`).
## La diferencia la pone quien llama a `spawn()`, no este script: aquí no se decide
## quién tiene zarpazo y quién espada.
##
## Dependencias: presentation -> infrastructure/configuration

## Arco de espada: lo usa el jugador, con o sin arma en la mano.
const SHEET := "res://assets/fx/slash.png"
## Zarpazo de bestia: lo usan los enemigos.
const NPC_SHEET := "res://assets/fx/claw.png"

var sheet_path: String = SHEET

var _sprite: Sprite2D = null
var _elapsed: float = 0.0
var _frame: int = 0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Frames"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = load(sheet_path) as Texture2D
	if _sprite.texture == null:
		GameLogger.warning("Falta el efecto de golpe (%s)" % sheet_path, "SlashEffect")
		return
	# La hoja es de 128x32 con el fotograma cuadrado de 32x32: cuatro en una fila.
	# Con la rejilla equivocada (16x32) cada fotograma se parte por la mitad y la
	# animación sale hecha pedazos sin que salte ningún error, por eso la rejilla
	# está en `GameConfig` y hay un test que la comprueba contra la hoja.
	_sprite.hframes = maxi(1, int(round(_sprite.texture.get_width() / GameConfig.FX_FRAME_WIDTH)))
	_sprite.vframes = maxi(1, int(round(_sprite.texture.get_height() / GameConfig.FX_FRAME_HEIGHT)))
	add_child(_sprite)


## Punto alrededor del que gira el arco, en coordenadas del mundo.
##
## El cuerpo se dibuja hacia arriba desde los pies, así que su centro está
## `ACTOR_SPRITE_OFFSET` por encima del nodo. El arco gira sobre su centro: si se le
## pone sobre los pies, el golpe lateral sale a la altura de los tobillos y el de
## arriba se pone encima de la cabeza en vez de delante de ella. De aquí sale la
## posición; `FX_ORIGIN_OFFSET` es lo que lo separa por delante del cuerpo.
static func origin_for(body_position: Vector2, direction: Vector2) -> Vector2:
	var center := body_position + GameConfig.ACTOR_SPRITE_OFFSET
	if direction.is_zero_approx():
		return center
	return center + direction.normalized() * GameConfig.FX_ORIGIN_OFFSET


## Sitúa el efecto y lo orienta hacia donde se ha pegado.
func face(direction: Vector2, origin: Vector2 = Vector2.ZERO) -> void:
	global_position = origin
	if direction.is_zero_approx() or _sprite == null:
		return
	# Solo hay que girarlo. El arco es simétrico respecto a su centro, así que el
	# ángulo de la dirección ya lo coloca bien en las cuatro: abajo apunta abajo, a la
	# izquierda queda espejado y hacia arriba sube. Reflejarlo además en vertical
	# deshacía justo la rotación que lo orientaba, y el golpe hacia abajo salía
	# apuntando hacia arriba.
	_sprite.rotation = direction.angle()


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_elapsed += delta
	_frame = int(_elapsed * GameConfig.FX_FPS)
	if _frame >= GameConfig.FX_FRAMES:
		queue_free()
		return
	_sprite.frame = _frame


## Crea un efecto en el mundo y lo orienta. Se suelta solo al terminar.
##
## `sheet_path` elige la hoja (`SHEET` para el arco de espada, `NPC_SHEET` para el
## zarpazo); se fija antes de `add_child` porque es dentro de `_ready()` cuando se lee.
static func spawn(
	parent: Node,
	direction: Vector2,
	origin: Vector2,
	z: int = 0,
	sheet_path: String = SHEET
) -> SlashEffect:
	if parent == null or not is_instance_valid(parent):
		return null
	var effect := SlashEffect.new()
	effect.z_index = z
	effect.sheet_path = sheet_path
	parent.add_child(effect)
	effect.face(direction, origin)
	return effect