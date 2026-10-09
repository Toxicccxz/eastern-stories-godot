class_name ForceHitWound
extends RefCounted

## A force skill whose hit_ob() goes on after std/force.c's (daemon/skill/iceforce.c): when
## the force hit returned a number and damage_bonus plus it is above 0, random(query_skill
## of the skill) over that sum wounds the victim's kee by it, sets `condition` to
## force_factor / `factor_divisor` and returns `message` instead of the number (the blow
## goes on without it). skills.json `force_hit_wound`, with standard_force_hit.
var condition_id: StringName
var factor_divisor: int
var message: String


func _init(p_condition_id: StringName = &"", p_factor_divisor: int = 1, p_message: String = "") -> void:
	condition_id = p_condition_id
	factor_divisor = p_factor_divisor
	message = p_message


## {condition, factor_divisor, message}.
static func from_record(reader: ContentRecordReader) -> ForceHitWound:
	var wound := ForceHitWound.new(
		StringName(reader.required_text("condition")), reader.required_integer("factor_divisor"),
		reader.required_text("message"),
	)
	reader.finish()
	if not ConditionIds.ALL.has(wound.condition_id):
		reader.fail("condition", "unknown condition %s" % wound.condition_id)
	if wound.factor_divisor < 1:
		reader.fail("factor_divisor", "must be positive")
	return wound
