class_name WorldDecor
extends StaticBody2D

## Base de los obstáculos sólidos del mundo (sección 7).
##
## Un decor es solo presentación: aporta dibujo y colisión, ninguna regla de juego.
## Si en el futuro un árbol se puede talar, esa regla vivirá en el dominio y el
## decor únicamente mostrará el resultado.
##
## Dependencias: presentation, infrastructure/configuration

## Punto del sprite que se ancla en la posición del tile (0.5, 1.0 = base).
@export var anchor_ratio: Vector2 = Vector2(0.5, 1.0)
@export var tint: Color = Color.WHITE

## ¿El decor detiene al jugador? Un barrel bloquea, una antorcha no.
@export var solid: bool = true


func _ready() -> void:
	_apply_anchor()
	_build_collision()


## Compensa el origen para que la base del objeto quede sobre su tile.
func _apply_anchor() -> void:
	position -= Vector2(GameConfig.tile_size(), GameConfig.tile_size()) * anchor_ratio


func _build_collision() -> void:
	collision_layer = CollisionLayers.WORLD if solid else 0
	collision_mask = 0
	if not solid:
		return
	var shape := CollisionShape2D.new()
	shape.name = "Solid"
	var rect := RectangleShape2D.new()
	rect.size = Vector2.ONE * float(GameConfig.tile_size())
	shape.shape = rect
	add_child(shape)