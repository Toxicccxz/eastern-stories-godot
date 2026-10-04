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


func perform(_context: SpecialContext) -> bool:
	return false


## The call_out() that ends `entry` in a fight (remove_effect()), for `context.me`,
## with the one it named as `context.target`. The entry's applies are gone already.
func remove_effect(_context: SpecialContext, _entry: CharacterTimedApplies.Entry) -> void:
	pass
