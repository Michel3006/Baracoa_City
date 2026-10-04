class_name TileCatalog
extends RefCounted

## Índice del atlas de texturas (sección 25).
##
## Un solo sitio conoce la retícula del atlas: el resto de la capa de presentación
## pide celdas por nombre. Añadir un tile nuevo es una entrada más en esta tabla,
## no un cambio en el mapa ni una clase nueva.
##
## El atlas es un pack de Tiny Dungeon de Kenney (licencia CC0). Mide 203x186 px
## con tiles de 16x16 y 1 px de separación: 12 columnas y 11 filas, 132 celdas.
##
## Dependencias: presentation

const ATLAS_PATH := "res://assets/environment/kenney_tiny_dungeon/Tilemap/tilemap.png"
const TILE_SIZE := 16
const SEPARATION := 1
const COLUMNS := 12
const ROWS := 11

## Terreno y muros. El MVP usa arena y tierra: la zona es costera.
enum Terrain {
	SAND,
	SAND_PEBBLE,
	SAND_DARK,
	SAND_BLEND,
	DIRT,
	DIRT_PEBBLE,
	PLANK,
	PAVED,
	WALL_BRICK,
}

## Objetos colocables en la zona.
enum Prop {
	BARREL,
	CRATE,
	CHEST,
	CAULDRON,
	BOOKSHELF,
	TABLE,
	TORCH,
	BUSH,
	BONES,
	POTION,
	SHIELD,
}

const _TERRAIN_CELLS := {
	Terrain.SAND: 48,
	Terrain.SAND_PEBBLE: 49,
	Terrain.SAND_DARK: 50,
	Terrain.SAND_BLEND: 53,
	Terrain.DIRT: 0,
	Terrain.DIRT_PEBBLE: 24,
	Terrain.PLANK: 26,
	Terrain.PAVED: 6,
	Terrain.WALL_BRICK: 36,
}

const _PROP_CELLS := {
	Prop.BARREL: 68,
	Prop.CRATE: 57,
	Prop.CHEST: 111,
	Prop.CAULDRON: 120,
	Prop.BOOKSHELF: 25,
	Prop.TABLE: 123,
	Prop.TORCH: 113,
	Prop.BUSH: 108,
	Prop.BONES: 60,
	Prop.POTION: 105,
	Prop.SHIELD: 92,
}


## Convierte el índice lineal de una celda en su coordenada dentro del atlas.
static func cell_of(index: int) -> Vector2i:
	return Vector2i(index % COLUMNS, index / COLUMNS)


## Región en píxeles que ocupa una celda, separaciones incluidas.
static func region_of(cell: Vector2i) -> Rect2:
	var step := float(TILE_SIZE + SEPARATION)
	return Rect2(Vector2(cell) * step, Vector2.ONE * float(TILE_SIZE))


static func terrain_cell(terrain: int) -> Vector2i:
	return cell_of(_TERRAIN_CELLS.get(terrain, 0))


static func prop_cell(prop: int) -> Vector2i:
	return cell_of(_PROP_CELLS.get(prop, 0))


## Textura de una celda suelta. El decor es un sprite, no un tile, así que
## recorta la región del atlas en lugar de montar un `TileSet`.
static func prop_texture(prop: int) -> AtlasTexture:
	var region := AtlasTexture.new()
	region.atlas = load(ATLAS_PATH)
	region.region = region_of(prop_cell(prop))
	region.filter_clip = true
	return region


## Fuente de tiles con las 132 celdas. La construye el terreno una sola vez.
static func build_source() -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(ATLAS_PATH)
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.separation = Vector2i(SEPARATION, SEPARATION)
	for index: int in COLUMNS * ROWS:
		source.create_tile(cell_of(index))
	return source