extends RefCounted

const AttackTypeScript := preload("res://core/combat/fight/combat_attack_type.gd")
const PerceptionProjectionScript := preload(
	"res://core/combat/fight/combat_perception_skill_projection.gd"
)
const FightFactsScript := preload(
	"res://core/combat/fight/combat_fight_decision_facts.gd"
)
const FightResultScript := preload(
	"res://core/combat/fight/combat_fight_decision_result.gd"
)
const FightServiceScript := preload(
	"res://core/combat/fight/combat_fight_decision_service.gd"
)
const RelationshipStateScript := preload(
	"res://core/combat/relationship/combat_relationship_state.gd"
)
const FailingRelationshipStateScript := preload(
	"res://tests/support/failing_combat_relationship_state.gd"
)
const ScriptedRandomSourceScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)
const CharacterSkillStateScript := preload(
	"res://core/skills/character_skill_state.gd"
)

const ATTACKER_ID: StringName = &"attacker-1"
const VICTIM_ID: StringName = &"victim-1"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_input_coherence_and_nonliving_attacker()
	_test_lazy_rng_and_visible_branch_facts()
	_test_visibility_and_effective_perception()
	_test_perception_failures_are_ordered()
	_test_quick_branches_and_reciprocal_relation()
	_test_direct_call_without_attacker_relation()
	_test_quick_reciprocal_failure_preserves_guard_clear()
	_test_regular_raw_formula_and_boundaries()
	_test_regular_failures_are_ordered()
	_test_guard_transition_and_all_indices()
	_test_guard_partial_failure_and_remain_guarding()
	_test_rng_order_and_result_immutability()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_input_coherence_and_nonliving_attacker() -> void:
	var invalid_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var invalid: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(),
		RelationshipStateScript.new(&"wrong-attacker"),
		RelationshipStateScript.new(VICTIM_ID),
		invalid_rng,
	)
	_assert_eq(invalid.outcome, FightResultScript.Outcome.INVALID_SOURCE_STATE, "owner mismatch is invalid source state")
	_assert_eq(invalid.failure_stage, FightResultScript.FailureStage.RELATIONSHIP_PROJECTION, "owner mismatch has exact stage")
	_assert_eq(invalid_rng.call_count(), 0, "owner mismatch consumes no RNG")

	var same_authority: CombatRelationshipState = RelationshipStateScript.new(ATTACKER_ID)
	var aliased: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(), same_authority, same_authority, ScriptedRandomSourceScript.new([0])
	)
	_assert_eq(aliased.failure_stage, FightResultScript.FailureStage.INPUT, "same relationship authority rejected")

	var pair: Array[CombatRelationshipState] = _pair(false)
	pair[0].set_guarding(true)
	var rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0, 0])
	var result: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(false, false, false, true), pair[0], pair[1], rng
	)
	_assert_eq(result.outcome, FightResultScript.Outcome.ATTACKER_NOT_LIVING, "nonliving attacker immediately stops")
	_assert_false(result.has_attack_intent, "nonliving attacker has no attack intent despite REGULAR value zero")
	_assert_false(result.visibility_evaluated, "nonliving attacker does not evaluate visibility")
	_assert_eq(rng.call_count(), 0, "nonliving attacker consumes no RNG")
	_assert_true(pair[0].guarding, "nonliving attacker does not mutate guarding")
	_assert_false(pair[1].has_opponent(ATTACKER_ID), "nonliving attacker adds no reciprocal relation")

	var malformed_pair: Array[CombatRelationshipState] = _pair(false)
	malformed_pair[0].set_guarding(true)
	var malformed_later_facts: CombatFightDecisionFacts = FightFactsScript.new(
		ATTACKER_ID,
		false,
		false,
		null,
		99,
		99,
		VICTIM_ID,
		true,
		false,
		-9,
	)
	var no_rng_result: CombatFightDecisionResult = FightServiceScript.decide(
		malformed_later_facts,
		malformed_pair[0],
		malformed_pair[1],
		null,
	)
	_assert_eq(no_rng_result.outcome, FightResultScript.Outcome.ATTACKER_NOT_LIVING, "nonliving gate ignores unavailable later projections and RNG")
	_assert_eq(no_rng_result.failure_stage, FightResultScript.FailureStage.NONE, "nonliving stop is not a source failure")
	_assert_false(no_rng_result.perception_random_reached, "nonliving gate does not reach malformed perception")
	_assert_true(malformed_pair[0].guarding, "nonliving gate retains pre-existing guarding")


