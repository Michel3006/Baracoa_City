class_name GameEvents
extends Node

## Bus de eventos del dominio (sección 26 de la especificación).
##
## Permite que dominio, combate, inventario, UI, audio y networking se comuniquen
## sin conocerse entre sí. Es la única pieza compartida que cruza capas.
##
## Las emisiones son síncronas: los publicadores son nodos que viven fuera de la
## cascada de signals. Un manejador que necesite diferir trabajo (firmar un nodo,
## destruirlo, abrir una escena) usa `call_deferred` por su cuenta.
##
## Dependencias: domain

signal player_spawned(player: Node2D)
signal player_state_changed(previous: PlayerState.Kind, current: PlayerState.Kind)
signal player_health_changed(current: float, maximum: float)
signal player_died()
signal player_respawned(position: Vector2)
signal player_moved(position: Vector2, direction: Vector2)
signal zone_entered(zone_id: StringName)
signal zone_exited(zone_id: StringName)


func reset() -> void:
	for info: Dictionary in get_signal_list():
		var event := StringName(info["name"])
		for connection: Dictionary in get_signal_connection_list(event):
			disconnect(event, connection["callable"])