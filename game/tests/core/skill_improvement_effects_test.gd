extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const CharacterResourceStateScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const CharacterSkillStateScript := preload("res://core/skills/character_skill_state.gd")
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")
const SkillImprovementResultScript := preload(
	"res://core/skills/skill_improvement_result.gd"
)
const EffectResultScript := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_result.gd"
)
const EffectRegistryScript := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_registry.gd"
)
const PracticePoliciesScript := preload("res://core/training/practice_policies.gd")
const PracticeResultScript := preload("res://core/training/practice_result.gd")
const PracticeServiceScript := preload("res://core/training/practice_service.gd")
const SkillLearnPolicyRegistryScript := preload(
	"res://core/learning/skill_learn_policy_registry.gd"
)
const SelfLearningResultScript := preload("res://core/training/self_learning_result.gd")
const SelfLearningServiceScript := preload("res://core/training/self_learning_service.gd")

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_improvement_result_and_no_level_callback_boundary()
	_test_periodic_attribute_hooks_level_boundaries()
	_test_force_callback_attribute_comparison_boundary()
	_test_unarmed_callback_attribute_comparison_boundary()
	_test_periodic_effect_does_not_repeat_between_trigger_levels()
	_test_six_chaos_sword_bellicosity_boundaries()
	_test_tao_mystery_bellicosity_effect()
	_test_nine_moon_literal_id_mismatch_boundaries()
	_test_active_hook_registration_boundaries()
	_test_practice_level_up_without_authored_hook()
	_test_selflearn_reachable_force_and_unarmed_effects()
	_test_selflearn_skill_without_callback()
	_test_effect_state_is_not_shared_between_characters()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_improvement_result_and_no_level_callback_boundary() -> void:
	var character: CharacterStateScript = CharacterStateScript.new()
	character.skills.set_raw_level(SkillIdsScript.FORCE, 48)
	character.skills.set_learned_progress(SkillIdsScript.FORCE, 2400)
	character.attributes.constitution = 11
	var no_level: SkillImprovementResultScript = character.skills.improve_skill(
		SkillIdsScript.FORCE,
		1,
		30,
	)
	## feature/skill.c: learned == (48 + 1)^2 does not level.
	_assert_false(no_level.leveled_up, "exact square does not level")
	_assert_eq(no_level.previous_level, 48, "no-level previous raw")
	_assert_eq(no_level.current_level, 48, "no-level current raw")
	_assert_eq(no_level.learned_before, 2400, "no-level learned before")
	_assert_eq(no_level.learned_after, 2401, "no-level learned after")
	var registry: EffectRegistryScript = _legacy_registry()
	var skipped: EffectResultScript = registry.apply(character, no_level)
	_assert_eq(skipped.status, EffectResultScript.Status.NOT_LEVELED_UP, "callback not evaluated")
	_assert_eq(character.attributes.constitution, 11, "no level has no authored mutation")

	var level_up: SkillImprovementResultScript = character.skills.improve_skill(
		SkillIdsScript.FORCE,
		1,
		30,
	)
	_assert_true(level_up.leveled_up, "strictly above square levels")
	_assert_eq(level_up.previous_level, 48, "level-up previous raw")
	_assert_eq(level_up.current_level, 49, "level-up current raw")
	_assert_eq(level_up.learned_before, 2401, "level-up learned before")
	_assert_eq(level_up.learned_after, 0, "level-up learned reset")
	_assert_eq(character.skills.raw_level(SkillIdsScript.FORCE), 49, "raw level changed before effect")
	var force_callback: EffectResultScript = registry.apply(character, level_up)
	_assert_eq(
		force_callback.status,
		EffectResultScript.Status.APPLIED,
		"level-up evaluates the registered force callback",
	)
	_assert_eq(character.attributes.constitution, 13, "force callback executes exactly once")

	var ordinary: CharacterStateScript = CharacterStateScript.new()
	ordinary.skills.set_raw_level(SkillIdsScript.SWORD, 2)
	ordinary.skills.set_learned_progress(SkillIdsScript.SWORD, 9)
	var ordinary_level_up: SkillImprovementResultScript = ordinary.skills.improve_skill(
		SkillIdsScript.SWORD,
		1,
		30,
	)
	var empty_callback: EffectResultScript = registry.apply(ordinary, ordinary_level_up)
	_assert_eq(
		empty_callback.status,
		EffectResultScript.Status.NO_AUTHORED_EFFECT,
		"std/skill default callback has no effect",
	)


