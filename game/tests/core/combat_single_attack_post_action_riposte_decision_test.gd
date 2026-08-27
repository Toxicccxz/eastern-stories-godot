extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const CharacterResourceStateScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const ActionDefinitionScript := preload(
	"res://core/combat/action/combat_action_definition.gd"
)
const ActionSetScript := preload("res://core/combat/action/combat_action_set.gd")
const ActionSelectionInputScript := preload(
	"res://core/combat/action/combat_action_selection_input.gd"
)
const ActionSelectorScript := preload(
	"res://core/combat/action/combat_action_selector.gd"
)
const AttackerSnapshotScript := preload(
	"res://core/combat/resolution/combat_attacker_snapshot.gd"
)
const DefenderSnapshotScript := preload(
	"res://core/combat/resolution/combat_defender_snapshot.gd"
)
const StrengthProjectionScript := preload(
	"res://core/combat/resolution/combat_strength_projection.gd"
)
const AttackInputScript := preload("res://core/combat/resolution/combat_attack_input.gd")
const HitPolicyStatusScript := preload(
	"res://core/combat/resolution/combat_hit_policy_status.gd"
)
const ProgressionFactsScript := preload(
	"res://core/combat/completion/combat_progression_facts.gd"
)
const BusyProjectionScript := preload(
	"res://core/combat/completion/combat_busy_interrupt_projection.gd"
)
const RelationshipStateScript := preload(
	"res://core/combat/relationship/combat_relationship_state.gd"
)
const FailingRelationshipStateScript := preload(
	"res://tests/support/failing_combat_relationship_state.gd"
)
const FightFactsScript := preload(
	"res://core/combat/fight/combat_fight_decision_facts.gd"
)
const FightServiceScript := preload(
	"res://core/combat/fight/combat_fight_decision_service.gd"
)
const AttackTypeScript := preload("res://core/combat/fight/combat_attack_type.gd")
const ExecutionResultScript := preload(
	"res://core/combat/execution/combat_single_attack_execution_result.gd"
)
const ExecutionServiceScript := preload(
	"res://core/combat/execution/combat_single_attack_execution_service.gd"
)
const RawComposureAuthorityScript := preload(
	"res://core/combat/execution/combat_raw_composure_authority.gd"
)
const ScriptedRandomSourceScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)
const WeaponCombatProfileScript := preload(
	"res://core/combat/resolution/weapon_combat_profile.gd"
)
const EffectRegistryScript := preload(
	"res://core/skills/improvement_effects/skill_improvement_effect_registry.gd"
)
const PeriodicEffectScript := preload(
	"res://core/skills/improvement_effects/periodic_attribute_improvement_effect.gd"
)

