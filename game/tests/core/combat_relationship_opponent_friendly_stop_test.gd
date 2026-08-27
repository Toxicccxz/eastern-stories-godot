extends RefCounted

const RelationshipStateScript := preload(
	"res://core/combat/relationship/combat_relationship_state.gd"
)
const AvailabilityFactsScript := preload(
	"res://core/combat/relationship/combat_opponent_availability_facts.gd"
)
const SelectionResultScript := preload(
	"res://core/combat/relationship/combat_opponent_selection_result.gd"
)
const SelectionServiceScript := preload(
	"res://core/combat/relationship/combat_opponent_selection_service.gd"
)
const PostRelationshipResultScript := preload(
	"res://core/combat/relationship/combat_post_relationship_result.gd"
)
const PostRelationshipServiceScript := preload(
	"res://core/combat/relationship/combat_post_relationship_service.gd"
)
const CombatAttackCalculationScript := preload(
	"res://core/combat/resolution/combat_attack_calculation.gd"
)
const CombatResourceMutationResultScript := preload(
	"res://core/combat/resolution/combat_resource_mutation_result.gd"
)
const CombatAttackResultScript := preload(
	"res://core/combat/resolution/combat_attack_result.gd"
)
const CombatProgressionResultScript := preload(
	"res://core/combat/completion/combat_progression_result.gd"
)
const StatusBoundaryResultScript := preload(
	"res://core/combat/completion/combat_status_report_boundary_result.gd"
)
const BusyInterruptResultScript := preload(
	"res://core/combat/completion/combat_busy_interrupt_result.gd"
)
const BusyInterruptProjectionScript := preload(
	"res://core/combat/completion/combat_busy_interrupt_projection.gd"
)
const OrdinaryAttackResultScript := preload(
	"res://core/combat/completion/combat_ordinary_attack_result.gd"
)
const ScriptedRandomSourceScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)
const FailingRelationshipStateScript := preload(
	"res://tests/support/failing_combat_relationship_state.gd"
)

const ATTACKER_ID: StringName = &"attacker-1"
const DEFENDER_ID: StringName = &"defender-1"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_cleanup_empty_and_all_valid()
	_test_cleanup_predicates_and_order()
	_test_cleanup_projection_coherence()
	_test_selection_bias_and_last_opponent()
	_test_selection_partial_failures()
	_test_friendly_stop_success_and_preserved_state()
	_test_friendly_stop_gates()
	_test_completed_busy_outcomes_do_not_gate_friendly_stop()
	_test_requested_damage_threshold_and_partial_rng_failure()
	_test_removal_invariant_ordering()
	_test_stable_lethal_identity_and_result_immutability()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_cleanup_empty_and_all_valid() -> void:
	var empty: CombatRelationshipState = RelationshipStateScript.new(&"owner")
	var empty_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var no_opponent: CombatOpponentSelectionResult = SelectionServiceScript.prepare(
		empty,
		[] as Array[CombatOpponentAvailabilityFacts],
		empty_rng,
	)
	_assert_eq(no_opponent.outcome, SelectionResultScript.Outcome.NO_OPPONENT, "empty cleanup prepares no opponent")
	_assert_eq(empty_rng.call_count(), 0, "empty selection consumes no RNG")
	_assert_eq(no_opponent.original_opponent_ids(), [], "empty original evidence")
	_assert_eq(no_opponent.resulting_opponent_ids(), [], "empty resulting evidence")
	_assert_true(no_opponent.cleanup_completed, "empty cleanup is explicitly complete")
	_assert_false(no_opponent.cleanup_mutated, "empty cleanup reports no mutation")

	var stale: CombatRelationshipState = _state_with_opponents(&"owner", [&"gone"])
	stale.mark_lethal_target(&"gone")
	stale.set_last_opponent(&"gone")
	var stale_result: CombatOpponentSelectionResult = SelectionServiceScript.prepare(
		stale,
		[_fact(&"gone", false, true, false)],
		ScriptedRandomSourceScript.new([0]),
	)
	_assert_eq(stale_result.outcome, SelectionResultScript.Outcome.NO_OPPONENT, "cleanup can leave no opponent")
	_assert_eq(stale.last_opponent_id, &"gone", "cleanup leaves stale last opponent unchanged")
	_assert_true(stale.has_lethal_target(&"gone"), "cleanup-only removal retains lethal marker")
	_assert_true(stale.mark_lethal_target(&"gone"), "existing lethal marker re-adds cleaned opponent")
	_assert_false(stale.remove_opponent(&"gone"), "ordinary removal still refuses re-added lethal opponent")

	var state: CombatRelationshipState = RelationshipStateScript.new(&"owner")
	state.add_opponent(&"third")
	state.add_opponent(&"first")
	state.add_opponent(&"second")
	var facts: Array[CombatOpponentAvailabilityFacts] = [
		_fact(&"second"),
		_fact(&"third"),
		_fact(&"first"),
	]
	var result: CombatOpponentSelectionResult = SelectionServiceScript.prepare(
		state,
		facts,
		ScriptedRandomSourceScript.new([1]),
	)
	_assert_eq(result.removed_opponent_ids(), [], "all valid cleanup removes none")
	_assert_true(result.cleanup_completed, "all-valid cleanup reports completion")
	_assert_false(result.cleanup_mutated, "all-valid cleanup distinguishes no removals")
	_assert_eq(result.retained_opponent_ids(), [&"third", &"first", &"second"], "retained evidence follows relationship insertion order")
	_assert_eq(result.resulting_opponent_ids(), [&"third", &"first", &"second"], "cleanup preserves exact insertion order")
	_assert_eq(result.selected_opponent_id, &"first", "selection uses cleaned insertion order")


