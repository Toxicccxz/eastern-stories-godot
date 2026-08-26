extends RefCounted

const CharacterResourceStateScript := preload(
	"res://core/characters/character_resource_state.gd"
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
const ScriptedCombatRandomSourceScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_selected_action_limb_and_input_boundaries()
	_test_projection_coherence_and_stage_presence()
	_test_ap_dp_and_dodge_boundaries()
	_test_pp_and_parry_matrix()
	_test_base_action_and_strength_damage()
	_test_authored_hook_stop_points()
	_test_policy_classification_and_force_predicate()
	_test_defense_factor_loop()
	_test_damage_wound_and_partial_failure()
	_test_additional_damage_and_wound_boundaries()
	_test_threshold_candidates()
	_test_rng_failure_stages()
	_test_rng_contract_and_immutability()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_selected_action_limb_and_input_boundaries() -> void:
	var caller_limbs: Array[StringName] = [&"头", &"右臂"]
	var action: CombatActionDefinitionScript = _action(&"selected-slash", 25, 0)
	var input: CombatAttackInputScript = CombatAttackInputScript.new(
		_attacker(),
		_defender(1, 2, 2, 2, false, 0, false, caller_limbs),
		action,
	)
	caller_limbs.clear()
	action._action_id = &"mutated-source"
	var vitality: CharacterResourceStateScript = _resource()
	var rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([1, 0])
	var result: CombatAttackResultScript = _resolve(input, rng, vitality)
	_assert_eq(result.outcome, CombatAttackResultScript.Outcome.DODGE, "selected action reaches dodge")
	_assert_eq(result.action_id, &"selected-slash", "resolver uses supplied selected action snapshot")
	_assert_eq(result.calculation.selected_limb, &"右臂", "limb uses exact authored index")
	_assert_eq(rng.requested_bounds(), [2, 12], "first resolver roll is limb, not action selection")
	_assert_eq(vitality.current, 100, "dodge does not mutate vitality")

	var empty_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0])
	var empty_result: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(), _defender(1, 2, 2, 2, false, 0, false, []), _action()),
		empty_rng,
		_resource(),
	)
	_assert_eq(
		empty_result.failure_stage,
		CombatAttackResultScript.FailureStage.INVALID_LIMB_SET,
		"empty limbs fail at typed limb boundary",
	)
	_assert_eq(empty_rng.call_count(), 0, "empty limbs fail before RNG")

	var missing_rng_result: CombatAttackResultScript = _resolve(
		_input(),
		null,
		_resource(),
	)
	_assert_eq(
		missing_rng_result.failure_stage,
		CombatAttackResultScript.FailureStage.RANDOM_SOURCE_MISSING,
		"missing RNG is typed",
	)

	var invalid_weapon: WeaponCombatProfileScript = WeaponCombatProfileScript.new(
		&"",
		&"sword",
		CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT,
	)
	var invalid_inputs: Array[CombatAttackInput] = [
		CombatAttackInputScript.new(
			CombatAttackerSnapshotScript.new(&"attacker-without-explicit-policy"),
			_defender(),
			_action(),
		),
		CombatAttackInputScript.new(
			_attacker_with_policies(null, &"unarmed", 10, 0, 0, 0, &"", CombatHitPolicyStatusScript.Value.NOT_APPLICABLE, &"", CombatHitPolicyStatusScript.Value.NOT_APPLICABLE, CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT, false, &""),
			_defender(),
			_action(),
		),
		CombatAttackInputScript.new(_attacker(), _defender_with_id(&""), _action()),
		CombatAttackInputScript.new(_attacker(), _defender(), _action(&"")),
		CombatAttackInputScript.new(
			_attacker_with_policies(invalid_weapon, &"sword"),
			_defender(),
			_action(),
		),
		CombatAttackInputScript.new(
			_attacker_with_policies(
				WeaponCombatProfileScript.new(&"weapon-without-policy", &"sword"),
				&"sword",
			),
			_defender(),
			_action(),
		),
	]
	for invalid_input: CombatAttackInput in invalid_inputs:
		var invalid_id_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0])
		var invalid_id_vitality: CharacterResourceStateScript = _resource()
		var invalid_id_result: CombatAttackResultScript = _resolve(
			invalid_input,
			invalid_id_rng,
			invalid_id_vitality,
		)
		_assert_eq(invalid_id_result.failure_stage, CombatAttackResultScript.FailureStage.INVALID_ATTACK_INPUT, "empty required identity fails typed input validation")
		_assert_eq(invalid_id_rng.call_count(), 0, "invalid identity fails before RNG")
		_assert_eq(invalid_id_vitality.current, 100, "invalid identity mutates no resource")


func _test_ap_dp_and_dodge_boundaries() -> void:
	var normal: CombatAttackResultScript = _resolve(
		_input(),
		ScriptedCombatRandomSourceScript.new([0, 0]),
		_resource(),
	)
	_assert_eq(normal.calculation.attack_power, 9, "AP uses skill_power then retains normal value")
	_assert_eq(normal.calculation.dodge_power, 3, "DP uses dodge skill_power")

	var clamped: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(
			_attacker(0, -2, 0, 10, 0, 0, 0, 0, false, false, false, false, null, false),
			_defender(0, 0, 0, 0, true),
			_action(),
		),
		ScriptedCombatRandomSourceScript.new([0, 0, 1]),
		_resource(),
	)
	_assert_eq(clamped.calculation.attack_power, 1, "negative/nonliving AP clamps to one")
	_assert_eq(clamped.calculation.dodge_power, 0, "busy DP divides after min-one clamp with no second clamp")
	_assert_eq(clamped.calculation.parry_power, 1, "PP clamps after busy division")

	var dodge: CombatAttackResultScript = _resolve(
		_input(),
		ScriptedCombatRandomSourceScript.new([0, 2]),
		_resource(),
	)
	_assert_eq(dodge.outcome, CombatAttackResultScript.Outcome.DODGE, "roll DP-1 dodges")
	_assert_eq(dodge.calculation.random_upper_bounds(), [2, 12], "dodge consumes no later roll")
	_assert_false(dodge.resource_mutation.damage_transition_completed, "dodge performs no damage transition")

	var equality: CombatAttackResultScript = _resolve(
		_input(),
		ScriptedCombatRandomSourceScript.new([0, 3, 0]),
		_resource(),
	)
	_assert_true(equality.outcome != CombatAttackResultScript.Outcome.DODGE, "roll equal DP is not dodge")
	_assert_eq(equality.calculation.random_upper_bounds().size(), 3, "DP equality reaches parry roll")


