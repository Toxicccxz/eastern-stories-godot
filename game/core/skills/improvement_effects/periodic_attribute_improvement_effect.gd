class_name PeriodicAttributeImprovementEffect
extends "res://core/skills/improvement_effects/skill_improvement_effect.gd"

enum AttributeTarget {
	STRENGTH,
	INTELLIGENCE,
	SPIRITUALITY,
	COMPOSURE,
	PERSONALITY,
	CONSTITUTION,
}

const LEVEL_PERIOD: int = 10
const TRIGGER_REMAINDER: int = 9
const ATTRIBUTE_LIMIT_DIVISOR: int = 4
const ATTRIBUTE_GAIN: int = 2

var attribute_target: int


func _init(
	p_skill_id: StringName = &"",
	p_attribute_target: int = AttributeTarget.STRENGTH,
) -> void:
	super(p_skill_id)
	attribute_target = p_attribute_target


func apply(
	character: CharacterStateType,
	improvement: SkillImprovementResultType,
) -> EffectResultType:
	var previous_value: int = _read_attribute(character)
	var mutation: int = _mutation_kind()
	if improvement.current_level % LEVEL_PERIOD != TRIGGER_REMAINDER:
		return EffectResultType.new(
			improvement.skill_id,
			EffectResultType.Status.EVALUATED_NO_MUTATION,
			mutation,
			0,
			previous_value,
			previous_value,
		)

	@warning_ignore("integer_division")
	var attribute_limit: int = improvement.current_level / ATTRIBUTE_LIMIT_DIVISOR
	if previous_value >= attribute_limit:
		return EffectResultType.new(
			improvement.skill_id,
			EffectResultType.Status.EVALUATED_NO_MUTATION,
			mutation,
			0,
			previous_value,
			previous_value,
		)

	var current_value: int = previous_value + ATTRIBUTE_GAIN
	_write_attribute(character, current_value)
	return EffectResultType.new(
		improvement.skill_id,
		EffectResultType.Status.APPLIED,
		mutation,
		ATTRIBUTE_GAIN,
		previous_value,
		current_value,
	)


func _read_attribute(character: CharacterStateType) -> int:
	match attribute_target:
		AttributeTarget.STRENGTH:
			return character.attributes.strength
		AttributeTarget.INTELLIGENCE:
			return character.attributes.intelligence
		AttributeTarget.SPIRITUALITY:
			return character.attributes.spirituality
		AttributeTarget.COMPOSURE:
			return character.attributes.composure
		AttributeTarget.PERSONALITY:
			return character.attributes.personality
		AttributeTarget.CONSTITUTION:
			return character.attributes.constitution
	return 0


func _write_attribute(character: CharacterStateType, value: int) -> void:
	match attribute_target:
		AttributeTarget.STRENGTH:
			character.attributes.strength = value
		AttributeTarget.INTELLIGENCE:
			character.attributes.intelligence = value
		AttributeTarget.SPIRITUALITY:
			character.attributes.spirituality = value
		AttributeTarget.COMPOSURE:
			character.attributes.composure = value
		AttributeTarget.PERSONALITY:
			character.attributes.personality = value
		AttributeTarget.CONSTITUTION:
			character.attributes.constitution = value


func _mutation_kind() -> int:
	match attribute_target:
		AttributeTarget.STRENGTH:
			return EffectResultType.Mutation.STRENGTH
		AttributeTarget.INTELLIGENCE:
			return EffectResultType.Mutation.INTELLIGENCE
		AttributeTarget.SPIRITUALITY:
			return EffectResultType.Mutation.SPIRITUALITY
		AttributeTarget.COMPOSURE:
			return EffectResultType.Mutation.COMPOSURE
		AttributeTarget.PERSONALITY:
			return EffectResultType.Mutation.PERSONALITY
		AttributeTarget.CONSTITUTION:
			return EffectResultType.Mutation.CONSTITUTION
	return EffectResultType.Mutation.NONE
