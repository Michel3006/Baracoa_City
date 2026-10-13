class_name AppearanceState
extends RefCounted

## Qué lleva puesto el jugador (plan de ropa y peinados, Fase 1).
##
## Vive en la presentación y guarda solo cosmética: no entra en el dominio ni
## cambia ninguna regla. El estado visual del cuerpo (clip, orientación,
## fotograma) sigue siendo de `ActorSprite`; esto solo dice qué prenda se pinta
## encima.

signal changed()

## Camiseta elegida (id de `GarmentCatalog`), o `&""` para ninguna.
var shirt_id: StringName = &""
## Peinado elegido (id de `GarmentCatalog`), o `&""` para ninguno.
var hair_id: StringName = &""


## Cambia la camiseta. Volver a pedir la misma no emite la señal.
func set_shirt(id: StringName) -> void:
	if id == shirt_id:
		return
	shirt_id = id
	changed.emit()


## Cambia el peinado. Volver a pedir el mismo no emite la señal.
func set_hair(id: StringName) -> void:
	if id == hair_id:
		return
	hair_id = id
	changed.emit()


## Id elegido para una parte del cuerpo.
func id_for(part: int) -> StringName:
	return hair_id if part == GarmentDefinition.Part.HAIR else shirt_id
