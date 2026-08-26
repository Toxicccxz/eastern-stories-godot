extends RefCounted

const CharacterResourceStateScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const CharacterInternalResourceStateScript := preload(
	"res://core/characters/character_internal_resource_state.gd"
)
const CombatActionDefinitionScript := preload(
	"res://core/combat/action/combat_action_definition.gd"
)
const CombatStrengthProjectionScript := preload(
	"res://core/combat/resolution/combat_strength_projection.gd"
)
const CombatHitPolicyStatusScript := preload(
	"res://core/combat/resolution/combat_hit_policy_status.gd"
)
const WeaponCombatProfileScript := preload(
	"res://core/combat/resolution/weapon_combat_profile.gd"
)
const CombatAttackerSnapshotScript := preload(
	"res://core/combat/resolution/combat_attacker_snapshot.gd"
)
const CombatDefenderSnapshotScript := preload(
	"res://core/combat/resolution/combat_defender_snapshot.gd"
)
const CombatAttackInputScript := preload(
	"res://core/combat/resolution/combat_attack_input.gd"
)
const CombatAttackResultScript := preload(
	"res://core/combat/resolution/combat_attack_result.gd"
)
const CombatAttackResolverScript := preload(
	"res://core/combat/resolution/combat_attack_resolver.gd"
)
const StandardForceHitInputScript := preload(
	"res://core/combat/force/standard_force_hit_input.gd"
)
const StandardForceHitResultScript := preload(
	"res://core/combat/force/standard_force_hit_result.gd"
)
const StandardForceHitPolicyScript := preload(
	"res://core/combat/force/standard_force_hit_policy.gd"
)
const ScriptedCombatRandomSourceScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_deduction_and_post_deduction_formula()
	_test_negative_armed_paths()
	_test_integer_zero_and_undefined_results()
	_test_negative_unarmed_reflection_boundaries()
	_test_reflection_mutation_and_threshold()
	_test_nonnegative_and_post_armor_paths()
	_test_policy_invalid_random_bounds()
	_test_resolver_entry_and_provider_routing()
	_test_resolver_armor_separation()
	_test_resolver_order_and_later_failures()
	_test_projection_identity_and_immutability()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_deduction_and_post_deduction_formula() -> void:
	var force: CharacterInternalResourceStateScript = _force(50)
	var result: StandardForceHitResultScript = _policy(
		_force_input(10, 5, true, 20, 20, 25, 0),
		force,
		_resource(),
		[0],
	)
	_assert_eq(force.current, 40, "std force deducts factor before all calculation and RNG")
	_assert_eq(result.force_before, 50, "result records force before deduction")
	_assert_eq(result.force_after_deduction, 40, "result records force after deduction")
	_assert_eq(result.force_damage_before_armor, 11, "force damage uses post-deduction 40/20 + 10 - 25/25")
	_assert_eq(result.outcome, StandardForceHitResultScript.Outcome.NUMERIC_BONUS, "normal force comparison returns numeric branch")
	_assert_eq(result.numeric_contribution, 11, "successful normal force contributes exact calculated damage")

	var signed_force: CharacterInternalResourceStateScript = _force(0)
	var signed: StandardForceHitResultScript = _policy(
		_force_input(-10, 5, true, 20, 20, 0, 0),
		signed_force,
		_resource(),
		[],
	)
	_assert_eq(signed_force.current, 10, "negative factor preserves source add(force, -factor) increase")
	_assert_eq(signed.force_damage_before_armor, -10, "signed factor arithmetic is not clamped")
	_assert_eq(signed.numeric_contribution, -5, "negative branch clamps contribution to -entering bonus")

	var negative_attacker_division: StandardForceHitResultScript = _policy(
		_force_input(0, 10, true, 10, 10, 0, 0),
		_force(-21),
		_resource(),
		[],
	)
	_assert_eq(negative_attacker_division.force_damage_before_armor, -1, "negative attacker force division truncates toward zero: -21/20 == -1")

	var negative_defender_division: StandardForceHitResultScript = _policy(
		_force_input(0, 10, true, 10, 10, -26, 0),
		_force(0),
		_resource(),
		[0],
	)
	_assert_eq(negative_defender_division.force_damage_before_armor, 1, "negative defender force division truncates toward zero: -26/25 == -1")


