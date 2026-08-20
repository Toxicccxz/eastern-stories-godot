extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const CharacterResourceStateScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const SkillIdsScript := preload("res://core/skills/skill_ids.gd")
const CultivationResultScript := preload("res://core/cultivation/cultivation_result.gd")
const CultivationServiceScript := preload("res://core/cultivation/cultivation_service.gd")

const TEST_SPELLS_SCHOOL: StringName = &"test-spells-school"
const TEST_MAGIC_SCHOOL: StringName = &"test-magic-school"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_exercise_normal_formula_and_skill_sources()
	_test_meditate_normal_formula_and_skill_sources()
	_test_respirate_normal_formula_and_skill_sources()
	_test_gain_thresholds_for_all_actions()
	_test_exercise_validation_order_and_cost_boundaries()
	_test_meditate_validation_order_and_cost_boundaries()
	_test_respirate_validation_order_and_cost_boundaries()
	_test_exercise_health_percentage_boundaries()
	_test_meditate_health_percentage_boundaries()
	_test_respirate_health_percentage_boundaries()
	_test_exercise_internal_maximum_boundaries()
	_test_meditate_internal_maximum_boundaries()
	_test_respirate_internal_maximum_boundaries()
	_test_skill_cap_boundaries_for_all_actions()
	_test_maximum_caps_use_exact_skill_query_types()
	_test_no_gain_still_consumes_source_and_skips_overflow_handling()
	_test_negative_legacy_values_are_not_normalized()
	_test_zero_health_maximum_reports_legacy_division_failure()
	_test_independent_character_states_for_all_actions()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_exercise_normal_formula_and_skill_sources() -> void:
	var character: CharacterStateScript = _base_character()
	character.attributes.constitution = 10
	character.attributes.constitution_modifier = 100
	character.skills.set_raw_level(SkillIdsScript.FORCE, 20)
	character.skills.set_raw_level(SkillIdsScript.FONXAN_FORCE, 30)
	character.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.FONXAN_FORCE)
	character.recovery.inner_force.current = 50
	character.recovery.inner_force.maximum = 100

	## exercise.c: 30 * (raw force 20 + base con 10) / 300 = 3.
	var result: CultivationResultScript = CultivationServiceScript.exercise(
		character,
		30,
		false,
		5,
	)
	_assert_true(result.success, "exercise succeeds")
	_assert_eq(result.action, CultivationResultScript.Action.EXERCISE, "exercise action")
	_assert_eq(result.completion, CultivationResultScript.Completion.GAINED, "exercise gained")
	_assert_eq(result.calculated_gain, 3, "exercise uses raw force and base constitution")
	_assert_eq(character.vitality.current, 70, "exercise spends kee")
	_assert_eq(character.recovery.inner_force.current, 53, "exercise increases force")
	_assert_eq(character.recovery.inner_force.maximum, 100, "normal exercise keeps maximum")
	_assert_eq(character.skills.learned_progress(SkillIdsScript.FORCE), 0, "exercise does not improve skill")


func _test_meditate_normal_formula_and_skill_sources() -> void:
	var character: CharacterStateScript = _base_character()
	character.attributes.spirituality = 15
	character.attributes.spirituality_modifier = 100
	character.skills.set_raw_level(SkillIdsScript.SPELLS, 20)
	character.skills.set_raw_level(TEST_SPELLS_SCHOOL, 30)
	character.skills.map_skill(SkillIdsScript.SPELLS, TEST_SPELLS_SCHOOL)
	character.recovery.mana.current = 50
	character.recovery.mana.maximum = 100

	## effective spells = temp 5 + raw 20 / 2 + mapped 30 = 45;
	## meditate.c: 30 * (45 + base spi 15) / 300 = 6.
	var result: CultivationResultScript = CultivationServiceScript.meditate(
		character,
		30,
		false,
		5,
	)
	_assert_true(result.success, "meditate succeeds")
	_assert_eq(result.action, CultivationResultScript.Action.MEDITATE, "meditate action")
	_assert_eq(result.calculated_gain, 6, "meditate uses effective spells and base spirituality")
	_assert_eq(character.spirit.current, 70, "meditate spends sen")
	_assert_eq(character.recovery.mana.current, 56, "meditate increases mana")
	_assert_eq(character.recovery.mana.maximum, 100, "normal meditate keeps maximum")
	_assert_eq(character.skills.learned_progress(SkillIdsScript.SPELLS), 0, "meditate does not improve skill")


func _test_respirate_normal_formula_and_skill_sources() -> void:
	var character: CharacterStateScript = _base_character()
	character.attributes.spirituality = 15
	character.attributes.spirituality_modifier = 100
	character.skills.set_raw_level(SkillIdsScript.MAGIC, 20)
	character.skills.set_raw_level(TEST_MAGIC_SCHOOL, 30)
	character.skills.map_skill(SkillIdsScript.MAGIC, TEST_MAGIC_SCHOOL)
	character.recovery.atman.current = 50
	character.recovery.atman.maximum = 100

	## effective magic = temp 5 + raw 20 / 2 + mapped 30 = 45;
	## respirate.c: 30 * (45 + base spi 15) / 300 = 6.
	var result: CultivationResultScript = CultivationServiceScript.respirate(
		character,
		30,
		false,
		5,
	)
	_assert_true(result.success, "respirate succeeds")
	_assert_eq(result.action, CultivationResultScript.Action.RESPIRATE, "respirate action")
	_assert_eq(result.calculated_gain, 6, "respirate uses effective magic and base spirituality")
	_assert_eq(character.essence.current, 70, "respirate spends gin")
	_assert_eq(character.recovery.atman.current, 56, "respirate increases atman")
	_assert_eq(character.recovery.atman.maximum, 100, "normal respirate keeps maximum")
	_assert_eq(character.skills.learned_progress(SkillIdsScript.MAGIC), 0, "respirate does not improve skill")


