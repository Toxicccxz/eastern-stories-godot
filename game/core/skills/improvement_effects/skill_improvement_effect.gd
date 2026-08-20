class_name SkillImprovementEffect
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const SkillImprovementResultType := preload(
	"res://core/skills/skill_improvement_result.gd"
)
const EffectResultType := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_result.gd"
)

var skill_id: StringName


func _init(p_skill_id: StringName = &"") -> void:
	skill_id = p_skill_id


func apply(
	_character: CharacterStateType,
	improvement: SkillImprovementResultType,
) -> EffectResultType:
	return EffectResultType.new(
		improvement.skill_id,
		EffectResultType.Status.EVALUATED_NO_MUTATION,
	)
