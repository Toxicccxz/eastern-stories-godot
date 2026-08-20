class_name BellicosityImprovementEffect
extends "res://core/skills/improvement_effects/skill_improvement_effect.gd"

var normal_gain: int
var periodic_gain: int
var period: int
var trigger_remainder: int


func _init(
	p_skill_id: StringName = &"",
	p_normal_gain: int = 0,
	p_periodic_gain: int = 0,
	p_period: int = 0,
	p_trigger_remainder: int = 0,
) -> void:
	super(p_skill_id)
	normal_gain = p_normal_gain
	periodic_gain = p_periodic_gain
	period = p_period
	trigger_remainder = p_trigger_remainder


func apply(
	character: CharacterStateType,
	improvement: SkillImprovementResultType,
) -> EffectResultType:
	var gain: int = normal_gain
	if period > 0 and improvement.current_level % period == trigger_remainder:
		gain = periodic_gain
	var previous_value: int = character.attributes.bellicosity
	character.attributes.bellicosity += gain
	return EffectResultType.new(
		improvement.skill_id,
		EffectResultType.Status.APPLIED,
		EffectResultType.Mutation.BELLICOSITY,
		gain,
		previous_value,
		character.attributes.bellicosity,
	)
