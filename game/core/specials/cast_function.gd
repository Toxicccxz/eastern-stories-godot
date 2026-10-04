class_name CastFunction
extends RefCounted

## One spell file (cast <id>, a spells skill's cast_spell_file()): cast() returns 1
## after its effect, or notify_fail() and 0.
var id: StringName


func cast(_context: SpecialContext) -> bool:
	return false