func _test_lazy_rng_and_visible_branch_facts() -> void:
	var quick_pair: Array[CombatRelationshipState] = _pair(false)
	var visible_quick_facts: CombatFightDecisionFacts = FightFactsScript.new(
		ATTACKER_ID,
		true,
		true,
		null,
		1,
		0,
		VICTIM_ID,
		true,
		true,
		-7,
	)
	var quick: CombatFightDecisionResult = FightServiceScript.decide(
		visible_quick_facts, quick_pair[0], quick_pair[1], null
	)
	_assert_eq(quick.outcome, FightResultScript.Outcome.QUICK_ATTACK, "visible busy QUICK needs neither perception nor RNG")
	_assert_false(quick.perception_random_reached or quick.courage_random_reached, "visible busy QUICK reaches no random branch")
	_assert_eq(quick.random_upper_bounds(), [], "visible busy QUICK records no random request")
	_assert_eq(quick.courage_random_bound, 0, "negative raw cps remains unreached on QUICK")

	var nonliving_pair: Array[CombatRelationshipState] = _pair(false)
	var visible_nonliving_facts: CombatFightDecisionFacts = FightFactsScript.new(
		ATTACKER_ID,
		true,
		true,
		null,
		1,
		0,
		VICTIM_ID,
		false,
		false,
		-7,
	)
	var nonliving_quick: CombatFightDecisionResult = FightServiceScript.decide(
		visible_nonliving_facts, nonliving_pair[0], nonliving_pair[1], null
	)
	_assert_eq(nonliving_quick.outcome, FightResultScript.Outcome.QUICK_ATTACK, "visible nonliving QUICK also needs no RNG")
	_assert_true(nonliving_pair[1].has_opponent(ATTACKER_ID), "nonliving victim receives ordinary reciprocal relation")

	var regular_pair: Array[CombatRelationshipState] = _pair(false)
	var visible_regular_without_perception: CombatFightDecisionFacts = FightFactsScript.new(
		ATTACKER_ID,
		true,
		true,
		null,
		1,
		0,
		VICTIM_ID,
		true,
		false,
		1,
	)
	var regular: CombatFightDecisionResult = FightServiceScript.decide(
		visible_regular_without_perception,
		regular_pair[0],
		regular_pair[1],
		ScriptedRandomSourceScript.new([0]),
	)
	_assert_eq(regular.outcome, FightResultScript.Outcome.REGULAR_ATTACK, "visible REGULAR ignores a missing perception projection")
	_assert_false(regular.perception_random_reached, "visible REGULAR records perception as unreached")

	var guard_pair: Array[CombatRelationshipState] = _pair(false)
	var visible_guard_wrong_perception: CombatFightDecisionFacts = FightFactsScript.new(
		ATTACKER_ID,
		true,
		true,
		PerceptionProjectionScript.new(&"not-perception", -1000),
		0,
		0,
		VICTIM_ID,
		true,
		false,
		1,
	)
	var guard: CombatFightDecisionResult = FightServiceScript.decide(
		visible_guard_wrong_perception,
		guard_pair[0],
		guard_pair[1],
		ScriptedRandomSourceScript.new([2, 0]),
	)
	_assert_eq(guard.outcome, FightResultScript.Outcome.ENTERED_GUARDING, "visible guard ignores malformed perception identity and bound")
	_assert_eq(guard.random_upper_bounds(), [3, 5], "visible guard consumes courage then guard only")


