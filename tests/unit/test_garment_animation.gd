extends RefCounted

## Pruebas de la ropa como espejo del cuerpo (plan de ropa, Fase 3/4).
##
## La capa de prenda no tiene reloj ni estado propio: en cada fotograma copia lo
## que el cuerpo está dibujando. Eso se comprueba aquí animando el cuerpo por
## **todas** las animaciones de la hoja, en las cuatro direcciones y fotograma a
## fotograma, y comparando el recorte de la prenda con el del cuerpo.
##
## Por qué unitario y no de integración: así se recorren las 24 animaciones reales
## del pack (reposo, caminar, los diez golpes, las patadas, los trances y las dos
## muertes) sin montar una escena y sin depender de que el presentador llegue a
## cada estado. `Sprite2D` se configura y se consulta fuera del árbol, y `_process`
## y `_sync` se llaman a mano para no depender de la tasa de fotogramas.
##
## Lo que se mide es lo que se rompe en silencio: que la prenda y el cuerpo se
## separen (la ropa caminando por su lado), que la superposición no tenga el mismo
## tamaño que la hoja (desalineada píxel a píxel) o que la capa no pinte en alguna
## animación concreta.

## Fotograma de física con el que se avanza el tiempo. Uno real y no un múltiplo
## exacto de la duración de un fotograma, porque en el juego el `delta` nunca lo es.
const STEP := 1.0 / 60.0

## Direcciones por número del pack, para poder decir en un fallo mirando dónde.
const DIRECTIONS := {
	2: Vector2.LEFT,
	4: Vector2.UP,
	6: Vector2.RIGHT,
	8: Vector2.DOWN,
}

## Nodos creados en el caso en curso, para soltarlos en `teardown()`.
var _alive: Array[Node] = []


func teardown() -> void:
	for node: Node in _alive:
		if is_instance_valid(node):
			node.free()
	_alive.clear()


func register() -> Array:
	return [
		["la prenda sigue al cuerpo en todas las animaciones y direcciones", _mirrors_every_clip],
		["la superposición tiene la misma rejilla que la hoja", _overlay_matches_the_sheet],
		["cambiar de prenda no toca el estado del cuerpo", _garment_does_not_write_back],
		["sin prenda la capa deja de pintar, y al ponérsela vuelve", _nothing_stops_painting],
	]


## Un cuerpo con la definición real del jugador y una capa de camiseta enganchada.
## Fuera del árbol: `apply_definition()` ya deja hoja, rejilla y clips puestos, así
## que no hace falta ni un `SceneTree`.
func _rig() -> Dictionary:
	var actor := ActorSprite.new()
	_alive.append(actor)
	ActorVisualCatalog.apply_to(ActorVisualCatalog.PLAYER, actor)
	var layer := GarmentLayer.new()
	_alive.append(layer)
	layer.actor = actor
	layer.part = GarmentDefinition.Part.SHIRT
	layer.appearance = _state(GarmentCatalog.SHIRT_BLUE)
	return {"actor": actor, "layer": layer}


func _state(shirt: StringName = &"", hair: StringName = &"") -> AppearanceState:
	var state := AppearanceState.new()
	state.set_shirt(shirt)
	state.set_hair(hair)
	return state


## Fotogramas que hay que avanzar para que el cuerpo pase por todos los de un clip.
## Se avanza un poco más de lo que dura, porque el último fotograma solo se alcanza
## al agotarse el reloj.
func _steps_for(actor: ActorSprite, clip: StringName) -> int:
	var data := actor.clips.get(clip, {}) as Dictionary
	var frames := maxi(1, int(data.get("frames", 1)))
	var fps := maxf(1.0, float(data.get("fps", 1.0)))
	return clampi(int(ceil(float(frames) * fps / 60.0)) + 2, 2, 90)


## Todo lo que la capa copia del cuerpo, en una línea comparable. Si cambia algo
## del cuerpo (hoja, rejilla, fotograma, anclaje, espejo), cambia la línea.
func _body_state(actor: ActorSprite) -> String:
	return "%s|%d|%d|%d|%s|%s|%s" % [
		actor.sheet_path,
		actor.hframes,
		actor.vframes,
		actor.frame,
		str(actor.offset),
		str(actor.flip_h),
		str(actor.centered),
	]


## El fallo clásico de una capa con estado propio: la ropa y el cuerpo separados.
## Se animan las 24 animaciones de la hoja en las cuatro direcciones y se compara,
## en cada fotograma, que la prenda esté recortando exactamente lo mismo.
func _mirrors_every_clip(ctx: ScriptTestContext) -> void:
	var rig := _rig()
	var actor: ActorSprite = rig["actor"]
	var layer: GarmentLayer = rig["layer"]
	var clips := actor.clips.size()
	ctx.check(clips >= 20, "la hoja del jugador debería traer sus animaciones, trae %d" % clips)

	var desyncs := 0
	var unpainted := 0
	var samples := 0
	var overlays: Dictionary = {}
	var worst := ""
	for clip: StringName in actor.clips.keys():
		for number: int in DIRECTIONS:
			actor.set_facing(DIRECTIONS[number])
			actor.play(clip, true)
			for _step: int in range(_steps_for(actor, clip)):
				actor._process(STEP)
				layer._sync()
				samples += 1
				if not layer.is_painting():
					unpainted += 1
					continue
				overlays[layer.texture.get_instance_id()] = true
				if layer.frame != actor.frame or layer.flip_h != actor.flip_h:
					desyncs += 1
					worst = "%s dir%d: cuerpo %d/%s, prenda %d/%s" % [
						str(clip), number, actor.frame, str(actor.flip_h),
						layer.frame, str(layer.flip_h),
					]
				if layer.offset != actor.offset or layer.hframes != actor.hframes \
						or layer.vframes != actor.vframes:
					desyncs += 1
					worst = "%s dir%d: la rejilla o el anclaje no coinciden" % [str(clip), number]

	ctx.check(samples > clips * 4, "no se animó apenas nada: %d muestras" % samples)
	ctx.check_equal(desyncs, 0, "la prenda y el cuerpo se separaron (%s)" % worst)
	ctx.check_equal(unpainted, 0, "hubo %d fotogramas sin prenda dibujada" % unpainted)
	ctx.check(
		overlays.size() >= clips,
		"se esperaban al menos %d superposiciones (una por hoja y dirección), hubo %d"
		% [clips, overlays.size()]
	)


