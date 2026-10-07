class_name DrunkConditionEffect
extends "res://core/conditions/condition_effect.gd"

## daemon/condition/drunk.c. Its tolerance is (con + max_force / 50) * 2: past it the
## drinker falls unconscious (and the condition ends), past half of it they reel, past
## a quarter they feel it; an unconscious drinker only hiccups. Each update counts down
## by one and the condition ends on the update that finds it at zero. The daemon's
## receive_healing() calls reach no function (damage.c has receive_heal()), so they
## heal nothing, as in ES2.
const ConditionIdsType := preload("res://core/conditions/condition_ids.gd")
const ConditionUpdateFlagsType := preload(
	"res://core/conditions/condition_update_flags.gd"
)
const DurationConditionPayloadType := preload(
	"res://core/conditions/duration_condition_payload.gd"
)


func condition_id() -> StringName:
	return ConditionIdsType.DRUNK


## (query("con") + query("max_force") / 50) * 2, shared with slumber_drug.c.
@warning_ignore("integer_division")
static func tolerance(character: CharacterStateType) -> int:
	return (character.attributes.constitution + character.recovery.inner_force.maximum / 50) * 2


@warning_ignore("integer_division")
func tick(character: CharacterStateType, payload: ConditionPayloadType, report: ConditionReport) -> int:
	var duration: DurationConditionPayloadType = payload as DurationConditionPayloadType
	if duration == null:
		assert(false, "drunk requires DurationConditionPayload.")
		return 0
	var previous_remaining: int = duration.remaining
	var limit: int = tolerance(character)
	if previous_remaining > limit and report.conscious:
		report.knock_out(character)
		return 0
	if not report.conscious:
		report.tell_room("{name}打了个隔，不过依然烂醉如泥。")
	elif previous_remaining > limit / 2:
		report.tell("你觉得脑中昏昏沉沉，身子轻飘飘地，大概是醉了。")
		report.tell_room("{name}摇头晃脑地站都站不稳，显然是喝醉了。")
		character.spirit.apply_damage(10)
	elif previous_remaining > limit / 4:
		report.tell("你觉得一阵酒意上冲，眼皮有些沉重了。")
		report.tell_room("{name}脸上已经略显酒意了。")
		character.spirit.apply_damage(3)
	character.conditions.add_or_replace_duration(condition_id(), previous_remaining - 1)
	if previous_remaining == 0:
		return 0
	return ConditionUpdateFlagsType.CONTINUE