func _test_visibility_and_effective_perception() -> void:
	var visible_pair: Array[CombatRelationshipState] = _pair(false)
	var visible_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var visible: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, true, true, 9, 0, 5),
		visible_pair[0],
		visible_pair[1],
		visible_rng,
	)
	_assert_eq(visible.outcome, FightResultScript.Outcome.QUICK_ATTACK, "visible busy victim reaches quick branch")
	_assert_false(visible.perception_random_reached, "visible target skips perception RNG")
	_assert_eq(visible_rng.call_count(), 0, "visible quick consumes no B1 RNG")

	var skills: CharacterSkillState = CharacterSkillStateScript.new()
	skills.set_raw_level(&"perception", 20)
	skills.set_raw_level(&"six-sense", 30)
	_assert_true(skills.map_skill(&"perception", &"six-sense"), "perception fixture maps authored skill")
	var effective_perception: int = skills.effective_level(&"perception", 7)
	_assert_eq(effective_perception, 47, "effective perception is apply plus raw half plus mapped raw")
	var hidden_pair: Array[CombatRelationshipState] = _pair(false)
	var hidden_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([99])
	var hidden: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, false, true, true, effective_perception),
		hidden_pair[0], hidden_pair[1], hidden_rng
	)
	_assert_eq(hidden.perception_random_bound, 147, "invisible bound uses effective perception")
	_assert_eq(hidden.outcome, FightResultScript.Outcome.TARGET_NOT_PERCEIVED, "draw below one hundred stops")
	_assert_false(hidden.has_attack_intent, "target-not-perceived remains distinct from REGULAR value zero")
	_assert_false(hidden.courage_random_reached, "failed perception reaches no courage roll")

	var equality_pair: Array[CombatRelationshipState] = _pair(false)
	var equality_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([100, 0])
	var equality: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, false, false, true, 1, 1, 0, 1),
		equality_pair[0], equality_pair[1], equality_rng
	)
	_assert_true(equality.perception_check_passed, "perception equality one hundred continues")
	_assert_eq(equality.outcome, FightResultScript.Outcome.REGULAR_ATTACK, "perceived hidden target continues to courage")
	_assert_eq(equality_rng.requested_bounds(), [101, 3], "perception then courage bounds are ordered")

	var hidden_quick_pair: Array[CombatRelationshipState] = _pair(false)
	var hidden_quick_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([100])
	var hidden_quick: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, false, true, true, 1),
		hidden_quick_pair[0], hidden_quick_pair[1], hidden_quick_rng
	)
	_assert_eq(hidden_quick.outcome, FightResultScript.Outcome.QUICK_ATTACK, "perceived invisible busy victim reaches quick")
	_assert_eq(hidden_quick_rng.requested_bounds(), [101], "invisible quick consumes perception only")
	_assert_false(hidden_quick.courage_random_reached or hidden_quick.guard_random_reached, "invisible quick skips later decision RNG")