func _test_gain_thresholds_for_all_actions() -> void:
	## exercise.c with cost 10 and base con 10: totals 29, 30, 31 produce 0, 1, 1.
	var exercise_cases: Array[Array] = [[19, 0], [20, 1], [21, 1]]
	for test_case: Array in exercise_cases:
		var exercise_character: CharacterStateScript = _base_character()
		exercise_character.attributes.constitution = 10
		exercise_character.skills.set_raw_level(SkillIdsScript.FORCE, test_case[0])
		exercise_character.skills.set_raw_level(SkillIdsScript.FONXAN_FORCE, 0)
		exercise_character.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.FONXAN_FORCE)
		exercise_character.recovery.inner_force.current = 0
		exercise_character.recovery.inner_force.maximum = 100
		var exercise_result: CultivationResultScript = CultivationServiceScript.exercise(
			exercise_character,
			10,
			false,
		)
		_assert_eq(exercise_result.calculated_gain, test_case[1], "exercise gain threshold")
		_assert_eq(exercise_character.recovery.inner_force.current, test_case[1], "exercise threshold current")

	## effective spells/magic are raw / 2 here; raw 38, 40, 42 plus spi 10
	## therefore produce formula totals 29, 30, 31 respectively.
	var effective_cases: Array[Array] = [[38, 0], [40, 1], [42, 1]]
	for test_case: Array in effective_cases:
		var meditate_character: CharacterStateScript = _base_character()
		meditate_character.attributes.spirituality = 10
		meditate_character.skills.set_raw_level(SkillIdsScript.SPELLS, test_case[0])
		meditate_character.recovery.mana.current = 0
		meditate_character.recovery.mana.maximum = 100
		var meditate_result: CultivationResultScript = CultivationServiceScript.meditate(
			meditate_character,
			10,
			false,
		)
		_assert_eq(meditate_result.calculated_gain, test_case[1], "meditate gain threshold")
		_assert_eq(meditate_character.recovery.mana.current, test_case[1], "meditate threshold current")

		var respirate_character: CharacterStateScript = _base_character()
		respirate_character.attributes.spirituality = 10
		respirate_character.skills.set_raw_level(SkillIdsScript.MAGIC, test_case[0])
		respirate_character.recovery.atman.current = 0
		respirate_character.recovery.atman.maximum = 100
		var respirate_result: CultivationResultScript = CultivationServiceScript.respirate(
			respirate_character,
			10,
			false,
		)
		_assert_eq(respirate_result.calculated_gain, test_case[1], "respirate gain threshold")
		_assert_eq(respirate_character.recovery.atman.current, test_case[1], "respirate threshold current")


func _test_exercise_validation_order_and_cost_boundaries() -> void:
	var character: CharacterStateScript = _base_character()
	character.recovery.inner_force.current = 12
	character.recovery.inner_force.maximum = 20
	var fighting: CultivationResultScript = CultivationServiceScript.exercise(character, 9, true)
	_assert_failure(fighting, CultivationResultScript.FailureReason.IN_COMBAT, "exercise combat first")
	_assert_exercise_unchanged(character, 100, 12, 20, "exercise combat failure")

	var unmapped: CultivationResultScript = CultivationServiceScript.exercise(character, 9, false)
	_assert_failure(
		unmapped,
		CultivationResultScript.FailureReason.FORCE_STYLE_NOT_ENABLED,
		"exercise mapping before cost",
	)
	_assert_exercise_unchanged(character, 100, 12, 20, "exercise mapping failure")

	_enable_minimum_force(character)
	var below_minimum: CultivationResultScript = CultivationServiceScript.exercise(character, 9, false)
	_assert_failure(
		below_minimum,
		CultivationResultScript.FailureReason.COST_BELOW_MINIMUM,
		"exercise minimum cost",
	)
	_assert_exercise_unchanged(character, 100, 12, 20, "exercise minimum failure")

	character.vitality.current = 9
	var one_below: CultivationResultScript = CultivationServiceScript.exercise(character, 10, false)
	_assert_failure(
		one_below,
		CultivationResultScript.FailureReason.INSUFFICIENT_VITALITY,
		"exercise one below source cost",
	)
	_assert_exercise_unchanged(character, 9, 12, 20, "exercise insufficient source")

	character.vitality.current = 10
	var exact: CultivationResultScript = CultivationServiceScript.exercise(character, 10, false)
	_assert_true(exact.success, "exercise exact source cost succeeds")
	_assert_eq(character.vitality.current, 0, "exercise exact source reaches zero")


