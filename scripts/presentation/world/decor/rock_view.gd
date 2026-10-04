class_name RockView
extends WorldDecor

## Piedra provisional del mapa de prueba (secciones 7 y 25).
##
## Dependencias: presentation/world/world_decor.gd

const STONE := Color("7d7f86")
const STONE_DARK := Color("5c5e65")


func _init() -> void:
	anchor_ratio = Vector2(0.5, 1.0)


func _draw() -> void:
	var tile := float(GameConfig.tile_size())
	draw_rect(Rect2(-tile * 0.3, -tile * 0.34, tile * 0.6, tile * 0.34), STONE_DARK)
	draw_rect(Rect2(-tile * 0.22, -tile * 0.44, tile * 0.46, tile * 0.28), STONE)
	draw_rect(Rect2(-tile * 0.22, -tile * 0.44, tile * 0.46, tile * 0.06), STONE.lightened(0.25))