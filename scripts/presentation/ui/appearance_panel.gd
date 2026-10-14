class_name AppearancePanel
extends Control

## Pantalla del vestuario: camisetas y peinados (plan de ropa y peinados, Fase 4).
##
## Es una `Control` a pantalla completa dentro de su propia `CanvasLayer`, como la
## mochila, y se dibuja entera con `draw_rect` y la mini fuente del proyecto: la del
## sistema sale borrosa a 384x216.
##
## ## Qué hace y qué no
##
## No decide nada de juego: lee el catálogo (`GarmentCatalog`) para saber qué hay y
## escribe en `PlayerView.set_shirt()`/`set_hair()`, que es presentación pura. El
## dominio y el combate no se enteran de que existe: cambiar de ropa no toca vida,
## daño, tiempos, colisión ni hitbox.
##
## ## Elegir es ponerse
##
## No hay borrador ni confirmación: mover la selección **pone** la prenda, y se ve
## al instante en la vista previa. Cerrar deja lo último elegido, que es lo que hace
## un vestuario. No hay "deshacer": `ui_cancel` (`Esc`) sigue siendo la tecla de
## salir del juego, igual que en la mochila.
##
## ## La vista previa
##
## El panel no dibuja un muñeco aparte: engancha dos `GarmentLayer` al cuerpo real y
## un `Sprite2D` que copia su fotograma, y los coloca en el recuadro. Son espejos
## puros, sin reloj ni estado propio, así que lo que se ve en el recuadro es
## exactamente lo que el cuerpo lleva puesto, en la pose en la que esté. Los tres
## van apagados (`PROCESS_MODE_DISABLED`) mientras el panel está cerrado: encendidos
## reconstruirían cada hoja por duplicado sin que nadie los vea.
##
## ## Pausa
##
## Abre con `toggle_appearance` y pausa el árbol mientras está abierto, como la
## mochila, y va en `PROCESS_MODE_ALWAYS` para seguir oyendo la entrada. Los dos
## paneles son modales: solo uno puede estar abierto a la vez, y el segundo `open()`
## se rechaza porque el árbol ya está pausado.
##
## Dependencias: presentation -> presentation (catálogo de prendas), infrastructure

const ACTION_TOGGLE := &"toggle_appearance"
const ACTION_CONFIRM := &"interact"
const ACTION_UP := &"move_up"
const ACTION_DOWN := &"move_down"
const ACTION_LEFT := &"move_left"
const ACTION_RIGHT := &"move_right"

var is_open: bool = false

var _player: PlayerView = null
var _actor: ActorSprite = null
var _selection := AppearanceSelection.new()

## Espejos de la vista previa. Se montan al enganchar al jugador.
var _preview: Node2D = null
var _preview_body: Sprite2D = null
var _preview_shirt: GarmentLayer = null
var _preview_hair: GarmentLayer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Igual que el HUD y la mochila: bajo una `CanvasLayer` los anchors no dan
	# tamaño (queda 0x0) y el panel se dibujaría con el origen en números negativos.
	# Se fija el tamaño del viewport; el proyecto es de resolución fija.
	size = get_viewport_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# El vestuario gestiona el mundo pausado: tiene que seguir recibiendo la entrada
	# cuando el resto del árbol está parado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _exit_tree() -> void:
	# Si el panel se queda abierto al abandonar la escena, no dejar el mundo
	# pausado para siempre.
	if is_open:
		close(false)


## Engancha al jugador y monta la vista previa.
##
## Se llama cuando el jugador ya está en el árbol (lo hace `Game` al aparecer), así
## que el cuerpo existe y se puede espejar. La ropa que lleva puesta se copia al
## cursor, para que el menú abra enseñando lo que hay puesto y no la primera opción.
func bind(player: PlayerView) -> void:
	_player = player
	if _player == null:
		return
	_actor = _player.get_node_or_null("Actor") as ActorSprite
	var state := _player.appearance_state()
	if state != null:
		state.changed.connect(_on_appearance_changed)
	_build_preview()
	_sync_selection()
	queue_redraw()


