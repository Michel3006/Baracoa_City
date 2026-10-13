class_name GarmentLayer
extends Sprite2D

## Capa dibujada encima del cuerpo con la prenda o el peinado (plan de ropa y
## peinados, Fase 3).
##
## Es una capa de **presentación pura** y no tiene reloj propio: en cada
## fotograma **lee** el estado del `ActorSprite` (clip, orientación, fotograma,
## textura, anclaje, espejo) y lo replica. El dueño del estado visual sigue
## siendo el cuerpo; si esta capa llevara su propia cuenta, la prenda y el cuerpo
## se separarían en cuanto uno de los dos se retrasara un fotograma.
##
## La superposición se construye una vez por (hoja, prenda) y se guarda en
## caché: cambiar de color no cuesta nada y moverse por el mapa solo paga la
## primera vez que se ve cada hoja.

## Cuerpo al que sigue. Lo pone quien construye la capa.
var actor: ActorSprite = null
## Qué lleva puesto el jugador. Lo pone quien construye la capa.
var appearance: AppearanceState = null
## Parte del cuerpo que viste esta capa (`GarmentDefinition.Part`).
var part: int = GarmentDefinition.Part.SHIRT

## Caché de superposiciones ya construidas: `hoja|prenda` -> `Texture2D` (o
## `null` si esa hoja no dio prenda). Se vacía al cambiar de prenda, porque su
## clave ya no puede volver a usarse.
var _cache: Dictionary = {}
var _cache_key: String = ""


func _ready() -> void:
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func _process(_delta: float) -> void:
	_sync()


## Replica en la capa el estado del cuerpo. Sin reloj: copia y, si nada cambió,
## no hace nada.
func _sync() -> void:
	if actor == null or appearance == null:
		visible = false
		return
	var id := appearance.id_for(part)
	if id == &"":
		visible = false
		return
	var def := GarmentCatalog.definition(part, id)
	if def == null or actor.texture == null:
		visible = false
		return
	var key := "%s|%s" % [actor.sheet_path, id]
	if key != _cache_key:
		_cache_key = key
		_cache.clear()
		texture = GarmentRecolor.build(actor.texture, actor.hframes, actor.vframes, def)
	else:
		texture = _cache.get(key, texture)
	if texture == null:
		visible = false
		return
	_cache[key] = texture
	# El resto del estado es del cuerpo: se copia tal cual. `frame`, `offset` y
	# `flip_h` cambian cada fotograma (animación y orientación), así que se
	# refrescan siempre; la rejilla solo cuando cambia la hoja.
	hframes = actor.hframes
	vframes = actor.vframes
	frame = actor.frame
	offset = actor.offset
	flip_h = actor.flip_h
	centered = actor.centered
	visible = true


## ¿La capa está enseñando una prenda de verdad?
func is_painting() -> bool:
	return visible and texture != null
