class_name PerformFunction
extends RefCounted

## One perform action file (perform <skill>.<id>, a martial skill's
## perform_action_file()): perform() returns 1 after its effect, or notify_fail() and 0.
var id: StringName
## Its name in the skill's help (doc/skill/<skill>), e.g. 「封」字诀.
var label: String
## The timed apply it starts (CharacterTimedApplies, named by its query_temp() flag),
## or empty for none.
var effect_id: StringName
## The busy it always leaves its performer in (counterattack.c's 1, hasten.c's 3); 0 for none
## or one that comes only sometimes (fakefault.c's on a failure). Under 战斗拍数 it counts into
## the beats the perform costs (max, DECISIONS「战斗拍数 C」); the battle panel says so.
var own_busy: int = 0
## Native (DECISIONS「点字诀」): the numbers the file reads from its skill's record (skills.json
## `perform_rules.<id>.numbers`), each required there; [] for a file whose numbers are ES2's own.
var number_keys: Array[String] = []


func perform(_context: SpecialContext) -> bool:
	return false


## What it does and costs, for its battle button's hover; "" for none.
func hint(_catalog: ContentCatalog) -> String:
	return ""


## The call_out() that ends `entry` in a fight (remove_effect()), for `context.me`,
## with the one it named as `context.target`. The entry's applies are gone already.
func remove_effect(_context: SpecialContext, _entry: CharacterTimedApplies.Entry) -> void:
	pass