func _test_periodic_attribute_hooks_level_boundaries() -> void:
	var periodic_skills: Array[StringName] = [
		SkillIdsScript.CELESTIAL,
		SkillIdsScript.FORCE,
		SkillIdsScript.LITERATE,
		SkillIdsScript.MUSIC,
		SkillIdsScript.STORMDANCE,
		SkillIdsScript.UNARMED,
	]
	var registry: EffectRegistryScript = _legacy_registry()
	for skill_id: StringName in periodic_skills:
		for level: int in [48, 49, 50]:
			var character: CharacterStateScript = CharacterStateScript.new()
			_set_callback_attribute(character, skill_id, 0)
			var effect: EffectResultScript = registry.apply(
				character,
				_level_event(skill_id, level),
			)
			var expected_value: int = 2 if level == 49 else 0
			## Each LPC hook uses new raw level: s % 10 == 9, then adds 2.
			_assert_eq(
				_callback_attribute(character, skill_id),
				expected_value,
				"periodic level boundary %s %d" % [skill_id, level],
			)
			_assert_eq(
				effect.status,
				(
					EffectResultScript.Status.APPLIED
					if level == 49
					else EffectResultScript.Status.EVALUATED_NO_MUTATION
				),
				"periodic callback status %s %d" % [skill_id, level],
			)


func _test_force_callback_attribute_comparison_boundary() -> void:
	var registry: EffectRegistryScript = _legacy_registry()
	var below_limit: CharacterStateScript = CharacterStateScript.new()
	below_limit.attributes.constitution = 11
	var applied: EffectResultScript = registry.apply(
		below_limit,
		_level_event(SkillIdsScript.FORCE, 49),
	)
	## force.c: 49 / 4 == 12; con 11 < 12, then con += 2.
	_assert_eq(applied.status, EffectResultScript.Status.APPLIED, "force con below limit applies")
	_assert_eq(applied.previous_value, 11, "force previous con")
	_assert_eq(applied.current_value, 13, "force current con")
	_assert_eq(applied.mutation_amount, 2, "force exact attribute gain")
	_assert_eq(below_limit.attributes.constitution, 13, "force base con mutates without clamp")

	var exact_limit: CharacterStateScript = CharacterStateScript.new()
	exact_limit.attributes.constitution = 12
	var rejected: EffectResultScript = registry.apply(
		exact_limit,
		_level_event(SkillIdsScript.FORCE, 49),
	)
	_assert_eq(
		rejected.status,
		EffectResultScript.Status.EVALUATED_NO_MUTATION,
		"force con equality does not apply",
	)
	_assert_eq(exact_limit.attributes.constitution, 12, "force equality keeps con")


func _test_unarmed_callback_attribute_comparison_boundary() -> void:
	var registry: EffectRegistryScript = _legacy_registry()
	var below_limit: CharacterStateScript = CharacterStateScript.new()
	below_limit.attributes.strength = 11
	var applied: EffectResultScript = registry.apply(
		below_limit,
		_level_event(SkillIdsScript.UNARMED, 49),
	)
	## unarmed.c: 49 / 4 == 12; str 11 < 12, then str += 2.
	_assert_eq(applied.status, EffectResultScript.Status.APPLIED, "unarmed str below limit applies")
	_assert_eq(applied.previous_value, 11, "unarmed previous str")
	_assert_eq(applied.current_value, 13, "unarmed current str")
	_assert_eq(applied.mutation_amount, 2, "unarmed exact attribute gain")
	_assert_eq(below_limit.attributes.strength, 13, "unarmed base str mutates without clamp")

	var exact_limit: CharacterStateScript = CharacterStateScript.new()
	exact_limit.attributes.strength = 12
	var rejected: EffectResultScript = registry.apply(
		exact_limit,
		_level_event(SkillIdsScript.UNARMED, 49),
	)
	_assert_eq(
		rejected.status,
		EffectResultScript.Status.EVALUATED_NO_MUTATION,
		"unarmed str equality does not apply",
	)
	_assert_eq(exact_limit.attributes.strength, 12, "unarmed equality keeps str")