func _test_projection_coherence_and_stage_presence() -> void:
	var weapon: WeaponCombatProfileScript = _weapon()
	var mismatch_attacker: CombatAttackerSnapshotScript = _attacker_with_policies(
		weapon,
		&"unarmed",
	)
	var mismatch_vitality: CharacterResourceStateScript = _resource()
	var mismatch: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(mismatch_attacker, _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([]),
		mismatch_vitality,
	)
	_assert_eq(
		mismatch.failure_stage,
		CombatAttackResultScript.FailureStage.ATTACK_SKILL_PROJECTION_MISMATCH,
		"weapon skill and effective attack projection must name the same skill type",
	)
	_assert_eq(mismatch.calculation.random_upper_bounds(), [], "skill mismatch fails before all RNG")
	_assert_false(
		mismatch.calculation.has_reached(CombatAttackCalculation.ReachedStage.LIMB_SELECTED),
		"skill mismatch reaches no attack calculation stage",
	)
	_assert_false(
		mismatch.calculation.has_reached(
			CombatAttackCalculation.ReachedStage.ATTACK_AND_DODGE_POWER_READY
		),
		"skill mismatch exposes no fabricated AP/DP values",
	)
	_assert_false(mismatch.resource_mutation.damage_transition_completed, "skill mismatch mutates no resource")

	var dodge: CombatAttackResultScript = _resolve(
		_input(),
		ScriptedCombatRandomSourceScript.new([0, 0]),
		_resource(),
	)
	_assert_true(
		dodge.calculation.has_reached(CombatAttackCalculation.ReachedStage.DODGE_EVALUATED),
		"dodge result marks dodge evaluation reached",
	)
	_assert_false(
		dodge.calculation.has_reached(CombatAttackCalculation.ReachedStage.PARRY_POWER_READY),
		"dodge result does not present default parry zero as calculated",
	)
	_assert_eq(
		dodge.threshold_candidate,
		CombatAttackResultScript.ThresholdCandidate.NOT_OBSERVED,
		"dodge never reports a threshold observation",
	)
	var unarmed_apply: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 0), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0]),
		_resource(),
	)
	_assert_eq(unarmed_apply.calculation.base_apply_damage, 10, "unarmed D reads projected current apply/damage")
	var armed_base: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(
			_attacker(0, 3, 0, 10, 0, 0, 0, 0, false, false, false, false, weapon),
			_defender(),
			_action(),
		),
		ScriptedCombatRandomSourceScript.new([0, 3, 1, 0, 0, 0]),
		_resource(),
	)
	_assert_eq(armed_base.calculation.base_apply_damage, 10, "armed D reads the same final aggregate contract")

	var armed: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(
			_attacker(0, 3, 0, 13, 0, 0, 0, 0, false, false, false, false, weapon),
			_defender(),
			_action(),
		),
		ScriptedCombatRandomSourceScript.new([0, 3, 1, 0, 0, 0]),
		_resource(),
	)
	_assert_eq(armed.calculation.base_apply_damage, 13, "armed D reads the character's final aggregate apply/damage exactly once")
	_assert_eq(armed.calculation.random_upper_bounds()[3], 13, "external +3 modifier changes armed random bound 10 to 13 without a second weapon add")
	_assert_eq(armed.calculation.damage_value, 6, "aggregate 13 follows source integer base random formula")
	_assert_true(
		armed.calculation.has_reached(CombatAttackCalculation.ReachedStage.THRESHOLD_OBSERVED),
		"completed hit explicitly marks threshold observation",
	)


func _test_pp_and_parry_matrix() -> void:
	var armed_profile: WeaponCombatProfileScript = _weapon(false)
	var armed_vs_armed: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 0, false, false, false, false, armed_profile), _defender(1, 2, 2, 2, false, 0, true), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 2]),
		_resource(),
	)
	_assert_eq(armed_vs_armed.calculation.parry_power, 3, "armed defender uses parry power")
	_assert_eq(armed_vs_armed.outcome, CombatAttackResultScript.Outcome.PARRY, "roll below armed PP parries")

	var unarmed_vs_armed: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(), _defender(1, 2, 2, 2, false, 0, true), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 5]),
		_resource(),
	)
	_assert_eq(unarmed_vs_armed.calculation.parry_power, 6, "armed defender doubles PP against unarmed attacker")

	var armed_vs_unarmed: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 0, false, false, false, false, armed_profile), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 0]),
		_resource(),
	)
	_assert_eq(armed_vs_unarmed.calculation.parry_power, 1, "unarmed defender against weapon gets source zero then min-one")

	var both_unarmed: CombatAttackResultScript = _resolve(
		_input(),
		ScriptedCombatRandomSourceScript.new([0, 3, 2]),
		_resource(),
	)
	_assert_eq(both_unarmed.calculation.parry_power, 3, "both unarmed uses unarmed defense power")

	var busy_doubled: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(), _defender(1, 2, 2, 2, true, 0, true), _action()),
		ScriptedCombatRandomSourceScript.new([0, 1, 1]),
		_resource(),
	)
	_assert_eq(busy_doubled.calculation.parry_power, 2, "PP doubles before busy division and final clamp")

	var parry_equality: CombatAttackResultScript = _resolve(
		_input(),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0]),
		_resource(),
	)
	_assert_true(parry_equality.outcome != CombatAttackResultScript.Outcome.PARRY, "roll equal PP is not parry")
	_assert_eq(parry_equality.calculation.random_upper_bounds()[3], 10, "PP equality reaches base damage roll")
	_assert_false(armed_vs_armed.resource_mutation.damage_transition_completed, "parry performs no resource mutation")
	_assert_eq(armed_vs_armed.threshold_candidate, CombatAttackResultScript.ThresholdCandidate.NOT_OBSERVED, "parry never reports a threshold observation")
	_assert_false(armed_vs_armed.interrupt_requested, "parry never requests later interrupt")


