extends RefCounted

## Pruebas del menú de selección de ropa y peinados (plan de ropa, Fase 4).
##
## `AppearanceSelection` es la parte del vestuario que se puede probar sin montar
## nada: qué opciones hay, dónde está el cursor y con qué vuelta se mueve. El
## dibujo y la entrada los pone `AppearancePanel`, y lo que se ve se mide en
## `startup_runner`.
##
## Lo que se comprueba aquí es lo que se rompe en silencio: que "nada puesto" sea
## una opción de verdad (el jugador del pack va sin camiseta), que el carrusel
## vuelva por los dos extremos, que el eje vertical no dé la vuelta y que el cursor
## abra siempre en la prenda que ya lleva puesta el jugador.


func register() -> Array:
	return [
		["cada parte ofrece 'nada' y luego el catálogo entero", _options_start_with_nothing],
		["el cursor arranca en la camiseta y en 'nada puesto'", _starts_empty],
		["la vuelta horizontal recorre el catálogo entero y da la vuelta", _cycle_wraps_both_ways],
		["la vuelta vertical cambia de fila y no da la vuelta", _switch_clamps],
		["un índice fuera de rango es 'nada', no una prenda inventada", _out_of_range_is_nothing],
		["sync coloca el cursor en la prenda que ya está puesta", _sync_finds_what_is_worn],
		["los nombres de 'nada' van por parte y el resto por catálogo", _labels],
		["elegir una parte que no existe no mueve el cursor", _unknown_part_is_ignored],
	]


## La opción 0 es "nada" en las dos partes, y detrás va el catálogo completo: el
## orden sale del catálogo, no de una copia, así que añadir un color lo añade al
## menú sin tocar esto.
func _options_start_with_nothing(ctx: ScriptTestContext) -> void:
	var selection := AppearanceSelection.new()
	for part_id: int in AppearanceSelection.PARTS:
		var options := selection.options(part_id)
		ctx.check(options.size() >= 2, "la parte %d no ofrece nada que elegir" % part_id)
		if options.is_empty():
			continue
		ctx.check_equal(options[0], &"", "la primera opción de la parte %d no es 'nada'" % part_id)
		ctx.check_equal(
			options.size(), 1 + _catalog_size(part_id),
			"la parte %d no ofrece el catálogo entero" % part_id
		)
	# Y son las del catálogo, no una lista paralela.
	var selection2 := AppearanceSelection.new()
	var shirts := selection2.options(GarmentDefinition.Part.SHIRT)
	for id: StringName in GarmentCatalog.shirt_ids():
		ctx.check(shirts.has(id), "el menú de camisetas se dejó fuera %s" % str(id))
	var hairs := selection2.options(GarmentDefinition.Part.HAIR)
	for id: StringName in GarmentCatalog.hair_ids():
		ctx.check(hairs.has(id), "el menú de peinados se dejó fuera %s" % str(id))


func _catalog_size(part_id: int) -> int:
	if part_id == GarmentDefinition.Part.HAIR:
		return GarmentCatalog.hair_ids().size()
	return GarmentCatalog.shirt_ids().size()


## Cuántos ids distintos hay en la lista. Sirve para comprobar que una vuelta
## completa no repite ninguna opción (que es lo que se vería como un menú que se
## queda pegado en una prenda).
func unique_size(ids: Array[StringName]) -> int:
	var seen: Dictionary = {}
	for id: StringName in ids:
		seen[id] = true
	return seen.size()


## Abrir el vestuario tiene que enseñar que el jugador del pack va con el torso
## desnudo: sin camiseta y sin peinado, y en la fila de arriba.
func _starts_empty(ctx: ScriptTestContext) -> void:
	var selection := AppearanceSelection.new()
	ctx.check_equal(
		selection.part, GarmentDefinition.Part.SHIRT, "el cursor no arranca en la camiseta"
	)
	ctx.check_equal(selection.index_of(GarmentDefinition.Part.SHIRT), 0, "arranca con algo puesto")
	ctx.check_equal(selection.selected_id(GarmentDefinition.Part.SHIRT), &"", "y no con 'nada'")
	ctx.check_equal(selection.selected_id(GarmentDefinition.Part.HAIR), &"", "el peinado igual")
	ctx.check_equal(
		selection.selected_label(GarmentDefinition.Part.SHIRT),
		GameConfig.APPEARANCE_NONE_SHIRT,
		"y lo que se lee es el nombre de 'nada'"
	)