func _test_cleanup_predicates_and_order() -> void:
	var state: CombatRelationshipState = RelationshipStateScript.new(&"owner")
	var ids: Array[StringName] = [
		&"missing",
		&"away",
		&"dead-friendly",
		&"dead-lethal",
		&"living-lethal",
		&"away-lethal",
		&"valid",
	]
	for opponent_id: StringName in ids:
		state.add_opponent(opponent_id)
	state.mark_lethal_target(&"dead-lethal")
	state.mark_lethal_target(&"living-lethal")
	state.mark_lethal_target(&"away-lethal")
	state.set_last_opponent(&"stale-last")
	var facts: Array[CombatOpponentAvailabilityFacts] = [
		_fact(&"valid"),
		_fact(&"away-lethal", true, false, true),
		_fact(&"dead-lethal", true, true, false),
		_fact(&"missing", false, true, true),
		_fact(&"living-lethal", true, true, true),
		_fact(&"dead-friendly", true, true, false),
		_fact(&"away", true, false, true),
	]
	var result: CombatOpponentSelectionResult = SelectionServiceScript.prepare(
		state,
		facts,
		ScriptedRandomSourceScript.new([2]),
	)
	_assert_eq(
		result.removed_opponent_ids(),
		[&"missing", &"away", &"dead-friendly", &"away-lethal"],
		"cleanup removes in original evaluation order",
	)
	_assert_eq(
		result.retained_opponent_ids(),
		[&"dead-lethal", &"living-lethal", &"valid"],
		"nonliving lethal and living lethal opponents remain",
	)
	_assert_eq(state.opponent_ids(), [&"dead-lethal", &"living-lethal", &"valid"], "cleanup authority order matches evidence")
	_assert_true(result.cleanup_completed and result.cleanup_mutated, "completed cleanup distinguishes ordered removals")
	_assert_true(state.has_lethal_target(&"away-lethal"), "cleanup retains lethal marker after opponent removal")
	_assert_eq(result.last_opponent_before, &"stale-last", "cleanup snapshots stale last opponent")
	_assert_eq(result.selected_opponent_id, &"valid", "selection follows cleanup")
	_assert_eq(state.last_opponent_id, &"valid", "successful selection replaces last opponent only after cleanup")


func _test_cleanup_projection_coherence() -> void:
	var duplicate: CombatRelationshipState = _state_with_opponents(&"owner", [&"a", &"b"])
	var duplicate_facts: Array[CombatOpponentAvailabilityFacts] = [_fact(&"a"), _fact(&"a")]
	var duplicate_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var duplicate_result: CombatOpponentSelectionResult = SelectionServiceScript.prepare(
		duplicate, duplicate_facts, duplicate_rng
	)
	_assert_eq(duplicate_result.outcome, SelectionResultScript.Outcome.INVALID_AVAILABILITY_PROJECTION, "duplicate fact ID rejected")
	_assert_false(duplicate_result.cleanup_completed, "invalid projection fails before cleanup completion")
	_assert_eq(duplicate.opponent_ids(), [&"a", &"b"], "duplicate projection fails before cleanup mutation")
	_assert_eq(duplicate_rng.call_count(), 0, "invalid projection consumes no RNG")

	var missing: CombatRelationshipState = _state_with_opponents(&"owner", [&"a", &"b"])
	var missing_facts: Array[CombatOpponentAvailabilityFacts] = [_fact(&"a")]
	_assert_eq(
		SelectionServiceScript.prepare(missing, missing_facts, ScriptedRandomSourceScript.new([0])).outcome,
		SelectionResultScript.Outcome.INVALID_AVAILABILITY_PROJECTION,
		"missing fact rejected",
	)
	_assert_eq(missing.opponent_ids(), [&"a", &"b"], "missing projection performs no partial cleanup")

	var extra: CombatRelationshipState = _state_with_opponents(&"owner", [&"a", &"b"])
	var extra_facts: Array[CombatOpponentAvailabilityFacts] = [_fact(&"a"), _fact(&"b"), _fact(&"c")]
	_assert_eq(
		SelectionServiceScript.prepare(extra, extra_facts, ScriptedRandomSourceScript.new([0])).outcome,
		SelectionResultScript.Outcome.INVALID_AVAILABILITY_PROJECTION,
		"extra unrelated fact rejected",
	)
	_assert_eq(extra.opponent_ids(), [&"a", &"b"], "extra projection performs no mutation")