func _test_base_action_and_strength_damage() -> void:
	var positive: CombatAttackResultScript = _hit_with_action_and_strength(50, 0, 0, 0, [0, 3, 3, 0, 0])
	_assert_eq(positive.calculation.damage_value, 7, "action +50 percent uses integer D += percent*D/100")
	var zero: CombatAttackResultScript = _hit_with_action_and_strength(0, 0, 0, 0, [0, 3, 3, 0, 0])
	_assert_eq(zero.calculation.damage_value, 5, "zero action damage is a no-op")
	var negative: CombatAttackResultScript = _hit_with_action_and_strength(-200, 0, 0, 0, [0, 3, 3, 0, 0])
	_assert_eq(negative.calculation.damage_value, 0, "negative action damage is preserved then D clamps after strength")

	var base_random: CombatAttackResultScript = _hit_with_action_and_strength(0, 0, 0, 0, [0, 3, 3, 9, 0])
	_assert_eq(base_random.calculation.damage_value, 9, "base damage is (10 + random(10)) / 2")

	for invalid_apply: int in [0, -5]:
		var vitality: CharacterResourceStateScript = _resource()
		var invalid: CombatAttackResultScript = _resolve(
			CombatAttackInputScript.new(_attacker(0, 3, 0, invalid_apply, 0), _defender(), _action()),
			ScriptedCombatRandomSourceScript.new([0, 3, 3]),
			vitality,
		)
		_assert_eq(invalid.failure_stage, CombatAttackResultScript.FailureStage.APPLY_DAMAGE_RANDOM_BOUND, "nonpositive apply/damage stops at random bound")
		_assert_eq(invalid.calculation.random_upper_bounds(), [2, 12, 12], "invalid apply/damage consumes no damage roll")
		_assert_eq(vitality.current, 100, "invalid apply/damage performs no mutation")

	var strength: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 10, 3, -2, 3), _defender(), _action(&"force-action", 0, 50)),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 15, 0]),
		_resource(),
	)
	_assert_eq(strength.calculation.initial_strength_bonus, 11, "query_str is str + force_factor + apply/strength")
	_assert_eq(strength.calculation.final_strength_bonus, 16, "action force applies integer percentage to current B")
	_assert_eq(strength.calculation.requested_damage, 20, "positive B adds (B + random(B))/2")

	var nonpositive_b: CombatAttackResultScript = _hit_with_action_and_strength(0, -2, 0, 1, [0, 3, 3, 0, 0])
	_assert_eq(nonpositive_b.calculation.final_strength_bonus, -1, "nonpositive B is not clamped")
	_assert_eq(nonpositive_b.calculation.random_upper_bounds(), [2, 12, 12, 10, 1], "B <= 0 consumes no strength roll")


func _test_authored_hook_stop_points() -> void:
	var hook_rolls: Array[int] = [0, 3, 3, 0]
	var force: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 10, 2, 0, 3, false, true), _defender(), _action(&"hook", 0, 50)),
		ScriptedCombatRandomSourceScript.new(hook_rolls),
		_resource(),
	)
	_assert_policy_stop(force, CombatAttackResultScript.FailureStage.FORCE_HIT_POLICY, CombatAttackResultScript.AuthoredPolicyKind.FORCE, 12, [2, 12, 12, 10], "force hook")

	var martial: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 10, 0, 0, 0, false, false, true), _defender(), _action(&"hook", 0, 50)),
		ScriptedCombatRandomSourceScript.new(hook_rolls),
		_resource(),
	)
	_assert_policy_stop(martial, CombatAttackResultScript.FailureStage.MARTIAL_HIT_POLICY, CombatAttackResultScript.AuthoredPolicyKind.MARTIAL, 15, [2, 12, 12, 10], "martial hook after action force")

	var weapon: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 10, 0, 0, 0, false, false, false, false, _weapon(true)), _defender(), _action(&"hook", 0, 50)),
		ScriptedCombatRandomSourceScript.new(hook_rolls),
		_resource(),
	)
	_assert_policy_stop(weapon, CombatAttackResultScript.FailureStage.WEAPON_HIT_POLICY, CombatAttackResultScript.AuthoredPolicyKind.WEAPON, 15, [2, 12, 10, 10], "weapon hook")

	var npc: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 10, 0, 0, 0, false, false, false, true), _defender(), _action(&"hook", 0, 50)),
		ScriptedCombatRandomSourceScript.new(hook_rolls),
		_resource(),
	)
	_assert_policy_stop(npc, CombatAttackResultScript.FailureStage.ATTACKER_HIT_POLICY, CombatAttackResultScript.AuthoredPolicyKind.ATTACKER, 15, [2, 12, 12, 10], "attacker/NPC hook")

	var zero_factor: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 10, false, true), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0]),
		_resource(),
	)
	_assert_eq(zero_factor.outcome, CombatAttackResultScript.Outcome.HIT, "force hook is not reached when force_factor is zero")
	var equal_force: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 2, 0, 2, false, true), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0]),
		_resource(),
	)
	_assert_eq(equal_force.outcome, CombatAttackResultScript.Outcome.HIT, "force hook requires current force strictly greater than factor")
	var armed_ignores_attacker_hook: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 0, 0, 0, 0, false, false, false, true, _weapon()), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 1, 0, 0, 1]),
		_resource(),
	)
	_assert_eq(armed_ignores_attacker_hook.outcome, CombatAttackResultScript.Outcome.HIT, "armed source selects weapon branch rather than attacker/NPC hook")