func _test_negative_armed_paths() -> void:
	var no_clamp_force: CharacterInternalResourceStateScript = _force(5)
	var no_clamp: StandardForceHitResultScript = _policy(
		_force_input(5, 10, true, 20, 20, 250, 0),
		no_clamp_force,
		_resource(),
		[],
	)
	_assert_eq(no_clamp.force_damage_before_armor, -5, "armed negative force damage formula")
	_assert_eq(no_clamp.numeric_contribution, -5, "armed negative contribution is returned unchanged when B remains nonnegative")
	_assert_eq(no_clamp.random_upper_bounds(), [], "armed negative branch consumes no reflection RNG")

	var clamp: StandardForceHitResultScript = _policy(
		_force_input(5, 3, true, 20, 20, 250, 0),
		_force(5),
		_resource(),
		[],
	)
	_assert_eq(clamp.numeric_contribution, -3, "armed negative branch returns exactly -damage_bonus when sum would be negative")


func _test_integer_zero_and_undefined_results() -> void:
	var negative_zero: StandardForceHitResultScript = _policy(
		_force_input(5, 0, true, 10, 10, 250, 0),
		_force(5),
		_resource(),
		[],
	)
	_assert_eq(negative_zero.outcome, StandardForceHitResultScript.Outcome.NUMERIC_BONUS, "negative clamp returning -B preserves integer-return taxonomy when B is zero")
	_assert_true(negative_zero.has_numeric_contribution(), "integer zero is still a numeric contribution")
	_assert_eq(negative_zero.numeric_contribution, 0, "negative clamp returns exact integer zero")

	var post_armor_zero: StandardForceHitResultScript = _policy(
		_force_input(5, 0, true, 10, 10, 100, 10),
		_force(5),
		_resource(),
		[],
	)
	_assert_eq(post_armor_zero.force_damage_after_armor, -9, "post-armor integer-zero control reaches combined-negative branch")
	_assert_eq(post_armor_zero.outcome, StandardForceHitResultScript.Outcome.NUMERIC_BONUS, "post-armor -B zero remains an integer return")
	_assert_eq(post_armor_zero.numeric_contribution, 0, "post-armor combined-negative returns exact integer zero")
	_assert_eq(post_armor_zero.random_upper_bounds(), [], "post-armor integer-zero early return consumes no attacker RNG")

	var undefined_zero: StandardForceHitResultScript = _policy(
		_force_input(5, 10, true, 10, 10, 100, 1),
		_force(5),
		_resource(),
		[0],
	)
	_assert_eq(undefined_zero.force_damage_after_armor, 0, "zero-force-damage control reaches exact zero after armor")
	_assert_eq(undefined_zero.random_upper_bounds(), [10], "zero force damage still consumes attacker-force RNG")
	_assert_eq(undefined_zero.outcome, StandardForceHitResultScript.Outcome.NO_NUMERIC_EFFECT, "zero force damage fallthrough remains undefined/no effect")
	_assert_false(undefined_zero.has_numeric_contribution(), "undefined/no effect is distinct from numeric zero")


func _test_negative_unarmed_reflection_boundaries() -> void:
	var equality_force: CharacterInternalResourceStateScript = _force(5)
	var equality: StandardForceHitResultScript = _policy(
		_force_input(5, 10, false, 10, 8, 250, 0),
		equality_force,
		_resource(),
		[5],
	)
	_assert_eq(equality.random_upper_bounds(), [8], "reflection uses defender effective force as exact bound")
	_assert_eq(equality.outcome, StandardForceHitResultScript.Outcome.NUMERIC_BONUS, "draw equal attacker force/2 does not reflect")
	_assert_eq(equality.numeric_contribution, -5, "equality continues negative numeric branch")

	var reflected: StandardForceHitResultScript = _policy(
		_force_input(5, 10, false, 10, 8, 250, 0),
		_force(5),
		_resource(),
		[6],
	)
	_assert_eq(reflected.outcome, StandardForceHitResultScript.Outcome.REFLECTION, "draw strictly greater than attacker force/2 reflects")
	_assert_false(reflected.has_numeric_contribution(), "string-equivalent reflection has no numeric contribution")


