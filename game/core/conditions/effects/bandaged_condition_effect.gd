class_name BandagedConditionEffect
extends "res://core/conditions/condition_effect.gd"

const ConditionIdsType := preload("res://core/conditions/condition_ids.gd")
const ConditionUpdateFlagsType := preload(
	"res://core/conditions/condition_update_flags.gd"
)
const DurationConditionPayloadType := preload(
	"res://core/conditions/duration_condition_payload.gd"
)


func condition_id() -> StringName:
	return ConditionIdsType.BANDAGED


func update(character: CharacterStateType, payload: ConditionPayloadType) -> int:
	var duration: DurationConditionPayloadType = payload as DurationConditionPayloadType
	if duration == null:
		assert(false, "bandaged requires DurationConditionPayload.")
		return 0

	var previous_remaining: int = duration.remaining
	if character.vitality.effective < character.vitality.maximum:
		character.vitality.cure(3)
	character.conditions.add_or_replace_duration(condition_id(), previous_remaining - 1)
	if previous_remaining == 0:
		return 0
	return ConditionUpdateFlagsType.CONTINUE
