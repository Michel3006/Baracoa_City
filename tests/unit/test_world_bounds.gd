extends RefCounted

## Pruebas de los límites del mundo (secciones 9, 14 y 17).


func register() -> Array:
	return [
		["los límites salen del tamaño en tiles", _bounds_from_tiles],
		["la zona de prueba tiene los límites esperados", _default_zone_bounds],
		["las capas de física son las declaradas", _collision_layers],
		["la cámara no ve más allá de la zona", _camera_fits_view],
	]


func _bounds_from_tiles(ctx: ScriptTestContext) -> void:
	var zone := ZoneView.new()
	zone.size_in_tiles = Vector2i(10, 5)
	var bounds := zone.compute_bounds()
	ctx.check_equal(bounds.position, Vector2.ZERO, "origen de la zona")
	ctx.check_equal(
		bounds.size,
		Vector2(160.0, 80.0),
		"tamaño derivado de 10x5 tiles de 16 px"
	)
	zone.free()


func _default_zone_bounds(ctx: ScriptTestContext) -> void:
	var zone := ZoneView.new()
	zone.size_in_tiles = Vector2i(64, 40)
	var bounds := zone.compute_bounds()
	ctx.check_equal(bounds.size, Vector2(1024.0, 640.0), "tamaño de zone_001")
	ctx.check(bounds.size.x > bounds.size.y, "la zona debe ser más ancha que alta")
	zone.free()


func _collision_layers(ctx: ScriptTestContext) -> void:
	ctx.check_equal(CollisionLayers.WORLD, 1, "capa world")
	ctx.check_equal(CollisionLayers.PLAYER, 2, "capa player")
	ctx.check_equal(CollisionLayers.NPC, 4, "capa npc")
	ctx.check_equal(CollisionLayers.ITEM, 8, "capa item")
	ctx.check_equal(CollisionLayers.HITBOX, 16, "capa hitbox")
	var mask := CollisionLayers.mask([CollisionLayers.WORLD, CollisionLayers.NPC])
	ctx.check_equal(mask, 5, "máscara combinada")
	ctx.check(CollisionLayers.has(mask, CollisionLayers.WORLD), "la máscara incluye world")
	ctx.check(not CollisionLayers.has(mask, CollisionLayers.PLAYER), "la máscara excluye player")


## Con zoom x3 la cámara muestra un tercio de la resolución base: 128x72 px.
## Tiene que caber en la zona para que los límites tengan sentido.
func _camera_fits_view(ctx: ScriptTestContext) -> void:
	var camera := WorldCamera.new()
	camera.zoom_level = 3.0
	var zone := Rect2(Vector2.ZERO, Vector2(1024.0, 640.0))
	camera.apply_zone_bounds(zone)

	var view_size := Vector2(GameConfig.BASE_RESOLUTION) / camera.zoom_level
	ctx.check(view_size.x < zone.size.x, "el ancho de cámara cabe en la zona")
	ctx.check(view_size.y < zone.size.y, "el alto de cámara cabe en la zona")
	ctx.check_equal(camera.limit_left, 0, "límite izquierdo")
	ctx.check_equal(camera.limit_right, 1024, "límite derecho")
	ctx.check_equal(camera.limit_bottom, 640, "límite inferior")
	camera.free()