func _test_selection_bias_and_last_opponent() -> void:
	for draw: int in range(4):
		_assert_selection([&"a"], draw, &"a", 0, "one opponent always selects first")
	var expected_two: Array[StringName] = [&"a", &"b", &"a", &"a"]
	var expected_three: Array[StringName] = [&"a", &"b", &"c", &"a"]
	var expected_four: Array[StringName] = [&"a", &"b", &"c", &"d"]
	for draw: int in range(4):
		_assert_selection([&"a", &"b"], draw, expected_two[draw], mini(draw, 1) if draw < 2 else 0, "two-opponent 3/4 source bias")
		_assert_selection([&"a", &"b", &"c"], draw, expected_three[draw], draw if draw < 3 else 0, "three-opponent mapping")
		_assert_selection([&"a", &"b", &"c", &"d"], draw, expected_four[draw], draw, "four-opponent mapping")
	var five_ids: Array[StringName] = [&"a", &"b", &"c", &"d", &"e"]
	for draw: int in range(4):
		var selected: CombatOpponentSelectionResult = _selection(five_ids, draw)
		_assert_eq(selected.selected_opponent_id, five_ids[draw], "five-plus only maps first four indices")
		_assert_false(selected.selected_opponent_id == &"e", "fifth opponent is retained but unselectable")
		_assert_eq(selected.resulting_opponent_ids().size(), 5, "selection imposes no four-opponent capacity")


func _test_selection_partial_failures() -> void:
	var state: CombatRelationshipState = _state_with_opponents(&"owner", [&"away", &"stay"])
	state.mark_lethal_target(&"away")
	state.set_last_opponent(&"prior")
	var facts: Array[CombatOpponentAvailabilityFacts] = [
		_fact(&"away", true, false, true),
		_fact(&"stay"),
	]
	var invalid_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([4])
	var invalid: CombatOpponentSelectionResult = SelectionServiceScript.prepare(state, facts, invalid_rng)
	_assert_eq(invalid.outcome, SelectionResultScript.Outcome.RANDOM_DRAW_OUT_OF_RANGE, "draw four rejected after cleanup")
	_assert_true(invalid.cleanup_completed and invalid.cleanup_mutated, "selection failure exposes completed prior cleanup")
	_assert_eq(state.opponent_ids(), [&"stay"], "invalid draw preserves completed cleanup")
	_assert_true(state.has_lethal_target(&"away"), "selection failure preserves cleaned opponent lethal marker")
	_assert_eq(state.last_opponent_id, &"prior", "selection failure preserves previous last opponent")
	_assert_eq(invalid.random_upper_bounds(), [4], "selection bound is always four")
	_assert_eq(invalid.random_draws(), [4], "invalid draw remains evidence")
	var negative_state: CombatRelationshipState = _state_with_opponents(&"owner", [&"stay"])
	var negative_facts: Array[CombatOpponentAvailabilityFacts] = [_fact(&"stay")]
	var negative: CombatOpponentSelectionResult = SelectionServiceScript.prepare(
		negative_state,
		negative_facts,
		ScriptedRandomSourceScript.new([-1]),
	)
	_assert_eq(negative.outcome, SelectionResultScript.Outcome.RANDOM_DRAW_OUT_OF_RANGE, "negative selection draw rejected")
	_assert_eq(negative_state.last_opponent_id, &"", "negative draw does not set last opponent")

	var missing_state: CombatRelationshipState = _state_with_opponents(&"owner", [&"away", &"stay"])
	missing_state.set_last_opponent(&"prior")
	var missing: CombatOpponentSelectionResult = SelectionServiceScript.prepare(
		missing_state,
		facts,
		null,
	)
	_assert_eq(missing.outcome, SelectionResultScript.Outcome.RANDOM_SOURCE_MISSING, "missing selection RNG typed after cleanup")
	_assert_eq(missing_state.opponent_ids(), [&"stay"], "missing RNG preserves cleanup")
	_assert_eq(missing_state.last_opponent_id, &"prior", "missing RNG leaves last opponent unchanged")
	_assert_true(missing.selection_random_reached, "missing RNG retains reached-stage evidence")
	_assert_false(missing.selection_random_attempted, "missing RNG performs no random call")