func _test_meditate_validation_order_and_cost_boundaries() -> void:
	var character: CharacterStateScript = _valid_meditate_character(12, 20)
	var fighting: CultivationResultScript = CultivationServiceScript.meditate(character, 9, true)
	_assert_failure(fighting, CultivationResultScript.FailureReason.IN_COMBAT, "meditate combat first")
	_assert_meditate_unchanged(character, 100, 12, 20, "meditate combat failure")

	var below_minimum: CultivationResultScript = CultivationServiceScript.meditate(character, 9, false)
	_assert_failure(
		below_minimum,
		CultivationResultScript.FailureReason.COST_BELOW_MINIMUM,
		"meditate minimum cost",
	)
	_assert_meditate_unchanged(character, 100, 12, 20, "meditate minimum failure")

	character.spirit.current = 9
	var one_below: CultivationResultScript = CultivationServiceScript.meditate(character, 10, false)
	_assert_failure(
		one_below,
		CultivationResultScript.FailureReason.INSUFFICIENT_SPIRIT,
		"meditate one below source cost",
	)
	_assert_meditate_unchanged(character, 9, 12, 20, "meditate insufficient source")

	character.spirit.current = 10
	var exact: CultivationResultScript = CultivationServiceScript.meditate(character, 10, false)
	_assert_true(exact.success, "meditate exact source cost succeeds")
	_assert_eq(character.spirit.current, 0, "meditate exact source reaches zero")


func _test_respirate_validation_order_and_cost_boundaries() -> void:
	var character: CharacterStateScript = _valid_respirate_character(12, 20)
	var fighting: CultivationResultScript = CultivationServiceScript.respirate(character, 9, true)
	_assert_failure(fighting, CultivationResultScript.FailureReason.IN_COMBAT, "respirate combat first")
	_assert_respirate_unchanged(character, 100, 12, 20, "respirate combat failure")

	var below_minimum: CultivationResultScript = CultivationServiceScript.respirate(character, 9, false)
	_assert_failure(
		below_minimum,
		CultivationResultScript.FailureReason.COST_BELOW_MINIMUM,
		"respirate minimum cost",
	)
	_assert_respirate_unchanged(character, 100, 12, 20, "respirate minimum failure")

	character.essence.current = 9
	var one_below: CultivationResultScript = CultivationServiceScript.respirate(character, 10, false)
	_assert_failure(
		one_below,
		CultivationResultScript.FailureReason.INSUFFICIENT_ESSENCE,
		"respirate one below source cost",
	)
	_assert_respirate_unchanged(character, 9, 12, 20, "respirate insufficient source")

	character.essence.current = 10
	var exact: CultivationResultScript = CultivationServiceScript.respirate(character, 10, false)
	_assert_true(exact.success, "respirate exact source cost succeeds")
	_assert_eq(character.essence.current, 0, "respirate exact source reaches zero")


func _test_exercise_health_percentage_boundaries() -> void:
	var first_failure: CharacterStateScript = _valid_exercise_character(10, 100)
	first_failure.spirit.current = 69
	first_failure.essence.current = 69
	_assert_failure(
		CultivationServiceScript.exercise(first_failure, 10, false),
		CultivationResultScript.FailureReason.SPIRIT_BELOW_HEALTH_THRESHOLD,
		"exercise checks sen ratio before gin ratio",
	)
	_assert_eq(first_failure.vitality.current, 100, "exercise health failure spends nothing")

	var second_failure: CharacterStateScript = _valid_exercise_character(10, 100)
	second_failure.spirit.current = 70
	second_failure.essence.current = 69
	_assert_failure(
		CultivationServiceScript.exercise(second_failure, 10, false),
		CultivationResultScript.FailureReason.ESSENCE_BELOW_HEALTH_THRESHOLD,
		"exercise exact sen 70 passes before gin failure",
	)

	var exact: CharacterStateScript = _valid_exercise_character(10, 100)
	exact.spirit.current = 70
	exact.essence.current = 70
	_assert_true(CultivationServiceScript.exercise(exact, 10, false).success, "exercise exact 70 percent")

	var truncated_fail: CharacterStateScript = _valid_exercise_character(10, 100)
	_set_primary(truncated_fail.spirit, 70, 101)
	_assert_failure(
		CultivationServiceScript.exercise(truncated_fail, 10, false),
		CultivationResultScript.FailureReason.SPIRIT_BELOW_HEALTH_THRESHOLD,
		"exercise 70*100/101 truncates below 70",
	)
	var truncated_pass: CharacterStateScript = _valid_exercise_character(10, 100)
	_set_primary(truncated_pass.spirit, 71, 101)
	_assert_true(
		CultivationServiceScript.exercise(truncated_pass, 10, false).success,
		"exercise 71*100/101 truncates to 70",
	)