const ATTACKER_ID: StringName = &"attacker-1"
const VICTIM_ID: StringName = &"defender-1"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_upstream_and_action_boundaries()
	_test_caller_authority_binding()
	_test_action_selection_rng_evidence()
	_test_legacy_damage_mapping()
	_test_post_relationship_then_post_action_order()
	_test_original_forward_weapon_context()
	_test_riposte_predicate_and_boundaries()
	_test_live_post_progression_composure()
	_test_request_shape_rng_evidence_and_independence()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_upstream_and_action_boundaries() -> void:
	var pair: Array[CombatRelationshipState] = _pair()
	var stopped: CombatFightDecisionResult = FightServiceScript.decide(
		FightFactsScript.new(
			ATTACKER_ID, false, true, null, 1, 0,
			VICTIM_ID, true, false, 1,
		),
		pair[0], pair[1], null,
	)
	var stopped_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var stopped_result: CombatSingleAttackExecutionResult = ExecutionServiceScript.execute(
		stopped,
		_selection_input(_action()),
		_input(_action()),
		_character(), _character(1),
		null,
		_facts(ATTACKER_ID, _character()), _facts(VICTIM_ID, _character(1)),
		_not_busy(), null, pair[0], pair[1], stopped_rng,
	)
	_assert_eq(stopped_result.outcome, ExecutionResultScript.Outcome.UPSTREAM_NOT_APPLICABLE, "completed non-attack B1 decision is a typed stop")
	_assert_eq(stopped_rng.call_count(), 0, "upstream non-attack consumes no composition RNG")
	var incoherent_stopped: CombatFightDecisionResult = stopped.duplicate_snapshot()
	incoherent_stopped._attack_type = AttackTypeScript.Value.REGULAR
	var incoherent_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var incoherent_result: CombatSingleAttackExecutionResult = ExecutionServiceScript.execute(
		incoherent_stopped, _selection_input(_action()), _input(_action()),
		_character(), _character(1), null,
		_facts(ATTACKER_ID, _character()), _facts(VICTIM_ID, _character(1)),
		_not_busy(), null, pair[0], pair[1], incoherent_rng,
	)
	_assert_eq(incoherent_result.outcome, ExecutionResultScript.Outcome.INVALID_UPSTREAM_RESULT, "incoherent no-action outcome with REGULAR intent is rejected")
	_assert_eq(incoherent_rng.call_count(), 0, "incoherent B1 evidence consumes no B2A RNG")

	var invalid_pair: Array[CombatRelationshipState] = _pair()
	var invalid: CombatFightDecisionResult = FightServiceScript.decide(
		_fight_facts(0, false), invalid_pair[0], invalid_pair[1],
		ScriptedRandomSourceScript.new([0]),
	)
	var invalid_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var invalid_result: CombatSingleAttackExecutionResult = ExecutionServiceScript.execute(
		invalid, _selection_input(_action()), _input(_action()),
		_character(), _character(1), null, _facts(ATTACKER_ID, _character()),
		_facts(VICTIM_ID, _character(1)), _not_busy(), null,
		invalid_pair[0], invalid_pair[1], invalid_rng,
	)
	_assert_eq(invalid_result.outcome, ExecutionResultScript.Outcome.INVALID_UPSTREAM_RESULT, "failed B1 result is rejected")
	_assert_eq(invalid_rng.call_count(), 0, "failed B1 result reaches no action RNG")

	var no_source: Dictionary = _regular_context([0])
	var no_source_result: CombatSingleAttackExecutionResult = ExecutionServiceScript.execute(
		no_source["decision"], ActionSelectionInputScript.new(), _input(_action()),
		no_source["attacker"], no_source["defender"],
		RawComposureAuthorityScript.new(ATTACKER_ID, no_source["attacker"].attributes),
		_facts(ATTACKER_ID, no_source["attacker"]),
		_facts(VICTIM_ID, no_source["defender"]), _not_busy(), null,
		no_source["relationships"][0], no_source["relationships"][1], no_source["rng"],
	)
	_assert_eq(no_source_result.outcome, ExecutionResultScript.Outcome.ACTION_SELECTION_FAILED, "action provider failure is typed")
	_assert_eq(no_source["rng"].call_count(), 1, "provider failure preserves only prior B1 RNG")
	_assert_true(no_source["relationships"][1].has_opponent(ATTACKER_ID), "action failure preserves B1 reciprocal mutation")

	var missing_data: Dictionary = _regular_context([0])
	var missing_data_result: CombatSingleAttackExecutionResult = ExecutionServiceScript.execute(
		missing_data["decision"], ActionSelectionInputScript.new(true, null), _input(_action()),
		missing_data["attacker"], missing_data["defender"],
		RawComposureAuthorityScript.new(ATTACKER_ID, missing_data["attacker"].attributes),
		_facts(ATTACKER_ID, missing_data["attacker"]),
		_facts(VICTIM_ID, missing_data["defender"]), _not_busy(), null,
		missing_data["relationships"][0], missing_data["relationships"][1], missing_data["rng"],
	)
	_assert_eq(missing_data_result.outcome, ExecutionResultScript.Outcome.ACTION_SELECTION_FAILED, "provider-present data-unavailable remains typed")
	_assert_eq(missing_data["rng"].call_count(), 1, "unavailable provider consumes no action RNG")

	var invalid_draw: Dictionary = _regular_context([0, 1])
	var invalid_draw_result: CombatSingleAttackExecutionResult = ExecutionServiceScript.execute(
		invalid_draw["decision"], _selection_input(_action()), _input(_action()),
		invalid_draw["attacker"], invalid_draw["defender"],
		RawComposureAuthorityScript.new(ATTACKER_ID, invalid_draw["attacker"].attributes),
		_facts(ATTACKER_ID, invalid_draw["attacker"]),
		_facts(VICTIM_ID, invalid_draw["defender"]), _not_busy(), null,
		invalid_draw["relationships"][0], invalid_draw["relationships"][1], invalid_draw["rng"],
	)
	_assert_eq(invalid_draw_result.outcome, ExecutionResultScript.Outcome.ACTION_SELECTION_FAILED, "invalid action draw stops before ordinary attack")
	_assert_eq(invalid_draw_result.combined_random_upper_bounds(), [3, 1], "invalid action draw appears once after B1 RNG")
	_assert_true(invalid_draw["relationships"][1].has_opponent(ATTACKER_ID), "invalid action draw preserves reciprocal opponent")

	var mismatch: Dictionary = _regular_context([0, 0])
	var selected: CombatActionDefinition = _action(&"selected")
	var mismatch_result: CombatSingleAttackExecutionResult = ExecutionServiceScript.execute(
		mismatch["decision"], _selection_input(selected), _input(_action(&"projected")),
		mismatch["attacker"], mismatch["defender"],
		RawComposureAuthorityScript.new(ATTACKER_ID, mismatch["attacker"].attributes),
		_facts(ATTACKER_ID, mismatch["attacker"]),
		_facts(VICTIM_ID, mismatch["defender"]), _not_busy(), null,
		mismatch["relationships"][0], mismatch["relationships"][1], mismatch["rng"],
	)
	_assert_eq(mismatch_result.outcome, ExecutionResultScript.Outcome.SELECTED_ACTION_PROJECTION_MISMATCH, "selected action mismatch stops before resolution")
	_assert_eq(mismatch["rng"].requested_bounds(), [3, 1], "projection mismatch consumes B1 then action RNG only")
	_assert_eq(mismatch["defender"].vitality.current, 100, "projection mismatch mutates no resource")

	var regular: Dictionary = _regular_context([0, 0, 0, 0])
	var regular_result: CombatSingleAttackExecutionResult = _execute(regular, _input(_action()), _selection_input(_action()))
	_assert_eq(regular_result.attack_type, AttackTypeScript.Value.REGULAR, "REGULAR numeric zero remains an executable intent")
	_assert_true(regular_result.has_legacy_damage, "completed ordinary attack has explicit legacy damage presence")

	var quick: Dictionary = _quick_context([0, 0, 0])
	var quick_result: CombatSingleAttackExecutionResult = _execute(quick, _input(_action(), 0, 1, 3, 2, 2, 10, 6, true), _selection_input(_action()), true)
	_assert_eq(quick_result.attack_type, AttackTypeScript.Value.QUICK, "QUICK B1 intent executes through the same composition")
	_assert_false(quick_result.riposte_eligible, "QUICK never enters the legacy riposte branch")