func _test_friendly_stop_success_and_preserved_state() -> void:
	var attacker: CombatRelationshipState = _state_with_opponents(ATTACKER_ID, [DEFENDER_ID, &"other-a"])
	var defender: CombatRelationshipState = _state_with_opponents(DEFENDER_ID, [ATTACKER_ID, &"other-d"])
	attacker.mark_lethal_target(&"other-a")
	defender.mark_lethal_target(&"other-d")
	attacker.set_guarding(true)
	defender.set_guarding(true)
	attacker.set_last_opponent(DEFENDER_ID)
	defender.set_last_opponent(ATTACKER_ID)
	var rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([4])
	var result: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
		_ordinary(CombatAttackResultScript.Outcome.HIT, 5),
		ATTACKER_ID,
		DEFENDER_ID,
		attacker,
		defender,
		rng,
	)
	_assert_eq(result.outcome, PostRelationshipResultScript.Outcome.COMPLETED, "bilateral nonlethal positive HIT stops fight")
	_assert_true(result.friendly_stop_predicate_matched, "friendly predicate evidence matched")
	_assert_true(result.attacker_removal_succeeded, "attacker relation removed first")
	_assert_true(result.defender_removal_succeeded, "defender relation removed second")
	_assert_eq(attacker.opponent_ids(), [&"other-a"], "attacker unrelated opponent retained")
	_assert_eq(defender.opponent_ids(), [&"other-d"], "defender unrelated opponent retained")
	_assert_true(attacker.has_lethal_target(&"other-a"), "attacker unrelated lethal marker retained")
	_assert_true(defender.has_lethal_target(&"other-d"), "defender unrelated lethal marker retained")
	_assert_true(attacker.guarding and defender.guarding, "friendly stop does not clear guarding")
	_assert_eq(attacker.last_opponent_id, DEFENDER_ID, "attacker last opponent remains stale")
	_assert_eq(defender.last_opponent_id, ATTACKER_ID, "defender last opponent remains stale")
	_assert_eq(rng.requested_bounds(), [6], "winner presentation requests exactly random six")
	_assert_eq(result.winner_presentation_index, 4, "winner draw becomes typed presentation index")
	_assert_eq(result.combined_random_upper_bounds(), [2, 3, 6], "winner RNG appends to attack RNG evidence")
	_assert_eq(result.combined_random_draws(), [0, 1, 4], "winner draw appends once to the ordinary attack RNG prefix")
	_assert_eq(rng.call_count(), 1, "post relationship consumes exactly one continuation draw")
	for winner_index: int in range(6):
		var winner_pair: Array[CombatRelationshipState] = _bilateral_pair()
		var winner_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([winner_index])
		var winner: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
			_ordinary(CombatAttackResultScript.Outcome.HIT, 5),
			ATTACKER_ID,
			DEFENDER_ID,
			winner_pair[0],
			winner_pair[1],
			winner_rng,
		)
		_assert_eq(winner.winner_presentation_index, winner_index, "all six winner indices are preserved")
		_assert_true(winner.has_winner_presentation_index, "winner index zero remains distinguishable from unreached")
		_assert_eq(winner_rng.requested_bounds(), [6], "each winner index uses bound six")


