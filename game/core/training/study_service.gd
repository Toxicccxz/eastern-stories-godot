class_name StudyService
extends RefCounted

## cmds/std/study.c: reading an item that carries set("skill", ...). Unlike learn.c it
## spends no potential. The message to the room (X正专心地研读Y。) is for others only.

const COST_DIVISOR: int = 20
const LITERATE_DIVISOR: int = 5


static func study(
	character: CharacterState,
	material: StudyMaterial,
	skill_learn_policy: SkillLearnPolicy,
	is_fighting: bool,
	effect_registry: SkillImprovementEffectRegistry = null,
) -> StudyResult:
	if is_fighting:
		return StudyResult.new(StudyResult.Outcome.IN_COMBAT)
	if material == null:
		return StudyResult.new(StudyResult.Outcome.NOTHING_TO_LEARN)
	var result := StudyResult.new(StudyResult.Outcome.STUDIED, material.skill_id)
	var literate: int = character.skills.raw_level(SkillIds.LITERATE)
	if literate == 0:
		result.outcome = StudyResult.Outcome.ILLITERATE
		return result
	if character.progression.combat_experience < material.exp_required:
		result.outcome = StudyResult.Outcome.COMBAT_EXPERIENCE_TOO_LOW
		return result
	if skill_learn_policy == null or skill_learn_policy.skill_id != material.skill_id:
		result.outcome = StudyResult.Outcome.VALID_LEARN_UNAVAILABLE
		return result
	result.skill_learn_policy_result = skill_learn_policy.evaluate(character)
	match result.skill_learn_policy_result.status:
		SkillLearnPolicyResult.Status.REJECTED:
			result.outcome = StudyResult.Outcome.VALID_LEARN_REJECTED
			return result
		SkillLearnPolicyResult.Status.DEPENDENCY_UNAVAILABLE:
			result.outcome = StudyResult.Outcome.VALID_LEARN_UNAVAILABLE
			return result
	# sen_cost + sen_cost * (difficulty - int) / 20, C division.
	@warning_ignore("integer_division")
	result.sen_cost = material.sen_cost + material.sen_cost * (material.difficulty - character.attributes.intelligence) / COST_DIVISOR
	if character.spirit.current < result.sen_cost:
		result.outcome = StudyResult.Outcome.TOO_TIRED
		return result
	if character.skills.raw_level(material.skill_id) > material.max_skill:
		result.outcome = StudyResult.Outcome.TOO_SHALLOW
		return result
	if result.sen_cost < 0:
		result.outcome = StudyResult.Outcome.LEGACY_NEGATIVE_COST
		return result
	character.spirit.apply_damage(result.sen_cost)
	if character.skills.raw_level(material.skill_id) == 0:
		character.skills.set_raw_level(material.skill_id, 0)
	@warning_ignore("integer_division")
	result.skill_improvement = character.skills.improve_skill(
		material.skill_id, literate / LITERATE_DIVISOR + 1, character.attributes.spirituality,
	)
	var registry: SkillImprovementEffectRegistry = effect_registry
	if registry == null:
		registry = SkillImprovementEffectRegistry.new()
		registry.register_legacy_defaults()
	result.authored_effect = registry.apply(character, result.skill_improvement)
	return result