func _test_periodic_effect_does_not_repeat_between_trigger_levels() -> void:
	var character: CharacterStateScript = CharacterStateScript.new()
	character.attributes.constitution = 11
	var registry: EffectRegistryScript = _legacy_registry()
	registry.apply(character, _level_event(SkillIdsScript.FORCE, 49))
	_assert_eq(character.attributes.constitution, 13, "force level 49 applies once")
	var next_level: EffectResultScript = registry.apply(
		character,
		_level_event(SkillIdsScript.FORCE, 50),
	)
	_assert_eq(
		next_level.status,
		EffectResultScript.Status.EVALUATED_NO_MUTATION,
		"force level 50 does not repeat level 49 effect",
	)
	_assert_eq(character.attributes.constitution, 13, "force non-trigger level keeps base con")
	registry.apply(character, _level_event(SkillIdsScript.FORCE, 59))
	## force.c permits the effect again at a later ...9 level: 13 < 59 / 4 == 14.
	_assert_eq(character.attributes.constitution, 15, "force later valid trigger applies again")


func _test_six_chaos_sword_bellicosity_boundaries() -> void:
	var registry: EffectRegistryScript = _legacy_registry()
	for level: int in [49, 50, 51]:
		var character: CharacterStateScript = CharacterStateScript.new()
		character.attributes.bellicosity = 7
		var result: EffectResultScript = registry.apply(
			character,
			_level_event(SkillIdsScript.SIX_CHAOS_SWORD, level),
		)
		var expected_gain: int = 1000 if level == 50 else 100
		## six-chaos-sword.c checks the new raw level modulo 10.
		_assert_eq(result.status, EffectResultScript.Status.APPLIED, "six-chaos callback applies")
		_assert_eq(result.mutation_amount, expected_gain, "six-chaos level-dependent gain")
		_assert_eq(character.attributes.bellicosity, 7 + expected_gain, "six-chaos bellicosity")


func _test_tao_mystery_bellicosity_effect() -> void:
	var character: CharacterStateScript = CharacterStateScript.new()
	character.attributes.bellicosity = -25
	var result: EffectResultScript = _legacy_registry().apply(
		character,
		_level_event(SkillIdsScript.TAO_MYSTERY, 17),
	)
	## tao-mystery.c unconditionally adds 100 and supplies no clamp.
	_assert_eq(result.status, EffectResultScript.Status.APPLIED, "tao-mystery callback applies")
	_assert_eq(result.mutation_amount, 100, "tao-mystery exact gain")
	_assert_eq(character.attributes.bellicosity, 75, "tao-mystery preserves add semantics")


func _test_nine_moon_literal_id_mismatch_boundaries() -> void:
	var registry: EffectRegistryScript = _legacy_registry()
	for queried_level: int in [9, 10, 11]:
		var character: CharacterStateScript = CharacterStateScript.new()
		character.skills.set_raw_level(SkillIdsScript.NINE_MOON_SWORD, queried_level)
		character.attributes.bellicosity = 50
		var result: EffectResultScript = registry.apply(
			character,
			_level_event(SkillIdsScript.NINE_MOON, 37),
		)
		var expected_gain: int = 2000 if queried_level == 10 else 200
		_assert_eq(result.status, EffectResultScript.Status.APPLIED, "nine-moon applies literally")
		_assert_eq(result.mutation_amount, expected_gain, "nine-moon queried level boundary")
		_assert_eq(character.attributes.bellicosity, 50 + expected_gain, "nine-moon gain")

	var missing_skill: CharacterStateScript = CharacterStateScript.new()
	var missing_result: EffectResultScript = registry.apply(
		missing_skill,
		_level_event(SkillIdsScript.NINE_MOON, 37),
	)
	## feature/skill.c raw query returns zero for a missing skill; 0 % 10 == 0.
	_assert_eq(missing_result.mutation_amount, 2000, "nine-moon missing raw skill legacy defect")
	_assert_eq(missing_skill.attributes.bellicosity, 2000, "nine-moon missing raw adds 2000")


