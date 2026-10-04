class_name TreeView
extends WorldDecor

## Árbol provisional del mapa de prueba (secciones 7 y 25).
##
## Dependencias: presentation/world/world_decor.gd

const CANOPY := Color("2f6b3a")
const TRUNK := Color("5a3f28")


func _init() -> void:
	anchor_ratio = Vector2(0.5, 1.0)


func _draw() -> void:
	var tile := float(GameConfig.tile_size())
	var half := tile * 0.5
	draw_rect(Rect2(Vector2(-half * 0.3, -tile * 0.45), Vector2(tile * 0.6, tile * 0.45)), TRUNK)
	draw_circle(Vector2.ZERO, tile * 0.5, CANOPY)
	draw_circle(Vector2(-tile * 0.18, -tile * 0.22), tile * 0.32, CANOPY.lightened(0.12))
	draw_circle(Vector2(tile * 0.2, tile * 0.12), tile * 0.26, CANOPY.darkened(0.15))