class_name CastFunction
extends RefCounted

## One spell file (cast <id>, a spells skill's cast_spell_file()): cast() returns 1
## after its effect, or notify_fail() and 0.
var id: StringName
## Its name on the player's battle panel when cast at an enemy (or at nobody), e.g. 困;
## empty for a spell no player casts at an enemy.
var label: String
## Its name when the player casts it at themselves (dun.c's 遁 to Snow's temple);
## empty for a file that does nothing different at its caster.
var self_label: String
## Whether the cast at oneself works outside a fight too (astral_vision.c): the 武学
## page's 法术 button.
var self_anywhere: bool = false
## Its name when the player casts it outside a fight at something in the world (animate.c's
## 驱尸 at a corpse, on the HUD); empty for a spell cast only in a fight.
var world_label: String
## The timed apply it starts (CharacterTimedApplies, named by its query_temp() flag),
## or empty for none.
var effect_id: StringName


func cast(_context: SpecialContext) -> bool:
	return false


## The sen its cast at oneself would take from `state` now, 0 when the file would refuse
## (or takes none): the 武学 page asks first when it would knock the player out.
func self_sen_cost(_state: CharacterState) -> int:
	return 0


## The call_out() that ends `entry` (remove_effect()), for `context.me`, in a fight or out
## of one. The entry's applies are gone already.
func remove_effect(_context: SpecialContext, _entry: CharacterTimedApplies.Entry) -> void:
	pass