func _test_caller_authority_binding() -> void:
	var wrong_live_state: Dictionary = _regular_context([0, 0])
	var wrong_live_result: CombatSingleAttackExecutionResult = ExecutionServiceScript.execute(
		wrong_live_state["decision"], _selection_input(_action()), _input(_action()),
		wrong_live_state["attacker"], wrong_live_state["defender"],
		RawComposureAuthorityScript.new(
			ATTACKER_ID, wrong_live_state["defender"].attributes
		),
		_facts(ATTACKER_ID, wrong_live_state["attacker"]),
		_facts(VICTIM_ID, wrong_live_state["defender"]),
		_not_busy(), null,
		wrong_live_state["relationships"][0], wrong_live_state["relationships"][1],
		wrong_live_state["rng"],
	)
	_assert_eq(wrong_live_result.outcome, ExecutionResultScript.Outcome.CALLER_AUTHORITY_MISMATCH, "raw cps authority bound to another character is rejected")
	_assert_eq(wrong_live_result.failure_stage, ExecutionResultScript.FailureStage.CALLER_AUTHORITY_BINDING, "authority mismatch has an explicit failure stage")
	_assert_eq(wrong_live_result.reached_stage, ExecutionResultScript.ReachedStage.UPSTREAM_VALIDATED, "authority mismatch stops before action selection")
	_assert_eq(wrong_live_state["rng"].call_count(), 1, "authority mismatch consumes only the already-completed B1 draw")
	_assert_eq(wrong_live_state["defender"].vitality.current, 100, "authority mismatch mutates no combat resource")
	_assert_true(wrong_live_state["relationships"][1].has_opponent(ATTACKER_ID), "authority mismatch preserves the prior B1 reciprocal relation")
	_assert_true(wrong_live_result.partial_mutation_preserved, "authority mismatch reports the prior B1 mutation")

	var wrong_owner: Dictionary = _regular_context([0, 0])
	var foreign_attacker_relationship: CombatRelationshipState = RelationshipStateScript.new(&"other")
	var wrong_owner_result: CombatSingleAttackExecutionResult = ExecutionServiceScript.execute(
		wrong_owner["decision"], _selection_input(_action()), _input(_action()),
		wrong_owner["attacker"], wrong_owner["defender"],
		RawComposureAuthorityScript.new(ATTACKER_ID, wrong_owner["attacker"].attributes),
		_facts(ATTACKER_ID, wrong_owner["attacker"]),
		_facts(VICTIM_ID, wrong_owner["defender"]),
		_not_busy(), null, foreign_attacker_relationship,
		wrong_owner["relationships"][1], wrong_owner["rng"],
	)
	_assert_eq(wrong_owner_result.outcome, ExecutionResultScript.Outcome.CALLER_AUTHORITY_MISMATCH, "relationship owner mismatch is rejected")
	_assert_eq(wrong_owner["rng"].call_count(), 1, "relationship owner mismatch reaches no action RNG")
	_assert_eq(wrong_owner["defender"].vitality.current, 100, "relationship owner mismatch reaches no ordinary mutation")

	var wrong_facts: Dictionary = _regular_context([0, 0])
	var wrong_facts_result: CombatSingleAttackExecutionResult = ExecutionServiceScript.execute(
		wrong_facts["decision"], _selection_input(_action()), _input(_action()),
		wrong_facts["attacker"], wrong_facts["defender"],
		RawComposureAuthorityScript.new(ATTACKER_ID, wrong_facts["attacker"].attributes),
		_facts(VICTIM_ID, wrong_facts["attacker"]),
		_facts(VICTIM_ID, wrong_facts["defender"]),
		_not_busy(), null,
		wrong_facts["relationships"][0], wrong_facts["relationships"][1],
		wrong_facts["rng"],
	)
	_assert_eq(wrong_facts_result.outcome, ExecutionResultScript.Outcome.CALLER_AUTHORITY_MISMATCH, "progression facts identity mismatch is rejected")
	_assert_eq(wrong_facts["rng"].call_count(), 1, "facts mismatch reaches no action RNG")