func _test_meditate_health_percentage_boundaries() -> void:
	var first_failure: CharacterStateScript = _valid_meditate_character(10, 100)
	first_failure.vitality.current = 69
	first_failure.essence.current = 69
	_assert_failure(
		CultivationServiceScript.meditate(first_failure, 10, false),
		CultivationResultScript.FailureReason.VITALITY_BELOW_HEALTH_THRESHOLD,
		"meditate checks kee ratio before gin ratio",
	)

	var second_failure: CharacterStateScript = _valid_meditate_character(10, 100)
	second_failure.vitality.current = 70
	second_failure.essence.current = 69
	_assert_failure(
		CultivationServiceScript.meditate(second_failure, 10, false),
		CultivationResultScript.FailureReason.ESSENCE_BELOW_HEALTH_THRESHOLD,
		"meditate exact kee 70 passes before gin failure",
	)

	var exact: CharacterStateScript = _valid_meditate_character(10, 100)
	exact.vitality.current = 70
	exact.essence.current = 70
	_assert_true(CultivationServiceScript.meditate(exact, 10, false).success, "meditate exact 70 percent")

	var truncated_fail: CharacterStateScript = _valid_meditate_character(10, 100)
	_set_primary(truncated_fail.vitality, 70, 101)
	_assert_failure(
		CultivationServiceScript.meditate(truncated_fail, 10, false),
		CultivationResultScript.FailureReason.VITALITY_BELOW_HEALTH_THRESHOLD,
		"meditate 70*100/101 truncates below 70",
	)
	var truncated_pass: CharacterStateScript = _valid_meditate_character(10, 100)
	_set_primary(truncated_pass.vitality, 71, 101)
	_assert_true(
		CultivationServiceScript.meditate(truncated_pass, 10, false).success,
		"meditate 71*100/101 truncates to 70",
	)


func _test_respirate_health_percentage_boundaries() -> void:
	var first_failure: CharacterStateScript = _valid_respirate_character(10, 100)
	first_failure.vitality.current = 69
	first_failure.spirit.current = 69
	_assert_failure(
		CultivationServiceScript.respirate(first_failure, 10, false),
		CultivationResultScript.FailureReason.VITALITY_BELOW_HEALTH_THRESHOLD,
		"respirate checks kee ratio before sen ratio",
	)

	var second_failure: CharacterStateScript = _valid_respirate_character(10, 100)
	second_failure.vitality.current = 70
	second_failure.spirit.current = 69
	_assert_failure(
		CultivationServiceScript.respirate(second_failure, 10, false),
		CultivationResultScript.FailureReason.SPIRIT_BELOW_HEALTH_THRESHOLD,
		"respirate exact kee 70 passes before sen failure",
	)

	var exact: CharacterStateScript = _valid_respirate_character(10, 100)
	exact.vitality.current = 70
	exact.spirit.current = 70
	_assert_true(CultivationServiceScript.respirate(exact, 10, false).success, "respirate exact 70 percent")

	var truncated_fail: CharacterStateScript = _valid_respirate_character(10, 100)
	_set_primary(truncated_fail.vitality, 70, 101)
	_assert_failure(
		CultivationServiceScript.respirate(truncated_fail, 10, false),
		CultivationResultScript.FailureReason.VITALITY_BELOW_HEALTH_THRESHOLD,
		"respirate 70*100/101 truncates below 70",
	)
	var truncated_pass: CharacterStateScript = _valid_respirate_character(10, 100)
	_set_primary(truncated_pass.vitality, 71, 101)
	_assert_true(
		CultivationServiceScript.respirate(truncated_pass, 10, false).success,
		"respirate 71*100/101 truncates to 70",
	)


func _test_exercise_internal_maximum_boundaries() -> void:
	var cases: Array[Array] = [
		[90, 91],
		[100, 101],
		[101, 102],
		[150, 151],
		[199, 200],
	]
	for test_case: Array in cases:
		var character: CharacterStateScript = _valid_exercise_character(test_case[0], 100)
		var result: CultivationResultScript = CultivationServiceScript.exercise(character, 10, false)
		_assert_eq(result.calculated_gain, 1, "exercise boundary gain is one")
		_assert_eq(character.recovery.inner_force.current, test_case[1], "exercise current boundary")
		_assert_eq(character.recovery.inner_force.maximum, 100, "exercise does not clamp before >2x")
		_assert_eq(result.completion, CultivationResultScript.Completion.GAINED, "exercise normal gain result")

	var twice: CharacterStateScript = _valid_exercise_character(200, 100)
	var growth: CultivationResultScript = CultivationServiceScript.exercise(twice, 10, false)
	_assert_eq(growth.completion, CultivationResultScript.Completion.MAXIMUM_INCREASED, "exercise start at 2x grows")
	_assert_eq(twice.recovery.inner_force.maximum, 101, "exercise maximum grows by one")
	_assert_eq(twice.recovery.inner_force.current, 101, "exercise overflow resets to new maximum")

	var above_twice: CharacterStateScript = _valid_exercise_character(201, 100)
	var above_growth: CultivationResultScript = CultivationServiceScript.exercise(above_twice, 10, false)
	_assert_eq(above_growth.completion, CultivationResultScript.Completion.MAXIMUM_INCREASED, "exercise above 2x grows")
	_assert_eq(above_twice.recovery.inner_force.maximum, 101, "exercise above 2x maximum grows")
	_assert_eq(above_twice.recovery.inner_force.current, 101, "exercise above 2x resets current")


