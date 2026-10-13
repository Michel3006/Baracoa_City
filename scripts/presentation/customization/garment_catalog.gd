class_name GarmentCatalog
extends RefCounted

## Catálogo de prendas y peinados de la prueba mínima a coste 0.
##
## Cada prenda es una tabla de cuatro colores (base, sombra, luz, oscura) que
## sustituyen los cuatro tonos de piel del torso. Los colores están elegidos
## **sobre la paleta real de la hoja**, no inventados: la piel del pack Hormelz es
## `f7a566` (base), `ef7d57` (sombra), `ffcd75` (luz) y `d05d55` (oscura), medidos
## contando píxeles en las hojas.
##
## No hay ninguna imagen que mantener: cambiar de color no cuesta nada y vale
## para las 92 hojas a la vez. Añadir un color es añadir una fila a la tabla.

## Colores de piel de la hoja que una prenda puede sustituir, en orden
## base -> sombra -> luz -> oscura. Son las claves del mapa de cada prenda.
const SKIN_BASE := Color("f7a566")
const SKIN_SHADOW := Color("ef7d57")
const SKIN_LIGHT := Color("ffcd75")
const SKIN_DARK := Color("d05d55")
const SKIN_KEYS: Array[Color] = [SKIN_BASE, SKIN_SHADOW, SKIN_LIGHT, SKIN_DARK]

# --- Camisetas ---
const SHIRT_RED := &"shirt_red"
const SHIRT_BLUE := &"shirt_blue"
const SHIRT_GREEN := &"shirt_green"
const SHIRT_YELLOW := &"shirt_yellow"
const SHIRT_PURPLE := &"shirt_purple"
const SHIRT_WHITE := &"shirt_white"
const SHIRT_BLACK := &"shirt_black"

# --- Peinados (color; ver la limitación en GameConfig.GARMENT_HAIR_*) ---
const HAIR_BLACK := &"hair_black"
const HAIR_BLOND := &"hair_blond"
const HAIR_BROWN := &"hair_brown"
const HAIR_RED := &"hair_red"
const HAIR_WHITE := &"hair_white"
const HAIR_BLUE := &"hair_blue"

## Tabla de colores por prenda: base, sombra, luz, oscura.
const SHIRT_COLORS := {
	SHIRT_RED: [Color("cc3e40"), Color("962830"), Color("f0786e"), Color("6e1c24")],
	SHIRT_BLUE: [Color("426eb4"), Color("2c4c8c"), Color("78a5dc"), Color("20366c")],
	SHIRT_GREEN: [Color("4c9e54"), Color("30703c"), Color("8cd484"), Color("24542c")],
	SHIRT_YELLOW: [Color("e4c64a"), Color("b2942e"), Color("fae48c"), Color("866e1c")],
	SHIRT_PURPLE: [Color("8c5cb4"), Color("643e8c"), Color("bc8ede"), Color("482c6e")],
	SHIRT_WHITE: [Color("eaeaea"), Color("bcbcce"), Color("ffffff"), Color("92929e")],
	SHIRT_BLACK: [Color("40404c"), Color("282834"), Color("686876"), Color("1a1a24")],
}

const HAIR_COLORS := {
	HAIR_BLACK: [Color("2e2a3a"), Color("1e1c28"), Color("524a62"), Color("14141e")],
	HAIR_BLOND: [Color("d8b460"), Color("aa8c46"), Color("f6de98"), Color("806836")],
	HAIR_BROWN: [Color("7a5238"), Color("5c3c28"), Color("a87452"), Color("462e1e")],
	HAIR_RED: [Color("ac4832"), Color("843428"), Color("d87052"), Color("62241e")],
	HAIR_WHITE: [Color("e2e2e8"), Color("babac6"), Color("ffffff"), Color("90909c")],
	HAIR_BLUE: [Color("486098"), Color("324674"), Color("7a98ca"), Color("26365c")],
}


## Ids de las camisetas disponibles.
static func shirt_ids() -> Array[StringName]:
	return [
		SHIRT_RED, SHIRT_BLUE, SHIRT_GREEN, SHIRT_YELLOW,
		SHIRT_PURPLE, SHIRT_WHITE, SHIRT_BLACK,
	]


## Ids de los peinados disponibles.
static func hair_ids() -> Array[StringName]:
	return [HAIR_BLACK, HAIR_BLOND, HAIR_BROWN, HAIR_RED, HAIR_WHITE, HAIR_BLUE]


## Definición de una camiseta, o `null` si el id no está en el catálogo.
static func shirt(id: StringName) -> GarmentDefinition:
	return definition(GarmentDefinition.Part.SHIRT, id)


## Definición de un peinado, o `null` si el id no está en el catálogo.
static func hair(id: StringName) -> GarmentDefinition:
	return definition(GarmentDefinition.Part.HAIR, id)


## Definición de una parte del cuerpo, o `null` si el id no existe.
static func definition(part: int, id: StringName) -> GarmentDefinition:
	var table: Dictionary = HAIR_COLORS if part == GarmentDefinition.Part.HAIR else SHIRT_COLORS
	if id == &"" or not table.has(id):
		return null
	var colors: Array = table[id]
	var def := GarmentDefinition.new()
	def.id = id
	def.part = part
	def.label = _label_of(id)
	def.palette = _palette_from(colors)
	if part == GarmentDefinition.Part.HAIR:
		def.top_ratio = GameConfig.GARMENT_HAIR_TOP_RATIO
		def.bottom_ratio = GameConfig.GARMENT_HAIR_BOTTOM_RATIO
	return def


## Mapa `color de la hoja -> color de la prenda` a partir de los cuatro tonos.
##
## El orden de `SKIN_KEYS` (base, sombra, luz, oscura) es el contrato: la tabla
## de cada prenda viene en ese mismo orden, así que un color nuevo solo tiene que
## traer sus cuatro tonos en el mismo orden para que el sombreado case.
static func _palette_from(colors: Array) -> Dictionary:
	var palette: Dictionary = {}
	for index: int in range(SKIN_KEYS.size()):
		if index < colors.size():
			palette[SKIN_KEYS[index]] = colors[index]
	return palette


## Nombre legible de un id: `shirt_red` -> `SHIRT RED`.
static func _label_of(id: StringName) -> String:
	return str(id).to_upper().replace("_", " ")