func _test_perception_failures_are_ordered() -> void:
	var mismatch_pair: Array[CombatRelationshipState] = _pair(false)
	var mismatch_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var mismatch: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, false, true, true, 0, 1, 0, 1, &"not-perception"),
		mismatch_pair[0], mismatch_pair[1], mismatch_rng
	)
	_assert_eq(mismatch.failure_stage, FightResultScript.FailureStage.PERCEPTION_SKILL_PROJECTION, "invisible skill identity mismatch typed at branch")
	_assert_eq(mismatch_rng.call_count(), 0, "projection mismatch consumes no RNG")

	var missing_pair: Array[CombatRelationshipState] = _pair(false)
	var missing: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, false, true, true, 1), missing_pair[0], missing_pair[1], null
	)
	_assert_eq(missing.outcome, FightResultScript.Outcome.RANDOM_SOURCE_MISSING, "missing perception RNG is typed")
	_assert_eq(missing.failure_stage, FightResultScript.FailureStage.PERCEPTION_RANDOM, "missing perception RNG has exact stage")
	_assert_false(missing_pair[1].has_opponent(ATTACKER_ID), "missing perception RNG mutates no reciprocal relation")

	var visible_mismatch_pair: Array[CombatRelationshipState] = _pair(false)
	var visible_mismatch: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, false, true, 0, 1, 0, 1, &"not-perception"),
		visible_mismatch_pair[0], visible_mismatch_pair[1], ScriptedRandomSourceScript.new([0])
	)
	_assert_eq(visible_mismatch.outcome, FightResultScript.Outcome.REGULAR_ATTACK, "visible path does not prematurely validate perception projection")

	var bound_pair: Array[CombatRelationshipState] = _pair(false)
	var invalid_bound: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, false, true, false, -100),
		bound_pair[0], bound_pair[1], ScriptedRandomSourceScript.new([0])
	)
	_assert_eq(invalid_bound.outcome, FightResultScript.Outcome.INVALID_RANDOM_BOUND, "zero perception bound is typed")
	_assert_eq(invalid_bound.failure_stage, FightResultScript.FailureStage.PERCEPTION_RANDOM_BOUND, "zero perception bound fails at exact source point")
	_assert_false(bound_pair[0].guarding or bound_pair[1].has_opponent(ATTACKER_ID), "perception bound failure mutates no relationship")

	var draw_pair: Array[CombatRelationshipState] = _pair(false)
	var invalid_draw: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, false, true, false, 1),
		draw_pair[0], draw_pair[1], ScriptedRandomSourceScript.new([101])
	)
	_assert_eq(invalid_draw.outcome, FightResultScript.Outcome.RANDOM_DRAW_OUT_OF_RANGE, "perception draw equal to bound rejected")
	_assert_eq(invalid_draw.random_upper_bounds(), [101], "invalid perception draw preserves bound evidence")

	var negative_pair: Array[CombatRelationshipState] = _pair(false)
	var negative_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([49])
	var valid_negative: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, false, true, true, -50),
		negative_pair[0],
		negative_pair[1],
		negative_rng,
	)
	_assert_eq(valid_negative.perception_random_bound, 50, "effective perception minus fifty keeps positive source bound")
	_assert_eq(valid_negative.outcome, FightResultScript.Outcome.TARGET_NOT_PERCEIVED, "maximum valid draw below fifty still cannot perceive")
	_assert_eq(negative_rng.requested_bounds(), [50], "valid negative perception performs exact random fifty call")


func _test_quick_branches_and_reciprocal_relation() -> void:
	var cases: Array[Array] = [
		[true, true, "busy living victim"],
		[false, false, "nonliving idle victim"],
		[true, false, "busy nonliving victim"],
	]
	for values: Array in cases:
		var pair: Array[CombatRelationshipState] = _pair(false)
		pair[0].set_guarding(true)
		var rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
		var result: CombatFightDecisionResult = FightServiceScript.decide(
			_facts(true, true, bool(values[0]), bool(values[1])),
			pair[0], pair[1], rng
		)
		_assert_eq(result.outcome, FightResultScript.Outcome.QUICK_ATTACK, "%s selects quick" % values[2])
		_assert_eq(result.attack_type, AttackTypeScript.Value.QUICK, "%s uses legacy quick value two" % values[2])
		_assert_false(pair[0].guarding, "%s clears attacker guarding" % values[2])
		_assert_true(pair[1].has_opponent(ATTACKER_ID), "%s adds victim-only reciprocal relation" % values[2])
		_assert_true(result.reciprocal_add_attempted and result.reciprocal_opponent_added, "%s reports reciprocal append" % values[2])
		_assert_false(pair[0].has_lethal_target(VICTIM_ID) or pair[1].has_lethal_target(ATTACKER_ID), "%s adds no lethal marker" % values[2])
		_assert_false(result.courage_random_reached or result.guard_random_reached, "%s skips courage and guard RNG" % values[2])
		_assert_eq(rng.call_count(), 0, "%s consumes no visible quick RNG" % values[2])

	var existing_pair: Array[CombatRelationshipState] = _pair(true)
	var existing: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, true, true),
		existing_pair[0], existing_pair[1], ScriptedRandomSourceScript.new([0])
	)
	_assert_true(existing.reciprocal_opponent_existed, "existing reciprocal relation observed")
	_assert_false(existing.reciprocal_add_attempted or existing.reciprocal_opponent_added, "existing reciprocal relation is not duplicated")
	_assert_eq(existing_pair[1].opponent_ids(), [ATTACKER_ID], "existing reciprocal insertion order unchanged")


