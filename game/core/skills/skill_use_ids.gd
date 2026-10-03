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


# TRANSLATORS: enable.c valid_types: what each use is called (拳脚 for unarmed …).
const KINDS: Dictionary[StringName, String] = {
	UNARMED: "拳脚", SWORD: "剑法", BLADE: "刀法", STICK: "棍法", STAFF: "杖法",
	THROWING: "暗器", FORCE: "内功", PARRY: "招架", DODGE: "轻功", MAGIC: "法术",
	SPELLS: "咒文", MOVE: "行动", ARRAY: "阵法", WHIP: "鞭法",
}


static func is_enable_command_use(use_id: StringName) -> bool:
	return KINDS.has(use_id)
