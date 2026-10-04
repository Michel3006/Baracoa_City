extends SceneTree

## Captura un frame del juego para inspección visual.
##
## Uso:
##   godot --script res://tests/support/screenshot.gd -- <salida.png> [frames] [x] [y] [zoom]
##
## Los autoload se cargan igual que en una partida normal, así que la captura
## muestra exactamente lo que vería el jugador. Si se pasan `x` e `y`, además
## teletransporta al jugador a esa posición del mundo antes de capturar; con
## `zoom` se cambia el aumento de la cámara para inspeccionar zonas enteras.

const DEFAULT_FRAMES := 20
const DEFAULT_PATH := "user://screenshot.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if args.size() > 0 else DEFAULT_PATH
	var frames := int(args[1]) if args.size() > 1 else DEFAULT_FRAMES
	_warm_up.call_deferred(output, frames, args)


func _warm_up(output: String, frames: int, args: PackedStringArray) -> void:
	var view := _find_world_view(root)
	if view == null:
		print("[AVISO] MainWorldView no encontrado; la captura no mostrará el juego")
	else:
		var game := root.get_node_or_null("Game")
		if args.size() >= 4:
			var target := Vector2(float(args[2]), float(args[3]))
			if game != null:
				game.session.teleport_to(target)
			else:
				view.move_player_to(target)
		if args.size() >= 5:
			view.camera.zoom = Vector2.ONE * float(args[4])

	for _frame: int in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	if image == null:
		print("[FALLO] no se pudo obtener la imagen del viewport")
		quit(1)
		return

	var path := ProjectSettings.globalize_path(output) if output.begins_with("res://") else output
	var error := image.save_png(path)
	if error != OK:
		print("[FALLO] no se pudo guardar %s (error %d)" % [path, error])
		quit(1)
		return
	print("[OK] captura guardada en %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	quit(0)


func _teleport(target: Vector2) -> void:
	var view := _find_world_view(root)
	if view == null:
		print("[AVISO] MainWorldView no encontrado; no se teletransportó")
		return
	view.move_player_to(target)


func _find_world_view(from: Node) -> MainWorldView:
	if from is MainWorldView:
		return from as MainWorldView
	for child: Node in from.get_children():
		var found := _find_world_view(child)
		if found != null:
			return found
	return null