func _test_action_selection_rng_evidence() -> void:
	var absent_result: CombatActionSelectionResult = ActionSelectorScript.select_action(
		ActionSelectionInputScript.new(), null
	)
	_assert_false(absent_result.random_reached, "no action source never reaches random selection")
	_assert_false(absent_result.random_attempted, "no action source never attempts random selection")

	var missing_rng_result: CombatActionSelectionResult = ActionSelectorScript.select_action(
		_selection_input(_action()), null
	)
	_assert_true(missing_rng_result.random_reached, "valid action data records reached random selection")
	_assert_false(missing_rng_result.random_attempted, "missing RNG records no attempted draw")
	_assert_eq(missing_rng_result.random_bound, 1, "missing RNG retains the independently known action bound")
	_assert_eq(missing_rng_result.random_draw, 0, "default zero draw is not confused with attempted evidence")

	var selected_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var selected_result: CombatActionSelectionResult = ActionSelectorScript.select_action(
		_selection_input(_action()), selected_rng
	)
	_assert_true(selected_result.random_reached, "selected action records random stage reach")
	_assert_true(selected_result.random_attempted, "selected action records attempted draw")
	_assert_eq(selected_result.random_upper_bounds(), [1], "selected action exposes one bound")
	_assert_eq(selected_result.random_draws(), [0], "selected action exposes explicit zero draw")
	_assert_eq(selected_rng.call_count(), 1, "selector consumes exactly one action draw")

	var first_action: CombatActionDefinition = _action(&"first")
	var second_action: CombatActionDefinition = _action(&"second")
	var outer: Dictionary = _regular_context([0, 1, 0, 0])
	var outer_selection: CombatActionSelectionInput = ActionSelectionInputScript.new(
		false, null, false, null, ActionSetScript.new([first_action, second_action])
	)
	var outer_result: CombatSingleAttackExecutionResult = _execute(
		outer, _input(second_action), outer_selection
	)
	_assert_eq(outer_result.selected_action_id, &"second", "outer composition executes exactly the selected action projection")
	_assert_eq(outer_result.combined_random_upper_bounds(), [3, 2, 2, 12], "outer RNG evidence orders B1/action/limb/dodge once each")
	_assert_eq(outer_result.combined_random_draws(), [0, 1, 0, 0], "outer RNG draws preserve source order without duplication")
	_assert_eq(outer["rng"].call_count(), 4, "one composed DODGE consumes each expected draw exactly once")


func _test_legacy_damage_mapping() -> void:
	var dodge: Dictionary = _regular_context([0, 0, 0, 0])
	dodge["relationships"][1].set_guarding(false)
	var dodge_result: CombatSingleAttackExecutionResult = _execute(dodge, _input(_action()), _selection_input(_action()))
	_assert_eq(dodge_result.legacy_damage, -1, "DODGE maps to legacy damage minus one")
	_assert_true(dodge_result.post_action_reached, "DODGE still reaches post_action position")

	var parry: Dictionary = _regular_context([0, 0, 0, 3, 0])
	var parry_input: CombatAttackInput = _input(_action(), 0, 1, 2, 2, 2)
	var parry_result: CombatSingleAttackExecutionResult = _execute(parry, parry_input, _selection_input(_action()))
	_assert_eq(parry_result.legacy_damage, -2, "PARRY maps to legacy damage minus two")

	var zero: Dictionary = _regular_context([0, 0, 0, 3, 3, 0, 0])
	var zero_input: CombatAttackInput = _input(_action(), 0, 1, 2, 2, 2, 1, 0)
	var zero_result: CombatSingleAttackExecutionResult = _execute(zero, zero_input, _selection_input(_action()))
	_assert_eq(zero_result.legacy_damage, 0, "HIT preserves exact requested zero damage")

	var positive: Dictionary = _regular_context([0, 0, 0, 3, 3, 9, 5, 0])
	var positive_input: CombatAttackInput = _input(_action(), 0, 1, 2, 2, 2, 10, 6)
	var positive_result: CombatSingleAttackExecutionResult = _execute(positive, positive_input, _selection_input(_action()))
	_assert_true(positive_result.legacy_damage > 0, "positive HIT uses requested damage rather than actual clamped loss")
	_assert_eq(positive_result.legacy_damage, positive_result.ordinary_attack_result.base_result.calculation.requested_damage, "HIT legacy damage equals resolver requested damage exactly")

	var saturated: Dictionary = _regular_context([0, 0, 0, 3, 3, 9, 5, 0])
	saturated["relationships"][0].mark_lethal_target(VICTIM_ID)
	saturated["defender"].vitality.current = 1
	var saturated_result: CombatSingleAttackExecutionResult = _execute(
		saturated, positive_input, _selection_input(_action())
	)
	_assert_eq(saturated["defender"].vitality.current, -1, "legacy damage fixture saturates current kee at minus one")
	_assert_true(saturated_result.legacy_damage > 2, "requested D is not replaced by saturated resource delta two")

	var incomplete: Dictionary = _regular_context([0, 0, 0, 3, 3])
	var incomplete_input: CombatAttackInput = _input(_action(), 0, 1, 2, 2, 2, 0, 0)
	var incomplete_result: CombatSingleAttackExecutionResult = _execute(incomplete, incomplete_input, _selection_input(_action()))
	_assert_eq(incomplete_result.outcome, ExecutionResultScript.Outcome.ORDINARY_ATTACK_FAILED, "incomplete resolver stops composition")
	_assert_false(incomplete_result.has_legacy_damage, "incomplete attack has no fake legacy damage")
	_assert_false(incomplete_result.post_action_reached, "incomplete attack reaches neither relationship nor post_action")


