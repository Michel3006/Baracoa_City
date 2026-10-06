class_name PixelFont
extends RefCounted

## Mini fuente de píxeles 3x5 dibujada con rectángulos de 1 px.
##
## La del sistema sale borrosa a 384x216, así que los textos del juego (cantidades
## de la mochila, pantalla de muerte) se dibujan con esta fuente: cada carácter es
## un bitmap de 3x5 y cada píxel encendido un `draw_rect` de 1x1. A la escala de
## ventana x3, un carácter son 9x15 píxeles de pantalla, igual de nítido que el
## resto del pixel-art.
##
## Cubre A-Z, 0-9 y unos pocos símbolos (`! ? . - : ( )`). Lo que no esté en la
## tabla se dibuja como `?`, para que un texto nunca se parta por un glifo que
## falta.
##
## `lit_pixels()` es el núcleo comprobable: devuelve la lista de píxeles sin tocar
## ningún `CanvasItem`, así se puede probar sin escena. `draw()` solo recorre esa
## lista llamando a `draw_rect`, y es lo único que necesita un lienzo.
##
## Dependencias: ninguna (raíz de la presentación, debajo de todo lo que dibuja).

const GLYPH_WIDTH := 3
const GLYPH_HEIGHT := 5
const DEFAULT_SPACING := 1

## Cada glifo son 5 filas de 3 celdas. `#` = píxel encendido, `.` = apagado.
const _GLYPHS := {
	"A": ["###", "#.#", "###", "#.#", "#.#"],
	"B": ["##.", "#.#", "##.", "#.#", "##."],
	"C": ["###", "#..", "#..", "#..", "###"],
	"D": ["##.", "#.#", "#.#", "#.#", "##."],
	"E": ["###", "#..", "##.", "#..", "###"],
	"F": ["###", "#..", "##.", "#..", "#.."],
	"G": ["###", "#..", "#.#", "#.#", "###"],
	"H": ["#.#", "#.#", "###", "#.#", "#.#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"],
	"J": ["..#", "..#", "..#", "#.#", "###"],
	"K": ["#.#", "#.#", "##.", "#.#", "#.#"],
	"L": ["#..", "#..", "#..", "#..", "###"],
	"M": ["#.#", "###", "###", "#.#", "#.#"],
	"N": ["#.#", "##.", "##.", "#.#", "#.#"],
	"O": ["###", "#.#", "#.#", "#.#", "###"],
	"P": ["###", "#.#", "###", "#..", "#.."],
	"Q": ["###", "#.#", "#.#", "##.", "..#"],
	"R": ["###", "#.#", "###", "##.", "#.#"],
	"S": ["###", "#..", "###", "..#", "###"],
	"T": ["###", ".#.", ".#.", ".#.", ".#."],
	"U": ["#.#", "#.#", "#.#", "#.#", "###"],
	"V": ["#.#", "#.#", "#.#", "#.#", ".#."],
	"W": ["#.#", "#.#", "###", "###", "#.#"],
	"X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
	"Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
	"Z": ["###", "..#", ".#.", "#..", "###"],
	"0": ["###", "#.#", "#.#", "#.#", "###"],
	"1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###", "..#", "###", "#..", "###"],
	"3": ["###", "..#", "###", "..#", "###"],
	"4": ["#.#", "#.#", "###", "..#", "..#"],
	"5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"],
	"7": ["###", "..#", "..#", "..#", "..#"],
	"8": ["###", "#.#", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "###"],
	"!": [".#.", ".#.", ".#.", "...", ".#."],
	"?": ["###", "..#", ".#.", "...", ".#."],
	".": ["...", "...", "...", "...", ".#."],
	"-": ["...", "...", "###", "...", "..."],
	":": ["...", ".#.", "...", ".#.", "..."],
	"(": [".#.", "#..", "#..", "#..", ".#."],
	")": [".#.", "..#", "..#", "..#", ".#."],
}


static func has_glyph(character: String) -> bool:
	return character.length() == 1 and _GLYPHS.has(character)


## Las 5 filas del glifo de `character`, o el glifo de `?` si no está en la tabla.
static func glyph(character: String) -> PackedStringArray:
	if character.length() == 1 and _GLYPHS.has(character):
		return _GLYPHS[character]
	return _GLYPHS["?"]


## Ancho de un carácter concreto con el espaciado. El espacio ocupa lo mismo que
## una letra: así el texto queda uniforme y `measure()` no tiene casos raros.
static func glyph_width(_character: String, spacing: int = DEFAULT_SPACING) -> int:
	return GLYPH_WIDTH


## Tamaño del texto: cada carácter mide `GLYPH_WIDTH` y entre caracteres hay
## `spacing` píxeles. Línea única, altura fija `GLYPH_HEIGHT`.
static func measure(text: String, spacing: int = DEFAULT_SPACING) -> Vector2i:
	if text.is_empty():
		return Vector2i.ZERO
	var width := text.length() * GLYPH_WIDTH + maxi(0, text.length() - 1) * spacing
	return Vector2i(width, GLYPH_HEIGHT)


## La lista de píxeles que dibujaría `draw()`: coordenadas locales a `origin`.
## Es el núcleo comprobable de la fuente, sin tocar ningún `CanvasItem`.
static func lit_pixels(text: String, spacing: int = DEFAULT_SPACING) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	var pen := 0
	for i in text.length():
		var character := text[i]
		if character == " ":
			pen += GLYPH_WIDTH + spacing
			continue
		var rows := glyph(character)
		for y in GLYPH_HEIGHT:
			for x in GLYPH_WIDTH:
				if rows[y][x] == "#":
					pixels.append(Vector2i(pen + x, y))
		pen += GLYPH_WIDTH + spacing
	return pixels


## Dibuja el texto en `canvas` con cada píxel de 1x1 (o `scale`x`scale`).
## Devuelve el rectángulo ocupado, para que quien lo dibuja pueda centrarlo.
static func draw(canvas: CanvasItem, origin: Vector2i, text: String, color: Color, spacing: int = DEFAULT_SPACING, scale: int = 1) -> Rect2i:
	var size := measure(text, spacing) * maxi(1, scale)
	for pixel in lit_pixels(text, spacing):
		var drawn := Vector2i(pixel.x * scale, pixel.y * scale)
		canvas.draw_rect(
			Rect2(Vector2(origin + drawn), Vector2(maxi(1, scale), maxi(1, scale))),
			color
		)
	return Rect2i(origin, size)