## El carrusel se recorre con vuelta: desde "nada" se pasa a la primera camiseta, y
## desde la última se vuelve a "nada". Se camina hasta completar la vuelta entera
## para comprobar que vuelve al punto de partida y que pasa por todas las opciones.
func _cycle_wraps_both_ways(ctx: ScriptTestContext) -> void:
	var selection := AppearanceSelection.new()
	var total := selection.count(GarmentDefinition.Part.SHIRT)
	ctx.check(total >= 3, "hacen falta al menos tres opciones para probar la vuelta")

	# Hacia delante: recorre las opciones una a una y la vuelta siguiente vuelve a
	# "nada".
	var forward: Array[StringName] = []
	for _step: int in range(total - 1):
		ctx.check(selection.cycle(1), "el carrusel hacia delante se atasca")
		forward.append(selection.selected_id(GarmentDefinition.Part.SHIRT))
	ctx.check_equal(forward.size(), total - 1, "no se recorrieron todas las opciones")
	ctx.check(not forward.has(&""), "la vuelta pasó por 'nada' antes de tiempo")
	ctx.check_equal(
		unique_size(forward), forward.size(), "la vuelta repitió alguna opción"
	)
	ctx.check(selection.cycle(1), "la vuelta se atasca al llegar al final")
	ctx.check_equal(
		selection.selected_id(GarmentDefinition.Part.SHIRT), &"",
		"tras una vuelta entera no se volvió a 'nada'"
	)

	# Hacia atrás desde "nada" cae en la última, y volviendo atrás otra vez sigue.
	ctx.check(selection.cycle(-1), "el carrusel hacia atrás no se mueve")
	ctx.check_equal(
		selection.selected_id(GarmentDefinition.Part.SHIRT),
		GarmentCatalog.shirt_ids()[GarmentCatalog.shirt_ids().size() - 1],
		"hacia atrás desde 'nada' no cae en la última camiseta"
	)
	ctx.check(selection.cycle(-1), "y sigue hacia atrás")
	ctx.check_equal(
		selection.selected_id(GarmentDefinition.Part.SHIRT),
		GarmentCatalog.shirt_ids()[GarmentCatalog.shirt_ids().size() - 2],
		"la segunda hacia atrás no cae en la penúltima"
	)

	# Sin desplazamiento no hay movimiento (el eje que no se pulsa).
	ctx.check(not selection.cycle(0), "un desplazamiento cero no debería mover nada")


## El eje vertical no es un carrusel: subir en la primera fila se queda ahí. Dar la
## vuelta aquí dejaría al jugador en la otra punta del menú sin haber visto nada.
func _switch_clamps(ctx: ScriptTestContext) -> void:
	var selection := AppearanceSelection.new()
	ctx.check(not selection.switch_part(-1), "subir en la primera fila no debería cambiar nada")
	ctx.check_equal(selection.part, GarmentDefinition.Part.SHIRT, "y sigue en la camiseta")
	ctx.check(selection.switch_part(1), "bajar debería cambiar de fila")
	ctx.check_equal(selection.part, GarmentDefinition.Part.HAIR, "a la fila del peinado")
	ctx.check(not selection.switch_part(1), "bajar en la última fila no debería dar la vuelta")
	ctx.check_equal(
		selection.part, GarmentDefinition.Part.HAIR, "y sigue en el peinado, no en la camiseta"
	)
	ctx.check(selection.switch_part(-1), "subir vuelve a la camiseta")
	ctx.check_equal(selection.part, GarmentDefinition.Part.SHIRT, "y está en la camiseta")

	# Cada fila lleva su propia cuenta: cambiar de fila no cambia la prenda elegida.
	ctx.check(selection.cycle(1), "se elige una camiseta")
	var shirt_id := selection.selected_id(GarmentDefinition.Part.SHIRT)
	selection.switch_part(1)
	selection.cycle(1)
	selection.switch_part(-1)
	ctx.check_equal(
		selection.selected_id(GarmentDefinition.Part.SHIRT), shirt_id,
		"mover el peinado cambió la camiseta elegida"
	)


## Un índice imposible (por debajo o por encima) devuelve "nada": el cursor nunca
## debe acabar apuntando a una prenda que no existe.
func _out_of_range_is_nothing(ctx: ScriptTestContext) -> void:
	var selection := AppearanceSelection.new()
	var total := selection.count(GarmentDefinition.Part.SHIRT)
	ctx.check_equal(selection.id_at(GarmentDefinition.Part.SHIRT, -1), &"", "el -1 no es 'nada'")
	ctx.check_equal(
		selection.id_at(GarmentDefinition.Part.SHIRT, total), &"", "el primero de más no es 'nada'"
	)
	ctx.check_equal(
		selection.id_at(GarmentDefinition.Part.SHIRT, 9999), &"", "un índice lejano no es 'nada'"
	)
	ctx.check(
		selection.id_at(GarmentDefinition.Part.SHIRT, 1) != &"",
		"el índice 1 debería ser la primera prenda del catálogo"
	)


