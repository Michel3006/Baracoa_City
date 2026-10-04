class_name CollisionLayers
extends RefCounted

## Nombres de las capas de física 2D (declaradas en project.godot).
##
## Centraliza los números para no repetir bits mágicos por el código. La capa
## solo filtra colisiones: las reglas de contacto las valida el servidor.
##
## Dependencias: shared

const WORLD: int = 1 << 0
const PLAYER: int = 1 << 1
const NPC: int = 1 << 2
const ITEM: int = 1 << 3
const HITBOX: int = 1 << 4


## Combina varias capas en una máscara.
static func mask(layers: Array[int]) -> int:
	var value := 0
	for layer: int in layers:
		value |= layer
	return value


## ¿La capa `layer` está activa en la máscara `mask`?
static func has(mask_value: int, layer: int) -> bool:
	return (mask_value & layer) != 0