func _test_friendly_stop_gates() -> void:
	for branch: int in [CombatAttackResultScript.Outcome.DODGE, CombatAttackResultScript.Outcome.PARRY]:
		var pair: Array[CombatRelationshipState] = _bilateral_pair()
		var rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
		var result: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
			_ordinary(branch, 0), ATTACKER_ID, DEFENDER_ID, pair[0], pair[1], rng
		)
		_assert_eq(result.outcome, PostRelationshipResultScript.Outcome.NOT_POSITIVE_HIT, "dodge/parry skips friendly stop")
		_assert_true(pair[0].has_opponent(DEFENDER_ID) and pair[1].has_opponent(ATTACKER_ID), "dodge/parry preserves relations")
		_assert_eq(rng.call_count(), 0, "dodge/parry consumes no winner RNG")

	var zero_pair: Array[CombatRelationshipState] = _bilateral_pair()
	var zero_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var zero: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
		_ordinary(CombatAttackResultScript.Outcome.HIT, 0), ATTACKER_ID, DEFENDER_ID,
		zero_pair[0], zero_pair[1], zero_rng
	)
	_assert_eq(zero.outcome, PostRelationshipResultScript.Outcome.NOT_POSITIVE_HIT, "zero HIT skips friendly stop")
	_assert_eq(zero_rng.call_count(), 0, "zero HIT consumes no winner RNG")

	var attacker_lethal: Array[CombatRelationshipState] = _bilateral_pair()
	attacker_lethal[0].mark_lethal_target(DEFENDER_ID)
	_assert_no_stop(attacker_lethal, "attacker unilateral lethal blocks friendly stop")
	var defender_lethal: Array[CombatRelationshipState] = _bilateral_pair()
	defender_lethal[1].mark_lethal_target(ATTACKER_ID)
	_assert_no_stop(defender_lethal, "defender unilateral lethal blocks friendly stop")
	var both_lethal: Array[CombatRelationshipState] = _bilateral_pair()
	both_lethal[0].mark_lethal_target(DEFENDER_ID)
	both_lethal[1].mark_lethal_target(ATTACKER_ID)
	_assert_no_stop(both_lethal, "bilateral lethal blocks friendly stop")
	var unilateral: Array[CombatRelationshipState] = [
		_state_with_opponents(ATTACKER_ID, [DEFENDER_ID]),
		RelationshipStateScript.new(DEFENDER_ID),
	]
	_assert_no_stop(unilateral, "unilateral fighting blocks friendly stop")
	var reverse_unilateral: Array[CombatRelationshipState] = [
		RelationshipStateScript.new(ATTACKER_ID),
		_state_with_opponents(DEFENDER_ID, [ATTACKER_ID]),
	]
	_assert_no_stop(reverse_unilateral, "reverse unilateral fighting blocks friendly stop")

	var incomplete_pair: Array[CombatRelationshipState] = _bilateral_pair()
	var incomplete_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var incomplete: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
		_ordinary(
			CombatAttackResultScript.Outcome.HIT,
			5,
			CombatAttackResultScript.ThresholdCandidate.NONE,
			OrdinaryAttackResultScript.Outcome.PROGRESSION_FAILED,
		),
		ATTACKER_ID,
		DEFENDER_ID,
		incomplete_pair[0],
		incomplete_pair[1],
		incomplete_rng,
	)
	_assert_eq(incomplete.outcome, PostRelationshipResultScript.Outcome.PRIOR_ATTACK_INCOMPLETE, "incomplete Phase 5B2B2 result stops relationship work")
	_assert_true(incomplete_pair[0].has_opponent(DEFENDER_ID) and incomplete_pair[1].has_opponent(ATTACKER_ID), "prior failure performs no relationship mutation")
	_assert_eq(incomplete_rng.call_count(), 0, "prior failure consumes no winner RNG")
	_assert_false(incomplete.has_winner_presentation_index, "unreached winner is distinct from winner index zero")


func _test_completed_busy_outcomes_do_not_gate_friendly_stop() -> void:
	var busy_results: Array[CombatBusyInterruptResult] = [
		BusyInterruptResultScript.new(
			BusyInterruptResultScript.Outcome.INTEGER_BUSY_CLEARED,
			true,
			BusyInterruptProjectionScript.BusyKind.INTEGER,
			BusyInterruptProjectionScript.InterruptKind.INTEGER,
			true,
			2,
			0,
			3,
		),
		BusyInterruptResultScript.new(
			BusyInterruptResultScript.Outcome.INTEGER_BUSY_REMAINED,
			true,
			BusyInterruptProjectionScript.BusyKind.INTEGER,
			BusyInterruptProjectionScript.InterruptKind.INTEGER,
			true,
			3,
			3,
			3,
		),
		BusyInterruptResultScript.new(
			BusyInterruptResultScript.Outcome.FUNCTION_BUSY_INTEGER_INTERRUPT_NO_OP,
			false,
			BusyInterruptProjectionScript.BusyKind.FUNCTION,
			BusyInterruptProjectionScript.InterruptKind.INTEGER,
		),
	]
	for busy_result: CombatBusyInterruptResult in busy_results:
		var pair: Array[CombatRelationshipState] = _bilateral_pair()
		var rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
		var result: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
			_ordinary(CombatAttackResultScript.Outcome.HIT, 5, CombatAttackResultScript.ThresholdCandidate.NONE, CombatOrdinaryAttackResult.Outcome.COMPLETED, busy_result),
			ATTACKER_ID,
			DEFENDER_ID,
			pair[0],
			pair[1],
			rng,
		)
		_assert_eq(result.outcome, PostRelationshipResultScript.Outcome.COMPLETED, "completed busy outcome does not gate friendly stop")
		_assert_false(pair[0].has_opponent(DEFENDER_ID), "completed busy outcome removes attacker relation")
		_assert_false(pair[1].has_opponent(ATTACKER_ID), "completed busy outcome removes defender relation")
		_assert_eq(rng.requested_bounds(), [6], "completed busy outcome reaches winner RNG")

	var failed_pair: Array[CombatRelationshipState] = _bilateral_pair()
	var failed_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var function_interrupt_failure: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
		_ordinary(
			CombatAttackResultScript.Outcome.HIT,
			5,
			CombatAttackResultScript.ThresholdCandidate.NONE,
			CombatOrdinaryAttackResult.Outcome.FUNCTION_INTERRUPT_POLICY_UNAVAILABLE,
			BusyInterruptResultScript.new(
				BusyInterruptResultScript.Outcome.FUNCTION_INTERRUPT_POLICY_UNAVAILABLE,
				true,
				BusyInterruptProjectionScript.BusyKind.INTEGER,
				BusyInterruptProjectionScript.InterruptKind.FUNCTION,
			),
		),
		ATTACKER_ID,
		DEFENDER_ID,
		failed_pair[0],
		failed_pair[1],
		failed_rng,
	)
	_assert_eq(function_interrupt_failure.outcome, PostRelationshipResultScript.Outcome.PRIOR_ATTACK_INCOMPLETE, "function-interrupt failure blocks friendly stop")
	_assert_true(failed_pair[0].has_opponent(DEFENDER_ID) and failed_pair[1].has_opponent(ATTACKER_ID), "function-interrupt failure preserves both relations")
	_assert_eq(failed_rng.call_count(), 0, "function-interrupt failure consumes no winner RNG")