func _test_defense_factor_loop() -> void:
	var zero_iterations: CombatAttackResultScript = _defense_loop_result([5])
	_assert_eq(zero_iterations.calculation.defense_iterations, 0, "defense loop can stop immediately")
	_assert_eq(zero_iterations.calculation.requested_damage, 15, "zero loops preserve D")
	var one_iteration: CombatAttackResultScript = _defense_loop_result([6, 5])
	_assert_eq(one_iteration.calculation.defense_iterations, 1, "one strict-greater defense loop iteration")
	_assert_eq(one_iteration.calculation.requested_damage, 10, "one loop subtracts integer D/3")
	var multiple: CombatAttackResultScript = _defense_loop_result([20, 6, 5])
	_assert_eq(multiple.calculation.defense_iterations, 2, "multiple defense iterations retained")
	_assert_eq(multiple.calculation.requested_damage, 7, "15 -> 10 -> 7 preserves per-round truncation")
	_assert_eq(multiple.calculation.random_upper_bounds().slice(-3), [40, 20, 10], "factor halves after each successful defense")

	var invalid_factor_vitality: CharacterResourceStateScript = _resource()
	var invalid_factor: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 0), _defender(0), _action()),
		ScriptedCombatRandomSourceScript.new([0, 2, 2, 0]),
		invalid_factor_vitality,
	)
	_assert_eq(invalid_factor.failure_stage, CombatAttackResultScript.FailureStage.DEFENSE_FACTOR_RANDOM_BOUND, "nonpositive defense factor is typed at required random")
	_assert_false(invalid_factor.resource_mutation.damage_transition_completed, "invalid factor precedes damage mutation")

	var negative_attacker: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(-1, 3, 0, 10, 0), _defender(1), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0]),
		_resource(),
	)
	_assert_eq(negative_attacker.failure_stage, CombatAttackResultScript.FailureStage.DEFENSE_FACTOR_RANDOM_BOUND, "negative attacker exp cannot hang when factor reaches zero")
	_assert_eq(negative_attacker.calculation.defense_iterations, 1, "source-valid factor-one iteration occurs before typed zero-bound failure")


func _test_policy_classification_and_force_predicate() -> void:
	var unavailable: int = CombatHitPolicyStatusScript.Value.AUTHORED_POLICY_UNAVAILABLE
	var proven_none: int = CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT
	var not_applicable: int = CombatHitPolicyStatusScript.Value.NOT_APPLICABLE

	var inactive_cases: Array[CombatAttackerSnapshot] = [
		_attacker_with_policies(null, &"unarmed", 10, 0, 0, 10, &"force:test", unavailable),
		_attacker_with_policies(null, &"unarmed", 10, 0, 2, 2, &"force:test", unavailable),
		_attacker_with_policies(null, &"unarmed", 10, 0, 2, 1, &"force:test", unavailable),
		_attacker_with_policies(null, &"unarmed", 10, 0, 2, 3, &"", not_applicable),
	]
	var inactive_messages: Array[String] = [
		"force_factor zero skips mapped force hook",
		"current force equal to factor skips mapped force hook",
		"current force below factor skips mapped force hook",
		"absent mapped force skips force hook even above threshold",
	]
	for index: int in inactive_cases.size():
		var inactive: CombatAttackResultScript = _resolve(
			CombatAttackInputScript.new(inactive_cases[index], _defender(), _action()),
			ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0]),
			_resource(),
		)
		_assert_eq(inactive.outcome, CombatAttackResultScript.Outcome.HIT, inactive_messages[index])

	var active_unavailable: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(
			_attacker_with_policies(null, &"unarmed", 10, 0, 2, 3, &"force:ice", unavailable),
			_defender(),
			_action(),
		),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0]),
		_resource(),
	)
	_assert_eq(active_unavailable.outcome, CombatAttackResultScript.Outcome.AUTHORED_HIT_POLICY_UNAVAILABLE, "active authored force hook remains deferred")
	_assert_eq(active_unavailable.authored_policy_id, &"force:ice", "deferred force result identifies exact provider")

	var mapped_no_effect: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(
			_attacker_with_policies(
				null,
				&"unarmed",
				10,
				0,
				2,
				3,
				&"force:plain",
				proven_none,
				&"unarmed-style:plain",
				proven_none,
			),
			_defender(),
			_action(),
		),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0]),
		_resource(),
	)
	_assert_eq(mapped_no_effect.outcome, CombatAttackResultScript.Outcome.HIT, "mapped providers proven to lack hit_ob continue normally")

	var ambiguous: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(
			_attacker_with_policies(
				null,
				&"unarmed",
				10,
				0,
				0,
				0,
				&"",
				not_applicable,
				&"unarmed-style:ambiguous",
				CombatHitPolicyStatusScript.Value.DRIVER_AMBIGUITY,
			),
			_defender(),
			_action(),
		),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0]),
		_resource(),
	)
	_assert_eq(ambiguous.outcome, CombatAttackResultScript.Outcome.HIT_POLICY_DISPATCH_AMBIGUOUS, "driver ambiguity is distinct from an unported authored override")
	_assert_eq(ambiguous.failure_stage, CombatAttackResultScript.FailureStage.MARTIAL_HIT_POLICY, "ambiguity retains exact dispatch site")
	_assert_eq(ambiguous.authored_policy_id, &"unarmed-style:ambiguous", "ambiguity retains provider identity")