func _test_post_relationship_then_post_action_order() -> void:
	var friendly: Dictionary = _regular_context([0, 0, 0, 3, 3, 9, 5, 0, 4])
	friendly["relationships"][0].add_opponent(VICTIM_ID)
	var policy_action: CombatActionDefinition = _action(&"policy-action", &"throw-weapon")
	var result: CombatSingleAttackExecutionResult = _execute(
		friendly,
		_input(policy_action, 0, 1, 2, 2, 2, 10, 6),
		_selection_input(policy_action),
	)
	_assert_eq(result.outcome, ExecutionResultScript.Outcome.AUTHORED_POST_ACTION_POLICY_UNAVAILABLE, "authored post_action is a typed future-policy stop")
	_assert_true(result.post_relationship_result.attacker_removal_succeeded, "friendly stop removes attacker relation before post_action")
	_assert_true(result.post_relationship_result.defender_removal_succeeded, "friendly stop removes defender relation before post_action")
	_assert_eq(result.post_relationship_result.winner_random_draw, 4, "winner selection completes before unavailable post_action")
	_assert_true(result.post_action_policy_present, "nonempty post_action policy presence is explicit")
	_assert_eq(result.post_action_policy_id, &"throw-weapon", "post_action policy ID is preserved")
	_assert_false(result.riposte_evaluation_reached, "unavailable post_action stops before riposte")

	var guarded: Dictionary = _regular_context([0, 0, 0, 0])
	guarded["relationships"][1].set_guarding(true)
	var guarded_policy: CombatActionDefinition = _action(&"guarded-policy", &"bash-weapon")
	var guarded_result: CombatSingleAttackExecutionResult = _execute(
		guarded, _input(guarded_policy), _selection_input(guarded_policy)
	)
	_assert_true(guarded["relationships"][1].guarding, "unavailable post_action does not clear victim guard")
	_assert_false(guarded_result.has_riposte_request, "unavailable post_action produces no reverse request")

	for policy_case: Array in [
		["parry", [0, 0, 0, 3, 0], _input(_action(&"p", &"policy"), 0, 1, 2, 2, 2)],
		["zero hit", [0, 0, 0, 3, 3, 0, 0], _input(_action(&"z", &"policy"), 0, 1, 2, 2, 2, 1, 0)],
	]:
		var policy_draws: Array[int] = []
		policy_draws.assign(policy_case[1])
		var policy_context: Dictionary = _regular_context(policy_draws)
		policy_context["relationships"][1].set_guarding(true)
		var policy_input: CombatAttackInput = policy_case[2]
		var policy_result: CombatSingleAttackExecutionResult = _execute(
			policy_context, policy_input, _selection_input(policy_input.selected_action)
		)
		_assert_eq(policy_result.outcome, ExecutionResultScript.Outcome.AUTHORED_POST_ACTION_POLICY_UNAVAILABLE, "%s reaches unavailable post_action" % policy_case[0])
		_assert_true(policy_context["relationships"][1].guarding, "%s unavailable policy leaves guard set" % policy_case[0])

	var failed_post: Dictionary = _regular_context([0, 0, 0, 3, 3, 9, 5, 0])
	failed_post["relationships"][0].add_opponent(VICTIM_ID)
	var failing_defender: CombatRelationshipState = FailingRelationshipStateScript.new(VICTIM_ID)
	failing_defender.add_opponent(ATTACKER_ID)
	failing_defender.fail_remove_id = ATTACKER_ID
	failed_post["relationships"][1] = failing_defender
	var failed_post_result: CombatSingleAttackExecutionResult = _execute(
		failed_post, _input(_action(), 0, 1, 2, 2, 2, 10, 6), _selection_input(_action())
	)
	_assert_eq(failed_post_result.outcome, ExecutionResultScript.Outcome.POST_RELATIONSHIP_FAILED, "relationship invariant failure stops composition")
	_assert_false(failed_post_result.post_action_reached, "relationship failure prevents post_action")
	_assert_false(failed_post_result.riposte_evaluation_reached, "relationship failure prevents riposte")
	_assert_true(failed_post_result.partial_mutation_preserved, "relationship failure reports prior attacker-side removal")

	var completed_friendly: Dictionary = _regular_context([0, 0, 0, 3, 3, 9, 5, 0, 4])
	completed_friendly["relationships"][0].add_opponent(VICTIM_ID)
	var completed_friendly_result: CombatSingleAttackExecutionResult = _execute(
		completed_friendly, _input(_action(), 0, 1, 2, 2, 2, 10, 6), _selection_input(_action())
	)
	_assert_eq(completed_friendly_result.outcome, ExecutionResultScript.Outcome.COMPLETED_WITHOUT_RIPOSTE, "positive friendly HIT completes after winner without riposte")
	_assert_eq(completed_friendly_result.combined_random_upper_bounds()[-1], 6, "winner random is terminal RNG for positive friendly HIT")
	_assert_false(completed_friendly_result.riposte_random_reached, "positive friendly winner never also reaches riposte RNG")


func _test_original_forward_weapon_context() -> void:
	var context: Dictionary = _regular_context([0, 0, 0, 0])
	var weapon: WeaponCombatProfile = WeaponCombatProfileScript.new(
		&"forward-weapon-7",
		&"sword",
		HitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT,
	)
	var action: CombatActionDefinition = _action(&"weapon-action", &"future-post-action")
	var result: CombatSingleAttackExecutionResult = _execute(
		context,
		_input(action, 0, 1, 3, 2, 2, 10, 6, false, weapon),
		_selection_input(action),
	)
	_assert_eq(result.outcome, ExecutionResultScript.Outcome.AUTHORED_POST_ACTION_POLICY_UNAVAILABLE, "weapon post_action still stops at the typed future-policy boundary")
	_assert_true(result.post_action_weapon_present, "post_action records original forward weapon presence")
	_assert_eq(result.post_action_weapon_id, &"forward-weapon-7", "post_action receives the exact original forward weapon identity")
	_assert_eq(result.selected_action_id, &"weapon-action", "weapon context does not replace the selected forward action")
	_assert_eq(context["rng"].call_count(), 4, "weapon-context evidence consumes no additional RNG")