func _test_requested_damage_threshold_and_partial_rng_failure() -> void:
	var threshold_pair: Array[CombatRelationshipState] = _bilateral_pair()
	var threshold: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
		_ordinary(CombatAttackResultScript.Outcome.HIT, 5, CombatAttackResultScript.ThresholdCandidate.DEATH),
		ATTACKER_ID, DEFENDER_ID, threshold_pair[0], threshold_pair[1],
		ScriptedRandomSourceScript.new([0])
	)
	_assert_eq(threshold.outcome, PostRelationshipResultScript.Outcome.COMPLETED, "death candidate does not block source friendly stop")
	_assert_true(threshold.positive_hit_gate_matched, "requested positive D drives gate despite threshold")
	var saturated_attack: CombatAttackResult = threshold.ordinary_attack_result.base_result
	_assert_eq(saturated_attack.calculation.requested_damage, 5, "friendly stop reads requested D")
	_assert_eq(saturated_attack.resource_mutation.vitality_current_before, 0, "saturation fixture begins at zero kee")
	_assert_eq(saturated_attack.resource_mutation.vitality_current_after, -1, "actual current delta is only one while requested D is five")

	var invalid_pair: Array[CombatRelationshipState] = _bilateral_pair()
	var invalid_rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([6])
	var invalid: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
		_ordinary(CombatAttackResultScript.Outcome.HIT, 5), ATTACKER_ID, DEFENDER_ID,
		invalid_pair[0], invalid_pair[1], invalid_rng
	)
	_assert_eq(invalid.outcome, PostRelationshipResultScript.Outcome.WINNER_RANDOM_DRAW_OUT_OF_RANGE, "invalid winner draw typed after removals")
	_assert_false(invalid_pair[0].has_opponent(DEFENDER_ID), "invalid winner draw preserves attacker removal")
	_assert_false(invalid_pair[1].has_opponent(ATTACKER_ID), "invalid winner draw preserves defender removal")
	_assert_true(invalid.partial_relationship_mutation_preserved, "winner failure reports partial relationship mutation")
	_assert_false(invalid.has_winner_presentation_index, "invalid winner draw does not masquerade as index zero")
	_assert_eq(invalid_rng.requested_bounds(), [6], "invalid winner still requests bound six")

	var missing_pair: Array[CombatRelationshipState] = _bilateral_pair()
	var missing: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
		_ordinary(CombatAttackResultScript.Outcome.HIT, 5), ATTACKER_ID, DEFENDER_ID,
		missing_pair[0], missing_pair[1], null
	)
	_assert_eq(missing.outcome, PostRelationshipResultScript.Outcome.WINNER_RANDOM_SOURCE_MISSING, "missing winner RNG typed after removals")
	_assert_true(missing.winner_selection_reached, "missing winner RNG records reached selection stage")
	_assert_false(missing.winner_random_attempted, "missing winner RNG records no draw attempt")
	_assert_false(missing_pair[0].has_opponent(DEFENDER_ID), "missing RNG preserves first removal")
	_assert_false(missing_pair[1].has_opponent(ATTACKER_ID), "missing RNG preserves second removal")