func _test_reflection_mutation_and_threshold() -> void:
	var vitality: CharacterResourceStateScript = _resource(8, 8, 100)
	var result: StandardForceHitResultScript = _policy(
		_force_input(5, 10, false, 10, 8, 250, 0),
		_force(5),
		vitality,
		[6],
	)
	var mutation: StandardForceReflectionMutationResult = result.reflection_mutation
	_assert_eq(mutation.requested_damage, 10, "reflection requests -force_damage * 2 damage")
	_assert_eq(mutation.requested_wound, 5, "reflection requests -force_damage wound")
	_assert_eq(mutation.vitality_current_before, 8, "reflection records attacker kee before")
	_assert_eq(mutation.vitality_current_after_damage, -1, "reflection damage applies before wound")
	_assert_eq(mutation.vitality_effective_after_damage, 8, "damage does not alter effective kee")
	_assert_eq(mutation.vitality_current_after_wound, -1, "wound retains saturated current kee")
	_assert_eq(mutation.vitality_effective_after_wound, 3, "reflection wound lowers effective kee second")
	_assert_eq(result.attacker_threshold_candidate, CombatAttackResultScript.ThresholdCandidate.UNCONSCIOUS, "reflection reports attacker unconscious candidate without lifecycle")

	var death_vitality: CharacterResourceStateScript = _resource(4, 4, 100)
	var death: StandardForceHitResultScript = _policy(
		_force_input(5, 10, false, 10, 8, 250, 0),
		_force(5),
		death_vitality,
		[6],
	)
	_assert_eq(death.attacker_threshold_candidate, CombatAttackResultScript.ThresholdCandidate.DEATH, "reflection death candidate uses post-wound effective kee")

	var essence_death: StandardForceHitResultScript = _policy(
		_force_input(5, 10, false, 10, 8, 250, 0),
		_force(5),
		_resource(),
		[6],
		_resource(-1, -1, 100),
		_resource(),
	)
	_assert_eq(essence_death.attacker_threshold_candidate, CombatAttackResultScript.ThresholdCandidate.DEATH, "reflection threshold observes attacker effective gin as well as kee")

	var spirit_unconscious: StandardForceHitResultScript = _policy(
		_force_input(5, 10, false, 10, 8, 250, 0),
		_force(5),
		_resource(),
		[6],
		_resource(),
		_resource(-1, 100, 100),
	)
	_assert_eq(spirit_unconscious.attacker_threshold_candidate, CombatAttackResultScript.ThresholdCandidate.UNCONSCIOUS, "reflection threshold observes attacker current sen when no resource is death-qualified")


func _test_nonnegative_and_post_armor_paths() -> void:
	var success: StandardForceHitResultScript = _policy(
		_force_input(10, 5, true, 10, 10, 25, 3),
		_force(50),
		_resource(),
		[7],
	)
	_assert_eq(success.force_damage_before_armor, 11, "normal path calculates force damage before armor_vs_force")
	_assert_true(success.armor_subtraction_reached, "normal path records armor_vs_force stage")
	_assert_eq(success.force_damage_after_armor, 8, "armor_vs_force subtracts only from force damage")
	_assert_eq(success.random_upper_bounds(), [10], "normal comparison uses attacker effective force bound")
	_assert_eq(success.numeric_contribution, 8, "draw 7 strictly below force damage 8 succeeds")

	var failed: StandardForceHitResultScript = _policy(
		_force_input(10, 5, true, 10, 10, 25, 3),
		_force(50),
		_resource(),
		[8],
	)
	_assert_eq(failed.outcome, StandardForceHitResultScript.Outcome.NO_NUMERIC_EFFECT, "normal strict less-than equality returns undefined/no effect")

	var early: StandardForceHitResultScript = _policy(
		_force_input(5, 3, true, 10, 10, 100, 10),
		_force(5),
		_resource(),
		[],
	)
	_assert_eq(early.force_damage_before_armor, 1, "combined-negative control pre-armor damage")
	_assert_eq(early.force_damage_after_armor, -9, "armor_vs_force may make force damage negative")
	_assert_eq(early.numeric_contribution, -3, "combined-negative post-armor branch returns -damage_bonus")
	_assert_eq(early.random_upper_bounds(), [], "combined-negative post-armor branch returns before attacker RNG")

	var post_armor_negative: StandardForceHitResultScript = _policy(
		_force_input(5, 10, true, 10, 10, 100, 10),
		_force(5),
		_resource(),
		[0],
	)
	_assert_eq(post_armor_negative.force_damage_after_armor, -9, "post-armor force damage remains negative without clamp")
	_assert_eq(post_armor_negative.random_upper_bounds(), [10], "combined nonnegative case still consumes attacker RNG")
	_assert_eq(post_armor_negative.outcome, StandardForceHitResultScript.Outcome.NO_NUMERIC_EFFECT, "nonnegative draw cannot be less than negative force damage")


