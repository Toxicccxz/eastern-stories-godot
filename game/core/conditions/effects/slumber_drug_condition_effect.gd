class_name SlumberDrugConditionEffect
extends "res://core/conditions/condition_effect.gd"

## daemon/condition/slumber_drug.c (蒙汗药, 极乐逍遥散 in a drink): past the drunk.c
## tolerance a conscious character falls unconscious (and the condition ends); past
## half of it they feel the drug and the room sees them sway. It counts down as drunk.c.
const ConditionIdsType := preload("res://core/conditions/condition_ids.gd")
const ConditionUpdateFlagsType := preload(
	"res://core/conditions/condition_update_flags.gd"
)
const DurationConditionPayloadType := preload(
	"res://core/conditions/duration_condition_payload.gd"
)
const DrunkConditionEffectType := preload(
	"res://core/conditions/effects/drunk_condition_effect.gd"
)


func condition_id() -> StringName:
	return ConditionIdsType.SLUMBER_DRUG


@warning_ignore("integer_division")
func tick(character: CharacterStateType, payload: ConditionPayloadType, report: ConditionReport) -> int:
	var duration: DurationConditionPayloadType = payload as DurationConditionPayloadType
	if duration == null:
		assert(false, "slumber_drug requires DurationConditionPayload.")
		return 0
	var previous_remaining: int = duration.remaining
	var limit: int = DrunkConditionEffectType.tolerance(character)
	if previous_remaining > limit and report.conscious:
		report.knock_out(character)
		return 0
	if previous_remaining > limit / 2:
		report.tell("你觉得脑中昏昏沉沉，心中空荡荡的，直想躺下来睡一觉。")
		report.tell_room("{name}摇头晃脑地站都站不稳，显然是蒙汗药的药力发作了。")
	character.conditions.add_or_replace_duration(condition_id(), previous_remaining - 1)
	if previous_remaining == 0:
		return 0
	return ConditionUpdateFlagsType.CONTINUE
