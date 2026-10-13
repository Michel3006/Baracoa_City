extends RefCounted

## Pruebas del recoloreado de prendas (plan de ropa, Fase 1).
##
## Es el núcleo del sistema a coste 0: construir, a partir de la propia hoja del
## personaje, una superposición con solo los píxeles de piel de la banda de la
## prenda. Se prueba contra imágenes sintéticas porque lo que hay que comprobar
## es geométrico: dónde pinta, dónde no, y que no toque lo que no es piel.
##
## Se usan imágenes de un solo actor de color plano, no las hojas reales: la hoja
## real cambia, y un test que dependiera de un fotograma concreto se rompería al
## retocar el pack sin que el sistema tuviera nada roto.

const SKIN := Color("f7a566")
const TRUNKS := Color("873258")
const BOOTS := Color("566c86")
const EYE := Color("f4f4f4")


func register() -> Array:
	return [
		["una hoja o una prenda vacías no dan superposición", _empty_inputs],
		["la prenda cubre la piel del torso y respeta cabeza y pantalón", _torso_band],
		["lo que no es piel no se repinta aunque caiga en la banda", _only_skin],
		["un cuerpo tumbado se pinta en horizontal, centrado", _wide_body],
		["el peinado no se pinta en un cuerpo tumbado", _no_hair_on_wide_body],
		["la superposición no lleva el cuerpo, solo la prenda", _only_garment_pixels],
		["cada celda se mide por su cuenta (varias filas y columnas)", _multi_cell],
	]


## Construye una hoja sintética pintando con `paint(img)`.
func _sheet(size: Vector2i, paint: Callable) -> ImageTexture:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	paint.call(img)
	return ImageTexture.create_from_image(img)


