extends RefCounted

## Pruebas del catálogo de prendas y peinados (plan de ropa, Fase 0/1).
##
## El catálogo es el contrato de datos: qué existe, qué colores sustituye y en
## qué banda del cuerpo. Es lo único que hay que mirar cuando se añade un color;
## aquí se comprueba que cada fila de la tabla esté completa y que las bandas
## sean las de su parte, para no acabar con una camiseta puesta en la cabeza.


func register() -> Array:
	return [
		["el catálogo trae camisetas y peinados", _has_both_kinds],
		["cada prenda mapea los cuatro tonos de piel del pack", _maps_skin_tones],
		["cada prenda es válida y trae nombre legible", _definitions_valid],
		["un id desconocido o vacío no da prenda", _unknown_is_null],
		["las camisetas van al torso y los peinados a la cabeza", _bands_by_part],
	]


func _has_both_kinds(ctx: ScriptTestContext) -> void:
	ctx.check(
		GarmentCatalog.shirt_ids().size() >= 1,
		"el catálogo no trae ninguna camiseta"
	)
	ctx.check(
		GarmentCatalog.hair_ids().size() >= 1,
		"el catálogo no trae ningún peinado"
	)


func _maps_skin_tones(ctx: ScriptTestContext) -> void:
	# Los cuatro tonos de la hoja tienen que estar como claves, y cada uno tiene
	# que dar un color distinto: si dos cayeran en el mismo, el sombreado del
	# torso se perdería y la prenda saldría plana.
	for id: StringName in GarmentCatalog.shirt_ids():
		var def := GarmentCatalog.shirt(id)
		ctx.check(def != null, "camiseta sin definición: %s" % str(id))
		if def == null:
			continue
		ctx.check_equal(
			def.palette.size(), GarmentCatalog.SKIN_KEYS.size(),
			"la camiseta %s no mapea los cuatro tonos de piel" % str(id)
		)
		for key: Color in GarmentCatalog.SKIN_KEYS:
			ctx.check(
				def.palette.has(key),
				"la camiseta %s no reconoce el tono %s de la hoja" % [str(id), key]
			)
		var targets: Array = def.palette.values()
		var unique: Dictionary = {}
		for target: Color in targets:
			unique[target] = true
		ctx.check_equal(
			unique.size(), targets.size(),
			"la camiseta %s repite color y pierde el sombreado" % str(id)
		)


func _definitions_valid(ctx: ScriptTestContext) -> void:
	for id: StringName in GarmentCatalog.shirt_ids():
		var def := GarmentCatalog.shirt(id)
		if def == null:
			continue
		ctx.check(def.is_valid(), "la camiseta %s no es válida" % str(id))
		ctx.check(not def.label.is_empty(), "la camiseta %s no trae nombre" % str(id))
	for id: StringName in GarmentCatalog.hair_ids():
		var def := GarmentCatalog.hair(id)
		if def == null:
			continue
		ctx.check(def.is_valid(), "el peinado %s no es válido" % str(id))
		ctx.check(not def.label.is_empty(), "el peinado %s no trae nombre" % str(id))


func _unknown_is_null(ctx: ScriptTestContext) -> void:
	ctx.check(
		GarmentCatalog.shirt(&"no_existe") == null,
		"un id de camiseta inventado debería dar null"
	)
	ctx.check(
		GarmentCatalog.hair(&"") == null,
		"un id vacío debería dar null"
	)


func _bands_by_part(ctx: ScriptTestContext) -> void:
	# La banda es una fracción de la altura del cuerpo: la camiseta empieza por
	# debajo de la cabeza, el peinado por la coronilla. Si esto se cruzara, la
	# camiseta se pondría en la cabeza.
	var shirt := GarmentCatalog.shirt(GarmentCatalog.SHIRT_RED)
	var hair := GarmentCatalog.hair(GarmentCatalog.HAIR_BLACK)
	ctx.check_equal(
		shirt.top_ratio, GameConfig.GARMENT_SHIRT_TOP_RATIO,
		"la camiseta no arranca donde dice GameConfig"
	)
	ctx.check_equal(
		shirt.bottom_ratio, GameConfig.GARMENT_SHIRT_BOTTOM_RATIO,
		"la camiseta no termina donde dice GameConfig"
	)
	ctx.check(
		hair.top_ratio < shirt.top_ratio,
		"el peinado debería empezar por encima de la camiseta (%f vs %f)"
		% [hair.top_ratio, shirt.top_ratio]
	)
	ctx.check(
		hair.bottom_ratio <= shirt.top_ratio,
		"el peinado se solapa con la camiseta (%f > %f)"
		% [hair.bottom_ratio, shirt.top_ratio]
	)
