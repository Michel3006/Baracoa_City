extends RefCounted

## Guardián de compilación (sección 29).
##
## Un error de parseo en un solo script no para el juego: Godot lo registra por
## consola y sigue. Lo que hace es arrastrar a los scripts que lo referencian, y
## como el fallo aparece en `_ready()` en vez de en un test, las suites siguen en
## verde mientras el juego está roto.
##
## Pasó de verdad: `HitboxSensor` llamaba a `add_excluded_object()`, que es API de
## `CollisionObject3D`. El script no compilaba, arrastraba a ocho más, la hitbox
## nunca se creaba y el combate no golpeaba a nadie. Ni los tests unitarios ni los
## de integración se enteraron.
##
## Este test recorre `scripts/` y obliga a que todo cargue. Es la red de seguridad
## que hacía falta.

const SCRIPTS_ROOT := "res://scripts"


func register() -> Array:
	return [
		["todos los scripts de scripts/ cargan sin errores", _every_script_loads],
		["las clases globales esperadas están registradas", _global_classes_present],
	]


## Recorre `scripts/` y carga cada `.gd`. Un `class_name` sin compilar se
## registra igual, así que comprobar solo el caché no basta: hay que cargarlos.
func _every_script_loads(ctx: ScriptTestContext) -> void:
	var paths: PackedStringArray = _collect_scripts(SCRIPTS_ROOT)
	ctx.check(paths.size() > 0, "no se encontró ningún script en %s" % SCRIPTS_ROOT)

	var broken: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var script: Variant = load(path)
		if script == null:
			broken.append("%s: no se pudo cargar" % path)
			continue
		if not (script is GDScript):
			continue
		var gdscript := script as GDScript
		# Un script con error de parseo carga como objeto pero no se puede
		# instanciar: esa es exactamente la firma del fallo que buscamos.
		if not gdscript.can_instantiate():
			broken.append("%s: compila con errores" % path)

	for failure: String in broken:
		ctx.failures.append(failure)


## Los `class_name` que el resto del código usa como tipo deben existir. Si uno
## desaparece, quien lo referencia deja de compilar y el fallo aparece lejos de
## la causa.
func _global_classes_present(ctx: ScriptTestContext) -> void:
	var required: PackedStringArray = [
		"ActorSprite",
		"ActorVisualCatalog",
		"AttackCatalog",
		"AttackDefinition",
		"CharacterStats",
		"CharacterVisualDefinition",
		"CollisionLayers",
		"CombatState",
		"DamageRules",
		"GameConfig",
		"GameSession",
		"GameLogger",
		"HitboxSensor",
		"MainWorldView",
		"MeleeCombat",
		"MovementController",
		"Player",
		"PlayerState",
		"PlayerView",
		"Weapon",
		"WeaponCatalog",
		"WorldCamera",
	]
	for expected: String in required:
		ctx.check(
			_global_class_exists(expected),
			"clase global no registrada: %s" % expected
		)


func _global_class_exists(identifier: String) -> bool:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == identifier:
			return true
	return false


## Lista recursivamente los `.gd` de un directorio del proyecto.
func _collect_scripts(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	# Array normal, no Packed: hace falta `pop_back()` para la pila y
	# `PackedStringArray` no lo trae.
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if entry.begins_with("."):
				entry = dir.get_next()
				continue
			var full := current.path_join(entry)
			if dir.current_is_dir():
				pending.append(full)
			elif entry.ends_with(".gd"):
				found.append(full)
			entry = dir.get_next()
		dir.list_dir_end()
	return found