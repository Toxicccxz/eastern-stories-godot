class_name SkillUseIds
extends RefCounted

## Categories accepted by cmds/std/enable.c.
const UNARMED: StringName = &"unarmed"
const SWORD: StringName = &"sword"
const BLADE: StringName = &"blade"
const STICK: StringName = &"stick"
const STAFF: StringName = &"staff"
const THROWING: StringName = &"throwing"
const FORCE: StringName = &"force"
const PARRY: StringName = &"parry"
const DODGE: StringName = &"dodge"
const MAGIC: StringName = &"magic"
const SPELLS: StringName = &"spells"
const MOVE: StringName = &"move"
const ARRAY: StringName = &"array"
const WHIP: StringName = &"whip"

## daemon/skill/jin-gang.c declares this use, but enable.c does not list it.
## It is retained only as traceable legacy metadata, not as a command category.
const LEGACY_IRON_CLOTH: StringName = &"iron-cloth"


static func is_enable_command_use(use_id: StringName) -> bool:
	return (
		use_id == UNARMED
		or use_id == SWORD
		or use_id == BLADE
		or use_id == STICK
		or use_id == STAFF
		or use_id == THROWING
		or use_id == FORCE
		or use_id == PARRY
		or use_id == DODGE
		or use_id == MAGIC
		or use_id == SPELLS
		or use_id == MOVE
		or use_id == ARRAY
		or use_id == WHIP
	)