func _test_damage_wound_and_partial_failure() -> void:
	var saturation_vitality: CharacterResourceStateScript = _resource(3, 100, 100)
	var saturation: CombatAttackResultScript = _resolve(
		_input(),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0]),
		saturation_vitality,
	)
	_assert_eq(saturation.calculation.requested_damage, 8, "combat retains requested damage")
	_assert_eq(saturation_vitality.current, -1, "closed resource damage saturates current at -1")
	_assert_eq(saturation.resource_mutation.requested_damage, 8, "result does not replace requested D with actual delta four")

	var friendly: CombatAttackResultScript = _resolve(
		_input(),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0]),
		_resource(),
	)
	_assert_false(friendly.calculation.wound_eligible, "friendly unarmed attack is not wound-eligible")
	_assert_eq(friendly.calculation.random_upper_bounds(), [2, 12, 12, 10, 6, 1], "friendly unarmed consumes no wound RNG")

	var equal_vitality: CharacterResourceStateScript = _resource()
	var equal_armor: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 0, true), _defender(1, 2, 2, 2, false, 3), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 3]),
		equal_vitality,
	)
	_assert_true(equal_armor.calculation.wound_roll_performed, "lethal attack evaluates wound")
	_assert_false(equal_armor.resource_mutation.wound_transition_completed, "wound roll equal armor does not wound")

	var ordered_vitality: CharacterResourceStateScript = _resource(10, 10, 100)
	var wound: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 0, true), _defender(1, 2, 2, 2, false, 3), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 4]),
		ordered_vitality,
	)
	_assert_eq(wound.calculation.wound_amount, 5, "wound amount is D - armor")
	_assert_eq(ordered_vitality.current, 2, "damage is applied before wound")
	_assert_eq(ordered_vitality.effective, 5, "wound then lowers effective kee")
	_assert_true(wound.resource_mutation.damage_transition_completed, "damage completion recorded")
	_assert_true(wound.resource_mutation.wound_transition_completed, "wound completion recorded")

	var armed_friendly: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 0, 0, 0, 0, false, false, false, false, _weapon()), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 1, 0, 0, 1]),
		_resource(),
	)
	_assert_true(armed_friendly.calculation.wound_eligible, "armed friendly attack is wound-eligible")

	var partial_vitality: CharacterResourceStateScript = _resource()
	var partial: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 1, 0, 0, 0, 0, true), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0]),
		partial_vitality,
	)
	_assert_eq(partial.failure_stage, CombatAttackResultScript.FailureStage.WOUND_RANDOM_BOUND, "zero D fails only when wound random is reached")
	_assert_true(partial.resource_mutation.damage_transition_completed, "zero-damage transition completed before wound failure")
	_assert_false(partial.resource_mutation.wound_transition_completed, "partial failure executes no wound")
	_assert_eq(partial_vitality.current, 100, "partial failure does not roll back or invent damage")
	_assert_eq(partial.calculation.random_upper_bounds(), [2, 12, 12, 1, 1], "invalid wound bound is not requested from RNG")
	_assert_false(partial.interrupt_requested, "wound-bound failure occurs before future interrupt request")
	_assert_eq(partial.threshold_candidate, CombatAttackResultScript.ThresholdCandidate.NOT_OBSERVED, "wound-bound failure does not execute later threshold observation")

	var invalid_draw_vitality: CharacterResourceStateScript = _resource()
	var invalid_wound_draw: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 0, true), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 8]),
		invalid_draw_vitality,
	)
	_assert_eq(invalid_wound_draw.failure_stage, CombatAttackResultScript.FailureStage.WOUND_RANDOM_DRAW, "out-of-contract wound draw fails after damage")
	_assert_eq(invalid_draw_vitality.current, 92, "positive damage is not rolled back after later wound draw failure")
	_assert_true(invalid_wound_draw.resource_mutation.damage_transition_completed, "partial positive damage completion is reported")
	_assert_false(invalid_wound_draw.resource_mutation.wound_transition_completed, "invalid wound draw performs no wound")
	_assert_false(invalid_wound_draw.interrupt_requested, "wound draw failure exposes no prematurely executed interrupt")


func _test_threshold_candidates() -> void:
	var none: CombatAttackResultScript = _resolve(
		_input(),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0]),
		_resource(),
	)
	_assert_eq(none.threshold_candidate, CombatAttackResultScript.ThresholdCandidate.NONE, "healthy hit reports no threshold")

	var unconscious: CombatAttackResultScript = _resolve(
		_input(),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0]),
		_resource(3, 100, 100),
	)
	_assert_eq(unconscious.threshold_candidate, CombatAttackResultScript.ThresholdCandidate.UNCONSCIOUS, "current kee below zero reports unconscious candidate")

	var death_vitality: CharacterResourceStateScript = _resource(5, 5, 100)
	var death: CombatAttackResultScript = _resolve_with_resources(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 0, true), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 1]),
		_resource(),
		death_vitality,
		_resource(),
	)
	_assert_eq(death.threshold_candidate, CombatAttackResultScript.ThresholdCandidate.DEATH, "effective kee below zero reports death")

	var essence_unconscious: CharacterResourceStateScript = _resource(-1, 100, 100)
	var death_precedence: CombatAttackResultScript = _resolve_with_resources(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 0, true), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 1]),
		essence_unconscious,
		_resource(5, 5, 100),
		_resource(),
	)
	_assert_eq(death_precedence.threshold_candidate, CombatAttackResultScript.ThresholdCandidate.DEATH, "death candidate precedes another resource's unconscious candidate")

	var essence: CharacterResourceStateScript = _resource(-1, 100, 100)
	var spirit: CharacterResourceStateScript = _resource(100, -1, 100)
	var non_vitality_threshold: CombatAttackResultScript = _resolve_with_resources(
		_input(),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0]),
		essence,
		_resource(),
		spirit,
	)
	_assert_eq(non_vitality_threshold.threshold_candidate, CombatAttackResultScript.ThresholdCandidate.DEATH, "pre-existing sen death threshold is observed after completed hit")
	_assert_eq(essence.current, -1, "ordinary attack does not mutate gin while observing its threshold")
	_assert_eq(spirit.effective, -1, "ordinary attack does not mutate sen while observing its threshold")