func _test_active_hook_registration_boundaries() -> void:
	var registry: EffectRegistryScript = _legacy_registry()
	var active_hook_ids: Array[StringName] = [
		SkillIdsScript.CELESTIAL,
		SkillIdsScript.FORCE,
		SkillIdsScript.LITERATE,
		SkillIdsScript.MUSIC,
		SkillIdsScript.NINE_MOON,
		SkillIdsScript.SIX_CHAOS_SWORD,
		SkillIdsScript.STORMDANCE,
		SkillIdsScript.TAO_MYSTERY,
		SkillIdsScript.UNARMED,
	]
	for skill_id: StringName in active_hook_ids:
		_assert_true(registry.has_effect(skill_id), "active daemon hook registered " + str(skill_id))

	var inherited_no_op_ids: Array[StringName] = [
		SkillIdsScript.DODGE,
		SkillIdsScript.SWORD,
		SkillIdsScript.BLADE,
		SkillIdsScript.STAFF,
		SkillIdsScript.PARRY,
		SkillIdsScript.FALL_STEPS,
		SkillIdsScript.FONXAN_FORCE,
		SkillIdsScript.NINE_MOON_SWORD,
	]
	for skill_id: StringName in inherited_no_op_ids:
		_assert_false(registry.has_effect(skill_id), "no invented active hook " + str(skill_id))


func _test_practice_level_up_without_authored_hook() -> void:
	var character: CharacterStateScript = _base_training_character()
	character.skills.set_raw_level(SkillIdsScript.DODGE, 10)
	character.skills.set_raw_level(SkillIdsScript.FALL_STEPS, 1)
	character.skills.set_learned_progress(SkillIdsScript.FALL_STEPS, 2)
	character.skills.map_skill(SkillIdsScript.DODGE, SkillIdsScript.FALL_STEPS)
	character.recovery.inner_force.current = 10
	character.recovery.inner_force.maximum = 50
	var learn_policies: SkillLearnPolicyRegistryScript = SkillLearnPolicyRegistryScript.new()
	learn_policies.register_known_legacy_policies()
	var result: PracticeResultScript = PracticeServiceScript.practice(
		character,
		SkillIdsScript.DODGE,
		PracticePoliciesScript.create_fall_steps(),
		learn_policies.policy_for(SkillIdsScript.FALL_STEPS),
		false,
	)
	_assert_eq(result.completion, PracticeResultScript.Completion.LEVEL_INCREASED, "practice levels")
	_assert_true(result.skill_improvement.leveled_up, "practice exposes level event")
	_assert_eq(result.skill_improvement.previous_level, 1, "practice previous level")
	_assert_eq(result.skill_improvement.current_level, 2, "practice current level")
	_assert_eq(
		result.authored_effect.status,
		EffectResultScript.Status.NO_AUTHORED_EFFECT,
		"fall-steps inherits empty std/skill callback",
	)


func _test_selflearn_reachable_force_and_unarmed_effects() -> void:
	for skill_id: StringName in [SkillIdsScript.FORCE, SkillIdsScript.UNARMED]:
		var character: CharacterStateScript = _selflearn_level_48_character(skill_id)
		_set_callback_attribute(character, skill_id, 11)
		var result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
			character,
			skill_id,
			false,
			1,
		)
		_assert_eq(
			result.completion,
			SelfLearningResultScript.Completion.LEVEL_INCREASED,
			"selflearn reaches callback " + str(skill_id),
		)
		_assert_eq(result.skill_improvement.previous_level, 48, "selflearn previous level")
		_assert_eq(result.skill_improvement.current_level, 49, "selflearn new level")
		_assert_eq(result.authored_effect.status, EffectResultScript.Status.APPLIED, "selflearn effect")
		_assert_eq(_callback_attribute(character, skill_id), 13, "selflearn callback executes once")
		_assert_eq(character.essence.current, 70, "selflearn resource order remains intact")


func _test_selflearn_skill_without_callback() -> void:
	var character: CharacterStateScript = _selflearn_level_48_character(SkillIdsScript.SWORD)
	var result: SelfLearningResultScript = SelfLearningServiceScript.self_learn(
		character,
		SkillIdsScript.SWORD,
		false,
		1,
	)
	_assert_eq(
		result.completion,
		SelfLearningResultScript.Completion.LEVEL_INCREASED,
		"selflearn no-hook skill still levels",
	)
	_assert_eq(character.skills.raw_level(SkillIdsScript.SWORD), 49, "selflearn sword raw level")
	_assert_eq(result.skill_improvement.learned_before, 2401, "selflearn sword learned before")
	_assert_eq(result.skill_improvement.learned_after, 0, "selflearn sword learned reset")
	_assert_eq(
		result.authored_effect.status,
		EffectResultScript.Status.NO_AUTHORED_EFFECT,
		"selflearn sword uses std/skill no-op callback",
	)
	_assert_eq(character.progression.potential_spent, 1, "selflearn sword spends potential")
	_assert_eq(character.essence.current, 70, "selflearn sword spends gin")