## El cursor abre donde está el jugador, no siempre en la primera opción: si lleva
## una camiseta puesta, esa tiene que ser la que sale marcada.
func _sync_finds_what_is_worn(ctx: ScriptTestContext) -> void:
	var selection := AppearanceSelection.new()
	var wanted := GarmentCatalog.shirt_ids()[2]
	selection.sync(GarmentDefinition.Part.SHIRT, wanted)
	ctx.check_equal(
		selection.selected_id(GarmentDefinition.Part.SHIRT), wanted,
		"el cursor no se colocó en la camiseta puesta"
	)
	selection.sync(GarmentDefinition.Part.HAIR, GarmentCatalog.hair_ids()[1])
	ctx.check_equal(
		selection.selected_id(GarmentDefinition.Part.HAIR), GarmentCatalog.hair_ids()[1],
		"el cursor no se colocó en el peinado puesto"
	)
	# Un id que ya no exista en el catálogo cae en "nada" en vez de dejar el cursor
	# en un índice que no corresponde a ninguna opción.
	selection.sync(GarmentDefinition.Part.HAIR, &"peinado_que_no_existe")
	ctx.check_equal(
		selection.selected_id(GarmentDefinition.Part.HAIR), &"",
		"un id desconocido debería dejar el cursor en 'nada'"
	)


## El nombre de "nada" es de cada parte ("camiseta" es femenino, "peinado"
## masculino) y el del resto sale del catálogo.
func _labels(ctx: ScriptTestContext) -> void:
	var selection := AppearanceSelection.new()
	ctx.check_equal(
		selection.label_of(GarmentDefinition.Part.SHIRT, &""),
		GameConfig.APPEARANCE_NONE_SHIRT,
		"el nombre de 'nada' en la camiseta"
	)
	ctx.check_equal(
		selection.label_of(GarmentDefinition.Part.HAIR, &""),
		GameConfig.APPEARANCE_NONE_HAIR,
		"el nombre de 'nada' en el peinado"
	)
	var id := GarmentCatalog.SHIRT_RED
	ctx.check_equal(
		selection.label_of(GarmentDefinition.Part.SHIRT, id),
		GarmentCatalog.shirt(id).label,
		"el nombre de una prenda no es el del catálogo"
	)
	ctx.check(
		not selection.label_of(GarmentDefinition.Part.SHIRT, id).is_empty(),
		"una prenda sin nombre dejaría la fila en blanco"
	)
	ctx.check_equal(
		selection.part_label(GarmentDefinition.Part.SHIRT),
		GameConfig.APPEARANCE_LABEL_SHIRT,
		"el nombre de la fila de la camiseta"
	)
	ctx.check_equal(
		selection.part_label(GarmentDefinition.Part.HAIR),
		GameConfig.APPEARANCE_LABEL_HAIR,
		"el nombre de la fila del peinado"
	)
	# Los nombres del menú tienen que poder escribirse con la fuente del proyecto:
	# solo trae A-Z, 0-9 y `! ? . - : ( )`.
	for text: String in [
		GameConfig.APPEARANCE_TITLE,
		GameConfig.APPEARANCE_LABEL_SHIRT,
		GameConfig.APPEARANCE_LABEL_HAIR,
		GameConfig.APPEARANCE_NONE_SHIRT,
		GameConfig.APPEARANCE_NONE_HAIR,
		GarmentCatalog.shirt(id).label,
		GarmentCatalog.hair(GarmentCatalog.HAIR_BLACK).label,
	]:
		for index: int in range(text.length()):
			if text[index] == " ":
				continue
			ctx.check(
				PixelFont.has_glyph(text[index]),
				"la fuente no tiene el glifo '%s' de \"%s\"" % [text[index], text]
			)


## El menú solo viste las partes que existen: pedir otra cosa no puede mover el
## cursor a una fila que no se dibuja.
func _unknown_part_is_ignored(ctx: ScriptTestContext) -> void:
	var selection := AppearanceSelection.new()
	ctx.check(not selection.select_part(GarmentDefinition.Part.SHIRT), "elegir la fila en la que ya está")
	ctx.check(not selection.select_part(99), "una parte inventada no debería cambiar el cursor")
	ctx.check_equal(selection.part, GarmentDefinition.Part.SHIRT, "y sigue donde estaba")