## Abre el vestuario. Devuelve `false` sin tocar nada si ya está abierto, si falta
## el jugador, si está muerto (pausar el mundo detrás de la pantalla de muerte
## rompería la reaparición) o si el árbol ya está pausado por otro panel modal: dos
## paneles a la vez dejarían el mundo corriendo al cerrar el primero.
func open() -> bool:
	if is_open or _player == null or _selection == null:
		return false
	if _player.is_dead():
		return false
	var tree := get_tree()
	if tree == null or tree.paused:
		return false
	is_open = true
	_sync_selection()
	visible = true
	_pause_world(true)
	_place_preview()
	_set_preview_active(true)
	_copy_body()
	queue_redraw()
	return true


func close(unpause: bool = true) -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_set_preview_active(false)
	if unpause:
		_pause_world(false)
	queue_redraw()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## Cierra el vestuario. Aquí elegir es ponerse, así que confirmar y salir son lo
## mismo: `E` cierra.
func confirm() -> bool:
	if not is_open:
		return false
	close()
	return true


## Mueve el cursor: arriba y abajo cambian de fila (con tope), e izquierda y derecha
## cambian de prenda (con vuelta). Cambiar de prenda la pone.
func move_selection(delta: Vector2i) -> void:
	if not is_open:
		return
	if delta.y != 0:
		if _selection.switch_part(delta.y):
			queue_redraw()
		return
	if delta.x != 0 and _selection.cycle(delta.x):
		_apply()
		queue_redraw()


# --- lectura del menú (para la interfaz y para los tests) ---

## Fila que tiene el cursor.
func selected_part() -> int:
	return _selection.part


## Nombre de la parte del cuerpo de una fila.
func row_label(part_id: int) -> String:
	return _selection.part_label(part_id)


## Nombre de lo elegido en una fila.
func row_value(part_id: int) -> String:
	return _selection.selected_label(part_id)


## Id de lo elegido en una fila (o `&""` para "nada").
func selected_id(part_id: int) -> StringName:
	return _selection.selected_id(part_id)


# --- geometría ---

## El rectángulo del panel, en coordenadas del panel (que cubre el viewport).
func panel_rect() -> Rect2:
	var panel_size: Vector2 = GameConfig.APPEARANCE_PANEL_SIZE
	var margin := float(GameConfig.APPEARANCE_PANEL_MARGIN)
	return Rect2(Vector2(size) - panel_size - Vector2(margin, margin), panel_size)


## El recuadro de la vista previa, dentro del panel.
func preview_rect() -> Rect2:
	var panel := panel_rect()
	var pad := float(GameConfig.APPEARANCE_PAD)
	return Rect2(
		panel.position + Vector2(pad, float(GameConfig.APPEARANCE_HEADER) + pad),
		GameConfig.APPEARANCE_PREVIEW_SIZE
	)


## El rectángulo de la fila de una parte del cuerpo.
func row_rect(part_id: int) -> Rect2:
	var panel := panel_rect()
	var pad := float(GameConfig.APPEARANCE_PAD)
	var row_h := float(GameConfig.APPEARANCE_ROW_H)
	var gap := float(GameConfig.APPEARANCE_ROW_GAP)
	var index := maxi(0, AppearanceSelection.PARTS.find(part_id))
	var y := preview_rect().end.y + gap + float(index) * (row_h + gap)
	return Rect2(
		Vector2(panel.position.x + pad, y), Vector2(panel.size.x - pad * 2.0, row_h)
	)


# --- montaje de la vista previa ---

