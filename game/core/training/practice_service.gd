class_name PracticeService
extends RefCounted

const CharacterStateType := preload("res://core/characters/character_state.gd")
const PracticePolicyType := preload("res://core/training/practice_policy.gd")
const PracticeResultType := preload("res://core/training/practice_result.gd")
const SkillImprovementResultType := preload(
	"res://core/skills/skill_improvement_result.gd"
)
const EffectRegistryType := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_registry.gd"
)
const EffectResultType := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_result.gd"
)


## Deterministic translation of cmds/std/practice.c after text parsing.
static func practice(
	character: CharacterStateType,
	basic_skill_id: StringName,
	policy: PracticePolicyType,
	is_fighting: bool,
	is_player_character: bool = true,
	effect_registry: EffectRegistryType = null,
) -> PracticeResultType:
	if is_fighting:
		return _failure(PracticeResultType.FailureReason.IN_COMBAT, basic_skill_id)

	var special_skill_id: StringName = character.skills.mapped_skill(basic_skill_id)
	if special_skill_id == &"":
		return _failure(PracticeResultType.FailureReason.SKILL_NOT_MAPPED, basic_skill_id)

	var special_level: int = character.skills.raw_level(special_skill_id)
	var basic_level: int = character.skills.raw_level(basic_skill_id)
	if special_level < 1:
		return _failure(
			PracticeResultType.FailureReason.SPECIAL_SKILL_NOT_LEARNED,
			basic_skill_id,
			special_skill_id,
		)
	if basic_level < 1:
		return _failure(
			PracticeResultType.FailureReason.BASIC_SKILL_NOT_LEARNED,
			basic_skill_id,
			special_skill_id,
		)
	if policy == null:
		return _failure(
			PracticeResultType.FailureReason.POLICY_NOT_AVAILABLE,
			basic_skill_id,
			special_skill_id,
		)
	if policy.skill_id != special_skill_id:
		return _failure(
			PracticeResultType.FailureReason.POLICY_SKILL_MISMATCH,
			basic_skill_id,
			special_skill_id,
		)
	if not policy.valid_learn(character):
		return _failure(
			PracticeResultType.FailureReason.VALID_LEARN_REJECTED,
			basic_skill_id,
			special_skill_id,
		)

	var learned_before: int = character.skills.learned_progress(special_skill_id)
	if not policy.practice(character):
		return PracticeResultType.new(
			false,
			PracticeResultType.FailureReason.PRACTICE_HOOK_REJECTED,
			PracticeResultType.Completion.NO_PROGRESS,
			basic_skill_id,
			special_skill_id,
			basic_level,
			special_level,
			character.skills.raw_level(special_skill_id),
			0,
			false,
			learned_before,
			character.skills.learned_progress(special_skill_id),
		)

	@warning_ignore("integer_division")
	var improvement_amount: int = basic_level / 5 + 1
	var weak_mode: bool = basic_level <= special_level
	var improvement: SkillImprovementResultType = character.skills.improve_skill(
		special_skill_id,
		improvement_amount,
		character.attributes.spirituality,
		weak_mode,
		is_player_character,
	)
	var registry: EffectRegistryType = effect_registry
	if registry == null:
		registry = EffectRegistryType.new()
		registry.register_legacy_defaults()
	var authored_effect: EffectResultType = registry.apply(character, improvement)
	return PracticeResultType.new(
		true,
		PracticeResultType.FailureReason.NONE,
		(
			PracticeResultType.Completion.LEVEL_INCREASED
			if improvement.leveled_up
			else PracticeResultType.Completion.PROGRESSED
		),
		basic_skill_id,
		special_skill_id,
		basic_level,
		special_level,
		character.skills.raw_level(special_skill_id),
		improvement_amount,
		weak_mode,
		learned_before,
		character.skills.learned_progress(special_skill_id),
		improvement,
		authored_effect,
	)


static func _failure(
	reason: int,
	basic_skill_id: StringName,
	special_skill_id: StringName = &"",
) -> PracticeResultType:
	return PracticeResultType.new(
		false,
		reason,
		PracticeResultType.Completion.NONE,
		basic_skill_id,
		special_skill_id,
	)
