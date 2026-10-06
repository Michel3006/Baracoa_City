extends RefCounted

## Pruebas de la mini fuente de píxeles (secciones 13, "cómo se ve lo que hay").
##
## Se prueba el núcleo de datos (`glyph`, `measure`, `lit_pixels`), que no toca
## ningún `CanvasItem` y no necesita escena. `draw()` solo recorre lo que ya
## devuelve `lit_pixels`, así que cubrir la lista de píxeles cubre el dibujo.

const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?.-:()"


func register() -> Array:
	return [
		["toda letra y dígito tiene su glifo de 3x5", _glyph_table_is_3x5],
		["las medidas cuadran con el espaciado", _measure_counts_chars_and_spacing],
		["los píxeles cubren la forma esperada y en orden de lectura", _lit_pixels_follow_shapes],
		["el espacio avanza sin encender píxeles", _space_advances],
		["un carácter desconocido cae en el glifo de interrogación", _unknown_falls_back],
	]


func _glyph_table_is_3x5(ctx: ScriptTestContext) -> void:
	for i in ALPHABET.length():
		var character := ALPHABET[i]
		var rows := PixelFont.glyph(character)
		ctx.check(PixelFont.has_glyph(character), "%s es un glifo conocido" % character)
		for row in rows:
			ctx.check_equal(row.length(), PixelFont.GLYPH_WIDTH, "%s: filas de %d celdas" % [character, PixelFont.GLYPH_WIDTH])
			for cell: String in row:
				ctx.check(cell == "#" or cell == ".", "%s solo tiene celdas encendidas o apagadas" % character)
		ctx.check_equal(rows.size(), PixelFont.GLYPH_HEIGHT, "%s: 5 filas por glifo" % character)


func _measure_counts_chars_and_spacing(ctx: ScriptTestContext) -> void:
	ctx.check_equal(PixelFont.measure(""), Vector2i.ZERO, "texto vacío no ocupa")
	ctx.check_equal(PixelFont.measure("A"), Vector2i(3, 5), "una letra es 3x5")
	ctx.check_equal(PixelFont.measure("AB", 1), Vector2i(7, 5), "dos letras suman el espaciado entre ellas")
	ctx.check_equal(PixelFont.measure("A B", 1), Vector2i(11, 5), "el espacio también mide como un carácter")


## Los píxeles salen en orden de lectura (fila a fila) y cubren la forma del glifo.
## La A tiene 12 píxeles: fila superior llena, dos verticales en el centro y la
## fila del medio llena otra vez.
func _lit_pixels_follow_shapes(ctx: ScriptTestContext) -> void:
	var a := PixelFont.lit_pixels("A")
	ctx.check_equal(a.size(), 12, "la A enciende 12 píxeles")
	ctx.check(Vector2i(0, 0) in a, "la A empieza en la esquina superior izquierda")
	ctx.check(Vector2i(2, 4) in a, "y termina en la inferior derecha")
	ctx.check(Vector2i(1, 0) in a, "la fila de arriba es continua")
	# Dos letras: la segunda aparece desplazada por su anchura más el espaciado.
	var ab := PixelFont.lit_pixels("AB", 1)
	ctx.check_equal(ab.size(), 12 + 10, "A y B juntas suman sus píxeles")
	ctx.check(Vector2i(4, 0) in ab, "la B empieza en x=4 (3 de A + 1 de espacio)")
	ctx.check(Vector2i(4, 4) in ab, "y su último píxel queda debajo de su origen")


func _space_advances(ctx: ScriptTestContext) -> void:
	var spaced := PixelFont.lit_pixels("A A")
	ctx.check_equal(spaced.size(), 24, "el espacio no enciende píxeles")
	# Cada carácter (el espacio incluido) ocupa su celda de 3 y deja 1 de separación:
	# la primera A ocupa 0-2, el espacio adelanta 4, la segunda arranca en x=8.
	ctx.check(Vector2i(8, 0) in spaced, "la segunda A arranca tras el espacio")
	ctx.check(not (Vector2i(3, 0) in spaced), "la celda del espacio queda vacía")
	ctx.check(not (Vector2i(7, 0) in spaced), "y la separación entre espacio y A también")


func _unknown_falls_back(ctx: ScriptTestContext) -> void:
	ctx.check(not PixelFont.has_glyph("_"), "un guion bajo no es un glifo")
	ctx.check_equal(PixelFont.glyph("_"), PixelFont.glyph("?"), "y cae en el interrogante")
	ctx.check_equal(PixelFont.lit_pixels("_"), PixelFont.lit_pixels("?"), "con los mismos píxeles")