func _test_policy_invalid_random_bounds() -> void:
	var reflection_force: CharacterInternalResourceStateScript = _force(5)
	var reflection_invalid: StandardForceHitResultScript = _policy(
		_force_input(5, 10, false, 10, 0, 250, 0),
		reflection_force,
		_resource(),
		[],
	)
	_assert_eq(reflection_invalid.failure_stage, StandardForceHitResultScript.FailureStage.REFLECTION_RANDOM_BOUND, "invalid defender force bound stops at reflection random")
	_assert_eq(reflection_force.current, 0, "reflection bound failure retains prior force deduction")
	_assert_true(reflection_invalid.has_failed_random_bound, "reflection bound failure records attempted bound")
	_assert_eq(reflection_invalid.failed_random_bound, 0, "reflection failed bound is exact")

	var normal_force: CharacterInternalResourceStateScript = _force(50)
	var normal_invalid: StandardForceHitResultScript = _policy(
		_force_input(10, 5, true, 0, 10, 25, 0),
		normal_force,
		_resource(),
		[],
	)
	_assert_eq(normal_invalid.failure_stage, StandardForceHitResultScript.FailureStage.NORMAL_RANDOM_BOUND, "invalid attacker force bound stops at normal random")
	_assert_eq(normal_force.current, 40, "normal bound failure retains prior force deduction")

	var reflection_draw_force: CharacterInternalResourceStateScript = _force(5)
	var reflection_draw_invalid: StandardForceHitResultScript = _policy(
		_force_input(5, 10, false, 10, 8, 250, 0),
		reflection_draw_force,
		_resource(),
		[8],
	)
	_assert_eq(reflection_draw_invalid.failure_stage, StandardForceHitResultScript.FailureStage.REFLECTION_RANDOM_DRAW, "out-of-range defender-force draw fails at reflection stage")
	_assert_eq(reflection_draw_force.current, 0, "invalid reflection draw retains prior force deduction")
	_assert_eq(reflection_draw_invalid.random_draws(), [8], "invalid reflection draw remains in policy evidence")

	var normal_draw_force: CharacterInternalResourceStateScript = _force(50)
	var normal_draw_invalid: StandardForceHitResultScript = _policy(
		_force_input(10, 5, true, 10, 10, 25, 0),
		normal_draw_force,
		_resource(),
		[10],
	)
	_assert_eq(normal_draw_invalid.failure_stage, StandardForceHitResultScript.FailureStage.NORMAL_RANDOM_DRAW, "out-of-range attacker-force draw fails at normal force stage")
	_assert_eq(normal_draw_force.current, 40, "invalid normal force draw retains prior force deduction")