## Monta la vista previa: un espejo del cuerpo y dos capas de prenda enganchadas al
## cuerpo de verdad, para que no haya dos verdades que se puedan separar.
func _build_preview() -> void:
	if _actor == null or _preview != null:
		return
	_preview = Node2D.new()
	_preview.name = "Preview"
	_preview.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_preview)

	_preview_body = Sprite2D.new()
	_preview_body.name = "PreviewBody"
	_preview_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.add_child(_preview_body)

	_preview_shirt = _preview_layer("PreviewShirt", GarmentDefinition.Part.SHIRT)
	_preview_hair = _preview_layer("PreviewHair", GarmentDefinition.Part.HAIR)


func _preview_layer(node_name: String, part: int) -> GarmentLayer:
	var layer := GarmentLayer.new()
	layer.name = node_name
	layer.part = part
	layer.actor = _actor
	layer.appearance = _player.appearance_state()
	_preview.add_child(layer)
	return layer


## Coloca la vista previa con los pies del personaje apoyados en el borde bajo del
## recuadro: el origen del nodo del cuerpo es la planta, así que basta con mover el
## espejo.
func _place_preview() -> void:
	if _preview == null:
		return
	var preview := preview_rect()
	_preview.position = Vector2(
		preview.get_center().x, preview.end.y - GameConfig.APPEARANCE_PREVIEW_FOOT_LIFT
	)


func _set_preview_active(active: bool) -> void:
	if _preview != null:
		_preview.process_mode = (
			Node.PROCESS_MODE_ALWAYS if active else Node.PROCESS_MODE_DISABLED
		)


## Copia el fotograma del cuerpo en el espejo. `centered`, `offset` y `flip_h` se
## copian tal cual y no se recalculan: son del cuerpo, y deducirlos otra vez aquí es
## justo la clase de error que ya costó una tanda de fallos.
##
## El tinte no se copia: en el mundo lo lleva puesto el nodo del jugador
## (`PlayerView.modulate`) y el recuadro no lo hereda, así que la vista previa sale a
## plena luz aunque el jugador esté herido o aturdido. Es lo que se quiere: un tinte
## rojo o violeta encima haría ilegible el color que se está eligiendo.
func _copy_body() -> void:
	if _preview_body == null or _actor == null:
		return
	_preview_body.texture = _actor.texture
	_preview_body.hframes = _actor.hframes
	_preview_body.vframes = _actor.vframes
	_preview_body.frame = _actor.frame
	_preview_body.offset = _actor.offset
	_preview_body.flip_h = _actor.flip_h
	_preview_body.centered = _actor.centered
	_preview_body.visible = _actor.texture != null


func _process(_delta: float) -> void:
	if not is_open:
		return
	# El cuerpo no avanza con el árbol pausado, pero el espejo se refresca igual:
	# cuesta nada y así no depende de que nada se mueva por debajo.
	_copy_body()


# --- escritura de la elección ---

## Pone en el jugador lo que el cursor tiene elegido. Se escribe en la vista, que es
## la dueña de `AppearanceState`: el panel no guarda copia de la ropa puesta.
func _apply() -> void:
	if _player == null:
		return
	var part := _selection.part
	var id := _selection.selected_id(part)
	if part == GarmentDefinition.Part.HAIR:
		_player.set_hair(id)
	else:
		_player.set_shirt(id)


## Copia al cursor lo que el jugador lleva puesto.
func _sync_selection() -> void:
	if _player == null:
		return
	var state := _player.appearance_state()
	if state == null:
		return
	for part_id: int in AppearanceSelection.PARTS:
		_selection.sync(part_id, state.id_for(part_id))


## Elegir desde fuera (o cambiar de ropa por otra vía) redibuja el menú. No se
## conecta `queue_redraw` directo por si algún día la señal lleva argumentos.
func _on_appearance_changed() -> void:
	queue_redraw()


# --- entrada ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_TOGGLE, false):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	var delta := _selection_delta(event)
	if delta != Vector2i.ZERO:
		move_selection(delta)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION_CONFIRM, false):
		confirm()
		get_viewport().set_input_as_handled()


