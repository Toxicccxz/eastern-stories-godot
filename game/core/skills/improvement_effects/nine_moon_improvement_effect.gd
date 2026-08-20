class_name NineMoonImprovementEffect
extends "res://core/skills/improvement_effects/skill_improvement_effect.gd"

const SkillIdsType := preload("res://core/skills/skill_ids.gd")

const NORMAL_BELLICOSITY_GAIN: int = 200
const TENTH_LEVEL_BELLICOSITY_GAIN: int = 2000


func apply(
	character: CharacterStateType,
	improvement: SkillImprovementResultType,
) -> EffectResultType:
	## Legacy defect preserved literally: daemon/skill/nine-moon.c is invoked for
	## "nine-moon", but its callback reads raw "nine-moon-sword". Missing raw
	## skills read as zero, and zero satisfies the modulo-ten branch.
	var queried_level: int = character.skills.raw_level(SkillIdsType.NINE_MOON_SWORD)
	var gain: int = NORMAL_BELLICOSITY_GAIN
	if queried_level % 10 == 0:
		gain = TENTH_LEVEL_BELLICOSITY_GAIN
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