func _test_additional_damage_and_wound_boundaries() -> void:
	var negative_damage: CombatAttackResultScript = _hit_with_action_and_strength(
		-50,
		0,
		0,
		0,
		[0, 3, 3, 0, 0],
	)
	_assert_eq(negative_damage.calculation.damage_value, 3, "negative action damage divides toward zero: 5 + (-25 / 100) = 3")
	var negative_force: CombatAttackResultScript = _hit_with_action_and_strength(
		0,
		5,
		0,
		0,
		[0, 3, 3, 0, 3, 0],
	)
	var negative_force_action: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 5), _defender(), _action(&"negative-force", 0, -50)),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0]),
		_resource(),
	)
	_assert_eq(negative_force.calculation.initial_strength_bonus, 5, "positive B control retains source projection")
	_assert_eq(negative_force_action.calculation.final_strength_bonus, 3, "negative action force divides toward zero: 5 + (-250 / 100) = 3")

	var friendly_zero: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 1, 0), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0]),
		_resource(),
	)
	_assert_eq(friendly_zero.outcome, CombatAttackResultScript.Outcome.HIT, "friendly unarmed zero D is a completed hit")
	_assert_true(friendly_zero.resource_mutation.damage_transition_completed, "zero D still completes damage transition")
	_assert_false(friendly_zero.interrupt_requested, "zero D does not request interruption")

	var negative_armor_vitality: CharacterResourceStateScript = _resource()
	var negative_armor: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 0, true), _defender(1, 2, 2, 2, false, -2), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 0]),
		negative_armor_vitality,
	)
	_assert_eq(negative_armor.calculation.requested_damage, 8, "negative armor case retains D")
	_assert_eq(negative_armor.calculation.wound_amount, 10, "source does not clamp wound D - negative armor")
	_assert_eq(negative_armor_vitality.effective, 90, "negative armor wound applies its full source amount")

	var saturated_vitality: CharacterResourceStateScript = _resource(3, 100, 100)
	var saturated_wound: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 0, true), _defender(1, 2, 2, 2, false, 3), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 4]),
		saturated_vitality,
	)
	_assert_eq(saturated_wound.resource_mutation.vitality_current_after, -1, "damage saturation remains visible")
	_assert_eq(saturated_wound.calculation.wound_amount, 5, "wound uses requested D rather than saturated actual current delta")
	_assert_eq(saturated_vitality.effective, 95, "saturated damage does not change requested wound basis")

	var armed_lethal: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 0, 0, 0, 0, true, false, false, false, _weapon()), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 1, 0, 0, 0]),
		_resource(),
	)
	_assert_true(armed_lethal.calculation.wound_eligible, "lethal armed attack remains wound eligible without double semantics")

	var same_identity: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(
			_attacker_with_policies(null, &"unarmed", 10, 0, 0, 0, &"", CombatHitPolicyStatusScript.Value.NOT_APPLICABLE, &"", CombatHitPolicyStatusScript.Value.NOT_APPLICABLE, CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT, false, &"same-character"),
			_defender_with_id(&"same-character"),
			_action(),
		),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0]),
		_resource(),
	)
	_assert_eq(same_identity.outcome, CombatAttackResultScript.Outcome.HIT, "ordinary core does not invent a self-attack rejection")


func _test_rng_failure_stages() -> void:
	var limb: CombatAttackResultScript = _resolve(
		_input(), ScriptedCombatRandomSourceScript.new([2]), _resource()
	)
	_assert_rng_failure(
		limb,
		CombatAttackResultScript.FailureStage.LIMB_RANDOM_DRAW,
		CombatAttackCalculation.ReachedStage.NONE,
		false,
		"limb RNG",
	)
	var dodge: CombatAttackResultScript = _resolve(
		_input(), ScriptedCombatRandomSourceScript.new([0, 12]), _resource()
	)
	_assert_rng_failure(
		dodge,
		CombatAttackResultScript.FailureStage.DODGE_RANDOM_DRAW,
		CombatAttackCalculation.ReachedStage.ATTACK_AND_DODGE_POWER_READY,
		false,
		"dodge RNG",
	)
	var parry: CombatAttackResultScript = _resolve(
		_input(), ScriptedCombatRandomSourceScript.new([0, 3, 12]), _resource()
	)
	_assert_rng_failure(
		parry,
		CombatAttackResultScript.FailureStage.PARRY_RANDOM_DRAW,
		CombatAttackCalculation.ReachedStage.PARRY_POWER_READY,
		false,
		"parry RNG",
	)
	var base_damage: CombatAttackResultScript = _resolve(
		_input(), ScriptedCombatRandomSourceScript.new([0, 3, 3, 10]), _resource()
	)
	_assert_rng_failure(
		base_damage,
		CombatAttackResultScript.FailureStage.APPLY_DAMAGE_RANDOM_DRAW,
		CombatAttackCalculation.ReachedStage.APPLY_DAMAGE_PROJECTED,
		false,
		"base damage RNG",
	)
	var strength: CombatAttackResultScript = _resolve(
		_input(), ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 6]), _resource()
	)
	_assert_rng_failure(
		strength,
		CombatAttackResultScript.FailureStage.STRENGTH_RANDOM_DRAW,
		CombatAttackCalculation.ReachedStage.TERMINAL_HOOK_PASSED,
		false,
		"strength RNG",
	)
	var defense: CombatAttackResultScript = _resolve(
		_input(), ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 1]), _resource()
	)
	_assert_rng_failure(
		defense,
		CombatAttackResultScript.FailureStage.DEFENSE_FACTOR_RANDOM_DRAW,
		CombatAttackCalculation.ReachedStage.STRENGTH_DAMAGE_READY,
		false,
		"defense RNG",
	)
	var wound_vitality: CharacterResourceStateScript = _resource()
	var wound: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 0, true), _defender(), _action()),
		ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0, 8]),
		wound_vitality,
	)
	_assert_rng_failure(
		wound,
		CombatAttackResultScript.FailureStage.WOUND_RANDOM_DRAW,
		CombatAttackCalculation.ReachedStage.WOUND_ELIGIBILITY_EVALUATED,
		true,
		"wound RNG",
	)
	_assert_eq(wound_vitality.current, 92, "wound RNG failure preserves already-completed damage")


