extends "res://core/conditions/condition_effect.gd"

const TEST_CONDITION_ID: StringName = &"test_no_heal"
const ConditionUpdateFlagsType := preload(
	"res://core/conditions/condition_update_flags.gd"
)
const DurationConditionPayloadType := preload(
	"res://core/conditions/duration_condition_payload.gd"
)


func condition_id() -> StringName:
	return TEST_CONDITION_ID


func update(character: CharacterStateType, payload: ConditionPayloadType) -> int:
	var duration: DurationConditionPayloadType = payload as DurationConditionPayloadType
	if duration == null:
		return 0
	character.conditions.add_or_replace_duration(condition_id(), duration.remaining - 1)
	return ConditionUpdateFlagsType.CONTINUE | ConditionUpdateFlagsType.NO_HEAL_UP
