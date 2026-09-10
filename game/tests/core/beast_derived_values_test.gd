extends RefCounted

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	# Literal expectations independently evaluated from race/beast.c. Includes
	# below/exact/above every branch, negative age, and serpent's overridden age.
	var cases: Array[Array] = [
		[-1, 50, 50, 50], [0, 50, 50, 50],
		[2, 50, 50, 50], [3, 50, 50, 50], [4, 70, 50, 50],
		[5, 90, 50, 50], [6, 110, 75, 50],
		[9, 170, 150, 50], [10, 190, 175, 50], [11, 195, 200, 50],
		[19, 235, 400, 50], [20, 240, 425, 50], [21, 245, 430, 60],
		[29, 285, 470, 140], [30, 290, 475, 150], [31, 291, 480, 160],
		[400, 660, 2325, 3850],
	]
	for row: Array in cases:
		var age: int = row[0]
		_eq(CharacterDerivedValues.beast_maximum_essence(age), row[1], "gin age %d" % age)
		_eq(CharacterDerivedValues.beast_maximum_vitality(age), row[2], "kee age %d" % age)
		_eq(CharacterDerivedValues.beast_maximum_spirit(age), row[3], "sen age %d" % age)
	# beast.h BASE_WEIGHT=2000, slope=2000; chard.c capacity=str*5000.
	for row: Array in [[0, -18000, 0], [6, -6000, 30000], [9, 0, 45000], [10, 2000, 50000], [40, 62000, 200000]]:
		_eq(CharacterDerivedValues.beast_weight(row[0]), row[1], "weight str %d" % row[0])
		_eq(CharacterDerivedValues.maximum_encumbrance(row[0]), row[2], "capacity str %d" % row[0])
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _eq(actual: int, expected: int, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %d, got %d" % [label, expected, actual])