func _test_removal_invariant_ordering() -> void:
	var attacker: CombatRelationshipState = _state_with_opponents(ATTACKER_ID, [DEFENDER_ID])
	var defender: CombatRelationshipState = FailingRelationshipStateScript.new(DEFENDER_ID)
	defender.add_opponent(ATTACKER_ID)
	defender.fail_remove_id = ATTACKER_ID
	var rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var result: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
		_ordinary(CombatAttackResultScript.Outcome.HIT, 5), ATTACKER_ID, DEFENDER_ID,
		attacker, defender, rng
	)
	_assert_eq(result.failure_stage, PostRelationshipResultScript.FailureStage.DEFENDER_RELATION_REMOVAL, "defender invariant failure occurs after attacker removal")
	_assert_true(result.partial_relationship_mutation_preserved, "defender invariant failure reports preserved first removal")
	_assert_false(attacker.has_opponent(DEFENDER_ID), "attacker-first removal remains on defender failure")
	_assert_true(defender.has_opponent(ATTACKER_ID), "failed defender removal remains")
	_assert_eq(rng.call_count(), 0, "winner RNG not reached after removal invariant failure")

	var failing_attacker: CombatRelationshipState = FailingRelationshipStateScript.new(ATTACKER_ID)
	failing_attacker.add_opponent(DEFENDER_ID)
	failing_attacker.fail_remove_id = DEFENDER_ID
	var untouched_defender: CombatRelationshipState = _state_with_opponents(DEFENDER_ID, [ATTACKER_ID])
	var first_failure: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
		_ordinary(CombatAttackResultScript.Outcome.HIT, 5), ATTACKER_ID, DEFENDER_ID,
		failing_attacker, untouched_defender, ScriptedRandomSourceScript.new([0])
	)
	_assert_eq(first_failure.failure_stage, PostRelationshipResultScript.FailureStage.ATTACKER_RELATION_REMOVAL, "attacker removal invariant stops before defender")
	_assert_false(first_failure.defender_removal_attempted, "defender removal is unreached after attacker failure")
	_assert_true(untouched_defender.has_opponent(ATTACKER_ID), "attacker failure leaves defender relation untouched")


func _test_stable_lethal_identity_and_result_immutability() -> void:
	var state: CombatRelationshipState = RelationshipStateScript.new(&"hero-instance")
	state.mark_lethal_target(&"bandit-instance-1")
	state.add_opponent(&"bandit-instance-2")
	_assert_false(state.has_lethal_target(&"bandit-instance-2"), "distinct stable CharacterId does not share legacy public-ID lethal marker")
	_assert_true(state.remove_opponent(&"bandit-instance-2"), "nonlethal stable sibling can be removed independently")

	var pair: Array[CombatRelationshipState] = _bilateral_pair()
	var result: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
		_ordinary(CombatAttackResultScript.Outcome.HIT, 5), ATTACKER_ID, DEFENDER_ID,
		pair[0], pair[1], ScriptedRandomSourceScript.new([2])
	)
	var returned_attack: CombatOrdinaryAttackResult = result.ordinary_attack_result
	returned_attack._outcome = OrdinaryAttackResultScript.Outcome.INVALID_COMPOSITION_INPUT
	_assert_eq(result.ordinary_attack_result.outcome, OrdinaryAttackResultScript.Outcome.COMPLETED, "outer result retains defensive attack snapshot")
	var bounds: Array[int] = result.combined_random_upper_bounds()
	bounds.clear()
	_assert_eq(result.combined_random_upper_bounds(), [2, 3, 6], "combined RNG evidence getter is defensive")

	var selection: CombatOpponentSelectionResult = _selection([&"a", &"b"], 1)
	var original_ids: Array[StringName] = selection.original_opponent_ids()
	original_ids.clear()
	_assert_eq(selection.original_opponent_ids(), [&"a", &"b"], "original opponent evidence is defensive")
	var selected_ids: Array[StringName] = selection.resulting_opponent_ids()
	selected_ids.clear()
	_assert_eq(selection.resulting_opponent_ids(), [&"a", &"b"], "selection result collections are defensive")
	var winner_bounds: Array[int] = result.winner_random_upper_bounds()
	winner_bounds.clear()
	_assert_eq(result.winner_random_upper_bounds(), [6], "winner RNG evidence is defensive")


func _assert_selection(
	ids: Array[StringName],
	draw: int,
	expected_id: StringName,
	expected_index: int,
	message: String,
) -> void:
	var result: CombatOpponentSelectionResult = _selection(ids, draw)
	_assert_eq(result.outcome, SelectionResultScript.Outcome.SELECTED, message + " completes")
	_assert_eq(result.selected_opponent_id, expected_id, message + " target")
	_assert_eq(result.selected_index, expected_index, message + " index")
	_assert_eq(result.random_upper_bounds(), [4], message + " bound")


func _selection(ids: Array[StringName], draw: int) -> CombatOpponentSelectionResult:
	var state: CombatRelationshipState = _state_with_opponents(&"owner", ids)
	state.set_last_opponent(&"prior")
	var facts: Array[CombatOpponentAvailabilityFacts] = []
	for opponent_id: StringName in ids:
		facts.append(_fact(opponent_id))
	var result: CombatOpponentSelectionResult = SelectionServiceScript.prepare(
		state,
		facts,
		ScriptedRandomSourceScript.new([draw]),
	)
	_assert_eq(state.last_opponent_id, result.selected_opponent_id, "successful selection sets last opponent")
	_assert_eq(result.last_opponent_before, &"prior", "selection records prior last opponent")
	return result


