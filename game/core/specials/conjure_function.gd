class_name ConjureFunction
extends RefCounted

## One 神通 file (conjure <id>, a magic skill's conjure_magic_file():
## daemon/class/bonze/essencemagic/): conjure() returns 1 after its effect, or
## notify_fail() and 0.
var id: StringName
## Its name as a button (doc/skill/essencemagic: 心识, 游识, 空识 and 神通).
var label: String
## It works on the one named (heart_sense.c: conjure heart_sense on <target>); the
## others refuse a target.
var targets_other: bool = false


func conjure(_context: SpecialContext) -> bool:
	return false