func _test_riposte_predicate_and_boundaries() -> void:
	for legacy_case: Array in [
		["dodge", [0, 0, 0, 0, 4], _input(_action())],
		["parry", [0, 0, 0, 3, 0, 4], _input(_action(), 0, 1, 2, 2, 2)],
		["zero", [0, 0, 0, 3, 3, 0, 0, 4], _input(_action(), 0, 1, 2, 2, 2, 1, 0)],
	]:
		var case_draws: Array[int] = []
		case_draws.assign(legacy_case[1])
		var context: Dictionary = _regular_context(case_draws)
		context["attacker"].attributes.composure = 5
		context["relationships"][1].set_guarding(true)
		var result: CombatSingleAttackExecutionResult = _execute(context, legacy_case[2], _selection_input(_action()))
		_assert_true(result.riposte_eligible, "%s with regular guarded victim is riposte-eligible" % legacy_case[0])
		_assert_eq(result.riposte_random_bound, 5, "%s uses live attacker raw cps bound" % legacy_case[0])
		_assert_eq(result.riposte_request.attack_type, AttackTypeScript.Value.QUICK, "%s draw below five requests QUICK" % legacy_case[0])
		_assert_false(context["relationships"][1].guarding, "%s clears victim guard before decision" % legacy_case[0])

	var equality: Dictionary = _regular_context([0, 0, 0, 0, 5])
	equality["attacker"].attributes.composure = 6
	equality["relationships"][1].set_guarding(true)
	var equality_result: CombatSingleAttackExecutionResult = _execute(equality, _input(_action()), _selection_input(_action()))
	_assert_eq(equality_result.riposte_request.attack_type, AttackTypeScript.Value.RIPOSTE, "draw equality five requests RIPOSTE")
	_assert_false(equality_result.riposte_request.attack_type == AttackTypeScript.Value.REGULAR, "reverse request type is never REGULAR")

	var no_guard: Dictionary = _regular_context([0, 0, 0, 0])
	no_guard["attacker"].attributes.composure = 6
	var no_guard_result: CombatSingleAttackExecutionResult = _execute(no_guard, _input(_action()), _selection_input(_action()))
	_assert_eq(no_guard_result.outcome, ExecutionResultScript.Outcome.COMPLETED_WITHOUT_RIPOSTE, "unguarded victim completes without riposte")
	_assert_false(no_guard_result.riposte_random_reached, "unguarded victim consumes no riposte RNG")

	var zero_bound: Dictionary = _regular_context([0, 0, 0, 0])
	zero_bound["attacker"].attributes.composure = 0
	zero_bound["relationships"][1].set_guarding(true)
	var zero_bound_result: CombatSingleAttackExecutionResult = _execute(zero_bound, _input(_action()), _selection_input(_action()))
	_assert_eq(zero_bound_result.outcome, ExecutionResultScript.Outcome.INVALID_RIPOSTE_RANDOM_BOUND, "zero live raw cps is an ordered typed boundary")
	_assert_false(zero_bound["relationships"][1].guarding, "zero bound preserves prior victim guard clear")
	_assert_false(zero_bound_result.riposte_random_attempted, "zero bound does not call RNG")

	var invalid_draw: Dictionary = _regular_context([0, 0, 0, 0, 6])
	invalid_draw["attacker"].attributes.composure = 6
	invalid_draw["relationships"][1].set_guarding(true)
	var invalid_draw_result: CombatSingleAttackExecutionResult = _execute(invalid_draw, _input(_action()), _selection_input(_action()))
	_assert_eq(invalid_draw_result.outcome, ExecutionResultScript.Outcome.RIPOSTE_RANDOM_DRAW_OUT_OF_RANGE, "riposte draw equal to bound is rejected")
	_assert_false(invalid_draw["relationships"][1].guarding, "invalid draw also preserves prior guard clear")

	var positive: Dictionary = _regular_context([0, 0, 0, 3, 3, 9, 5, 0])
	positive["attacker"].attributes.composure = 6
	positive["relationships"][0].mark_lethal_target(VICTIM_ID)
	positive["relationships"][1].set_guarding(true)
	var positive_result: CombatSingleAttackExecutionResult = _execute(positive, _input(_action(), 0, 1, 2, 2, 2, 10, 6), _selection_input(_action()))
	_assert_false(positive_result.riposte_eligible, "positive legacy damage does not riposte")
	_assert_true(positive["relationships"][1].guarding, "positive damage does not clear guarding")

	var quick_parry: Dictionary = _quick_context([0, 0, 1, 0])
	quick_parry["relationships"][1].set_guarding(true)
	var quick_parry_result: CombatSingleAttackExecutionResult = _execute(
		quick_parry, _input(_action(), 0, 1, 2, 2, 2, 10, 6, true), _selection_input(_action()), true
	)
	_assert_eq(quick_parry_result.legacy_damage, -2, "QUICK may complete a PARRY sentinel")
	_assert_false(quick_parry_result.riposte_eligible, "QUICK PARRY cannot riposte")
	_assert_true(quick_parry["relationships"][1].guarding, "QUICK PARRY does not clear victim guard")

	var quick_zero: Dictionary = _quick_context([0, 0, 1, 1, 0, 0])
	quick_zero["relationships"][1].set_guarding(true)
	var quick_zero_result: CombatSingleAttackExecutionResult = _execute(
		quick_zero, _input(_action(), 0, 1, 2, 2, 2, 1, 0, true), _selection_input(_action()), true
	)
	_assert_eq(quick_zero_result.legacy_damage, 0, "QUICK may complete reached zero HIT")
	_assert_false(quick_zero_result.riposte_eligible, "QUICK zero HIT cannot riposte")
	_assert_true(quick_zero["relationships"][1].guarding, "QUICK zero HIT does not clear victim guard")


