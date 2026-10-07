class_name TestRunner
extends SceneTree

## Ejecutor de tests headless (sección 29).
##
## Uso: godot --headless --script res://tests/support/test_runner.gd
##
## Cada archivo de test expone una clase que extiende `TestCase` y declara sus
## casos en `register()`. El runner los ejecuta, informa el resultado y termina
## con código 1 si hay algún fallo, para poder integrarlo en CI.

const TEST_FILES: PackedStringArray = [
	"res://tests/unit/test_script_integrity.gd",
	"res://tests/unit/test_player_state.gd",
	"res://tests/unit/test_health.gd",
	"res://tests/unit/test_character_stats.gd",
	"res://tests/unit/test_movement_intent.gd",
	"res://tests/unit/test_damage_rules.gd",
	"res://tests/unit/test_weapon.gd",
	"res://tests/unit/test_item.gd",
	"res://tests/unit/test_inventory.gd",
	"res://tests/unit/test_actor_sprite.gd",
	"res://tests/unit/test_melee_combat.gd",
	"res://tests/unit/test_npc.gd",
	"res://tests/unit/test_npc_combat.gd",
	"res://tests/unit/test_npc_brain.gd",
	"res://tests/unit/test_world_bounds.gd",
	"res://tests/unit/test_game_config.gd",
	"res://tests/unit/test_pixel_font.gd",
	"res://tests/unit/test_punch_arm.gd",
]

var _failures: Array[String] = []
var _total: int = 0
var _passed: int = 0


func _initialize() -> void:
	print("== Tests unitarios ==")
	for path: String in TEST_FILES:
		_run_file(path)
	_report()
	quit(0 if _failures.is_empty() else 1)


func _run_file(path: String) -> void:
	var script: Script = load(path)
	if script == null:
		_failures.append("%s: no se pudo cargar" % path)
		print("  [ERROR] %s no se pudo cargar" % path)
		return
	# Un archivo de test con error de parseo carga como GDScript pero no se puede
	# instanciar. Sin esta comprobación el runner lo salta en silencio y la suite
	# sale en verde con casos sin ejecutar.
	if not script.can_instantiate():
		_failures.append("%s: compila con errores" % path)
		print("  [ERROR] %s no compila" % path)
		return
	var test_case: RefCounted = script.new()
	print("-- %s" % path.get_file())
	for entry: Array in test_case.register():
		var case_name: String = entry[0]
		var case_body: Callable = entry[1]
		_total += 1
		if _invoke(case_body):
			_passed += 1
			print("  [OK]   %s" % case_name)
		else:
			_failures.append("%s :: %s" % [path.get_file(), case_name])
			print("  [FAIL] %s" % case_name)
		_teardown(test_case)


## Suelta lo que un caso haya dejado puesto.
##
## Los unitarios no tienen escena, pero sí pueden crear nodos: un `Sprite2D` con una
## hoja cargada se queda con la textura si nadie lo libera, y Godot avisa de fugas al
## salir. Como un error por consola significa que algo está mal aunque el resultado sea
## verde, el runner da un sitio donde soltar eso en vez de confiar en que cada caso se
## acuerde.
func _teardown(test_case: RefCounted) -> void:
	if not test_case.has_method(&"teardown"):
		return
	(test_case as Object).call(&"teardown")


func _invoke(callable: Callable) -> bool:
	var context: ScriptTestContext = ScriptTestContext.new()
	callable.call(context)
	if not context.failures.is_empty():
		for failure: String in context.failures:
			print("         %s" % failure)
		return false
	return true


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("RESULTADO: %d/%d pruebas correctas" % [_passed, _total])
		return
	print("RESULTADO: %d/%d correctas, %d fallidas" % [_passed, _total, _failures.size()])
	for failure: String in _failures:
		print("  - %s" % failure)