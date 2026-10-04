class_name ZoneView
extends Node2D

## Presentación de una zona del mundo (sección 14).
##
## Una zona es una escena autónoma con su terreno, sus obstáculos y sus límites.
## Añadir zonas nuevas no obliga a modificar el mapa existente, y el mapa completo
## nunca se carga de una sola vez.
##
## El terreno son tiles del atlas (`TileCatalog`), no rectángulos dibujados a mano:
## la zona se pinta una vez al cargar y a partir de ahí solo hay nodos.
##
## Dependencias: presentation, infrastructure/configuration

## Calle vertical (columna) y horizontal (fila), en tiles.
const PATH_X := 20
const PATH_Y := 22

## Radio en tiles de la losa empedrada alrededor del punto de aparición.
const PLAZA_RADIUS := 2

## Identificador de la fuente de tiles dentro del `TileSet` de la zona.
const SOURCE_ID := 0

@export var zone_id: StringName = &"zone_001"
@export var size_in_tiles: Vector2i = Vector2i(64, 40)
@export var demo_layout: bool = true
@export var scattered_trees: bool = false

var bounds: Rect2 = Rect2()


func _ready() -> void:
	bounds = compute_bounds()
	_build_terrain()
	_build_bounds_wall()
	if demo_layout:
		build_demo_layout()
	if scattered_trees:
		_scatter_trees()
	GameLogger.debug(
		"Zona %s lista: %s px" % [zone_id, bounds.size], "ZoneView"
	)


## Rectángulo jugable en coordenadas de mundo (sección 16).
func compute_bounds() -> Rect2:
	var tile := float(GameConfig.tile_size())
	return Rect2(Vector2.ZERO, Vector2(size_in_tiles) * tile)


## Terreno y calles como tiles reales. Las calles conservan las coordenadas que
## ya usaba el mapa dibujado a mano (x=20, y=22).
func _build_terrain() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TileCatalog.TILE_SIZE, TileCatalog.TILE_SIZE)
	tile_set.add_source(TileCatalog.build_source())

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tile_set
	add_child(ground)

	for tile_y: int in range(size_in_tiles.y):
		for tile_x: int in range(size_in_tiles.x):
			_paint(ground, Vector2i(tile_x, tile_y), _ground_variant(tile_x, tile_y))
	_paint_paths(ground)
	_paint_plaza(ground)


func _paint_paths(ground: TileMapLayer) -> void:
	for tile_x: int in range(size_in_tiles.x):
		_paint_path(ground, Vector2i(tile_x, PATH_Y), tile_x)
	for tile_y: int in range(size_in_tiles.y):
		_paint_path(ground, Vector2i(PATH_X, tile_y), tile_y)
	_paint(ground, Vector2i(PATH_X, PATH_Y), TileCatalog.Terrain.DIRT)


func _paint_path(ground: TileMapLayer, cell: Vector2i, salt: int) -> void:
	var terrain := TileCatalog.Terrain.DIRT
	if salt % 3 == 0:
		terrain = TileCatalog.Terrain.DIRT_PEBBLE
	_paint(ground, cell, terrain)


## Losa empedrada en el punto de aparición: donde el jugador entra ya no hay arena.
func _paint_plaza(ground: TileMapLayer) -> void:
	var tile := float(GameConfig.tile_size())
	var spawn_tile := Vector2i(GameConfig.PLAYER_SPAWN / tile)
	for tile_y: int in range(spawn_tile.y - PLAZA_RADIUS, spawn_tile.y + PLAZA_RADIUS + 1):
		for tile_x: int in range(spawn_tile.x - PLAZA_RADIUS, spawn_tile.x + PLAZA_RADIUS + 1):
			if _is_inside(Vector2i(tile_x, tile_y)):
				_paint(ground, Vector2i(tile_x, tile_y), TileCatalog.Terrain.PAVED)


## Arena en tres tonos, elegidos con un hash determinista: el mismo mapa en cada
## partida y en cada test, igual que `_scatter_trees`.
func _ground_variant(tile_x: int, tile_y: int) -> int:
	match (tile_x * 31 + tile_y * 17) % 3:
		0:
			return TileCatalog.Terrain.SAND
		1:
			return TileCatalog.Terrain.SAND_DARK
		_:
			return TileCatalog.Terrain.SAND_PEBBLE


func _paint(ground: TileMapLayer, cell: Vector2i, terrain: int) -> void:
	if not _is_inside(cell):
		return
	ground.set_cell(cell, SOURCE_ID, TileCatalog.terrain_cell(terrain))


func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size_in_tiles.x and cell.y < size_in_tiles.y


## Muro invisible en el borde de la zona: mantiene al jugador dentro del área
## jugable sin gastar tiles de borde (secciones 17 y 38).
func _build_bounds_wall() -> void:
	var thickness := float(GameConfig.tile_size())
	var wall := StaticBody2D.new()
	wall.name = "Bounds"
	wall.collision_layer = CollisionLayers.WORLD
	wall.collision_mask = 0
	add_child(wall)

	var outer := bounds.grow(thickness)
	var walls: Array[Rect2] = [
		Rect2(outer.position, Vector2(outer.size.x, thickness)),
		Rect2(Vector2(outer.position.x, outer.end.y - thickness), Vector2(outer.size.x, thickness)),
		Rect2(outer.position, Vector2(thickness, outer.size.y)),
		Rect2(Vector2(outer.end.x - thickness, outer.position.y), Vector2(thickness, outer.size.y)),
	]
	for cell: Rect2 in walls:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = cell.size
		shape.shape = rect
		shape.position = cell.position + cell.size * 0.5
		wall.add_child(shape)