func _assert_no_stop(pair: Array[CombatRelationshipState], message: String) -> void:
	var attacker_had_defender: bool = pair[0].has_opponent(DEFENDER_ID)
	var defender_had_attacker: bool = pair[1].has_opponent(ATTACKER_ID)
	var rng: ScriptedCombatRandomSource = ScriptedRandomSourceScript.new([0])
	var result: CombatPostRelationshipResult = PostRelationshipServiceScript.apply(
		_ordinary(CombatAttackResultScript.Outcome.HIT, 5), ATTACKER_ID, DEFENDER_ID,
		pair[0], pair[1], rng
	)
	_assert_eq(result.outcome, PostRelationshipResultScript.Outcome.FRIENDLY_STOP_NOT_MATCHED, message)
	_assert_eq(pair[0].has_opponent(DEFENDER_ID), attacker_had_defender, message + " preserves attacker relationship exactly")
	_assert_eq(pair[1].has_opponent(ATTACKER_ID), defender_had_attacker, message + " preserves defender relationship exactly")
	_assert_eq(rng.call_count(), 0, message + " consumes no winner RNG")


func _ordinary(
	branch: int,
	requested_damage: int,
	threshold: int = CombatAttackResult.ThresholdCandidate.NONE,
	ordinary_outcome: int = CombatOrdinaryAttackResult.Outcome.COMPLETED,
	busy_result: CombatBusyInterruptResult = null,
) -> CombatOrdinaryAttackResult:
	var calculation: CombatAttackCalculation = CombatAttackCalculationScript.new()
	calculation._requested_damage = requested_damage
	calculation._random_upper_bounds = [2, 3]
	calculation._random_draws = [0, 1]
	var mutation: CombatResourceMutationResult = CombatResourceMutationResultScript.new(
		branch == CombatAttackResult.Outcome.HIT,
		false,
		requested_damage,
		0,
		0,
		100,
		-1 if requested_damage > 0 else 0,
		100,
	)
	var base: CombatAttackResult = CombatAttackResultScript.new(
		branch,
		CombatAttackResultScript.FailureStage.NONE,
		CombatAttackResultScript.AuthoredPolicyKind.NONE,
		&"",
		threshold,
		ATTACKER_ID,
		DEFENDER_ID,
		&"ordinary-action",
		requested_damage > 0,
		calculation,
		mutation,
	)
	var progression: CombatProgressionResult = CombatProgressionResultScript.new()
	progression._outcome = CombatProgressionResultScript.Outcome.COMPLETED
	progression._reached_stage = CombatProgressionResultScript.ReachedStage.COMPLETED
	var failure_stage: int = OrdinaryAttackResultScript.FailureStage.NONE
	if ordinary_outcome == OrdinaryAttackResultScript.Outcome.PROGRESSION_FAILED:
		failure_stage = OrdinaryAttackResultScript.FailureStage.PROGRESSION
	elif ordinary_outcome == OrdinaryAttackResultScript.Outcome.FUNCTION_INTERRUPT_POLICY_UNAVAILABLE:
		failure_stage = OrdinaryAttackResultScript.FailureStage.BUSY_INTERRUPT
	var resolved_busy_result: CombatBusyInterruptResult = busy_result
	if resolved_busy_result == null:
		resolved_busy_result = BusyInterruptResultScript.new(
			BusyInterruptResultScript.Outcome.DEFENDER_NOT_BUSY
		)
	return OrdinaryAttackResultScript.new(
		ordinary_outcome,
		failure_stage,
		base,
		progression,
		StatusBoundaryResultScript.new(StatusBoundaryResultScript.Outcome.VALIDATED),
		resolved_busy_result,
		ordinary_outcome != OrdinaryAttackResultScript.Outcome.COMPLETED,
	)


func _fact(
	opponent_id: StringName,
	exists: bool = true,
	same_location: bool = true,
	living: bool = true,
) -> CombatOpponentAvailabilityFacts:
	return AvailabilityFactsScript.new(opponent_id, exists, same_location, living)


func _state_with_opponents(
	owner_id: StringName,
	opponent_ids: Array[StringName],
) -> CombatRelationshipState:
	var state: CombatRelationshipState = RelationshipStateScript.new(owner_id)
	for opponent_id: StringName in opponent_ids:
		state.add_opponent(opponent_id)
	return state


func _bilateral_pair() -> Array[CombatRelationshipState]:
	return [
		_state_with_opponents(ATTACKER_ID, [DEFENDER_ID]),
		_state_with_opponents(DEFENDER_ID, [ATTACKER_ID]),
	]


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