func _test_direct_call_without_attacker_relation() -> void:
	var quick_attacker: CombatRelationshipState = RelationshipStateScript.new(ATTACKER_ID)
	var quick_victim: CombatRelationshipState = RelationshipStateScript.new(VICTIM_ID)
	quick_attacker.set_last_opponent(&"prior-target")
	var quick: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, true, true), quick_attacker, quick_victim, null
	)
	_assert_eq(quick.outcome, FightResultScript.Outcome.QUICK_ATTACK, "direct QUICK does not require attacker to list victim")
	_assert_eq(quick_attacker.opponent_ids(), [], "direct QUICK does not repair attacker relation")
	_assert_eq(quick_victim.opponent_ids(), [ATTACKER_ID], "direct QUICK adds only victim to attacker relation")
	_assert_eq(quick_attacker.last_opponent_id, &"prior-target", "fight decision does not set attacker last_opponent")

	var regular_attacker: CombatRelationshipState = RelationshipStateScript.new(ATTACKER_ID)
	var regular_victim: CombatRelationshipState = RelationshipStateScript.new(VICTIM_ID)
	regular_attacker.set_last_opponent(&"prior-target")
	var regular: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, false, true, 0, 1, 0, 1),
		regular_attacker,
		regular_victim,
		ScriptedRandomSourceScript.new([0]),
	)
	_assert_eq(regular.outcome, FightResultScript.Outcome.REGULAR_ATTACK, "direct REGULAR does not require attacker to list victim")
	_assert_true(regular.has_attack_intent, "REGULAR numeric zero has explicit attack-intent presence")
	_assert_eq(regular.attack_type, 0, "REGULAR preserves literal legacy value zero")
	_assert_eq(regular_attacker.opponent_ids(), [], "direct REGULAR leaves attacker relation unchanged")
	_assert_eq(regular_victim.opponent_ids(), [ATTACKER_ID], "direct REGULAR adds victim-side reciprocal only")
	_assert_eq(regular_attacker.last_opponent_id, &"prior-target", "REGULAR decision leaves prior last_opponent untouched")
	_assert_false(regular.attack_type == AttackTypeScript.Value.RIPOSTE, "B1 never substitutes reserved RIPOSTE intent")


func _test_quick_reciprocal_failure_preserves_guard_clear() -> void:
	var attacker: CombatRelationshipState = RelationshipStateScript.new(ATTACKER_ID)
	attacker.add_opponent(VICTIM_ID)
	attacker.set_guarding(true)
	var victim: CombatRelationshipState = FailingRelationshipStateScript.new(VICTIM_ID)
	victim.fail_add_id = ATTACKER_ID
	var result: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, true, true), attacker, victim, ScriptedRandomSourceScript.new([0])
	)
	_assert_eq(result.outcome, FightResultScript.Outcome.RELATIONSHIP_INVARIANT_FAILURE, "failed reciprocal add is typed")
	_assert_eq(result.failure_stage, FightResultScript.FailureStage.RECIPROCAL_RELATION, "failed reciprocal add has exact stage")
	_assert_false(attacker.guarding, "guard clear precedes failed reciprocal add")
	_assert_true(result.partial_relationship_mutation_preserved, "failed reciprocal add reports preserved guard mutation")
	_assert_false(result.has_attack_intent, "failed reciprocal add produces no attack intent")