## Pinta un rectángulo de color en la imagen.
func _fill(img: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			img.set_pixel(x, y, color)


func _empty_inputs(ctx: ScriptTestContext) -> void:
	var def := GarmentCatalog.shirt(GarmentCatalog.SHIRT_RED)
	var sheet := _sheet(Vector2i(42, 44), func(_img: Image) -> void: pass)
	ctx.check(GarmentRecolor.build(null, 1, 1, def) == null, "sin hoja debería dar null")
	ctx.check(GarmentRecolor.build(sheet, 1, 1, null) == null, "sin prenda debería dar null")
	var blank := GarmentDefinition.new()
	ctx.check(
		GarmentRecolor.build(sheet, 1, 1, blank) == null,
		"una prenda sin paleta debería dar null"
	)


## Cuerpo erguido de 25 px de alto: cabeza (arriba), torso (piel), pantalón rojo
## y botas azules. La banda de la camiseta tiene que caer en el torso, no en la
## cabeza ni en el pantalón.
func _torso_band(ctx: ScriptTestContext) -> void:
	var sheet := _sheet(Vector2i(42, 44), func(img: Image) -> void:
		_fill(img, Rect2i(19, 8, 4, 5), SKIN)   # cabeza (y 8..12)
		_fill(img, Rect2i(19, 13, 4, 12), SKIN) # torso (y 13..24)
		_fill(img, Rect2i(19, 25, 4, 4), TRUNKS) # pantalón (y 25..28)
		_fill(img, Rect2i(19, 29, 4, 4), BOOTS)  # botas (y 29..32)
	)
	var def := GarmentCatalog.shirt(GarmentCatalog.SHIRT_RED)
	var base: Color = def.palette[GarmentCatalog.SKIN_BASE]
	var overlay := GarmentRecolor.build(sheet, 1, 1, def)
	ctx.check(overlay != null, "no se construyó la superposición de la camiseta")
	if overlay == null:
		return
	var image := overlay.get_image()
	ctx.check_equal(image.get_size(), Vector2i(42, 44), "el tamaño de la superposición cambió")

	var torso := image.get_pixel(20, 18)
	ctx.check_equal(torso.r8, base.r8, "el torso no cogió el color de la camiseta (rojo)")
	ctx.check_equal(torso.g8, base.g8, "el torso no cogió el color de la camiseta (verde)")
	ctx.check_equal(torso.b8, base.b8, "el torso no cogió el color de la camiseta (azul)")

	ctx.check_equal(image.get_pixel(20, 10).a8, 0, "la cabeza se pintó con la camiseta")
	ctx.check_equal(image.get_pixel(20, 26).a8, 0, "el pantalón se pintó con la camiseta")
	ctx.check_equal(image.get_pixel(0, 0).a8, 0, "se pintó un píxel vacío")


## Un píxel que no es del color de la piel (un ojo, una insignia) no se repinta
## aunque la banda pase por encima: la oclusión no puede depender de la forma.
func _only_skin(ctx: ScriptTestContext) -> void:
	var sheet := _sheet(Vector2i(42, 44), func(img: Image) -> void:
		_fill(img, Rect2i(19, 8, 4, 25), SKIN)
		img.set_pixel(20, 20, EYE)
	)
	var def := GarmentCatalog.shirt(GarmentCatalog.SHIRT_RED)
	var overlay := GarmentRecolor.build(sheet, 1, 1, def)
	ctx.check(overlay != null, "no se construyó la superposición")
	if overlay == null:
		return
	var image := overlay.get_image()
	ctx.check(
		image.get_pixel(20, 18).a8 > 0,
		"la piel del torso debería repintarse"
	)
	ctx.check_equal(
		image.get_pixel(20, 20).a8, 0,
		"un píxel que no es piel se repintó con la camiseta"
	)


## Cuerpo tumbado (más ancho que alto): la banda va centrada en horizontal, para
## que la prenda caiga en el torso y no en los extremos (pies y cabeza).
func _wide_body(ctx: ScriptTestContext) -> void:
	var sheet := _sheet(Vector2i(42, 44), func(img: Image) -> void:
		_fill(img, Rect2i(5, 20, 30, 6), SKIN)
	)
	var def := GarmentCatalog.shirt(GarmentCatalog.SHIRT_RED)
	var overlay := GarmentRecolor.build(sheet, 1, 1, def)
	ctx.check(overlay != null, "no se construyó la superposición de un cuerpo tumbado")
	if overlay == null:
		return
	var image := overlay.get_image()
	ctx.check(image.get_pixel(20, 22).a8 > 0, "el centro del cuerpo tumbado no se pintó")
	ctx.check_equal(image.get_pixel(6, 22).a8, 0, "se pintó un extremo del cuerpo tumbado")
	ctx.check_equal(image.get_pixel(33, 22).a8, 0, "se pintó el otro extremo del cuerpo tumbado")


## En un cuerpo tumbado no se puede saber en qué extremo está la cabeza (el mismo
## fotograma vale para las dos direcciones espejadas), así que el peinado no
## pinta nada: mejor sin pelo que con el pelo puesto en el torso.
func _no_hair_on_wide_body(ctx: ScriptTestContext) -> void:
	var sheet := _sheet(Vector2i(42, 44), func(img: Image) -> void:
		_fill(img, Rect2i(5, 20, 30, 6), SKIN)
	)
	var def := GarmentCatalog.hair(GarmentCatalog.HAIR_BLOND)
	var overlay := GarmentRecolor.build(sheet, 1, 1, def)
	ctx.check(overlay != null, "no se construyó la superposición del peinado")
	if overlay == null:
		return
	var image := overlay.get_image()
	var painted := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a8 > 0:
				painted += 1
	ctx.check_equal(painted, 0, "el peinado se pintó sobre un cuerpo tumbado")


## La superposición no es una copia del cuerpo: fuera de la banda (y fuera de lo
## que la prenda repinta) no debe quedar ni un píxel del cuerpo original.
func _only_garment_pixels(ctx: ScriptTestContext) -> void:
	var sheet := _sheet(Vector2i(42, 44), func(img: Image) -> void:
		_fill(img, Rect2i(19, 8, 4, 25), SKIN)
	)
	var def := GarmentCatalog.shirt(GarmentCatalog.SHIRT_RED)
	var overlay := GarmentRecolor.build(sheet, 1, 1, def)
	ctx.check(overlay != null, "no se construyó la superposición")
	if overlay == null:
		return
	var image := overlay.get_image()
	# La cabeza sigue siendo piel en el original, pero en la superposición tiene
	# que estar vacía: si estuviera, al dibujarla encima taparía el cuerpo.
	ctx.check_equal(image.get_pixel(20, 10).a8, 0, "la superposición repite la cabeza del cuerpo")


## Con rejilla de 2x2, cada celda se mide por su cuenta: el mismo fotograma
## pequeño en una esquina no debe arrastrar la banda a las otras celdas.
func _multi_cell(ctx: ScriptTestContext) -> void:
	var sheet := _sheet(Vector2i(84, 88), func(img: Image) -> void:
		# Solo la celda de abajo a la derecha tiene cuerpo.
		_fill(img, Rect2i(61, 52, 4, 25), SKIN)
	)
	var def := GarmentCatalog.shirt(GarmentCatalog.SHIRT_RED)
	var overlay := GarmentRecolor.build(sheet, 2, 2, def)
	ctx.check(overlay != null, "no se construyó la superposición en rejilla")
	if overlay == null:
		return
	var image := overlay.get_image()
	ctx.check(image.get_pixel(62, 62).a8 > 0, "el cuerpo de su celda no se pintó")
	ctx.check_equal(image.get_pixel(20, 20).a8, 0, "se pintó una celda vacía")
	ctx.check_equal(image.get_pixel(62, 20).a8, 0, "la banda saltó a otra celda")