## La superposición se recorta con la misma rejilla que el cuerpo, así que tiene
## que medir lo mismo que la hoja y no ser la propia hoja: si lo fuera, taparía al
## jugador con una segunda copia de su cuerpo.
func _overlay_matches_the_sheet(ctx: ScriptTestContext) -> void:
	var rig := _rig()
	var actor: ActorSprite = rig["actor"]
	var layer: GarmentLayer = rig["layer"]
	var checked := 0
	for clip: StringName in actor.clips.keys():
		actor.set_facing(Vector2.DOWN)
		actor.play(clip, true)
		layer._sync()
		if not layer.is_painting():
			continue
		ctx.check(
			layer.texture != actor.texture,
			"la superposición de %s es la propia hoja del cuerpo" % str(clip)
		)
		ctx.check_equal(
			layer.texture.get_size(), actor.texture.get_size(),
			"la superposición de %s no mide como la hoja" % str(clip)
		)
		ctx.check_equal(
			layer.hframes, actor.hframes, "la rejilla de columnas de %s" % str(clip)
		)
		ctx.check_equal(
			layer.vframes, actor.vframes, "la rejilla de filas de %s" % str(clip)
		)
		checked += 1
	ctx.check(checked >= 20, "solo se comprobó la superposición de %d animaciones" % checked)


## La capa solo lee del cuerpo: cambiar de prenda con el cuerpo parado no puede
## moverle un solo píxel. Es la garantía de que la ropa no rompe la animación.
func _garment_does_not_write_back(ctx: ScriptTestContext) -> void:
	var rig := _rig()
	var actor: ActorSprite = rig["actor"]
	var layer: GarmentLayer = rig["layer"]
	var state: AppearanceState = layer.appearance

	# A media caminata (un fotograma cualquiera, no el primero).
	actor.set_facing(Vector2.RIGHT)
	actor.play(ActorSprite.WALK, true)
	for _step: int in range(7):
		actor._process(STEP)
	layer._sync()
	var before := _body_state(actor)
	var clip_before := actor.current_clip()
	var painting_before := layer.texture

	# Se cambia la camiseta y el peinado, que es justo lo que hace el vestuario.
	state.set_shirt(GarmentCatalog.SHIRT_GREEN)
	state.set_hair(GarmentCatalog.HAIR_WHITE)
	for _sync: int in range(3):
		layer._sync()
	ctx.check_equal(_body_state(actor), before, "ponerse ropa cambió el dibujo del cuerpo")
	ctx.check_equal(
		actor.current_clip(), clip_before, "ponerse ropa cambió la animación del cuerpo"
	)
	ctx.check(layer.is_painting(), "y la prenda nueva no se pintó")
	ctx.check(
		layer.texture != painting_before, "la superposición no se rehízo al cambiar de camiseta"
	)

	# Y quitarse la ropa tampoco.
	state.set_shirt(&"")
	state.set_hair(&"")
	layer._sync()
	ctx.check_equal(_body_state(actor), before, "quitarse la ropa cambió el dibujo del cuerpo")
	ctx.check_equal(actor.current_clip(), clip_before, "quitarse la ropa cambió la animación")


## Sin prenda la capa no dibuja (nada de una prenda fantasma), y al ponérsela
## vuelve a pintar: el cruce se puede repetir sin dejar la capa a medias.
func _nothing_stops_painting(ctx: ScriptTestContext) -> void:
	var rig := _rig()
	var actor: ActorSprite = rig["actor"]
	var layer: GarmentLayer = rig["layer"]
	var state: AppearanceState = layer.appearance

	actor.play(ActorSprite.IDLE, true)
	layer._sync()
	ctx.check(layer.is_painting(), "con camiseta la capa debería pintar")

	state.set_shirt(&"")
	layer._sync()
	ctx.check(not layer.is_painting(), "sin camiseta la capa no debería pintar nada")

	state.set_shirt(GarmentCatalog.SHIRT_BLACK)
	layer._sync()
	ctx.check(layer.is_painting(), "puesta otra vez, la capa debería volver a pintar")

	# El peinado va en su propia capa: quitar la camiseta no puede apagarlo.
	var hair := GarmentLayer.new()
	_alive.append(hair)
	hair.actor = actor
	hair.part = GarmentDefinition.Part.HAIR
	hair.appearance = state
	state.set_hair(GarmentCatalog.HAIR_RED)
	state.set_shirt(&"")
	hair._sync()
	layer._sync()
	ctx.check(hair.is_painting(), "el peinado debería pintar aunque no haya camiseta")
	ctx.check(not layer.is_painting(), "y la camiseta quitada no debería pintar")