func _test_regular_raw_formula_and_boundaries() -> void:
	var regular_pair: Array[CombatRelationshipState] = _pair(false)
	regular_pair[0].set_guarding(true)
	var regular_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([5])
	var regular: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, false, true, 0, 1, 250, 2),
		regular_pair[0], regular_pair[1], regular_rng
	)
	_assert_eq(regular.courage_random_bound, 6, "courage bound is raw cps times three")
	_assert_eq(regular.courage_threshold, 6, "threshold is raw cor plus raw bellicosity divided by fifty")
	var hypothetical_query_cps: int = 2 + 100 / 2 + 7
	var hypothetical_query_cor: int = 1 + 250 / 50 + 100
	_assert_true(regular.courage_random_bound != hypothetical_query_cps * 3, "raw cps bound excludes force_factor and apply/composure")
	_assert_true(regular.courage_threshold != hypothetical_query_cor, "raw courage threshold excludes apply/courage")
	_assert_eq(regular.outcome, FightResultScript.Outcome.REGULAR_ATTACK, "draw below threshold selects regular")
	_assert_eq(regular.attack_type, 0, "regular uses literal legacy value zero")
	_assert_true(regular.has_attack_intent, "regular value zero remains distinct from absent attack intent")
	_assert_eq(AttackTypeScript.Value.RIPOSTE, 1, "riposte reserves legacy value one without being emitted")
	_assert_eq(AttackTypeScript.Value.QUICK, 2, "quick preserves legacy value two")
	_assert_false(regular_pair[0].guarding, "regular clears guarding before reciprocal relation")
	_assert_true(regular_pair[1].has_opponent(ATTACKER_ID), "regular establishes victim-only reciprocal relation")

	var equality_pair: Array[CombatRelationshipState] = _pair(false)
	var equality: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, false, true, 0, 6, 0, 3),
		equality_pair[0], equality_pair[1], ScriptedRandomSourceScript.new([6, 0])
	)
	_assert_false(equality.courage_check_passed, "courage equality fails strict comparison")
	_assert_eq(equality.outcome, FightResultScript.Outcome.ENTERED_GUARDING, "courage equality enters guard")
	_assert_false(equality_pair[1].has_opponent(ATTACKER_ID), "guard path does not establish reciprocal relation")

	var negative_pair: Array[CombatRelationshipState] = _pair(false)
	var negative: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, false, true, 0, 0, -49, 1),
		negative_pair[0], negative_pair[1], ScriptedRandomSourceScript.new([0, 0])
	)
	_assert_eq(negative.courage_threshold, 0, "negative bellicosity minus forty-nine truncates toward zero")
	_assert_eq(negative.outcome, FightResultScript.Outcome.ENTERED_GUARDING, "zero raw threshold does not use effective courage modifiers")
	_assert_eq(negative.courage_random_bound, 3, "raw cps ignores hypothetical force_factor and apply/composure")

	var negative_fifty_pair: Array[CombatRelationshipState] = _pair(false)
	var negative_fifty: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, false, true, 0, 0, -50, 1),
		negative_fifty_pair[0], negative_fifty_pair[1], ScriptedRandomSourceScript.new([0, 0])
	)
	_assert_eq(negative_fifty.courage_threshold, -1, "negative bellicosity minus fifty contributes negative one")


