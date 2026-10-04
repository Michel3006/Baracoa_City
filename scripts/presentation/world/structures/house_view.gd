class_name HouseView
extends WorldDecor

## Construcción sencilla del mapa de prueba (secciones 7 y 25).
##
## La colisión cubre solo el volumen construido, no el tejado: así se puede
## caminar por detrás de la casa sin chocar, como en un RPG top-down.
##
## Dependencias: presentation/world/world_decor.gd

const WALL := Color("c9b394")
const WALL_DARK := Color("9d8a6e")
const ROOF := Color("8c4a3f")
const DOOR := Color("4a3524")

@export var size_in_tiles: Vector2i = Vector2i(5, 4)


func _init() -> void:
	anchor_ratio = Vector2(0.5, 1.0)


func _ready() -> void:
	super._ready()
	_build_walls()


func _build_walls() -> void:
	var tile := float(GameConfig.tile_size())
	var width := float(size_in_tiles.x) * tile
	var height := float(size_in_tiles.y) * tile
	var footprint := Rect2(-width * 0.5, -height, width, height)

	var shape := get_node_or_null("Solid") as CollisionShape2D
	if shape != null:
		var rect := shape.shape as RectangleShape2D
		rect.size = Vector2(width, height)
		shape.position = footprint.position + footprint.size * 0.5


func _draw() -> void:
	var tile := float(GameConfig.tile_size())
	var width := float(size_in_tiles.x) * tile
	var height := float(size_in_tiles.y) * tile
	var left := -width * 0.5
	var top := -height

	draw_rect(Rect2(left, top, width, height), WALL)
	draw_rect(Rect2(left, top + height - tile * 0.6, width, tile * 0.6), WALL_DARK)

	var roof := PackedVector2Array([
		Vector2(left - tile * 0.4, top),
		Vector2(left + width + tile * 0.4, top),
		Vector2(left + width, top - tile * 1.1),
		Vector2(left, top - tile * 1.1),
	])
	draw_colored_polygon(roof, ROOF)
	draw_rect(Rect2(left + width * 0.42, top + height * 0.45, tile, height * 0.55), DOOR)
	draw_rect(
		Rect2(left + tile * 0.6, top + height * 0.3, tile * 0.8, tile * 0.6),
		WALL_DARK
	)