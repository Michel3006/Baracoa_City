class_name ScriptTestContext
extends RefCounted

## Recoge las aserciones de un caso de prueba.
##
## Un caso falla si recorded al menos un error; los casos que necesitan_ASSERT
## fuera de un callable pueden consultarlo al final.

var failures: PackedStringArray = PackedStringArray()


func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition


func check_equal(actual: Variant, expected: Variant, label: String) -> bool:
	if _same(actual, expected):
		return true
	failures.append("%s: se esperaba %s, se obtuvo %s" % [label, expected, actual])
	return false


func check_almost_equal(actual: float, expected: float, label: String) -> bool:
	if is_equal_approx(actual, expected):
		return true
	failures.append("%s: se esperaba ~%f, se obtuvo %f" % [label, expected, actual])
	return false


func _same(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) == typeof(expected):
		return actual == expected
	return is_same(actual, expected)