## Un evento no puede ser de dos ejes a la vez: el primero que manda gana.
func _selection_delta(event: InputEvent) -> Vector2i:
	if event.is_action_pressed(ACTION_LEFT, false):
		return Vector2i(-1, 0)
	if event.is_action_pressed(ACTION_RIGHT, false):
		return Vector2i(1, 0)
	if event.is_action_pressed(ACTION_UP, false):
		return Vector2i(0, -1)
	if event.is_action_pressed(ACTION_DOWN, false):
		return Vector2i(0, 1)
	return Vector2i.ZERO


func _pause_world(paused: bool) -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = paused


# --- dibujo ---

func _draw() -> void:
	if not is_open:
		return
	draw_rect(Rect2(Vector2.ZERO, size), GameConfig.APPEARANCE_OVERLAY)
	var panel := panel_rect()
	draw_rect(panel, GameConfig.APPEARANCE_BG)
	draw_rect(panel, GameConfig.APPEARANCE_BORDER, false, 1.0)
	_draw_title(panel)
	var preview := preview_rect()
	draw_rect(preview, GameConfig.APPEARANCE_PREVIEW_BG)
	draw_rect(preview, GameConfig.APPEARANCE_BORDER, false, 1.0)
	for part_id: int in AppearanceSelection.PARTS:
		_draw_row(part_id)
	_draw_hint(panel)


func _draw_title(panel: Rect2) -> void:
	PixelFont.draw(
		self,
		Vector2i(panel.position) + Vector2i(GameConfig.APPEARANCE_PAD, 4),
		GameConfig.APPEARANCE_TITLE,
		GameConfig.APPEARANCE_TEXT
	)


func _draw_row(part_id: int) -> void:
	var rect := row_rect(part_id)
	var active := _selection.part == part_id
	draw_rect(rect, GameConfig.APPEARANCE_PREVIEW_BG)
	if active:
		# El anillo de la fila activa sale por fuera de la fila, como el de la
		# mochila, para que se lea a la vez que el valor.
		draw_rect(rect.grow(1.0), GameConfig.APPEARANCE_SELECTED, false, 1.0)
	PixelFont.draw(
		self,
		Vector2i(rect.position) + Vector2i(2, 1),
		row_label(part_id),
		(
			GameConfig.APPEARANCE_SELECTED
			if active
			else GameConfig.APPEARANCE_MUTED
		)
	)
	PixelFont.draw(
		self,
		Vector2i(rect.position) + Vector2i(2, 12),
		"(%s)" % row_value(part_id),
		GameConfig.APPEARANCE_TEXT
	)
	_draw_swatch(rect, part_id)


## La muestra de color de lo elegido: sus cuatro tonos (base, sombra, luz y oscura),
## que son los que el recoloreado va a usar. Cuando no hay nada puesto no se dibuja
## nada, y eso también se ve.
func _draw_swatch(rect: Rect2, part_id: int) -> void:
	var definition := GarmentCatalog.definition(part_id, _selection.selected_id(part_id))
	if definition == null:
		return
	var side := float(GameConfig.APPEARANCE_SWATCH)
	var count := GarmentCatalog.SKIN_KEYS.size()
	var x := rect.end.x - side * float(count) - float(count - 1) - 3.0
	var y := rect.position.y + 12.0
	for key: Color in GarmentCatalog.SKIN_KEYS:
		var color: Color = definition.palette[key]
		draw_rect(Rect2(Vector2(x, y), Vector2(side, side)), color)
		x += side + 1.0


func _draw_hint(panel: Rect2) -> void:
	var lines: PackedStringArray = GameConfig.APPEARANCE_HINT
	var line_h := PixelFont.GLYPH_HEIGHT + 3
	var y := int(panel.end.y) - int(lines.size()) * line_h - 4
	for line: String in lines:
		PixelFont.draw(
			self,
			Vector2i(int(panel.position.x) + GameConfig.APPEARANCE_PAD, y),
			line,
			GameConfig.APPEARANCE_MUTED
		)
		y += line_h
