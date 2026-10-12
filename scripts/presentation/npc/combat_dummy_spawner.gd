class_name CombatDummySpawner
extends Node2D

## Crea el muñeco de entrenamiento y lo mantiene vivo (sección 33).
##
## Es el equivalente del `NpcSpawner` para el muñeco: monta su cuerpo, su caso de
## uso y su presentador y se ocupa de la reaparición. No decide reglas: la vida,
## el puesto y el tiempo de reaparición viven en `GameConfig`, y el estado del
## muñeco (salud, estado, muerte) en `CombatDummy`, que es un `Npc`.
##
## ## Por qué vive fuera del director de enemigos
##
## El muñeco no es un enemigo: no se reparte objetivo, no entra en la tabla de
## aparición y no cuenta para la IA. Gestionarlo aquí, como un elemento del
## mundo aparte, hace que apagar `NPC_ENABLED` no se lleve a la zona el objetivo
## de pruebas, y que el director no tenga que saber que existe.
##
## ## La reaparición
##
## Cuando el combate del muñeco avisa que ha muerto empieza una cuenta atrás de
## `DUMMY_RESPAWN_TIME` segundos; al vencer, se vacía la vida, se sueltan los
## relojes de combate (aturdimiento, invulnerabilidad, reacción, empuje) y se
## devuelve el cuerpo a su puesto. La cuenta va en `_physics_process` y no con un
## `Timer` para que los tests puedan avanzarla con fotogramas de física.
##
## Dependencias: presentation -> application, domain

## Mismo plano que los enemigos: por encima del mundo y por debajo del jugador.
const DUMMY_Z_INDEX := 1

var _dummy: CombatDummy = null
var _brain: NpcBrain = null
var _combat: NpcCombat = null
var _view: NpcView = null
var _presenter: NpcPresenter = null

## Capa de efectos del mundo, para el arco si alguna vez golpeara (hoy ataca
## nunca: `attack_range` en cero). La inyecta `MainWorldView`.
var _fx_parent: Node2D = null

## Receptor de los impactos del muñeco (sección 37): cuando recibe un golpe la
## cámara tiembla igual que si fuera un enemigo. Lo comparte con el revelador de
## los enemigos.
var _impact_sink: Callable = Callable()
var _impact_bound := false

## Cuenta atrás para reaparecer, en segundos. Negativo = el muñeco está vivo y no
## se cuenta nada.
var _respawn_remaining: float = -1.0


func _ready() -> void:
	z_index = DUMMY_Z_INDEX
	_build_dummy()


## Construye el muñeco: dominio, caso de uso y presentador, con el mismo orden y
## los mismos tiempos que `NpcSpawner._on_agent_ready`.
func _build_dummy() -> void:
	_dummy = CombatDummy.new(0)
	_dummy.home = GameConfig.DUMMY_SPAWN
	_dummy.position = GameConfig.DUMMY_SPAWN

	_brain = NpcBrain.new(_dummy)
	_combat = NpcCombat.new(_dummy)

	_view = NpcView.new()
	_view.name = "Dummy"
	add_child(_view)

	_presenter = NpcPresenter.new()
	_presenter.name = "Presenter"
	_view.add_child(_presenter)
	_presenter.setup(_view, _dummy, _brain, _combat)
	_presenter.set_fx_parent(_fx_parent)
	# El presentador ya oye `died` para apagar el cuerpo; este aviso es para la
	# reaparición, que es cosa del generador.
	_combat.died.connect(_on_dummy_died)
	_bind_impact()


## Inyecta la capa de efectos y el receptor de impactos. Vale llamarla después de
## `_ready()`: el muñeco se construye solo y este cableado solo añade lo que el
## mundo ya compartía con los enemigos.
func setup(fx_parent: Node2D, impact_sink: Callable) -> void:
	_fx_parent = fx_parent
	_impact_sink = impact_sink
	if _presenter != null:
		_presenter.set_fx_parent(_fx_parent)
	_bind_impact()


func view() -> NpcView:
	return _view


func presenter() -> NpcPresenter:
	return _presenter


func dummy() -> CombatDummy:
	return _dummy


func combat() -> NpcCombat:
	return _combat


## Cuando el muñeco recibe un golpe, su combate avisa al receptor común: la
## cámara tiembla con el mismo tier que usaría un enemigo.
func _bind_impact() -> void:
	if _combat == null or _impact_bound:
		return
	_impact_bound = true
	_combat.impact_struck.connect(_relay_impact)


func _relay_impact(tier: StringName) -> void:
	if _impact_sink.is_valid():
		_impact_sink.call(tier)


func _physics_process(delta: float) -> void:
	if _respawn_remaining < 0.0:
		return
	_respawn_remaining -= delta
	if _respawn_remaining > 0.0:
		return
	_respawn_remaining = -1.0
	_respawn_dummy()


func _on_dummy_died() -> void:
	if _dummy == null or not _dummy.is_dead:
		return
	_respawn_remaining = GameConfig.DUMMY_RESPAWN_TIME


## Vuelve a la vida en su puesto. `respawn_at` rellena la vida y devuelve el
## estado a IDLE; antes se drenan los relojes del combate para que el muñeco no
## vuelva teñido de rojo/violeta ni derrapando por el empuje del golpe anterior.
func _respawn_dummy() -> void:
	if _combat != null:
		_combat.advance(GameConfig.DUMMY_RESPAWN_TIME + 1.0)
	if _dummy != null:
		_dummy.respawn_at(GameConfig.DUMMY_SPAWN)
	if _view != null:
		_view.global_position = GameConfig.DUMMY_SPAWN