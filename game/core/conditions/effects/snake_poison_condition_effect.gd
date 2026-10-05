class_name SnakePoisonConditionEffect
extends "res://core/conditions/condition_effect.gd"

const ConditionIdsType := preload("res://core/conditions/condition_ids.gd")
const ConditionUpdateFlagsType := preload(
	"res://core/conditions/condition_update_flags.gd"
)
const DurationConditionPayloadType := preload(
	"res://core/conditions/duration_condition_payload.gd"
)


func condition_id() -> StringName:
	return ConditionIdsType.SNAKE_POISON


## daemon/condition/snake_poison.c: tell_object(me, HIG "你中的蛇毒发作了！").
func message() -> String:
	return "你中的蛇毒发作了！"


func message_color() -> StringName:
	return ColoredLine.HIG


func shown_name() -> String:
	return "蛇毒"


func update(character: CharacterStateType, payload: ConditionPayloadType) -> int:
	var duration: DurationConditionPayloadType = payload as DurationConditionPayloadType
	if duration == null:
		assert(false, "snake_poison requires DurationConditionPayload.")
		return 0

	var previous_remaining: int = duration.remaining
	character.vitality.apply_wound(10)
	character.spirit.apply_damage(10)
	character.conditions.add_or_replace_duration(condition_id(), previous_remaining - 1)
	if previous_remaining < 1:
		return 0
	return ConditionUpdateFlagsType.CONTINUE
