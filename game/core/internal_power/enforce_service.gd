class_name EnforceService
extends RefCounted

## cmds/std/enforce.c: how much force each hit carries (force_factor), from 0 (none)
## to query_skill("force") / 2. It needs an enabled force and nothing else: no busy
## or fight check, so it works in a fight too. combatd.c spends the factor on each
## hit that lands while force is above it; query_str() and query_cps() add it.
const BASIC_FORCE: StringName = &"force"


## The highest factor enforce.c accepts; `force_level` is query_skill("force").
static func limit(force_level: int) -> int:
	@warning_ignore("integer_division")
	return force_level / 2


## `enforce <points>`; 0 is `enforce none` (delete("force_factor") reads as 0).
## Returns the lines enforce.c prints; the factor changes only with Ok.
static func enforce(character: CharacterState, points: int, force_level: int) -> Array[ColoredLine]:
	if character.skills.mapped_skill(BASIC_FORCE).is_empty():
		return [ColoredLine.new(_t("你必须先 enable 一种内功。"))]
	if points < 0 or points > limit(force_level):
		return [ColoredLine.new(_t("你只能用 none 表示不运内力，或数字表示每一击用几点内力。"))]
	character.attributes.force_factor = points
	# TRANSLATORS: enforce.c's answer when the factor is set; ES2 prints it in English.
	return [ColoredLine.new(_t("Ok."))]


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
