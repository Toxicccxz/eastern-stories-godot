extends RefCounted

## PacingDefinition.copy() keeps every knob. Suites run the world on a copy of the game's record
## (Es2Pacing.use_reactions(), TestDay and the rest), so a knob added to the record and forgotten
## in copy() would hand them its old default unseen, as the hand-built records once did. Every
## field the script declares (got by get_property_list(), not by a list kept here) is set to a
## value of its own that is no default, and the copy must hold each, sub-records compared by
## value. Fields hold different values, so two knobs swapped in copy() show as well.

## Fields that are only read through a getter of another (none today); named here if one comes.
const DERIVED: Array[String] = []

var _count: int = 0
var _failures: Array[String] = []
var _next: int = 1000


func run_all() -> Dictionary[String, Variant]:
	var record := PacingDefinition.new()
	var set_fields: Array[String] = _fill(record)
	_check(set_fields.size() >= 45, "the record's fields are found: %d" % set_fields.size())
	for name: String in ["_beat_rules", "_decision_rules", "_combat_rules", "feel", "npc_idle", "_corpse_decay_seconds", "_coach_minutes_per_leg"]:
		_check(set_fields.has(name), "%s is among the fields set" % name)
	var copied: PacingDefinition = record.copy()
	_check(copied != record, "copy() makes a new record")
	var differences: Array[String] = []
	_compare(record, copied, "", differences)
	_check(differences.is_empty(), "copy() keeps every field: %s" % [differences])
	_self_check()
	return {"assertions": _count, "failures": _failures}


## The test's own comparison sees a field left out, a sub-record's field, and two values swapped.
func _self_check() -> void:
	var record := PacingDefinition.new()
	_fill(record)
	var copied: PacingDefinition = record.copy()
	copied._coach_fare_base = PacingDefinition.new()._coach_fare_base
	var differences: Array[String] = []
	_compare(record, copied, "", differences)
	_check(differences.size() == 1 and differences[0].begins_with("_coach_fare_base"), "a field left at its default shows: %s" % [differences])
	copied = record.copy()
	copied.feel = copied.feel.but({"session_start_slice_ms": 0})
	differences.clear()
	_compare(record, copied, "", differences)
	_check(differences.size() == 1 and differences[0].begins_with("feel._session_start_slice_ms"), "a sub-record's field shows: %s" % [differences])
	copied = record.copy()
	var swapped: int = copied._coach_fare_base
	copied._coach_fare_base = copied._coach_fare_per_leg
	copied._coach_fare_per_leg = swapped
	differences.clear()
	_compare(record, copied, "", differences)
	_check(differences.size() == 2, "two fields swapped show: %s" % [differences])


## Every script field of `object` set to a value of its own; returns the names set.
func _fill(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in _fields(object):
		var name: String = property["name"]
		var value: Variant = object.get(name)
		match typeof(value):
			TYPE_BOOL:
				object.set(name, not value)
			TYPE_INT:
				object.set(name, _other_enum(property, value) if property["hint"] == PROPERTY_HINT_ENUM else _fresh())
			TYPE_FLOAT:
				object.set(name, float(_fresh()) + 0.5)
			TYPE_STRING:
				object.set(name, "s%d" % _fresh())
			TYPE_STRING_NAME:
				object.set(name, StringName("s%d" % _fresh()))
			TYPE_ARRAY:
				var array: Array = (value as Array).duplicate()
				array.clear()
				var element: int = (value as Array).get_typed_builtin()
				for _index: int in 3:
					array.append(StringName("s%d" % _fresh()) if element == TYPE_STRING_NAME else _fresh())
				object.set(name, array)
			TYPE_DICTIONARY:
				var dictionary: Dictionary = (value as Dictionary).duplicate()
				dictionary.clear()
				dictionary[StringName("k%d" % _fresh())] = _fresh()
				object.set(name, dictionary)
			TYPE_OBJECT:
				if value == null:
					_failures.append("%s is null on a new record: give it a value here" % name)
					continue
				_fill(value)
			_:
				_failures.append("%s: no non-default value for type %d; teach _fill() it" % [name, typeof(value)])
				continue
		if typeof(value) != TYPE_OBJECT:
			_check(object.get(name) != value, "%s took its new value" % name)
		names.append(name)
	return names


## `a` and `b` field by field, sub-records by value; each difference appended as "path: a vs b".
func _compare(a: Object, b: Object, path: String, differences: Array[String]) -> void:
	for property: Dictionary in _fields(a):
		var name: String = property["name"]
		var left: Variant = a.get(name)
		var right: Variant = b.get(name)
		if typeof(left) == TYPE_OBJECT and left != null and right != null:
			_compare(left, right, path + name + ".", differences)
		elif typeof(left) != typeof(right) or left != right:
			differences.append("%s%s: %s vs %s" % [path, name, left, right])


## The fields the script declares that hold a value of their own. A record with `_`-named fields
## keeps its knobs there behind getters (combat_round_seconds reads _combat_round_ms): those, and
## its public sub-records (feel, npc_idle). A record without (CombatBeatRules) is all plain fields.
func _fields(object: Object) -> Array[Dictionary]:
	var declared: Array[Dictionary] = []
	var private: bool = false
	for property: Dictionary in object.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and not DERIVED.has(property["name"]):
			declared.append(property)
			private = private or String(property["name"]).begins_with("_")
	if not private:
		return declared
	return declared.filter(func(p: Dictionary) -> bool: return String(p["name"]).begins_with("_") or int(p["type"]) == TYPE_OBJECT)


func _other_enum(property: Dictionary, value: int) -> int:
	var options: PackedStringArray = String(property["hint_string"]).split(",")
	var values: Array[int] = []
	for index: int in options.size():
		var parts: PackedStringArray = options[index].split(":")
		values.append(int(parts[1]) if parts.size() > 1 else index)
	for candidate: int in values:
		if candidate != value:
			return candidate
	return value


func _fresh() -> int:
	_next += 1
	return _next


func _check(condition: bool, label: String) -> bool:
	_count += 1
	if not condition:
		_failures.append(label)
	return condition