func _test_resolver_entry_and_provider_routing() -> void:
	var not_reached: CombatAttackResultScript = _attack(
		_standard_attacker(2),
		_force_defender(),
		ScriptedCombatRandomSourceScript.new([0, 0]),
		_force(30),
		_resource(),
	)
	_assert_eq(not_reached.outcome, CombatAttackResultScript.Outcome.DODGE, "dodge stops before the force seam")
	_assert_false(not_reached.has_standard_force_result, "attack stopped before force has no standard result")
	_assert_false(not_reached.calculation.has_reached(CombatAttackCalculation.ReachedStage.INITIAL_STRENGTH_READY), "pre-force stop is explicit in calculation stage evidence")

	var inactive_force: CharacterInternalResourceStateScript = _force(2)
	var inactive_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0])
	var inactive: CombatAttackResultScript = _attack(
		_standard_attacker(2),
		_force_defender(),
		inactive_rng,
		inactive_force,
		_resource(),
	)
	_assert_eq(inactive.outcome, CombatAttackResultScript.Outcome.HIT, "force equal factor skips standard policy")
	_assert_eq(inactive_force.current, 2, "false entry predicate deducts no force")
	_assert_false(inactive.has_standard_force_result, "false entry predicate emits no policy result")
	_assert_eq(inactive_rng.requested_bounds(), [2, 12, 12, 10, 2, 1], "false predicate consumes no force-policy RNG")
	_assert_true(inactive.calculation.has_reached(CombatAttackCalculation.ReachedStage.FORCE_HOOK_PASSED), "false force predicate is distinguishable from not reaching the seam")

	var signed_force: CharacterInternalResourceStateScript = _force(-5)
	var signed: CombatAttackResultScript = _attack(
		_standard_attacker(-10, CombatHitPolicyStatusScript.Value.STANDARD_FORCE, &"fonxanforce", 10, false, _weapon()),
		_force_defender(),
		ScriptedCombatRandomSourceScript.new([0, 3, 1, 0, 0, 0]),
		signed_force,
		_resource(),
	)
	_assert_eq(signed.outcome, CombatAttackResultScript.Outcome.HIT, "negative nonzero factor enters when live current force is strictly greater")
	_assert_eq(signed_force.current, 5, "negative factor increases live current force without clamp")
	_assert_eq(signed.standard_force_result.numeric_contribution, 10, "negative-factor armed branch preserves exact -B integer return")

	var routed_force: CharacterInternalResourceStateScript = _force(30)
	var routed: CombatAttackResultScript = _attack(
		_standard_attacker(2),
		_force_defender(10, 0, 0),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 0]),
		routed_force,
		_resource(),
	)
	_assert_true(routed.has_standard_force_result, "standard provider routes through shared native policy")
	_assert_eq(routed.standard_force_result.provider_id, &"fonxanforce", "resolver preserves mapped provider ID")
	_assert_eq(routed_force.current, 28, "routed standard provider deducts factor")

	var authored_force: CharacterInternalResourceStateScript = _force(30)
	var authored: CombatAttackResultScript = _attack(
		_standard_attacker(2, CombatHitPolicyStatusScript.Value.AUTHORED_POLICY_UNAVAILABLE, &"iceforce"),
		_force_defender(),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0]),
		authored_force,
		_resource(),
	)
	_assert_eq(authored.outcome, CombatAttackResultScript.Outcome.AUTHORED_HIT_POLICY_UNAVAILABLE, "iceforce authored override remains wholly unavailable")
	_assert_eq(authored.failure_stage, CombatAttackResultScript.FailureStage.FORCE_HIT_POLICY, "iceforce stops at the force seam")
	_assert_eq(authored_force.current, 30, "authored override does not partially execute inherited standard force")
	_assert_false(authored.has_standard_force_result, "authored override emits no partial standard result")
	_assert_false(authored.calculation.has_reached(CombatAttackCalculation.ReachedStage.FORCE_HOOK_PASSED), "authored force stop is distinct from a false entry predicate")

	var invalid_force_draw_authority: CharacterInternalResourceStateScript = _force(3)
	var invalid_force_draw: CombatAttackResultScript = _attack(
		_standard_attacker(2),
		_force_defender(10, 200, 0),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 10]),
		invalid_force_draw_authority,
		_resource(),
		_action(100),
	)
	_assert_eq(invalid_force_draw.failure_stage, CombatAttackResultScript.FailureStage.FORCE_REFLECTION_RANDOM_DRAW, "invalid policy draw maps to exact resolver force stage")
	_assert_eq(invalid_force_draw_authority.current, 1, "resolver force draw failure preserves completed deduction")
	_assert_true(invalid_force_draw.has_standard_force_result, "resolver force draw failure preserves typed force evidence")
	_assert_eq(invalid_force_draw.calculation.final_strength_bonus, 2, "invalid force draw stops before action.force")
	_assert_false(invalid_force_draw.resource_mutation.damage_transition_completed, "invalid force draw stops before defender damage")
	_assert_eq(invalid_force_draw.calculation.random_upper_bounds(), [2, 12, 12, 10, 10], "invalid force draw consumes no later RNG")


func _test_resolver_armor_separation() -> void:
	var result: CombatAttackResultScript = _attack(
		_standard_attacker(2, CombatHitPolicyStatusScript.Value.STANDARD_FORCE, &"fonxanforce", 10, false, _weapon()),
		_force_defender(10, 0, 1, 5),
		ScriptedCombatRandomSourceScript.new([0, 3, 1, 0, 0, 0, 0, 6]),
		_force(30),
		_resource(),
	)
	_assert_eq(result.outcome, CombatAttackResultScript.Outcome.HIT, "separate force and physical armor integration completes")
	_assert_eq(result.standard_force_result.force_damage_before_armor, 3, "force integration control computes pre-armor value")
	_assert_eq(result.standard_force_result.force_damage_after_armor, 2, "force policy subtracts armor_vs_force value 1")
	_assert_eq(result.calculation.armor, 5, "ordinary wound retains distinct physical armor value 5")
	_assert_eq(result.calculation.wound_amount, 2, "physical wound subtracts ordinary armor, not armor_vs_force")


