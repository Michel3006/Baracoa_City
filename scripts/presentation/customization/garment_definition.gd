class_name GarmentDefinition
extends RefCounted

## Definición de una prenda o un peinado (plan de ropa y peinados, Fase 1).
##
## Es **datos puros**: qué colores de la hoja sustituye y en qué banda del cuerpo.
## No sabe dibujar; de eso se encarga `GarmentLayer` con `GarmentRecolor`.
##
## Por qué por color y no por imagen: el personaje tiene 92 hojas y ~2.236
## fotogramas, así que redibujar la prenda por fotograma no cabe en ningún
## presupuesto sensato (ni de generaciones ni de autoría). Sustituyendo los
## píxeles de piel del torso por los de la prenda, la alineación es exacta por
## construcción y la oclusión es automática: brazos, manos y botas son de otro
## color y no se tocan.

## Qué parte del cuerpo viste la prenda.
enum Part { SHIRT, HAIR, HAIR_SHAPE }

## Identificador (los del `GarmentCatalog`).
var id: StringName = &""
## Parte del cuerpo que cubre.
var part: int = Part.SHIRT
## Nombre legible, para la interfaz que venga después.
var label: String = ""
## Colores de la hoja que la prenda sustituye: `Color base` -> `Color de prenda`.
##
## Las claves son colores del pack (piel del torso); los valores, los de la
## prenda. Se mantienen los cuatro tonos (base, sombra, luz, oscura) para que el
## sombreado y el volumen del cuerpo sigan leyéndose.
var palette: Dictionary = {}
## Banda de la prenda, en fracción de la altura del cuerpo (0 = pies del dibujo,
## 1 = coronilla). Para el pelo es la parte de arriba de la cabeza.
var top_ratio: float = GameConfig.GARMENT_SHIRT_TOP_RATIO
var bottom_ratio: float = GameConfig.GARMENT_SHIRT_BOTTOM_RATIO


## ¿Esta definición pinta algo de verdad?
func is_valid() -> bool:
	return id != &"" and not palette.is_empty() and bottom_ratio > top_ratio