func _test_regular_failures_are_ordered() -> void:
	var quick_pair: Array[CombatRelationshipState] = _pair(false)
	var quick: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, true, true, 0, 99, 0, 0),
		quick_pair[0], quick_pair[1], ScriptedRandomSourceScript.new([0])
	)
	_assert_eq(quick.outcome, FightResultScript.Outcome.QUICK_ATTACK, "quick does not prevalidate zero raw cps")
	_assert_false(quick.courage_random_reached, "quick never reaches invalid courage bound")

	var invalid_pair: Array[CombatRelationshipState] = _pair(false)
	invalid_pair[0].set_guarding(true)
	var invalid: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, false, true, 0, 99, 0, 0),
		invalid_pair[0], invalid_pair[1], ScriptedRandomSourceScript.new([0])
	)
	_assert_eq(invalid.outcome, FightResultScript.Outcome.INVALID_RANDOM_BOUND, "zero cps courage bound is typed")
	_assert_eq(invalid.failure_stage, FightResultScript.FailureStage.COURAGE_RANDOM_BOUND, "zero cps fails at courage source point")
	_assert_true(invalid_pair[0].guarding, "courage bound failure does not clear guarding")
	_assert_false(invalid_pair[1].has_opponent(ATTACKER_ID), "courage bound failure adds no reciprocal relation")

	var invalid_draw_pair: Array[CombatRelationshipState] = _pair(false)
	var invalid_draw: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, false, true, 0, 1, 0, 1),
		invalid_draw_pair[0], invalid_draw_pair[1], ScriptedRandomSourceScript.new([3])
	)
	_assert_eq(invalid_draw.outcome, FightResultScript.Outcome.RANDOM_DRAW_OUT_OF_RANGE, "courage draw equal to positive bound rejected")
	_assert_eq(invalid_draw.failure_stage, FightResultScript.FailureStage.COURAGE_RANDOM, "invalid courage draw has exact stage")
	_assert_false(invalid_draw.courage_comparison_evaluated, "invalid courage draw fails before threshold comparison")
	_assert_eq(invalid_draw.courage_threshold, 0, "unreached courage threshold keeps explicit default evidence")
	_assert_false(invalid_draw_pair[0].guarding or invalid_draw_pair[1].has_opponent(ATTACKER_ID), "invalid courage draw mutates no relationship")

	var hidden_pair: Array[CombatRelationshipState] = _pair(false)
	var hidden_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([100, 3])
	var hidden_failure: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, false, false, true, 1, 10, 0, 0),
		hidden_pair[0], hidden_pair[1], hidden_rng
	)
	_assert_eq(hidden_failure.failure_stage, FightResultScript.FailureStage.COURAGE_RANDOM_BOUND, "late courage bound fails after perception")
	_assert_eq(hidden_failure.random_upper_bounds(), [101], "late courage failure preserves prior perception RNG only")
	_assert_eq(hidden_rng.call_count(), 1, "invalid courage bound performs no second random call")


func _test_guard_transition_and_all_indices() -> void:
	for guard_index: int in range(5):
		var pair: Array[CombatRelationshipState] = _pair(false)
		var rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([2, guard_index])
		var result: CombatFightDecisionResult = FightServiceScript.decide(
			_facts(true, true, false, true, 0, 1, 0, 1),
			pair[0], pair[1], rng
		)
		_assert_eq(result.outcome, FightResultScript.Outcome.ENTERED_GUARDING, "courage failure enters guarding")
		_assert_true(pair[0].guarding, "guard transition mutates attacker authority")
		_assert_eq(result.guard_presentation_index, guard_index, "all five guard indices retained")
		_assert_true(result.has_guard_presentation_index, "guard index zero differs from unreached")
		_assert_eq(rng.requested_bounds(), [3, 5], "guard RNG follows courage with exact bound five")
		_assert_false(pair[1].has_opponent(ATTACKER_ID), "guard never establishes reciprocal relation")
		_assert_false(result.has_attack_intent, "guard produces no attack intent")


