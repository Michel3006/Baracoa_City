class_name GarmentRecolor
extends RefCounted

## Construye la superposición de una prenda a partir de la propia hoja del
## personaje (plan de ropa y peinados, Fase 1).
##
## Qué hace, en una frase: coge la hoja, y por cada celda (fotograma) busca el
## cuerpo, calcula la banda que cubre la prenda y sustituye los píxeles de piel
## que caen dentro por los colores de la prenda. Lo demás queda transparente.
##
## Por qué así:
##
## - **Alineación exacta.** Trabaja sobre los mismos píxeles que el cuerpo, en la
##   misma rejilla y con el mismo anclaje. No hay forma de que el dibujo de la
##   prenda y el cuerpo se separen: son la misma imagen.
## - **Cobertura total a coste 0.** Cualquier hoja de cualquier clip y cualquier
##   fotograma pasa por aquí, así que la prenda sale en las 92 hojas sin gastar
##   una sola generación ni dibujar un solo fotograma a mano.
## - **La banda se mide por celda, no se fija.** El torso de una patada no está
##   donde el del reposo; con una caja fija la prenda se saldría del cuerpo.
##   Aquí se calcula el rectángulo del cuerpo de cada fotograma.
##
## Lo que NO hace: cambiar el color de un píxel que no esté en la banda o que no
## sea del color clave. Por eso los brazos, las manos y las botas (otros colores,
## y las manos fuera de la banda) quedan intactos: la oclusión sale sola.

## Construye la textura de superposición de `def` sobre `sheet`.
##
## `columns` y `rows` son la rejilla de la hoja (`hframes`/`vframes` del actor).
## Devuelve `null` si no se puede construir (hoja o definición vacías).
static func build(
	sheet: Texture2D,
	columns: int,
	rows: int,
	def: GarmentDefinition
) -> Texture2D:
	if sheet == null or def == null or not def.is_valid():
		return null
	var source := sheet.get_image()
	if source == null:
		return null
	if source.get_format() != Image.FORMAT_RGBA8:
		source = source.duplicate() as Image
		source.convert(Image.FORMAT_RGBA8)
	var width := source.get_width()
	var height := source.get_height()
	if width <= 0 or height <= 0:
		return null
	var cols := maxi(1, columns)
	var total_rows := maxi(1, rows)
	var cell_w := maxi(1, width / cols)
	var cell_h := maxi(1, height / total_rows)

	var src := source.get_data()
	# El destino nace transparente: la superposición lleva solo los píxeles que
	# la prenda repinta. Si llevara el cuerpo entero, volvería a dibujarlo encima
	# de sí mismo y los bordes translúcidos se oscurecerían al doblarse.
	var dst := PackedByteArray()
	dst.resize(src.size())
	var keys := _int_keys(def.palette)
	for row in range(total_rows):
		for col in range(cols):
			_recolor_cell(
				src, dst, width, col * cell_w, row * cell_h, cell_w, cell_h, def, keys
			)
	var out := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, dst)
	if out == null:
		return null
	return ImageTexture.create_from_image(out)


## Convierte el mapa de la definición a claves empaquetadas (`r<<16|g<<8|b`),
## para no construir un `Color` por píxel al comparar.
static func _int_keys(palette: Dictionary) -> Dictionary:
	var keys: Dictionary = {}
	for color: Color in palette:
		keys[(color.r8 << 16) | (color.g8 << 8) | color.b8] = palette[color]
	return keys


## Repinta una celda (un fotograma).
static func _recolor_cell(
	src: PackedByteArray,
	dst: PackedByteArray,
	width: int,
	x0: int,
	y0: int,
	cell_w: int,
	cell_h: int,
	def: GarmentDefinition,
	keys: Dictionary
) -> void:
	# Rectángulo del cuerpo de ESTE fotograma, saltando los píxeles transparentes.
	var min_x := cell_w
	var max_x := -1
	var min_y := cell_h
	var max_y := -1
	for y in range(cell_h):
		var row_base := ((y0 + y) * width + x0) * 4
		for x in range(cell_w):
			if src[row_base + x * 4 + 3] > 0:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return
	var body_w := max_x - min_x + 1
	var body_h := max_y - min_y + 1

	var x_from := min_x
	var x_to := max_x
	var y_from := min_y
	var y_to := max_y
	if body_w > int(round(body_h * GameConfig.GARMENT_WIDE_BODY_RATIO)):
		# Cuerpo tumbado o rodando (más ancho que alto): la banda va centrada en
		# horizontal, que es donde cae el torso cuando el personaje está en el
		# suelo.
		#
		# El pelo NO se pinta aquí: en un cuerpo tumbado la cabeza está en un
		# extremo, pero no se sabe en cuál (el mismo fotograma sirve para las dos
		# direcciones espejadas), así que pintar "la banda central" le pondría el
		# pelo en el torso. Mejor sin pelo que con el pelo mal puesto: la cabeza
		# se queda con su aspecto base, que es lo que ya se ve sin peinado.
		if def.part == GarmentDefinition.Part.HAIR:
			return
		x_from = min_x + int(round(GameConfig.GARMENT_WIDE_BAND_MIN * body_w))
		x_to = min_x + int(round(GameConfig.GARMENT_WIDE_BAND_MAX * body_w))
	else:
		# Cuerpo erguido: la banda arranca después de la cabeza y termina en la
		# cadera, en fracciones de la altura para que siga al fotograma.
		y_from = min_y + int(round(def.top_ratio * body_h))
		y_to = min_y + int(round(def.bottom_ratio * body_h))

	for y in range(maxi(0, y_from), mini(cell_h - 1, y_to) + 1):
		var row_base := ((y0 + y) * width + x0) * 4
		for x in range(maxi(0, x_from), mini(cell_w - 1, x_to) + 1):
			var index := row_base + x * 4
			if src[index + 3] == 0:
				continue
			var key := (src[index] << 16) | (src[index + 1] << 8) | src[index + 2]
			if not keys.has(key):
				continue
			var target: Color = keys[key]
			dst[index] = target.r8
			dst[index + 1] = target.g8
			dst[index + 2] = target.b8
			dst[index + 3] = src[index + 3]
