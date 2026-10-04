class_name NpcSpecialAction
extends RefCounted

## A chat function of std/char/npc.c that runs a skill's special file:
## perform_action("<use>.<id>") through the skill enabled for `use`, cast_spell(id)
## through the enabled spells, exert_function(id) through the enabled force; or
## command("surrender") (cmds/std/surrender.c). npc.c calls the skill daemon
## directly, not perform.c, cast.c or exert.c: no busy check, no practice from use.
enum Kind { PERFORM, CAST, EXERT, SURRENDER }

const KINDS: Dictionary[String, Kind] = {
	"perform": Kind.PERFORM, "cast": Kind.CAST, "exert": Kind.EXERT, "surrender": Kind.SURRENDER,
}

var kind: Kind
## The use a perform goes through (sword); spells and force for cast and exert.
var use: StringName
var function_id: StringName


func _init(p_kind: Kind = Kind.SURRENDER, p_use: StringName = &"", p_function_id: StringName = &"") -> void:
	kind = p_kind
	use = p_use
	function_id = p_function_id
	if kind == Kind.CAST:
		use = SkillUseIds.SPELLS
	elif kind == Kind.EXERT:
		use = SkillUseIds.FORCE


func is_valid() -> bool:
	if kind == Kind.SURRENDER:
		return function_id.is_empty()
	return not use.is_empty() and not function_id.is_empty()


## {"action": "perform", "skill", "function"} | {"action": "cast"|"exert", "function"}
## | {"action": "surrender"}.
static func from_record(reader: ContentRecordReader, action: String) -> NpcSpecialAction:
	var kind: Kind = KINDS[action]
	var value := NpcSpecialAction.new(
		kind, StringName(reader.required_text("skill")) if kind == Kind.PERFORM else &"",
		&"" if kind == Kind.SURRENDER else StringName(reader.required_text("function")),
	)
	if not value.is_valid():
		reader.fail("", "needs its skill and function")
	return value
