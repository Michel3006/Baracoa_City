class_name PropView
extends WorldDecor

## Prop del atlas colocado en la zona (secciones 14 y 25).
##
## Un solo tipo para todos los objetos: la celda del atlas es el dato. Añadir un
## prop nuevo no obliga a escribir una clase (sección 6: no duplicar lógica).
##
## Por defecto no bloquea: son atrezo. Solo lo que el diseño del mapa marque como
## sólido detiene al jugador, igual que un árbol o una casa.
##
## Dependencias: presentation

@export var prop: int = TileCatalog.Prop.BARREL


func _init() -> void:
	solid = false


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = TileCatalog.prop_texture(prop)
	sprite.modulate = tint
	add_child(sprite)
	super._ready()