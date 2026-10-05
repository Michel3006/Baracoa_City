class_name RespawnInput
extends Node

## Botón de revivir: lee la tecla y pide la reaparición (sección 8).
##
## Separate del `PlayerPresenter` a propósito. El presentador está desactivado en los
## tests de integración porque lee el teclado, y si el botón de revivir viviera ahí,
## ningún test podría comprobar el ciclo de muerte y reaparición. Aquí solo hay una
## lectura de entrada y una llamada al caso de uso, así que se puede apagar igual.
##
## No decide ni cuándo ni dónde se revive: pide, y `GameSession` decide si puede.
##
## Dependencias: presentation -> application

## Tecla de reaparición. La misma que `interact`: en la pantalla de muerte no hay
## nada con lo que interactuar, así que reutilizarla no obliga a aprender dos.
const ACTION_RESPAWN := &"interact"

var session: GameSession = null


func bind(source: GameSession) -> void:
	session = source


func _physics_process(delta: float) -> void:
	if session == null:
		return
	session.advance(delta)
	if not session.can_respawn():
		return
	if Input.is_action_just_pressed(ACTION_RESPAWN):
		session.request_respawn()