func _test_meditate_internal_maximum_boundaries() -> void:
	var cases: Array[Array] = [[90, 91], [100, 101], [101, 102], [150, 151], [199, 200]]
	for test_case: Array in cases:
		var character: CharacterStateScript = _valid_meditate_character(test_case[0], 100)
		var result: CultivationResultScript = CultivationServiceScript.meditate(character, 10, false)
		_assert_eq(result.calculated_gain, 1, "meditate boundary gain is one")
		_assert_eq(character.recovery.mana.current, test_case[1], "meditate current boundary")
		_assert_eq(character.recovery.mana.maximum, 100, "meditate does not clamp before >2x")
		_assert_eq(result.completion, CultivationResultScript.Completion.GAINED, "meditate normal gain result")

	var twice: CharacterStateScript = _valid_meditate_character(200, 100)
	var growth: CultivationResultScript = CultivationServiceScript.meditate(twice, 10, false)
	_assert_eq(growth.completion, CultivationResultScript.Completion.MAXIMUM_INCREASED, "meditate start at 2x grows")
	_assert_eq(twice.recovery.mana.maximum, 101, "meditate maximum grows by one")
	_assert_eq(twice.recovery.mana.current, 101, "meditate overflow resets to new maximum")

	var above_twice: CharacterStateScript = _valid_meditate_character(201, 100)
	var above_growth: CultivationResultScript = CultivationServiceScript.meditate(above_twice, 10, false)
	_assert_eq(above_growth.completion, CultivationResultScript.Completion.MAXIMUM_INCREASED, "meditate above 2x grows")
	_assert_eq(above_twice.recovery.mana.maximum, 101, "meditate above 2x maximum grows")
	_assert_eq(above_twice.recovery.mana.current, 101, "meditate above 2x resets current")


func _test_respirate_internal_maximum_boundaries() -> void:
	var cases: Array[Array] = [[90, 91], [100, 101], [101, 102], [150, 151], [199, 200]]
	for test_case: Array in cases:
		var character: CharacterStateScript = _valid_respirate_character(test_case[0], 100)
		var result: CultivationResultScript = CultivationServiceScript.respirate(character, 10, false)
		_assert_eq(result.calculated_gain, 1, "respirate boundary gain is one")
		_assert_eq(character.recovery.atman.current, test_case[1], "respirate current boundary")
		_assert_eq(character.recovery.atman.maximum, 100, "respirate does not clamp before >2x")
		_assert_eq(result.completion, CultivationResultScript.Completion.GAINED, "respirate normal gain result")

	var twice: CharacterStateScript = _valid_respirate_character(200, 100)
	var growth: CultivationResultScript = CultivationServiceScript.respirate(twice, 10, false)
	_assert_eq(growth.completion, CultivationResultScript.Completion.MAXIMUM_INCREASED, "respirate start at 2x grows")
	_assert_eq(twice.recovery.atman.maximum, 101, "respirate maximum grows by one")
	_assert_eq(twice.recovery.atman.current, 101, "respirate overflow resets to new maximum")

	var above_twice: CharacterStateScript = _valid_respirate_character(201, 100)
	var above_growth: CultivationResultScript = CultivationServiceScript.respirate(above_twice, 10, false)
	_assert_eq(above_growth.completion, CultivationResultScript.Completion.MAXIMUM_INCREASED, "respirate above 2x grows")
	_assert_eq(above_twice.recovery.atman.maximum, 101, "respirate above 2x maximum grows")
	_assert_eq(above_twice.recovery.atman.current, 101, "respirate above 2x resets current")


func _test_skill_cap_boundaries_for_all_actions() -> void:
	## raw force 20, effective force 10: cap = (20 + 10 / 5) * 10 = 220.
	var exercise_cases: Array[Array] = [
		[219, CultivationResultScript.Completion.MAXIMUM_INCREASED, 220],
		[220, CultivationResultScript.Completion.SKILL_CAP_REACHED, 220],
		[221, CultivationResultScript.Completion.SKILL_CAP_REACHED, 221],
	]
	for test_case: Array in exercise_cases:
		var exercise_character: CharacterStateScript = _valid_exercise_character(
			test_case[0] * 2,
			test_case[0],
		)
		var exercise_result: CultivationResultScript = CultivationServiceScript.exercise(
			exercise_character,
			10,
			false,
		)
		_assert_eq(exercise_result.completion, test_case[1], "exercise cap boundary")
		_assert_eq(exercise_character.recovery.inner_force.maximum, test_case[2], "exercise cap maximum")
		_assert_eq(exercise_character.recovery.inner_force.current, test_case[2], "exercise cap current")

	## raw spells/magic 10: cap = 100. Effective 5 plus base spi 25 gives gain 1.
	var direct_cap_cases: Array[Array] = [
		[99, CultivationResultScript.Completion.MAXIMUM_INCREASED, 100],
		[100, CultivationResultScript.Completion.SKILL_CAP_REACHED, 100],
		[101, CultivationResultScript.Completion.SKILL_CAP_REACHED, 101],
	]
	for test_case: Array in direct_cap_cases:
		var meditate_character: CharacterStateScript = _base_character()
		meditate_character.attributes.spirituality = 25
		meditate_character.skills.set_raw_level(SkillIdsScript.SPELLS, 10)
		meditate_character.recovery.mana.current = test_case[0] * 2
		meditate_character.recovery.mana.maximum = test_case[0]
		var meditate_result: CultivationResultScript = CultivationServiceScript.meditate(
			meditate_character,
			10,
			false,
		)
		_assert_eq(meditate_result.completion, test_case[1], "meditate cap boundary")
		_assert_eq(meditate_character.recovery.mana.maximum, test_case[2], "meditate cap maximum")
		_assert_eq(meditate_character.recovery.mana.current, test_case[2], "meditate cap current")

		var respirate_character: CharacterStateScript = _base_character()
		respirate_character.attributes.spirituality = 25
		respirate_character.skills.set_raw_level(SkillIdsScript.MAGIC, 10)
		respirate_character.recovery.atman.current = test_case[0] * 2
		respirate_character.recovery.atman.maximum = test_case[0]
		var respirate_result: CultivationResultScript = CultivationServiceScript.respirate(
			respirate_character,
			10,
			false,
		)
		_assert_eq(respirate_result.completion, test_case[1], "respirate cap boundary")
		_assert_eq(respirate_character.recovery.atman.maximum, test_case[2], "respirate cap maximum")
		_assert_eq(respirate_character.recovery.atman.current, test_case[2], "respirate cap current")


