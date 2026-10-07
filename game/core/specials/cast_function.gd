class_name CastFunction
extends RefCounted

## One spell file (cast <id>, a spells skill's cast_spell_file()): cast() returns 1
## after its effect, or notify_fail() and 0.
var id: StringName
## Its name on the player's battle panel when cast at an enemy (or at nobody), e.g. 困;
## empty for a spell no player can reach yet (the NPCs' bolts).
var label: String
## Its name when the player casts it at themselves (dun.c's 遁 to Snow's temple);
## empty for a file that does nothing different at its caster.
var self_label: String


func cast(_context: SpecialContext) -> bool:
	return false
