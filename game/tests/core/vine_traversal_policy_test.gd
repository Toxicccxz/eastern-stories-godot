extends RefCounted

const WATERFALL_PORTAL: StringName = &"test.vine.waterfall"
const PASSAGE_PORTAL: StringName = &"test.vine.passage"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_strict_branch_boundaries()
	_test_non_positive_bounds()
	_test_invalid_injected_draws()
	_test_input_and_independence()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_strict_branch_boundaries() -> void:
	_assert_branch(5, 0, VineTraversalPolicyResult.Branch.WATERFALL, WATERFALL_PORTAL)
	_assert_branch(5, 4, VineTraversalPolicyResult.Branch.WATERFALL, WATERFALL_PORTAL)
	_assert_branch(6, 4, VineTraversalPolicyResult.Branch.WATERFALL, WATERFALL_PORTAL)
	_assert_branch(6, 5, VineTraversalPolicyResult.Branch.PASSAGE, PASSAGE_PORTAL)
	_assert_branch(20, 19, VineTraversalPolicyResult.Branch.PASSAGE, PASSAGE_PORTAL)


func _test_non_positive_bounds() -> void:
	for bound: int in [0, -4]:
		var random: ScriptedWorldInteractionRandomSource = (
			ScriptedWorldInteractionRandomSource.new([0])
		)
		var result: VineTraversalPolicyResult = _policy().evaluate(bound, random)
		_assert_eq(
			result.outcome,
			VineTraversalPolicyResult.Outcome.LEGACY_RANDOM_BOUND_AMBIGUITY,
			"non-positive bound is typed at the legacy random stage",
		)
		_assert_eq(result.reached_stage, VineTraversalPolicyResult.ReachedStage.RANDOM_BOUND, "ambiguity reaches bound stage only")
		_assert_true(result.legacy_ambiguity, "ambiguity evidence retained")
		_assert_false(result.draw_performed, "non-positive bound performs no draw")
		_assert_eq(random.call_count(), 0, "non-positive bound consumes zero RNG")
		_assert_eq(result.random_bound, bound, "original ambiguous bound retained")
		_assert_eq(result.selected_branch, VineTraversalPolicyResult.Branch.NONE, "ambiguity selects no branch")
		_assert_eq(result.selected_portal_id, &"", "ambiguity selects no portal")


func _test_invalid_injected_draws() -> void:
	for draw: int in [-1, 6]:
		var random: ScriptedWorldInteractionRandomSource = (
			ScriptedWorldInteractionRandomSource.new([draw])
		)
		var result: VineTraversalPolicyResult = _policy().evaluate(6, random)
		_assert_eq(result.outcome, VineTraversalPolicyResult.Outcome.INVALID_RANDOM_DRAW, "out-of-range draw is typed")
		_assert_true(result.draw_performed, "invalid injected draw still records reached RNG call")
		_assert_true(result.invalid_draw, "invalid draw evidence retained")
		_assert_eq(result.draw_value, draw, "invalid draw is not clamped")
		_assert_eq(random.call_count(), 1, "invalid draw has no hidden retry")
		_assert_eq(random.requested_bounds(), [6], "invalid draw used exact positive bound")
		_assert_false(result.branch_selected(), "invalid draw selects no branch")


func _test_input_and_independence() -> void:
	var invalid: VineTraversalPolicyResult = VineTraversalPolicy.new().evaluate(
		6,
		ScriptedWorldInteractionRandomSource.new([5]),
	)
	_assert_eq(invalid.outcome, VineTraversalPolicyResult.Outcome.INVALID_INPUT, "missing portal identities are invalid")
	_assert_false(invalid.draw_performed, "invalid input draws nothing")
	var left_random: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new([4])
	var right_random: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new([5])
	var left: VineTraversalPolicyResult = _policy().evaluate(6, left_random)
	var right: VineTraversalPolicyResult = _policy().evaluate(6, right_random)
	_assert_eq(left.selected_branch, VineTraversalPolicyResult.Branch.WATERFALL, "left policy result independent")
	_assert_eq(right.selected_branch, VineTraversalPolicyResult.Branch.PASSAGE, "right policy result independent")
	_assert_eq(left_random.call_count(), 1, "left RNG has independent call state")
	_assert_eq(right_random.call_count(), 1, "right RNG has independent call state")


func _assert_branch(
	bound: int,
	draw: int,
	expected_branch: int,
	expected_portal: StringName,
) -> void:
	var random: ScriptedWorldInteractionRandomSource = (
		ScriptedWorldInteractionRandomSource.new([draw])
	)
	var result: VineTraversalPolicyResult = _policy().evaluate(bound, random)
	_assert_eq(result.effective_dodge, bound, "effective dodge is the exact random bound")
	_assert_eq(result.random_bound, bound, "random bound retained")
	_assert_eq(result.draw_value, draw, "draw evidence retained")
	_assert_true(result.draw_performed, "positive bound performs a draw")
	_assert_eq(random.call_count(), 1, "valid policy performs exactly one draw")
	_assert_eq(random.requested_bounds(), [bound], "policy requests exact bound")
	_assert_eq(result.reached_stage, VineTraversalPolicyResult.ReachedStage.BRANCH_SELECTED, "valid draw reaches branch selection")
	_assert_eq(result.selected_branch, expected_branch, "strict draw < 5 branch")
	_assert_eq(result.selected_portal_id, expected_portal, "branch selects exact authored portal identity")


func _policy() -> VineTraversalPolicy:
	return VineTraversalPolicy.new(WATERFALL_PORTAL, PASSAGE_PORTAL)


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