func _test_maximum_caps_use_exact_skill_query_types() -> void:
	var exercise_character: CharacterStateScript = _base_character()
	exercise_character.attributes.constitution = 10
	exercise_character.skills.set_raw_level(SkillIdsScript.FORCE, 20)
	exercise_character.skills.set_raw_level(SkillIdsScript.FONXAN_FORCE, 30)
	exercise_character.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.FONXAN_FORCE)
	exercise_character.recovery.inner_force.current = 500
	exercise_character.recovery.inner_force.maximum = 250
	## effective force = temp 5 + raw 20 / 2 + mapped 30 = 45;
	## cap = (raw 20 + effective 45 / 5) * 10 = 290, so max 250 can grow.
	var exercise_result: CultivationResultScript = CultivationServiceScript.exercise(
		exercise_character,
		10,
		false,
		5,
	)
	_assert_eq(
		exercise_result.completion,
		CultivationResultScript.Completion.MAXIMUM_INCREASED,
		"exercise cap includes effective force",
	)
	_assert_eq(exercise_character.recovery.inner_force.maximum, 251, "exercise effective cap permits growth")

	var meditate_character: CharacterStateScript = _base_character()
	meditate_character.attributes.spirituality = 25
	meditate_character.skills.set_raw_level(SkillIdsScript.SPELLS, 10)
	meditate_character.skills.set_raw_level(TEST_SPELLS_SCHOOL, 100)
	meditate_character.skills.map_skill(SkillIdsScript.SPELLS, TEST_SPELLS_SCHOOL)
	meditate_character.recovery.mana.current = 200
	meditate_character.recovery.mana.maximum = 100
	var meditate_result: CultivationResultScript = CultivationServiceScript.meditate(
		meditate_character,
		10,
		false,
		50,
	)
	_assert_eq(meditate_result.calculated_gain, 6, "meditate gain sees effective spells")
	_assert_eq(
		meditate_result.completion,
		CultivationResultScript.Completion.SKILL_CAP_REACHED,
		"meditate cap remains raw spells times ten",
	)
	_assert_eq(meditate_character.recovery.mana.maximum, 100, "meditate effective values do not raise cap")

	var respirate_character: CharacterStateScript = _base_character()
	respirate_character.attributes.spirituality = 25
	respirate_character.skills.set_raw_level(SkillIdsScript.MAGIC, 10)
	respirate_character.skills.set_raw_level(TEST_MAGIC_SCHOOL, 100)
	respirate_character.skills.map_skill(SkillIdsScript.MAGIC, TEST_MAGIC_SCHOOL)
	respirate_character.recovery.atman.current = 200
	respirate_character.recovery.atman.maximum = 100
	var respirate_result: CultivationResultScript = CultivationServiceScript.respirate(
		respirate_character,
		10,
		false,
		50,
	)
	_assert_eq(respirate_result.calculated_gain, 6, "respirate gain sees effective magic")
	_assert_eq(
		respirate_result.completion,
		CultivationResultScript.Completion.SKILL_CAP_REACHED,
		"respirate cap remains raw magic times ten",
	)
	_assert_eq(respirate_character.recovery.atman.maximum, 100, "respirate effective values do not raise cap")


