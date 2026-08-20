class_name SelfLearningService
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const SkillIdsType := preload("res://core/skills/skill_ids.gd")
const SelfLearningResultType := preload("res://core/training/self_learning_result.gd")
const SkillImprovementResultType := preload(
	"res://core/skills/skill_improvement_result.gd"
)
const EffectRegistryType := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_registry.gd"
)
const EffectResultType := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_result.gd"
)

const MINIMUM_RAW_SKILL_LEVEL: int = 40
const ESSENCE_COST_NUMERATOR: int = 300
const COMBAT_EXPERIENCE_DIVISOR: int = 10


## Deterministic translation of cmds/std/selflearn.c. improvement_roll is the
## externally supplied result of legacy random(base_intelligence + raw_level).
static func self_learn(
	character: CharacterStateType,
	skill_id: StringName,
	is_fighting: bool,
	improvement_roll: int,
	effect_registry: EffectRegistryType = null,
) -> SelfLearningResultType:
	if not _is_self_learnable(skill_id):
		return _failure(SelfLearningResultType.FailureReason.SKILL_NOT_SELF_LEARNABLE, skill_id)
	if is_fighting:
		return _failure(SelfLearningResultType.FailureReason.IN_COMBAT, skill_id)

	var level: int = character.skills.raw_level(skill_id)
	if level < MINIMUM_RAW_SKILL_LEVEL:
		return _failure(SelfLearningResultType.FailureReason.RAW_SKILL_BELOW_MINIMUM, skill_id)

	var base_intelligence: int = character.attributes.intelligence
	if base_intelligence <= 0:
		return _failure(
			SelfLearningResultType.FailureReason.LEGACY_NON_POSITIVE_INTELLIGENCE,
			skill_id,
		)
	@warning_ignore("integer_division")
	var essence_cost: int = ESSENCE_COST_NUMERATOR / base_intelligence

	if character.progression.potential_spent >= character.progression.potential:
		return _failure(SelfLearningResultType.FailureReason.POTENTIAL_EXHAUSTED, skill_id)

	var learned_before: int = character.skills.learned_progress(skill_id)
	var potential_spent_before: int = character.progression.potential_spent
	if character.essence.current <= essence_cost:
		var essence_spent: int = character.essence.current
		character.essence.apply_damage(essence_spent)
		return SelfLearningResultType.new(
			true,
			SelfLearningResultType.FailureReason.NONE,
			SelfLearningResultType.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE,
			skill_id,
			level,
			character.skills.raw_level(skill_id),
			essence_cost,
			essence_spent,
			improvement_roll,
			base_intelligence + level,
			learned_before,
			character.skills.learned_progress(skill_id),
			potential_spent_before,
			character.progression.potential_spent,
		)

	@warning_ignore("integer_division")
	var required_combat_experience: int = level * level * level / COMBAT_EXPERIENCE_DIVISOR
	if required_combat_experience > character.progression.combat_experience:
		character.essence.apply_damage(essence_cost)
		return SelfLearningResultType.new(
			true,
			SelfLearningResultType.FailureReason.NONE,
			SelfLearningResultType.Completion.NO_PROGRESS_COMBAT_EXPERIENCE,
			skill_id,
			level,
			character.skills.raw_level(skill_id),
			essence_cost,
			essence_cost,
			improvement_roll,
			base_intelligence + level,
			learned_before,
			character.skills.learned_progress(skill_id),
			potential_spent_before,
			character.progression.potential_spent,
		)

	var improvement_roll_upper_bound: int = base_intelligence + level
	if improvement_roll < 0 or improvement_roll >= improvement_roll_upper_bound:
		return _failure(
			SelfLearningResultType.FailureReason.INVALID_IMPROVEMENT_ROLL,
			skill_id,
		)

	character.progression.potential_spent += 1
	var improvement: SkillImprovementResultType = character.skills.improve_skill(
		skill_id,
		improvement_roll,
		character.attributes.spirituality,
	)
	var registry: EffectRegistryType = effect_registry
	if registry == null:
		registry = EffectRegistryType.new()
		registry.register_legacy_defaults()
	var authored_effect: EffectResultType = registry.apply(character, improvement)
	character.essence.apply_damage(essence_cost)
	return SelfLearningResultType.new(
		true,
		SelfLearningResultType.FailureReason.NONE,
		(
			SelfLearningResultType.Completion.LEVEL_INCREASED
			if improvement.leveled_up
			else SelfLearningResultType.Completion.PROGRESSED
		),
		skill_id,
		level,
		character.skills.raw_level(skill_id),
		essence_cost,
		essence_cost,
		improvement_roll,
		improvement_roll_upper_bound,
		learned_before,
		character.skills.learned_progress(skill_id),
		potential_spent_before,
		character.progression.potential_spent,
		improvement,
		authored_effect,
	)


static func _is_self_learnable(skill_id: StringName) -> bool:
	return (
		skill_id == SkillIdsType.DODGE
		or skill_id == SkillIdsType.FORCE
		or skill_id == SkillIdsType.SWORD
		or skill_id == SkillIdsType.BLADE
		or skill_id == SkillIdsType.STAFF
		or skill_id == SkillIdsType.PARRY
		or skill_id == SkillIdsType.UNARMED
	)


static func _failure(reason: int, skill_id: StringName) -> SelfLearningResultType:
	return SelfLearningResultType.new(false, reason, SelfLearningResultType.Completion.NONE, skill_id)