func _test_guard_partial_failure_and_remain_guarding() -> void:
	var invalid_pair: Array[CombatRelationshipState] = _pair(false)
	var invalid_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([2, 5])
	var invalid: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, false, true, 0, 1, 0, 1),
		invalid_pair[0], invalid_pair[1], invalid_rng
	)
	_assert_eq(invalid.failure_stage, FightResultScript.FailureStage.GUARD_PRESENTATION_RANDOM, "invalid guard draw fails at presentation stage")
	_assert_true(invalid_pair[0].guarding, "guard is set before invalid guard draw")
	_assert_true(invalid.partial_relationship_mutation_preserved, "invalid guard draw reports preserved guard mutation")
	_assert_false(invalid.has_guard_presentation_index, "invalid guard draw does not masquerade as index zero")

	var missing_pair: Array[CombatRelationshipState] = _pair(false)
	var missing: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, false, true, 0, 1, 0, 1),
		missing_pair[0], missing_pair[1], null
	)
	_assert_eq(missing.failure_stage, FightResultScript.FailureStage.COURAGE_RANDOM, "missing source first fails at courage, before guard mutation")
	_assert_false(missing_pair[0].guarding, "missing courage RNG cannot reach guard mutation")

	var already_pair: Array[CombatRelationshipState] = _pair(false)
	already_pair[0].set_guarding(true)
	var already_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([2, 4])
	var already: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, true, false, true, 0, 1, 0, 1),
		already_pair[0], already_pair[1], already_rng
	)
	_assert_eq(already.outcome, FightResultScript.Outcome.REMAIN_GUARDING, "existing guarding remains after courage failure")
	_assert_eq(already_rng.requested_bounds(), [3], "already guarding skips guard presentation draw")
	_assert_false(already.guard_random_reached, "already guarding records guard RNG unreached")
	_assert_false(already_pair[1].has_opponent(ATTACKER_ID), "already guarding adds no reciprocal relation")


func _test_rng_order_and_result_immutability() -> void:
	var pair: Array[CombatRelationshipState] = _pair(false)
	var rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([100, 2, 0])
	var result: CombatFightDecisionResult = FightServiceScript.decide(
		_facts(true, false, false, true, 1, 1, 0, 1), pair[0], pair[1], rng
	)
	_assert_eq(result.outcome, FightResultScript.Outcome.ENTERED_GUARDING, "hidden target can reach new guard")
	_assert_eq(result.random_upper_bounds(), [101, 3, 5], "perception courage guard bounds preserve exact order")
	_assert_eq(result.random_draws(), [100, 2, 0], "perception courage guard draws preserve exact order")
	var bounds: Array[int] = result.random_upper_bounds()
	bounds.clear()
	_assert_eq(result.random_upper_bounds(), [101, 3, 5], "result RNG arrays are defensive")
	var copy: CombatFightDecisionResult = result.duplicate_snapshot()
	copy._guard_presentation_index = 4
	_assert_eq(result.guard_presentation_index, 0, "result snapshot shares no mutable result state")

	var projection: CombatPerceptionSkillProjection = PerceptionProjectionScript.new(&"perception", 12)
	var facts: CombatFightDecisionFacts = FightFactsScript.new(
		ATTACKER_ID, true, false, projection, 1, 0, VICTIM_ID, true, false, 1
	)
	projection._effective_level = 999
	_assert_eq(facts.perception.effective_level, 12, "facts defensively snapshot perception projection")
	var returned_projection: CombatPerceptionSkillProjection = facts.perception
	returned_projection._effective_level = 888
	_assert_eq(facts.perception.effective_level, 12, "facts getter returns defensive perception snapshot")


func _facts(
	attacker_living: bool = true,
	target_visible: bool = true,
	victim_busy: bool = false,
	victim_living: bool = true,
	effective_perception: int = 0,
	attacker_raw_courage: int = 1,
	attacker_raw_bellicosity: int = 0,
	victim_raw_composure: int = 1,
	perception_skill_id: StringName = &"perception",
) -> CombatFightDecisionFacts:
	return FightFactsScript.new(
		ATTACKER_ID,
		attacker_living,
		target_visible,
		PerceptionProjectionScript.new(perception_skill_id, effective_perception),
		attacker_raw_courage,
		attacker_raw_bellicosity,
		VICTIM_ID,
		victim_living,
		victim_busy,
		victim_raw_composure,
	)


func _pair(reciprocal: bool) -> Array[CombatRelationshipState]:
	var attacker: CombatRelationshipState = RelationshipStateScript.new(ATTACKER_ID)
	attacker.add_opponent(VICTIM_ID)
	var victim: CombatRelationshipState = RelationshipStateScript.new(VICTIM_ID)
	if reciprocal:
		victim.add_opponent(ATTACKER_ID)
	return [attacker, victim]


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
