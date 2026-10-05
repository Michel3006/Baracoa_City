class_name NpcDirector
extends RefCounted

## Caso de uso: dirige a los NPC de la zona (secciones 9 y 18).
##
## Construye un `Npc` con su `NpcBrain` y su `NpcCombat` por cada entrada de la tabla
## de aparición, y los mantiene vivos: reparte la posición del jugador entre los
## cerebros y les da el objetivo a quien lo tiene cerca.
##
## ## Por qué un director y no un NPC suelto
##
## Un enemigo aislado necesita tres cosas del mundo: saber dónde está el jugador,
## saber si le toca perseguir, y tener un cuerpo contra el que pegarle. Repartir eso
## en cada uno significaría que cada NPC busca al jugador por su cuenta y todos
##UFFER. El director lo hace una vez y decide a quién le toca perseguir.
##
## ## Nada de nodos
##
## Solo crea y mueve objetos de dominio. Los cuerpos físicos los crea
## `NpcSpawner`, en Presentation, que escucha `agent_ready`. La dependencia va en un
## solo sentido: Application no sabe que existen vistas.
##
## ## Señales, no referencias cruzadas
##
## El director avisa con señales. Nadie guarda el director para preguntarle quién
## hay: quien lo necesita se conecta.
##
## Dependencias: application -> domain, infrastructure/configuration

signal agent_ready(id: int, npc: Npc, brain: NpcBrain, combat: NpcCombat)
signal agent_damaged(id: int, npc: Npc, amount: float)
signal agent_died(id: int, npc: Npc)

## Un enemigo con su IA y su combate. Se emite entero para que la presentación pueda
## montar el cuerpo sin tener que preguntar por partes.
class Agent extends RefCounted:
	var npc: Npc
	var brain: NpcBrain
	var combat: NpcCombat

	func _init(body: Npc, body_brain: NpcBrain, body_combat: NpcCombat) -> void:
		npc = body
		brain = body_brain
		combat = body_combat

	## ¿Le toca perseguir al jugador ahora mismo? Un solo perseguidor a la vez.
	func is_chasing() -> bool:
		return npc.state == NpcState.Kind.CHASE or npc.state == NpcState.Kind.ATTACK

var agents: Array[Agent] = []
var _next_id: int = 1
## Conexiones con los agentes. Se guardan para poder deshacerlas: conectar señales
## entre dos `RefCounted` crea un ciclo que Godot no recolecta.
var _links: Array[Array] = []


## Crea los enemigos de la tabla de aparición y los deja listos para que la
## presentación les ponga cuerpo.
func populate(table: Array = NpcSpawnTable.demo(), limit: int = -1) -> void:
	var total := table.size() if limit < 0 else mini(table.size(), limit)
	for index: int in range(total):
		var entry: NpcSpawnTable.Entry = table[index]
		var body := Npc.new(_next_id, entry.display_name, entry.behavior)
		body.kind = entry.kind
		body.home = NpcSpawnTable.to_world(entry.tile)
		body.position = body.home
		body.move_to(body.home, Vector2.DOWN)

		var agent := Agent.new(body, NpcBrain.new(body), NpcCombat.new(body))
		agents.append(agent)
		_next_id += 1

		# Cada conexión se ata con el identificador del NPC para poder traducirla a
		# un aviso con id, que es como lo escucha la presentación.
		_link(body.died, _on_agent_died.bind(body.id))
		_link(agent.combat.damaged, _on_agent_damaged.bind(body.id))

		agent_ready.emit(body.id, body, agent.brain, agent.combat)
	GameLogger.info("Director: %d NPC en la zona" % agents.size(), "NpcDirector")


## Reparte el objetivo entre los enemigos y deja que su IA decida.
##
## Solo uno persigue a la vez: el más cercano, y solo si el jugador ha entrado en su
## radio de detección. Con seis enemigos persiguiendo a la vez el combate deja de
## ser legible y el jugador muere sin ver por qué.
##
## Solo reparte el objetivo: el reloj de cada enemigo lo mueve su propio
## presentador, en `NpcPresenter._physics_process()`. Aquí no se avanza nada para no
## tener dos relojes sobre el mismo caso de uso.
func distribute_target(player_position: Vector2) -> void:
	var hunter := _pick_hunter(player_position)
	for agent in agents:
		if agent.npc.is_dead:
			agent.brain.clear_target()
		elif agent == hunter:
			agent.brain.set_target(player_position)
		else:
			agent.brain.clear_target()


## El enemigo vivo más cercano al jugador, si está dentro de su radio de
## detección. Devuelve `null` si no hay ninguno.
func _pick_hunter(player_position: Vector2) -> Agent:
	var best: Agent = null
	var best_distance := INF
	for agent in agents:
		if agent.npc.is_dead:
			continue
		var distance := agent.npc.position.distance_to(player_position)
		if distance > agent.npc.behavior.aggro_radius or distance >= best_distance:
			continue
		best_distance = distance
		best = agent
	return best


## Enemigos vivos. Filtro, no copia: quien lo lee no debería poder cambiarlo.
func living() -> Array[Npc]:
	var found: Array[Npc] = []
	for agent in agents:
		if not agent.npc.is_dead:
			found.append(agent.npc)
	return found


func find(id: int) -> Npc:
	for agent in agents:
		if agent.npc.id == id:
			return agent.npc
	return null


func count() -> int:
	return agents.size()


func _link(source: Signal, target: Callable) -> void:
	source.connect(target)
	_links.append([source, target])


## Corta las conexiones y suelta a los enemigos. Sin esto los `RefCounted` se quedan
## vivos entre sesiones y Godot reporta fugas.
func shutdown() -> void:
	for link: Array in _links:
		(link[0] as Signal).disconnect(link[1] as Callable)
	_links.clear()
	agents.clear()
	_next_id = 1


## Traduce "este NPC ha muerto" al aviso con identificador que escucha la
## presentación. Se ata con el id en `populate()` en vez de con el propio NPC, para
## que quien escucha no tenga que buscarlo otra vez.
func _on_agent_died(id: int) -> void:
	var body := find(id)
	if body != null:
		agent_died.emit(id, body)


func _on_agent_damaged(amount: float, _source: Object, id: int) -> void:
	var body := find(id)
	if body != null:
		agent_damaged.emit(id, body, amount)