func _test_rng_contract_and_immutability() -> void:
	var full: CombatAttackResultScript = _resolve(
		CombatAttackInputScript.new(_attacker(0, 3, 0, 10, 6, 0, 0, 0, true), _defender(1, 2, 2, 2, false, 3), _action(&"full")),
		ScriptedCombatRandomSourceScript.new([1, 3, 3, 0, 0, 0, 4]),
		_resource(),
	)
	_assert_eq(full.outcome, CombatAttackResultScript.Outcome.HIT, "hook-free full path hits")
	_assert_eq(full.calculation.random_upper_bounds(), [2, 12, 12, 10, 6, 1, 8], "full RNG order is limb,dodge,parry,base,B,defense,wound")
	_assert_eq(full.calculation.random_draws(), [1, 3, 3, 0, 0, 0, 4], "result retains exact RNG evidence")
	_assert_true(full.interrupt_requested, "positive hit requests later busy interrupt")

	var returned_calculation: CombatAttackCalculation = full.calculation
	returned_calculation._selected_limb = &"mutated"
	returned_calculation._random_upper_bounds.clear()
	_assert_eq(full.calculation.selected_limb, &"右臂", "result calculation getter is defensive")
	_assert_eq(full.calculation.random_upper_bounds().size(), 7, "result RNG arrays are not aliased")
	var returned_mutation: CombatResourceMutationResult = full.resource_mutation
	returned_mutation._requested_damage = 999
	_assert_eq(full.resource_mutation.requested_damage, 8, "resource evidence getter is defensive")

	var profile: WeaponCombatProfileScript = _weapon(false)
	var source_attacker: CombatAttackerSnapshotScript = _attacker(0, 3, 0, 99, 0, 0, 0, 0, false, false, false, false, profile)
	var snapshotted_input: CombatAttackInputScript = CombatAttackInputScript.new(source_attacker, _defender(), _action(&"immutable"))
	profile._skill_type = &"mutated"
	source_attacker._weapon_profile._skill_type = &"mutated-again"
	var snapshot_result: CombatAttackResultScript = _resolve(
		snapshotted_input,
		ScriptedCombatRandomSourceScript.new([0, 3, 1, 0, 0, 1]),
		_resource(),
	)
	_assert_eq(snapshot_result.calculation.base_apply_damage, 99, "character aggregate apply/damage is snapshotted")
	_assert_eq(snapshot_result.calculation.attack_skill_type, &"sword", "weapon skill type is defensively snapshotted")

	var first_vitality: CharacterResourceStateScript = _resource()
	var second_vitality: CharacterResourceStateScript = _resource()
	_resolve(_input(), ScriptedCombatRandomSourceScript.new([0, 3, 3, 0, 0, 0]), first_vitality)
	_assert_eq(first_vitality.current, 92, "first character authority receives its attack damage")
	_assert_eq(second_vitality.current, 100, "independent character authority shares no resolver state")


func _hit_with_action_and_strength(
	damage_percent: int,
	base_strength: int,
	force_factor: int,
	strength_modifier: int,
	draws: Array[int],
) -> CombatAttackResult:
	return _resolve(
		CombatAttackInputScript.new(
			_attacker(0, 3, 0, 10, base_strength, force_factor, strength_modifier),
			_defender(),
			_action(&"damage-action", damage_percent),
		),
		ScriptedCombatRandomSourceScript.new(draws),
		_resource(),
	)


func _defense_loop_result(defense_draws: Array[int]) -> CombatAttackResult:
	var draws: Array[int] = [0, 20, 20, 0]
	draws.append_array(defense_draws)
	return _resolve(
		CombatAttackInputScript.new(
			_attacker(5, 0, 0, 30, 0),
			_defender(40, 0, 0, 0),
			_action(),
		),
		ScriptedCombatRandomSourceScript.new(draws),
		_resource(),
	)


func _assert_policy_stop(
	result: CombatAttackResult,
	expected_stage: int,
	expected_kind: int,
	expected_final_strength: int,
	expected_bounds: Array[int],
	message: String,
) -> void:
	var expected_reached_stage: int = CombatAttackCalculation.ReachedStage.INITIAL_STRENGTH_READY
	if expected_kind == CombatAttackResultScript.AuthoredPolicyKind.MARTIAL:
		expected_reached_stage = CombatAttackCalculation.ReachedStage.ACTION_FORCE_READY
	elif (
		expected_kind == CombatAttackResultScript.AuthoredPolicyKind.WEAPON
		or expected_kind == CombatAttackResultScript.AuthoredPolicyKind.ATTACKER
	):
		expected_reached_stage = CombatAttackCalculation.ReachedStage.MARTIAL_HOOK_PASSED
	_assert_eq(result.outcome, CombatAttackResultScript.Outcome.AUTHORED_HIT_POLICY_UNAVAILABLE, "%s returns unavailable" % message)
	_assert_eq(result.failure_stage, expected_stage, "%s stops at exact stage" % message)
	_assert_eq(result.authored_policy_kind, expected_kind, "%s retains policy kind" % message)
	_assert_false(result.authored_policy_id.is_empty(), "%s retains concrete provider ID" % message)
	_assert_eq(result.calculation.final_strength_bonus, expected_final_strength, "%s retains source-position B" % message)
	_assert_eq(result.calculation.random_upper_bounds(), expected_bounds, "%s consumes no later RNG" % message)
	_assert_eq(result.calculation.reached_stage, expected_reached_stage, "%s exposes no later calculated-zero fields" % message)
	_assert_false(result.resource_mutation.damage_transition_completed, "%s performs no resource mutation" % message)