func _test_effect_state_is_not_shared_between_characters() -> void:
	var registry: EffectRegistryScript = _legacy_registry()
	var first: CharacterStateScript = CharacterStateScript.new()
	var second: CharacterStateScript = CharacterStateScript.new()
	var event: SkillImprovementResultScript = _level_event(SkillIdsScript.UNARMED, 49)
	var first_result: EffectResultScript = registry.apply(first, event)
	_assert_eq(first.attributes.strength, 2, "first character receives effect")
	_assert_eq(second.attributes.strength, 0, "second character remains independent")
	var second_result: EffectResultScript = registry.apply(second, event)
	_assert_eq(first.attributes.strength, 2, "second effect does not repeat on first")
	_assert_eq(second.attributes.strength, 2, "second character receives own effect")
	_assert_true(first_result != second_result, "effect results are not shared")

	var first_skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	var second_skills: CharacterSkillStateScript = CharacterSkillStateScript.new()
	first_skills.set_raw_level(SkillIdsScript.SWORD, 2)
	second_skills.set_raw_level(SkillIdsScript.SWORD, 2)
	first_skills.set_learned_progress(SkillIdsScript.SWORD, 9)
	second_skills.set_learned_progress(SkillIdsScript.SWORD, 9)
	var first_improvement: SkillImprovementResultScript = first_skills.improve_skill(
		SkillIdsScript.SWORD,
		1,
		30,
	)
	var second_improvement: SkillImprovementResultScript = second_skills.improve_skill(
		SkillIdsScript.SWORD,
		1,
		30,
	)
	_assert_true(first_improvement != second_improvement, "improvement results are not shared")


func _level_event(skill_id: StringName, current_level: int) -> SkillImprovementResultScript:
	return SkillImprovementResultScript.new(
		skill_id,
		current_level - 1,
		current_level,
		true,
		0,
		0,
	)


func _legacy_registry() -> EffectRegistryScript:
	var registry: EffectRegistryScript = EffectRegistryScript.new()
	registry.register_legacy_defaults()
	return registry


func _base_training_character() -> CharacterStateScript:
	var character: CharacterStateScript = CharacterStateScript.new()
	_set_primary(character.essence, 100)
	_set_primary(character.vitality, 100)
	_set_primary(character.spirit, 100)
	character.attributes.intelligence = 10
	character.attributes.spirituality = 10
	character.progression.potential = 100
	return character


func _selflearn_level_48_character(skill_id: StringName) -> CharacterStateScript:
	var character: CharacterStateScript = _base_training_character()
	character.skills.set_raw_level(skill_id, 48)
	## (48 + 1)^2 == 2401; 2401 + roll 1 crosses the strict threshold.
	character.skills.set_learned_progress(skill_id, 2401)
	## 48^3 / 10 == 11059, and equality is sufficient.
	character.progression.combat_experience = 11_059
	return character


func _set_primary(resource: CharacterResourceStateScript, value: int) -> void:
	resource.maximum = 100
	resource.effective = 100
	resource.current = value


func _set_callback_attribute(
	character: CharacterStateScript,
	skill_id: StringName,
	value: int,
) -> void:
	match skill_id:
		SkillIdsScript.CELESTIAL:
			character.attributes.composure = value
		SkillIdsScript.FORCE:
			character.attributes.constitution = value
		SkillIdsScript.LITERATE:
			character.attributes.intelligence = value
		SkillIdsScript.MUSIC:
			character.attributes.spirituality = value
		SkillIdsScript.STORMDANCE:
			character.attributes.personality = value
		SkillIdsScript.UNARMED:
			character.attributes.strength = value


func _callback_attribute(character: CharacterStateScript, skill_id: StringName) -> int:
	match skill_id:
		SkillIdsScript.CELESTIAL:
			return character.attributes.composure
		SkillIdsScript.FORCE:
			return character.attributes.constitution
		SkillIdsScript.LITERATE:
			return character.attributes.intelligence
		SkillIdsScript.MUSIC:
			return character.attributes.spirituality
		SkillIdsScript.STORMDANCE:
			return character.attributes.personality
		SkillIdsScript.UNARMED:
			return character.attributes.strength
	return 0


func _assert_true(condition: bool, label: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(label + ": expected true")


func _assert_false(condition: bool, label: String) -> void:
	_assertion_count += 1
	if condition:
		_failures.append(label + ": expected false")


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