func _test_resolver_order_and_later_failures() -> void:
	var force: CharacterInternalResourceStateScript = _force(30)
	var ordered: CombatAttackResultScript = _attack(
		_standard_attacker(2),
		_force_defender(10, 0, 0),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 0]),
		force,
		_resource(),
		_action(100),
	)
	_assert_eq(ordered.calculation.random_upper_bounds(), [2, 12, 12, 10, 10, 10, 1], "force RNG is globally ordered between base-damage and final-B RNG")
	_assert_eq(ordered.calculation.final_strength_bonus, 10, "action.force applies after standard numeric contribution: (2 + 3) * 2")

	var reflection_vitality: CharacterResourceStateScript = _resource()
	var reflection: CombatAttackResultScript = _attack(
		_standard_attacker(2, CombatHitPolicyStatusScript.Value.STANDARD_FORCE, &"fonxanforce", 10),
		_force_defender(10, 200, 0),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 6, 0, 0]),
		_force(3),
		reflection_vitality,
		null,
		_resource(-1, -1, 100),
		_resource(),
	)
	_assert_eq(reflection.standard_force_result.outcome, StandardForceHitResultScript.Outcome.REFLECTION, "resolver preserves string-equivalent reflection result")
	_assert_eq(reflection.standard_force_result.attacker_threshold_candidate, CombatAttackResultScript.ThresholdCandidate.DEATH, "resolver records three-resource attacker death candidate after reflection")
	_assert_eq(reflection.calculation.final_strength_bonus, 2, "reflection leaves entering B unchanged")
	_assert_eq(reflection.calculation.random_upper_bounds(), [2, 12, 12, 10, 10, 2, 1], "reflection RNG precedes unchanged-B RNG")
	_assert_eq(reflection_vitality.current, 88, "reflection mutates attacker vitality while outer attack continues")
	_assert_true(reflection.resource_mutation.damage_transition_completed, "outer defender damage still completes after reflected attacker death candidate")

	var martial_force: CharacterInternalResourceStateScript = _force(30)
	var martial: CombatAttackResultScript = _attack(
		_standard_attacker(2, CombatHitPolicyStatusScript.Value.STANDARD_FORCE, &"fonxanforce", 10, true),
		_force_defender(),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0]),
		martial_force,
		_resource(),
		_action(100),
	)
	_assert_eq(martial.outcome, CombatAttackResultScript.Outcome.AUTHORED_HIT_POLICY_UNAVAILABLE, "later martial policy still stops at its seam")
	_assert_eq(martial.failure_stage, CombatAttackResultScript.FailureStage.MARTIAL_HIT_POLICY, "later failure stage remains martial")
	_assert_eq(martial_force.current, 28, "martial failure retains earlier force deduction")
	_assert_true(martial.has_standard_force_result, "martial failure preserves standard force evidence")
	_assert_eq(martial.calculation.final_strength_bonus, 10, "action.force completed before martial failure")
	_assert_false(martial.resource_mutation.damage_transition_completed, "martial failure precedes defender damage")

	var reflected_then_blocked_force: CharacterInternalResourceStateScript = _force(3)
	var reflected_then_blocked_vitality: CharacterResourceStateScript = _resource()
	var reflected_then_blocked: CombatAttackResultScript = _attack(
		_standard_attacker(2, CombatHitPolicyStatusScript.Value.STANDARD_FORCE, &"fonxanforce", 10, true),
		_force_defender(10, 200, 0),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 6]),
		reflected_then_blocked_force,
		reflected_then_blocked_vitality,
		null,
		_resource(-1, -1, 100),
		_resource(),
	)
	_assert_eq(reflected_then_blocked.failure_stage, CombatAttackResultScript.FailureStage.MARTIAL_HIT_POLICY, "reflection does not bypass a later unavailable martial seam")
	_assert_eq(reflected_then_blocked_force.current, 1, "later martial failure retains force deducted before reflection")
	_assert_eq(reflected_then_blocked_vitality.current, 88, "later martial failure retains reflected attacker damage")
	_assert_eq(reflected_then_blocked_vitality.effective, 94, "later martial failure retains reflected attacker wound")
	_assert_eq(reflected_then_blocked.standard_force_result.outcome, StandardForceHitResultScript.Outcome.REFLECTION, "later martial failure preserves reflection evidence")
	_assert_eq(reflected_then_blocked.standard_force_result.attacker_threshold_candidate, CombatAttackResultScript.ThresholdCandidate.DEATH, "later martial failure preserves three-resource attacker threshold evidence")
	_assert_false(reflected_then_blocked.resource_mutation.damage_transition_completed, "later martial failure still precedes defender ordinary damage after reflection")
	_assert_eq(reflected_then_blocked.calculation.random_upper_bounds(), [2, 12, 12, 10, 10], "later martial failure consumes no RNG after reflection")

	var weapon_force: CharacterInternalResourceStateScript = _force(30)
	var weapon_failure: CombatAttackResultScript = _attack(
		_standard_attacker(2, CombatHitPolicyStatusScript.Value.STANDARD_FORCE, &"fonxanforce", 10, false, _weapon(true)),
		_force_defender(),
		ScriptedCombatRandomSourceScript.new([0, 3, 1, 0, 0]),
		weapon_force,
		_resource(),
	)
	_assert_eq(weapon_failure.failure_stage, CombatAttackResultScript.FailureStage.WEAPON_HIT_POLICY, "later weapon failure remains at weapon seam")
	_assert_eq(weapon_force.current, 28, "weapon failure retains earlier force deduction")
	_assert_true(weapon_failure.has_standard_force_result, "weapon failure preserves force policy evidence")


