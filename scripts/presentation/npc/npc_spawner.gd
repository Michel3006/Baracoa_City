class_name NpcSpawner
extends Node2D

## Crea y destruye los cuerpos físicos de los NPC (secciones 9 y 18).
##
## Escucha al `NpcDirector` y monta un `NpcView` más un `NpcPresenter` por cada
## enemigo que se anuncia. No decide nada de juego: si un NPC aparece, dónde, cómo
## pelea y cuánto aguanta ya está decidido antes de que este nodo exista.
##
## ## Por qué no hay escena `.tscn` por enemigo
##
## Cada enemigo es un `NpcView` con tres hijos (cuerpo, sprite, hitbox) que se
## construye por código. Con seis enemigos se ahorran seis escenas que solo
## declararían lo mismo que `NpcView._ready()`. La escena del mundo sigue siendo la
## que dice qué hay en el mapa; esto solo es la fábrica.
##
## ## Z y capas
##
## Los NPC van en la capa de física `npc` y con z_index por encima del mundo pero
## por debajo del jugador, para que un enemigo que pasa por detrás no tape al
## protagonista.
##
## Dependencias: presentation -> application

const NPC_Z_INDEX := 1

var director: NpcDirector = null

## Presentadores por identificador de NPC. El presentador es el que mueve el reloj
## del caso de uso, así que el director lo necesita para repartir el objetivo sin
## tener que recorrer los nodos.
var _presenters: Dictionary = {}

## Capa de efectos del mundo, para que el arco del golpe salga en su sitio. La
## inyecta `MainWorldView.setup_npcs()`.
var _fx_parent: Node2D = null

## Receptor de los impactos de los enemigos (sección 37). Lo inyecta
## `MainWorldView` y lo comparte la cámara con el del jugador: cada
## `NpcCombat` que conecta un golpe avisa por aquí.
var _impact_sink: Callable = Callable()
## Combates ya conectados al relevo, para que `set_impact_sink` y los agentes
## que llegan después no dupliquen la conexión.
var _impact_bound: Dictionary = {}


func _ready() -> void:
	z_index = NPC_Z_INDEX


## Conecta el director y monta un cuerpo por cada enemigo que ya tenga.
func bind(source: NpcDirector) -> void:
	# Conectar dos veces las mismas señales hace que cada enemigo reciba el aviso
	# duplicado, así que volver a pasarle el mismo director no hace nada. Quien llama
	# no tiene que saber si ya estaba conectado.
	if director == source:
		return
	director = source
	if director == null:
		GameLogger.warning("El generador de NPC no tiene director", "NpcSpawner")
		return
	director.agent_ready.connect(_on_agent_ready)
	director.agent_died.connect(_on_agent_died)
	# Un director ya poblado antes de que llegara este nodo: se montan ahora los
	# cuerpos que seannounced mientras no había nadie que los escuchara.
	for agent in director.agents:
		_on_agent_ready(agent.npc.id, agent.npc, agent.brain, agent.combat)


## Reparte el objetivo antes de que los.presentadores muevan su reloj, para que en el
## mismo frame en el que el jugador entra en el radio de detección el enemigo que lo
## ha visto ya sepa a quién persigue.
func distribute_target(player_position: Vector2) -> void:
	if director != null:
		director.distribute_target(player_position)


## Presentadores vivos, para lo que necesite consultarlos (efectos, HUD).
func presenters() -> Array[NpcPresenter]:
	var found: Array[NpcPresenter] = []
	for presenter: NpcPresenter in _presenters.values():
		found.append(presenter)
	return found


func _on_agent_ready(id: int, npc: Npc, brain: NpcBrain, combat: NpcCombat) -> void:
	if _presenters.has(id):
		return
	var view := NpcView.new()
	view.name = "Npc%d" % id
	add_child(view)

	var presenter := NpcPresenter.new()
	presenter.name = "Presenter"
	view.add_child(presenter)
	presenter.setup(view, npc, brain, combat)
	presenter.set_fx_parent(_fx_parent)
	_bind_impact(presenter)
	_presenters[id] = presenter


## Dónde se sueltan los efectos de golpe de los enemigos.
##
## Va tanto a los presentadores que ya existen como a los que se creen después: el
## orden entre `bind()` y esta llamada no debería decidir si los enemigos tienen
## arco.
func set_fx_parent(node: Node2D) -> void:
	_fx_parent = node
	for presenter: NpcPresenter in _presenters.values():
		presenter.set_fx_parent(_fx_parent)


## Receptor de los impactos de los enemigos (sección 37).
##
## Igual que `set_fx_parent`: vale tanto para los presentadores que ya existen como
## para los que se creen después, y repetir la llamada no duplica conexiones
## (`_impact_bound` lo impide).
func set_impact_sink(sink: Callable) -> void:
	_impact_sink = sink
	for presenter: NpcPresenter in _presenters.values():
		_bind_impact(presenter)


## Conecta el impacto del combate de un enemigo al relevo que llega a la cámara.
func _bind_impact(presenter: NpcPresenter) -> void:
	var combat := presenter.combat()
	if combat == null or _impact_bound.has(combat):
		return
	_impact_bound[combat] = true
	combat.impact_struck.connect(_relay_impact)


## Releva el impacto de un enemigo al receptor común. Si nadie ha inyectado receptor
## todavía (orden entre `bind()` y `set_impact_sink`), la señal se ignora y no pasa
## nada: el jugador ya tiembla por su cuenta.
func _relay_impact(tier: StringName) -> void:
	if _impact_sink.is_valid():
		_impact_sink.call(tier)


## Un NPC ha muerto. El cuerpo se queda congelado en pantalla, que es la lectura
## inmediata de "este ya está"; retirarlo de golpe haría que el combate pareciera un
## fallo de carga.
func _on_agent_died(id: int, _npc: Npc) -> void:
	var presenter: NpcPresenter = _presenters.get(id)
	if presenter == null:
		return
	GameLogger.debug("NPC %d muerto" % id, "NpcSpawner")