func _test_live_post_progression_composure() -> void:
	var context: Dictionary = _regular_context([0, 0, 0, 0, 0, 1, 5])
	context["attacker"].attributes.composure = 6
	context["attacker"].attributes.force_factor = 100
	context["attacker"].skills.set_raw_level(&"unarmed", 28)
	context["attacker"].skills.set_learned_progress(&"unarmed", 841)
	context["relationships"][1].set_guarding(true)
	var registry: SkillImprovementEffectRegistry = EffectRegistryScript.new()
	registry.register_effect(
		PeriodicEffectScript.new(
			&"unarmed",
			PeriodicEffectScript.AttributeTarget.COMPOSURE,
		)
	)
	var input: CombatAttackInput = _input(_action(), 0, 1, 3, 100, 2)
	var result: CombatSingleAttackExecutionResult = _execute(
		context, input, _selection_input(_action()), false, registry
	)
	_assert_eq(context["attacker"].skills.raw_level(&"unarmed"), 29, "DODGE progression levels attack skill before riposte")
	_assert_eq(context["attacker"].attributes.composure, 8, "authored level-up effect changes live raw cps before riposte")
	_assert_eq(result.riposte_random_bound, 8, "riposte bound reads post-progression raw cps authority")
	_assert_false(result.riposte_random_bound == context["attacker"].attributes.effective_composure(), "riposte does not use effective cps with force factor")
	_assert_false(result.riposte_random_bound == context["defender"].attributes.composure, "riposte does not use victim raw cps")
	_assert_eq(result.riposte_request.attack_type, AttackTypeScript.Value.RIPOSTE, "post-progression draw five selects RIPOSTE")


func _test_request_shape_rng_evidence_and_independence() -> void:
	var first: Dictionary = _regular_context([0, 0, 0, 0, 4])
	first["attacker"].attributes.composure = 5
	first["relationships"][1].set_guarding(true)
	var first_result: CombatSingleAttackExecutionResult = _execute(first, _input(_action()), _selection_input(_action()))
	var request: CombatRiposteRequest = first_result.riposte_request
	_assert_eq(request.attacker_id, VICTIM_ID, "reverse request swaps original victim to attacker")
	_assert_eq(request.victim_id, ATTACKER_ID, "reverse request swaps original attacker to victim")
	_assert_eq(request.triggering_forward_action_id, &"ordinary-action", "reverse request retains trigger action evidence")
	_assert_eq(request.triggering_legacy_damage, -1, "reverse request retains trigger legacy damage")
	_assert_eq(request.random_bound, 5, "reverse request retains decision bound")
	_assert_eq(request.random_draw, 4, "reverse request retains decision draw")
	request._random_draw = 99
	_assert_eq(first_result.riposte_request.random_draw, 4, "returned reverse request cannot mutate stored result evidence")
	var returned_selection: CombatActionSelectionResult = first_result.action_selection_result
	returned_selection._random_draw = 99
	_assert_eq(first_result.action_selection_result.random_draw, 0, "returned action evidence cannot mutate stored result evidence")
	var returned_fight: CombatFightDecisionResult = first_result.fight_decision_result
	returned_fight._attack_type = AttackTypeScript.Value.RIPOSTE
	_assert_eq(first_result.fight_decision_result.attack_type, AttackTypeScript.Value.REGULAR, "returned B1 evidence cannot mutate stored result evidence")
	_assert_eq(first_result.combined_random_upper_bounds(), [3, 1, 2, 12, 5], "combined RNG evidence follows B1/action/ordinary/riposte source order")
	var mutated_bounds: Array[int] = first_result.combined_random_upper_bounds()
	mutated_bounds.clear()
	_assert_eq(first_result.combined_random_upper_bounds(), [3, 1, 2, 12, 5], "combined RNG evidence is defensive")
	_assert_eq(first["attacker"].vitality.current, 100, "reverse request does not execute nested reverse damage")

	var property_names: Array[StringName] = []
	for property: Dictionary in request.get_property_list():
		property_names.append(StringName(property["name"]))
	_assert_false(property_names.has(&"attack_input"), "reverse request embeds no CombatAttackInput")
	_assert_false(property_names.has(&"attacker_state"), "reverse request embeds no CharacterState authority")
	_assert_false(property_names.has(&"weapon"), "reverse request embeds no weapon authority")
	_assert_false(property_names.has(&"selected_action"), "reverse request embeds no selected reverse action")
	_assert_false(property_names.has(&"attacker_snapshot"), "reverse request embeds no attacker snapshot")
	_assert_false(property_names.has(&"random_source"), "reverse request embeds no RNG authority")
	_assert_false(property_names.has(&"raw_composure_authority"), "reverse request embeds no live raw-cps authority")

	var second: Dictionary = _regular_context([0, 0, 0, 0])
	second["attacker"].attributes.composure = 5
	second["relationships"][1].set_guarding(false)
	var second_result: CombatSingleAttackExecutionResult = _execute(second, _input(_action()), _selection_input(_action()))
	_assert_false(second_result.has_riposte_request, "independent character pair shares no reverse-request state")
	_assert_false(second["relationships"][1].guarding, "independent guard authority remains unchanged")