func _assert_rng_failure(
	result: CombatAttackResult,
	expected_failure_stage: int,
	expected_reached_stage: int,
	expected_damage_completed: bool,
	message: String,
) -> void:
	_assert_eq(result.outcome, CombatAttackResultScript.Outcome.INVALID_SOURCE_STATE, "%s is typed invalid source state" % message)
	_assert_eq(result.failure_stage, expected_failure_stage, "%s retains exact failure stage" % message)
	_assert_eq(result.calculation.reached_stage, expected_reached_stage, "%s retains last completed calculation stage" % message)
	_assert_eq(result.threshold_candidate, CombatAttackResultScript.ThresholdCandidate.NOT_OBSERVED, "%s does not invent threshold observation" % message)
	_assert_eq(result.resource_mutation.damage_transition_completed, expected_damage_completed, "%s reports only actual prior mutation" % message)


func _input() -> CombatAttackInput:
	return CombatAttackInputScript.new(_attacker(), _defender(), _action())


func _attacker(
	combat_experience: int = 0,
	effective_attack_skill_level: int = 3,
	attack_usage_bonus: int = 0,
	unarmed_apply_damage: int = 10,
	base_strength: int = 6,
	force_factor: int = 0,
	strength_modifier: int = 0,
	current_inner_force: int = 0,
	lethal_intent: bool = false,
	force_hook: bool = false,
	martial_hook: bool = false,
	attacker_hook: bool = false,
	weapon: WeaponCombatProfile = null,
	living: bool = true,
) -> CombatAttackerSnapshot:
	return CombatAttackerSnapshotScript.new(
		&"attacker-1",
		living,
		combat_experience,
		0,
		0,
		weapon.skill_type if weapon != null else &"unarmed",
		effective_attack_skill_level,
		attack_usage_bonus,
		unarmed_apply_damage,
		CombatStrengthProjectionScript.new(base_strength, force_factor, strength_modifier),
		current_inner_force,
		lethal_intent,
		&"force:test" if force_hook else &"",
		(
			CombatHitPolicyStatusScript.Value.AUTHORED_POLICY_UNAVAILABLE
			if force_hook
			else CombatHitPolicyStatusScript.Value.NOT_APPLICABLE
		),
		&"martial:test" if martial_hook else &"",
		(
			CombatHitPolicyStatusScript.Value.AUTHORED_POLICY_UNAVAILABLE
			if martial_hook
			else CombatHitPolicyStatusScript.Value.NOT_APPLICABLE
		),
		(
			CombatHitPolicyStatusScript.Value.AUTHORED_POLICY_UNAVAILABLE
			if attacker_hook
			else CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT
		),
		weapon,
	)


func _attacker_with_policies(
	weapon: WeaponCombatProfile = null,
	projected_skill_type: StringName = &"unarmed",
	projected_apply_damage: int = 10,
	base_strength: int = 0,
	force_factor: int = 0,
	current_inner_force: int = 0,
	mapped_force_skill_id: StringName = &"",
	force_policy_status: int = CombatHitPolicyStatusScript.Value.NOT_APPLICABLE,
	mapped_attack_skill_id: StringName = &"",
	martial_policy_status: int = CombatHitPolicyStatusScript.Value.NOT_APPLICABLE,
	attacker_policy_status: int = CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT,
	lethal_intent: bool = false,
	character_id: StringName = &"attacker-1",
) -> CombatAttackerSnapshot:
	return CombatAttackerSnapshotScript.new(
		character_id,
		true,
		0,
		0,
		0,
		projected_skill_type,
		3,
		0,
		projected_apply_damage,
		CombatStrengthProjectionScript.new(base_strength, force_factor, 0),
		current_inner_force,
		lethal_intent,
		mapped_force_skill_id,
		force_policy_status,
		mapped_attack_skill_id,
		martial_policy_status,
		attacker_policy_status,
		weapon,
	)


func _defender(
	combat_experience: int = 1,
	dodge_level: int = 2,
	parry_level: int = 2,
	unarmed_level: int = 2,
	busy: bool = false,
	armor: int = 0,
	has_weapon: bool = false,
	limbs: Array[StringName] = [&"头", &"右臂"],
	living: bool = true,
	defense_usage_bonus: int = 0,
) -> CombatDefenderSnapshot:
	return CombatDefenderSnapshotScript.new(
		&"defender-1",
		living,
		busy,
		combat_experience,
		0,
		0,
		dodge_level,
		parry_level,
		unarmed_level,
		defense_usage_bonus,
		armor,
		has_weapon,
		limbs,
	)


func _defender_with_id(character_id: StringName) -> CombatDefenderSnapshot:
	return CombatDefenderSnapshotScript.new(
		character_id,
		true,
		false,
		1,
		0,
		0,
		2,
		2,
		2,
		0,
		0,
		false,
		[&"头", &"右臂"],
	)


func _weapon(
	hit_policy_required: bool = false,
) -> WeaponCombatProfile:
	return WeaponCombatProfileScript.new(
		&"weapon:sword:test",
		&"sword",
		(
			CombatHitPolicyStatusScript.Value.AUTHORED_POLICY_UNAVAILABLE
			if hit_policy_required
			else CombatHitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT
		),
	)


func _action(
	action_id: StringName = &"ordinary-action",
	damage_percent: int = 0,
	force_percent: int = 0,
) -> CombatActionDefinition:
	return CombatActionDefinitionScript.new(action_id, damage_percent, force_percent, &"伤害")


func _resource(current: int = 100, effective: int = 100, maximum: int = 100) -> CharacterResourceState:
	return CharacterResourceStateScript.new(current, effective, maximum)


func _resolve(
	input: CombatAttackInput,
	rng: ScriptedCombatRandomSource,
	vitality: CharacterResourceState,
) -> CombatAttackResult:
	return _resolve_with_resources(input, rng, _resource(), vitality, _resource())


func _resolve_with_resources(
	input: CombatAttackInput,
	rng: ScriptedCombatRandomSource,
	essence: CharacterResourceState,
	vitality: CharacterResourceState,
	spirit: CharacterResourceState,
) -> CombatAttackResult:
	return CombatAttackResolverScript.resolve(input, essence, vitality, spirit, rng)


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
