class_name SkillImprovementEffectRegistry
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const SkillIdsType := preload("res://core/skills/skill_ids.gd")
const SkillImprovementResultType := preload(
	"res://core/skills/skill_improvement_result.gd"
)
const EffectType := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect.gd"
)
const EffectResultType := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_result.gd"
)
const PeriodicAttributeEffectType := preload(
	"res://core/skills/improvement_effects/periodic_attribute_improvement_effect.gd"
)
const BellicosityEffectType := preload(
	"res://core/skills/improvement_effects/bellicosity_improvement_effect.gd"
)
const NineMoonEffectType := preload(
	"res://core/skills/improvement_effects/nine_moon_improvement_effect.gd"
)

var _effects: Dictionary[StringName, EffectType] = {}


func register_effect(effect: EffectType) -> void:
	_effects[effect.skill_id] = effect


func has_effect(skill_id: StringName) -> bool:
	return _effects.has(skill_id)


func apply(
	character: CharacterStateType,
	improvement: SkillImprovementResultType,
) -> EffectResultType:
	if not improvement.leveled_up:
		return EffectResultType.new(
			improvement.skill_id,
			EffectResultType.Status.NOT_LEVELED_UP,
		)
	if not _effects.has(improvement.skill_id):
		return EffectResultType.new(
			improvement.skill_id,
			EffectResultType.Status.NO_AUTHORED_EFFECT,
		)
	return _effects[improvement.skill_id].apply(character, improvement)


func register_legacy_defaults() -> void:
	_effects.clear()
	register_effect(
		PeriodicAttributeEffectType.new(
			SkillIdsType.CELESTIAL,
			PeriodicAttributeEffectType.AttributeTarget.COMPOSURE,
		)
	)
	register_effect(
		PeriodicAttributeEffectType.new(
			SkillIdsType.FORCE,
			PeriodicAttributeEffectType.AttributeTarget.CONSTITUTION,
		)
	)
	register_effect(
		PeriodicAttributeEffectType.new(
			SkillIdsType.LITERATE,
			PeriodicAttributeEffectType.AttributeTarget.INTELLIGENCE,
		)
	)
	register_effect(
		PeriodicAttributeEffectType.new(
			SkillIdsType.MUSIC,
			PeriodicAttributeEffectType.AttributeTarget.SPIRITUALITY,
		)
	)
	register_effect(
		BellicosityEffectType.new(SkillIdsType.SIX_CHAOS_SWORD, 100, 1000, 10, 0)
	)
	register_effect(
		PeriodicAttributeEffectType.new(
			SkillIdsType.STORMDANCE,
			PeriodicAttributeEffectType.AttributeTarget.PERSONALITY,
		)
	)
	register_effect(
		BellicosityEffectType.new(SkillIdsType.TAO_MYSTERY, 100)
	)
	register_effect(
		PeriodicAttributeEffectType.new(
			SkillIdsType.UNARMED,
			PeriodicAttributeEffectType.AttributeTarget.STRENGTH,
		)
	)
	register_effect(NineMoonEffectType.new(SkillIdsType.NINE_MOON))