func _test_projection_identity_and_immutability() -> void:
	var mismatch_force: CharacterInternalResourceStateScript = _force(30)
	var mismatch_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0])
	var mismatch: CombatAttackResultScript = _attack(
		_standard_attacker(2, CombatHitPolicyStatusScript.Value.STANDARD_FORCE, &"fonxanforce", 10, false, null, &"magic"),
		_force_defender(),
		mismatch_rng,
		mismatch_force,
		_resource(),
	)
	_assert_eq(mismatch.failure_stage, CombatAttackResultScript.FailureStage.FORCE_SKILL_PROJECTION_MISMATCH, "mislabeled force scalar is rejected")
	_assert_eq(mismatch_rng.call_count(), 0, "force projection mismatch fails before RNG")
	_assert_eq(mismatch_force.current, 30, "force projection mismatch mutates no authority")

	var martial_status_attacker: CombatAttackerSnapshot = _standard_attacker(0)
	martial_status_attacker._mapped_attack_skill_id = &"martial:test"
	martial_status_attacker._martial_hit_policy_status = CombatHitPolicyStatusScript.Value.STANDARD_FORCE
	var martial_status_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([])
	var martial_status: CombatAttackResultScript = _attack(
		martial_status_attacker,
		_force_defender(),
		martial_status_rng,
		_force(0),
		_resource(),
	)
	_assert_eq(martial_status.failure_stage, CombatAttackResultScript.FailureStage.INVALID_ATTACK_INPUT, "STANDARD_FORCE at martial seam typed-fails input validation")
	_assert_eq(martial_status_rng.call_count(), 0, "invalid martial force status consumes no RNG")

	var attacker_status_attacker: CombatAttackerSnapshot = _standard_attacker(0)
	attacker_status_attacker._attacker_hit_policy_status = CombatHitPolicyStatusScript.Value.STANDARD_FORCE
	var attacker_status: CombatAttackResultScript = _attack(
		attacker_status_attacker,
		_force_defender(),
		ScriptedCombatRandomSourceScript.new([]),
		_force(0),
		_resource(),
	)
	_assert_eq(attacker_status.failure_stage, CombatAttackResultScript.FailureStage.INVALID_ATTACK_INPUT, "STANDARD_FORCE at attacker/NPC seam typed-fails input validation")

	var weapon_status: CombatAttackResultScript = _attack(
		_standard_attacker(0, CombatHitPolicyStatusScript.Value.STANDARD_FORCE, &"fonxanforce", 10, false, WeaponCombatProfileScript.new(&"weapon:test", &"sword", CombatHitPolicyStatusScript.Value.STANDARD_FORCE)),
		_force_defender(),
		ScriptedCombatRandomSourceScript.new([]),
		_force(0),
		_resource(),
	)
	_assert_eq(weapon_status.failure_stage, CombatAttackResultScript.FailureStage.INVALID_ATTACK_INPUT, "STANDARD_FORCE at weapon seam typed-fails input validation")
	_assert_true(CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT != CombatHitPolicyStatusScript.Value.STANDARD_FORCE, "proven no authored effect remains distinct from standard force")

	var source_input: StandardForceHitInputScript = _force_input(10, 5, true, 20, 20, 25, 0)
	var copied_input: StandardForceHitInputScript = source_input.duplicate_snapshot()
	source_input._provider_id = &"mutated"
	_assert_eq(copied_input.provider_id, &"fonxanforce", "standard force input duplicate is independent")

	var outer: CombatAttackResultScript = _attack(
		_standard_attacker(2),
		_force_defender(),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 0]),
		_force(30),
		_resource(),
	)
	var returned: StandardForceHitResult = outer.standard_force_result
	returned._force_after_deduction = 999
	returned._random_draws.clear()
	_assert_eq(outer.standard_force_result.force_after_deduction, 28, "outer force result getter is defensive")
	_assert_eq(outer.standard_force_result.random_draws(), [0], "outer policy RNG evidence is not aliased")