func _test_no_gain_still_consumes_source_and_skips_overflow_handling() -> void:
	var exercise_character: CharacterStateScript = _base_character()
	exercise_character.attributes.constitution = 10
	exercise_character.skills.set_raw_level(SkillIdsScript.FORCE, 19)
	exercise_character.skills.set_raw_level(SkillIdsScript.FONXAN_FORCE, 0)
	exercise_character.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.FONXAN_FORCE)
	exercise_character.recovery.inner_force.current = 500
	exercise_character.recovery.inner_force.maximum = 100
	var exercise_result: CultivationResultScript = CultivationServiceScript.exercise(
		exercise_character,
		10,
		false,
	)
	_assert_eq(exercise_result.completion, CultivationResultScript.Completion.NO_GAIN, "exercise no gain")
	_assert_eq(exercise_result.calculated_gain, 0, "exercise 10*29/300 truncates to zero")
	_assert_eq(exercise_character.vitality.current, 90, "exercise no gain still spends kee")
	_assert_eq(exercise_character.recovery.inner_force.current, 500, "exercise no gain skips overflow")

	var meditate_character: CharacterStateScript = _base_character()
	meditate_character.attributes.spirituality = 10
	meditate_character.skills.set_raw_level(SkillIdsScript.SPELLS, 38)
	meditate_character.recovery.mana.current = 500
	meditate_character.recovery.mana.maximum = 100
	var meditate_result: CultivationResultScript = CultivationServiceScript.meditate(
		meditate_character,
		10,
		false,
	)
	_assert_eq(meditate_result.completion, CultivationResultScript.Completion.NO_GAIN, "meditate no gain")
	_assert_eq(meditate_result.calculated_gain, 0, "meditate 10*29/300 truncates to zero")
	_assert_eq(meditate_character.spirit.current, 90, "meditate no gain still spends sen")
	_assert_eq(meditate_character.recovery.mana.current, 500, "meditate no gain skips overflow")

	var respirate_character: CharacterStateScript = _base_character()
	respirate_character.attributes.spirituality = 10
	respirate_character.skills.set_raw_level(SkillIdsScript.MAGIC, 38)
	respirate_character.recovery.atman.current = 500
	respirate_character.recovery.atman.maximum = 100
	var respirate_result: CultivationResultScript = CultivationServiceScript.respirate(
		respirate_character,
		10,
		false,
	)
	_assert_eq(respirate_result.completion, CultivationResultScript.Completion.NO_GAIN, "respirate no gain")
	_assert_eq(respirate_result.calculated_gain, 0, "respirate 10*29/300 truncates to zero")
	_assert_eq(respirate_character.essence.current, 90, "respirate no gain still spends gin")
	_assert_eq(respirate_character.recovery.atman.current, 500, "respirate no gain skips overflow")


func _test_negative_legacy_values_are_not_normalized() -> void:
	var character: CharacterStateScript = _base_character()
	character.attributes.constitution = -80
	character.skills.set_raw_level(SkillIdsScript.FORCE, 20)
	character.skills.set_raw_level(SkillIdsScript.FONXAN_FORCE, 0)
	character.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.FONXAN_FORCE)
	character.recovery.inner_force.current = -7
	character.recovery.inner_force.maximum = -5

	## exercise.c: 30 * (20 - 80) / 300 = -6; gain < 1 exits after spending kee.
	var result: CultivationResultScript = CultivationServiceScript.exercise(character, 30, false)
	_assert_true(result.success, "negative legacy gain still completes command")
	_assert_eq(result.calculated_gain, -6, "negative legacy gain is preserved")
	_assert_eq(character.vitality.current, 70, "negative legacy gain still spends kee")
	_assert_eq(character.recovery.inner_force.current, -7, "negative current is not normalized")
	_assert_eq(character.recovery.inner_force.maximum, -5, "negative maximum is not normalized")


func _test_zero_health_maximum_reports_legacy_division_failure() -> void:
	var exercise_character: CharacterStateScript = _valid_exercise_character(10, 100)
	_set_primary(exercise_character.spirit, 0, 0)
	var exercise_result: CultivationResultScript = CultivationServiceScript.exercise(
		exercise_character,
		10,
		false,
	)
	_assert_failure(
		exercise_result,
		CultivationResultScript.FailureReason.LEGACY_ZERO_MAXIMUM_SPIRIT_DIVISOR,
		"exercise exposes zero max_sen divisor",
	)
	_assert_eq(exercise_character.vitality.current, 100, "exercise divisor failure has no mutation")

	var meditate_character: CharacterStateScript = _valid_meditate_character(10, 100)
	_set_primary(meditate_character.vitality, 0, 0)
	var meditate_result: CultivationResultScript = CultivationServiceScript.meditate(
		meditate_character,
		10,
		false,
	)
	_assert_failure(
		meditate_result,
		CultivationResultScript.FailureReason.LEGACY_ZERO_MAXIMUM_VITALITY_DIVISOR,
		"meditate exposes zero max_kee divisor",
	)
	_assert_eq(meditate_character.spirit.current, 100, "meditate divisor failure has no mutation")

	var respirate_character: CharacterStateScript = _valid_respirate_character(10, 100)
	_set_primary(respirate_character.vitality, 0, 0)
	var respirate_result: CultivationResultScript = CultivationServiceScript.respirate(
		respirate_character,
		10,
		false,
	)
	_assert_failure(
		respirate_result,
		CultivationResultScript.FailureReason.LEGACY_ZERO_MAXIMUM_VITALITY_DIVISOR,
		"respirate exposes zero max_kee divisor",
	)
	_assert_eq(respirate_character.essence.current, 100, "respirate divisor failure has no mutation")


