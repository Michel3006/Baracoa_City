class_name Hud
extends Control

## HUD del jugador: vida, stamina, barra de golpe y el arma en la mano (secciones 8
## y 17).
##
## Lee del caso de uso y dibuja, sin decidir nada. No toca el dominio: si el HUD
## escribiera en la vida del jugador, la interfaz sería la dueña del modelo, que es
## justo lo contrario de lo que pide la sección 4.
##
## ## Sin texto y con el theme del pack
##
## Las hojas de UI del pack vienen para otro tamaño de ventana y el texto del
## sistema se ve borroso a 384x216, así que no se usa ninguno de los dos. El equipo se
## enseña con el sprite del arma en la mano, que es el mismo que lleva el jugador: si
## se ve un arma, se lleva un arma, y si no hay ninguna, va a puños.
##
## ## La barra de golpe
##
## Tercera barra, debajo de la stamina. Mide la preparación del golpe y no el
## cooldown que queda: **llena = se puede pegar**, vacía = recién golpeado, y se
## llena sola al pasar el cooldown. Invertida respecto a `cooldown_ratio` a
## propósito, porque a puños o con lo que sea siempre se vuelve al estado listo y
## una barra que se queda vacía en reposo diría "no puedes atacar" justo cuando sí.
##
## El cooldown no emite señal por fotograma: es un reloj que corre, así que aquí se
## consulta en `_process` y solo se redibuja cuando cambia el píxel que se va a
## pintar.
##
## Dependencias: presentation -> application

var session: GameSession = null

var _health: float = 1.0
var _stamina: float = 1.0
var _attack_ready: float = 1.0
var _weapon_icon: Texture2D = null
var _is_unarmed: bool = true
var _is_down: bool = false

## Ancho en píxeles de la barra de golpe ya dibujado, para no redibujar el HUD
## entero sesenta veces por segundo cuando el valor no ha cambiado.
var _attack_width: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if session == null or session.combat == null:
		return
	var ready := 1.0 - session.combat.cooldown_ratio
	var width := _fill_width(GameConfig.HUD_BAR_SIZE, ready)
	if width == _attack_width:
		return
	_attack_width = width
	_attack_ready = ready
	queue_redraw()


## Grado de preparación del golpe, de 0 (recién golpeado) a 1 (listo). Es el valor
## exacto que se dibuja, así que lo que mide un test sobre esto es lo que se pinta.
func attack_ready() -> float:
	return _attack_ready


## Conecta la sesión y se queda con sus valores iniciales.
func bind(source: GameSession) -> void:
	session = source
	if session == null:
		return
	_health = session.player.health.ratio
	_stamina = session.player.stamina_ratio
	session.health_changed.connect(_on_health_changed)
	session.stamina_changed.connect(_on_stamina_changed)
	session.player_died.connect(_on_player_died)
	session.player_respawned.connect(_on_player_respawned)
	_show_weapon(session.combat.weapon)


## Cambia el arma que se enseña. Lo llama el presenter, porque el golpe en curso puede
## ser a puños aunque el arma equipada siga en la mano.
func set_weapon(weapon: Weapon) -> void:
	_show_weapon(weapon)
	queue_redraw()


## Tinte de la pantalla mientras el jugador está sin vida. Apagar el HUD entero
## sería peor: un jugador muerto necesita ver cuanta vida le ha quedado.
func set_down(down: bool) -> void:
	if _is_down == down:
		return
	_is_down = down
	queue_redraw()


func _show_weapon(weapon: Weapon) -> void:
	_is_unarmed = weapon == null or WeaponCatalog.is_unarmed(weapon)
	_weapon_icon = null
	if _is_unarmed or weapon.texture_path.is_empty():
		return
	if ResourceLoader.exists(weapon.texture_path):
		_weapon_icon = load(weapon.texture_path) as Texture2D


func _draw() -> void:
	if _is_down:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.0, 0.0, GameConfig.HUD_DOWN_TINT))
	var margin := GameConfig.HUD_BAR_MARGIN
	var bar := GameConfig.HUD_BAR_SIZE

	_draw_bar(Vector2(margin.x, margin.y), bar, _health, Color("d9443f"), Color("5a1f1d"))
	_draw_bar(
		Vector2(margin.x, margin.y + bar.y + GameConfig.HUD_BAR_GAP),
		bar,
		_stamina,
		Color("4f9ad6"),
		Color("20435c")
	)
	# Barra de golpe: la tercera fila. El icono del arma vive a la derecha y a la
	# altura de las dos primeras, así que no se pisan.
	_draw_bar(
		Vector2(margin.x, margin.y + (bar.y + GameConfig.HUD_BAR_GAP) * 2.0),
		bar,
		_attack_ready,
		Color("f0c05a"),
		Color("5a4a20")
	)
	_draw_weapon_icon(
		Vector2(
			margin.x + bar.x + GameConfig.HUD_BAR_GAP,
			margin.y + GameConfig.HUD_WEAPON_SIZE.y * 0.5
		)
	)


## Barra con fondo y relleno. El relleno se dibuja con anchos enteros para que a
## esta resolución no aparezcan columnas de medio píxel.
func _draw_bar(origin: Vector2, size: Vector2, ratio: float, fill: Color, background: Color) -> void:
	draw_rect(Rect2(origin, size), background)
	var width := _fill_width(size, ratio)
	if width > 0:
		draw_rect(Rect2(origin + Vector2(1.0, 0.0), Vector2(float(width), size.y)), fill)
	draw_rect(Rect2(origin, size), Color(0.0, 0.0, 0.0, 0.6), false, 1.0)


## Píxeles de relleno que le tocan a una barra. Se calcula en un solo sitio para que
## el dibujo y `_process` decidan lo mismo para el mismo valor: si cada uno
## redondeara por su cuenta, la barra saltaría de un píxel a otro sin cambiar el
## cooldown.
func _fill_width(bar: Vector2, ratio: float) -> int:
	return int(round((bar.x - 2.0) * clampf(ratio, 0.0, 1.0)))


## El icono del arma, centrado en el punto que le pasan. Sin arma no se dibuja nada,
## que es la misma diferencia que se ve en la mano del jugador.
func _draw_weapon_icon(center: Vector2) -> void:
	if _weapon_icon == null:
		return
	var size := _weapon_icon.get_size()
	var scale := GameConfig.HUD_WEAPON_SIZE.y / maxf(1.0, size.y)
	var drawn := size * scale
	draw_texture_rect(
		_weapon_icon,
		Rect2(center - drawn * 0.5, drawn),
		false,
		Color(1.0, 1.0, 1.0, 0.9)
	)


func _on_health_changed(current: float, maximum: float) -> void:
	_health = current / maximum if maximum > 0.0 else 0.0
	queue_redraw()


func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina = current / maximum if maximum > 0.0 else 0.0
	queue_redraw()


func _on_player_died() -> void:
	set_down(true)


func _on_player_respawned(_spawn: Vector2) -> void:
	set_down(false)