func _policy(
	input: StandardForceHitInput,
	force: CharacterInternalResourceState,
	vitality: CharacterResourceState,
	draws: Array[int],
	essence: CharacterResourceState = null,
	spirit: CharacterResourceState = null,
) -> StandardForceHitResult:
	return StandardForceHitPolicyScript.resolve(
		input,
		force,
		essence if essence != null else _resource(),
		vitality,
		spirit if spirit != null else _resource(),
		ScriptedCombatRandomSourceScript.new(draws),
	)


func _force_input(
	factor: int,
	damage_bonus: int,
	has_weapon: bool,
	attacker_force_level: int,
	defender_force_level: int,
	defender_current_force: int,
	armor_vs_force: int,
) -> StandardForceHitInput:
	return StandardForceHitInputScript.new(
		&"fonxanforce",
		&"attacker-1",
		&"defender-1",
		factor,
		damage_bonus,
		has_weapon,
		&"force",
		attacker_force_level,
		&"force",
		defender_force_level,
		defender_current_force,
		armor_vs_force,
	)


func _standard_attacker(
	factor: int,
	force_status: int = CombatHitPolicyStatusScript.Value.STANDARD_FORCE,
	provider_id: StringName = &"fonxanforce",
	force_level: int = 10,
	martial_unavailable: bool = false,
	weapon: WeaponCombatProfile = null,
	force_skill_type: StringName = &"force",
) -> CombatAttackerSnapshot:
	return CombatAttackerSnapshotScript.new(
		&"attacker-1",
		true,
		0,
		0,
		0,
		weapon.skill_type if weapon != null else &"unarmed",
		3,
		0,
		10,
		CombatStrengthProjectionScript.new(0, factor, 0),
		false,
		provider_id,
		force_status,
		&"martial:test" if martial_unavailable else &"",
		(
			CombatHitPolicyStatusScript.Value.AUTHORED_POLICY_UNAVAILABLE
			if martial_unavailable
			else CombatHitPolicyStatusScript.Value.NOT_APPLICABLE
		),
		CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT,
		weapon,
		force_skill_type,
		force_level,
	)


func _force_defender(
	force_level: int = 10,
	current_force: int = 0,
	armor_vs_force: int = 0,
	armor: int = 0,
) -> CombatDefenderSnapshot:
	return CombatDefenderSnapshotScript.new(
		&"defender-1",
		true,
		false,
		1,
		0,
		0,
		2,
		2,
		2,
		0,
		armor,
		false,
		[&"头", &"右臂"],
		&"force",
		force_level,
		current_force,
		armor_vs_force,
	)


func _attack(
	attacker: CombatAttackerSnapshot,
	defender: CombatDefenderSnapshot,
	rng: ScriptedCombatRandomSource,
	attacker_force: CharacterInternalResourceState,
	attacker_vitality: CharacterResourceState,
	action: CombatActionDefinition = null,
	attacker_essence: CharacterResourceState = null,
	attacker_spirit: CharacterResourceState = null,
) -> CombatAttackResult:
	return CombatAttackResolverScript.resolve(
		CombatAttackInputScript.new(
			attacker,
			defender,
			action if action != null else _action(),
		),
		_resource(),
		_resource(),
		_resource(),
		rng,
		attacker_force,
		attacker_essence if attacker_essence != null else _resource(),
		attacker_vitality,
		attacker_spirit if attacker_spirit != null else _resource(),
	)


func _weapon(unavailable: bool = false) -> WeaponCombatProfile:
	return WeaponCombatProfileScript.new(
		&"weapon:test",
		&"sword",
		(
			CombatHitPolicyStatusScript.Value.AUTHORED_POLICY_UNAVAILABLE
			if unavailable
			else CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT
		),
	)


func _action(force_percent: int = 0) -> CombatActionDefinition:
	return CombatActionDefinitionScript.new(&"ordinary", 0, force_percent, &"伤害")


func _force(current: int) -> CharacterInternalResourceState:
	return CharacterInternalResourceStateScript.new(current, 100)


func _resource(
	current: int = 100,
	effective: int = 100,
	maximum: int = 100,
) -> CharacterResourceState:
	return CharacterResourceStateScript.new(current, effective, maximum)


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