func _test_independent_character_states_for_all_actions() -> void:
	var first_exercise: CharacterStateScript = _valid_exercise_character(50, 100)
	var second_exercise: CharacterStateScript = _valid_exercise_character(50, 100)
	var first_result: CultivationResultScript = CultivationServiceScript.exercise(first_exercise, 10, false)
	_assert_eq(first_exercise.vitality.current, 90, "first exercise character spends vitality")
	_assert_eq(first_exercise.recovery.inner_force.current, 51, "first exercise character gains force")
	_assert_eq(second_exercise.vitality.current, 100, "second exercise character vitality unchanged")
	_assert_eq(second_exercise.recovery.inner_force.current, 50, "second exercise character force unchanged")
	var second_result: CultivationResultScript = CultivationServiceScript.exercise(second_exercise, 10, false)
	_assert_true(first_result != second_result, "exercise results are independently allocated")

	var first_meditate: CharacterStateScript = _valid_meditate_character(50, 100)
	var second_meditate: CharacterStateScript = _valid_meditate_character(50, 100)
	CultivationServiceScript.meditate(first_meditate, 10, false)
	_assert_eq(first_meditate.spirit.current, 90, "first meditate character spends spirit")
	_assert_eq(first_meditate.recovery.mana.current, 51, "first meditate character gains mana")
	_assert_eq(second_meditate.spirit.current, 100, "second meditate character spirit unchanged")
	_assert_eq(second_meditate.recovery.mana.current, 50, "second meditate character mana unchanged")

	var first_respirate: CharacterStateScript = _valid_respirate_character(50, 100)
	var second_respirate: CharacterStateScript = _valid_respirate_character(50, 100)
	CultivationServiceScript.respirate(first_respirate, 10, false)
	_assert_eq(first_respirate.essence.current, 90, "first respirate character spends essence")
	_assert_eq(first_respirate.recovery.atman.current, 51, "first respirate character gains atman")
	_assert_eq(second_respirate.essence.current, 100, "second respirate character essence unchanged")
	_assert_eq(second_respirate.recovery.atman.current, 50, "second respirate character atman unchanged")


func _base_character() -> CharacterStateScript:
	var character: CharacterStateScript = CharacterStateScript.new()
	_set_primary(character.essence, 100, 100)
	_set_primary(character.vitality, 100, 100)
	_set_primary(character.spirit, 100, 100)
	return character


func _valid_exercise_character(current_force: int, maximum_force: int) -> CharacterStateScript:
	var character: CharacterStateScript = _base_character()
	character.attributes.constitution = 10
	character.skills.set_raw_level(SkillIdsScript.FORCE, 20)
	character.skills.set_raw_level(SkillIdsScript.FONXAN_FORCE, 0)
	character.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.FONXAN_FORCE)
	character.recovery.inner_force.current = current_force
	character.recovery.inner_force.maximum = maximum_force
	return character


func _valid_meditate_character(current_mana: int, maximum_mana: int) -> CharacterStateScript:
	var character: CharacterStateScript = _base_character()
	character.attributes.spirituality = 10
	character.skills.set_raw_level(SkillIdsScript.SPELLS, 40)
	character.recovery.mana.current = current_mana
	character.recovery.mana.maximum = maximum_mana
	return character


func _valid_respirate_character(current_atman: int, maximum_atman: int) -> CharacterStateScript:
	var character: CharacterStateScript = _base_character()
	character.attributes.spirituality = 10
	character.skills.set_raw_level(SkillIdsScript.MAGIC, 40)
	character.recovery.atman.current = current_atman
	character.recovery.atman.maximum = maximum_atman
	return character


func _enable_minimum_force(character: CharacterStateScript) -> void:
	character.skills.set_raw_level(SkillIdsScript.FORCE, 0)
	character.skills.set_raw_level(SkillIdsScript.FONXAN_FORCE, 0)
	character.skills.map_skill(SkillIdsScript.FORCE, SkillIdsScript.FONXAN_FORCE)


func _set_primary(resource: CharacterResourceStateScript, current: int, maximum: int) -> void:
	resource.maximum = maximum
	resource.effective = maximum
	resource.current = current


func _assert_failure(result: CultivationResultScript, expected_reason: int, label: String) -> void:
	_assert_false(result.success, label + " success")
	_assert_eq(result.failure_reason, expected_reason, label + " reason")
	_assert_eq(result.source_spent, 0, label + " source spent")
	_assert_eq(result.completion, CultivationResultScript.Completion.NONE, label + " completion")


func _assert_exercise_unchanged(
	character: CharacterStateScript,
	expected_vitality: int,
	expected_force: int,
	expected_maximum: int,
	label: String,
) -> void:
	_assert_eq(character.vitality.current, expected_vitality, label + " vitality")
	_assert_eq(character.recovery.inner_force.current, expected_force, label + " force")
	_assert_eq(character.recovery.inner_force.maximum, expected_maximum, label + " maximum")


func _assert_meditate_unchanged(
	character: CharacterStateScript,
	expected_spirit: int,
	expected_mana: int,
	expected_maximum: int,
	label: String,
) -> void:
	_assert_eq(character.spirit.current, expected_spirit, label + " spirit")
	_assert_eq(character.recovery.mana.current, expected_mana, label + " mana")
	_assert_eq(character.recovery.mana.maximum, expected_maximum, label + " maximum")


func _assert_respirate_unchanged(
	character: CharacterStateScript,
	expected_essence: int,
	expected_atman: int,
	expected_maximum: int,
	label: String,
) -> void:
	_assert_eq(character.essence.current, expected_essence, label + " essence")
	_assert_eq(character.recovery.atman.current, expected_atman, label + " atman")
	_assert_eq(character.recovery.atman.maximum, expected_maximum, label + " maximum")


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