## Coloca un decor/obstáculo. `kind` es una clave de `scripts/presentation/world/decor`.
func place_decor(kind: StringName, tile_position: Vector2i) -> Node2D:
	var node := _create_decor(kind)
	if node == null:
		GameLogger.warning("Decor desconocido: %s" % kind, "ZoneView")
		return null
	node.position = _tile_to_world(tile_position)
	add_child(node)
	return node


func _create_decor(kind: StringName) -> WorldDecor:
	match kind:
		&"tree":
			return TreeView.new()
		&"rock":
			return RockView.new()
		&"house":
			return HouseView.new()
		_:
			return null


## Coloca un prop del atlas. `prop` es un `TileCatalog.Prop`.
func place_prop(prop: int, tile_position: Vector2i, is_solid: bool = false) -> Node2D:
	var node := PropView.new()
	node.prop = prop
	node.solid = is_solid
	node.position = _tile_to_world(tile_position)
	add_child(node)
	return node


func _tile_to_world(tile_position: Vector2i) -> Vector2:
	return Vector2(tile_position) * float(GameConfig.tile_size())


## Distribución de prueba de la primera demostración (sección 38).
##
## Los sólidos (barriles, cajas, mesas) están fuera de los pasillos que usan los
## tests de integración: esos pasillos los recorren en línea recta.
func build_demo_layout() -> void:
	var trees: Array[Vector2i] = [
		Vector2i(6, 8), Vector2i(24, 4), Vector2i(9, 24),
		Vector2i(34, 20), Vector2i(44, 30), Vector2i(52, 22),
	]
	for tile: Vector2i in trees:
		place_decor(&"tree", tile)
	var rocks: Array[Vector2i] = [Vector2i(40, 11), Vector2i(29, 27), Vector2i(18, 18)]
	for tile: Vector2i in rocks:
		place_decor(&"rock", tile)
	var houses: Array[Vector2i] = [Vector2i(14, 30), Vector2i(48, 8)]
	for tile: Vector2i in houses:
		place_decor(&"house", tile)
	_place_props()


## Atrezo de la zona. Solo `solid` bloquea al jugador; el resto se pisa.
func _place_props() -> void:
	var solids: Array[Vector2i] = [
		Vector2i(2, 2), Vector2i(61, 2), Vector2i(2, 37), Vector2i(61, 37),
		Vector2i(4, 4), Vector2i(59, 5), Vector2i(56, 34), Vector2i(47, 30),
		Vector2i(43, 33), Vector2i(45, 33), Vector2i(18, 16),
	]
	for tile: Vector2i in solids:
		place_prop(_solid_prop_at(tile), tile, true)

	var bushes: Array[Vector2i] = [
		Vector2i(30, 10), Vector2i(52, 25), Vector2i(10, 35), Vector2i(40, 30),
	]
	for tile: Vector2i in bushes:
		place_prop(TileCatalog.Prop.BUSH, tile)

	var torches: Array[Vector2i] = [
		Vector2i(19, 14), Vector2i(21, 18), Vector2i(25, 23), Vector2i(30, 19),
	]
	for tile: Vector2i in torches:
		place_prop(TileCatalog.Prop.TORCH, tile)

	place_prop(TileCatalog.Prop.BONES, Vector2i(16, 6))
	place_prop(TileCatalog.Prop.POTION, Vector2i(17, 16))
	place_prop(TileCatalog.Prop.SHIELD, Vector2i(57, 33))


## Qué prop va en cada tile sólido: una regla fija, no un dato duplicado.
func _solid_prop_at(tile: Vector2i) -> int:
	match tile:
		Vector2i(2, 2), Vector2i(61, 2), Vector2i(2, 37), Vector2i(61, 37):
			return TileCatalog.Prop.BARREL
		Vector2i(4, 4), Vector2i(59, 5):
			return TileCatalog.Prop.CRATE
		Vector2i(56, 34):
			return TileCatalog.Prop.CHEST
		Vector2i(47, 30):
			return TileCatalog.Prop.CAULDRON
		Vector2i(43, 33), Vector2i(45, 33):
			return TileCatalog.Prop.BOOKSHELF
		_:
			return TileCatalog.Prop.TABLE


## Rellena la zona con árboles según un patrón determinista: el mismo mapa en
## todas las partidas y en los tests, sin necesidad de un mapa gigante.
func _scatter_trees() -> void:
	for tile_y: int in range(2, size_in_tiles.y - 2, 3):
		for tile_x: int in range(2, size_in_tiles.x - 2, 3):
			if (tile_x * 31 + tile_y * 17) % 5 == 0:
				continue
			place_decor(&"tree", Vector2i(tile_x, tile_y))