func _execute(
	context: Dictionary,
	input: CombatAttackInput,
	selection: CombatActionSelectionInput,
	busy: bool = false,
	registry: SkillImprovementEffectRegistry = null,
) -> CombatSingleAttackExecutionResult:
	var busy_projection: CombatBusyInterruptProjection = _not_busy()
	if busy:
		busy_projection = BusyProjectionScript.new(
			BusyProjectionScript.BusyKind.FUNCTION,
			BusyProjectionScript.InterruptKind.INTEGER,
		)
	return ExecutionServiceScript.execute(
		context["decision"], selection, input,
		context["attacker"], context["defender"],
		RawComposureAuthorityScript.new(
			ATTACKER_ID, context["attacker"].attributes
		),
		_facts(
			ATTACKER_ID,
			context["attacker"],
			false if registry != null else true,
			input.attacker.projected_attack_skill_type,
		),
		_facts(VICTIM_ID, context["defender"]),
		busy_projection, null,
		context["relationships"][0], context["relationships"][1],
		context["rng"], registry,
	)


func _regular_context(draws: Array[int]) -> Dictionary:
	var attacker: CharacterState = _character()
	var defender: CharacterState = _character(1)
	var relationships: Array[CombatRelationshipState] = _pair()
	var rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new(draws)
	var decision: CombatFightDecisionResult = FightServiceScript.decide(
		_fight_facts(1, false), relationships[0], relationships[1], rng
	)
	return {"attacker": attacker, "defender": defender, "relationships": relationships, "rng": rng, "decision": decision}


func _quick_context(draws: Array[int]) -> Dictionary:
	var attacker: CharacterState = _character()
	var defender: CharacterState = _character(1)
	var relationships: Array[CombatRelationshipState] = _pair()
	var rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new(draws)
	var decision: CombatFightDecisionResult = FightServiceScript.decide(
		_fight_facts(1, true), relationships[0], relationships[1], rng
	)
	return {"attacker": attacker, "defender": defender, "relationships": relationships, "rng": rng, "decision": decision}


func _fight_facts(victim_raw_composure: int, victim_busy: bool) -> CombatFightDecisionFacts:
	return FightFactsScript.new(
		ATTACKER_ID, true, true, null, 1, 0,
		VICTIM_ID, true, victim_busy, victim_raw_composure,
	)


func _selection_input(action: CombatActionDefinition) -> CombatActionSelectionInput:
	return ActionSelectionInputScript.new(false, null, false, null, ActionSetScript.new([action]))


func _action(
	action_id: StringName = &"ordinary-action",
	post_action_policy_id: StringName = &"",
) -> CombatActionDefinition:
	return ActionDefinitionScript.new(
		action_id, 0, 0, &"伤害", &"presentation", "legacy text", "$w",
		post_action_policy_id,
	)


func _input(
	action: CombatActionDefinition,
	attacker_exp: int = 0,
	defender_exp: int = 1,
	attack_level: int = 3,
	dodge_level: int = 2,
	parry_level: int = 2,
	apply_damage: int = 10,
	base_strength: int = 6,
	busy: bool = false,
	weapon_profile: WeaponCombatProfile = null,
) -> CombatAttackInput:
	var attack_skill_type: StringName = &"unarmed"
	if weapon_profile != null:
		attack_skill_type = weapon_profile.skill_type
	return AttackInputScript.new(
		AttackerSnapshotScript.new(
			ATTACKER_ID, true, attacker_exp, 0, 0, attack_skill_type, attack_level, 0,
			apply_damage, StrengthProjectionScript.new(base_strength, 0, 0), false,
			&"", HitPolicyStatusScript.Value.NOT_APPLICABLE,
			&"", HitPolicyStatusScript.Value.NOT_APPLICABLE,
			HitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT,
			weapon_profile,
		),
		DefenderSnapshotScript.new(
			VICTIM_ID, true, busy, defender_exp, 0, 0,
			dodge_level, parry_level, 2, 0, 0, false, [&"头", &"右臂"],
		),
		action,
	)


func _facts(
	character_id: StringName,
	character: CharacterState,
	is_user: bool = true,
	attack_skill_id: StringName = &"unarmed",
) -> CombatProgressionFacts:
	return ProgressionFactsScript.new(
		character_id, is_user,
		character.attributes.intelligence,
		character.attributes.spirituality,
		attack_skill_id, true,
	)


func _not_busy() -> CombatBusyInterruptProjection:
	return BusyProjectionScript.new(
		BusyProjectionScript.BusyKind.NOT_BUSY,
		BusyProjectionScript.InterruptKind.INTEGER,
	)


func _pair() -> Array[CombatRelationshipState]:
	return [RelationshipStateScript.new(ATTACKER_ID), RelationshipStateScript.new(VICTIM_ID)]


func _character(combat_experience: int = 0) -> CharacterState:
	var character: CharacterState = CharacterStateScript.new()
	character.attributes.intelligence = 20
	character.attributes.spirituality = 20
	character.attributes.composure = 1
	character.attributes.courage = 1
	character.essence = CharacterResourceStateScript.new(100, 100, 100)
	character.vitality = CharacterResourceStateScript.new(100, 100, 100)
	character.spirit = CharacterResourceStateScript.new(100, 100, 100)
	character.progression.combat_experience = combat_experience
	return character


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
