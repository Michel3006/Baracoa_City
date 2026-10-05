class_name SlashEffect
extends Node2D

## Efecto visual del golpe cuerpo a cuerpo (sección 25).
##
## Una hoja de ocho fotogramas, cada uno de 16 de ancho por 32 de alto, que se reproduce
## una vez y se borra sola. No decide nada ni comprueba nada: si aparece, es porque
## alguien ha pegado. Por eso es un `Node2D` suelto y no un hijo del actor que golpea,
## así puede morir el actor sin que el efecto se borre a mitad.
##
## La hoja es `FX/Attack/SlashCurved/SpriteSheet.png` del pack, recortada en
## `GameConfig.FX_FRAME_WIDTH` x `GameConfig.FX_FRAME_HEIGHT`.
##
## Dependencias: presentation -> infrastructure/configuration

const SHEET := "res://assets/fx/slash.png"

var _sprite: Sprite2D = null
var _elapsed: float = 0.0
var _frame: int = 0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Frames"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = load(SHEET) as Texture2D
	if _sprite.texture == null:
		GameLogger.warning("Falta el efecto de golpe (%s)" % SHEET, "SlashEffect")
		return
	# El fotograma del efecto no es cuadrado: es 16 de ancho por 32 de alto, que es lo
	# que mide un arco de espada. Recortarlo en 16x16 partiría la hoja en dos filas y
	# el efecto recorrería la de arriba, que está casi vacía.
	_sprite.hframes = maxi(1, int(round(_sprite.texture.get_width() / GameConfig.FX_FRAME_WIDTH)))
	_sprite.vframes = maxi(1, int(round(_sprite.texture.get_height() / GameConfig.FX_FRAME_HEIGHT)))
	add_child(_sprite)


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
static func spawn(parent: Node, direction: Vector2, origin: Vector2, z: int = 0) -> SlashEffect:
	if parent == null or not is_instance_valid(parent):
		return null
	var effect := SlashEffect.new()
	effect.z_index = z
	parent.add_child(effect)
	effect.face(direction, origin)
	return effect