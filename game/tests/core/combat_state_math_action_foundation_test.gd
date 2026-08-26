extends RefCounted

const CombatRelationshipStateScript := preload(
	"res://core/combat/relationship/combat_relationship_state.gd"
)
const ActionBusyStateScript := preload(
	"res://core/combat/busy/action_busy_state.gd"
)
const CombatSkillPowerInputScript := preload(
	"res://core/combat/math/combat_skill_power_input.gd"
)
const CombatMathScript := preload("res://core/combat/math/combat_math.gd")
const CombatActionDefinitionScript := preload(
	"res://core/combat/action/combat_action_definition.gd"
)
const CombatActionSetScript := preload(
	"res://core/combat/action/combat_action_set.gd"
)
const CombatActionSelectionInputScript := preload(
	"res://core/combat/action/combat_action_selection_input.gd"
)
const CombatActionSelectionResultScript := preload(
	"res://core/combat/action/combat_action_selection_result.gd"
)
const CombatActionSelectorScript := preload(
	"res://core/combat/action/combat_action_selector.gd"
)
const ScriptedCombatRandomSourceScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_relationship_owner_and_local_transitions()
	_test_relationship_order_and_snapshot_isolation()
	_test_relationship_lethal_invariant()
	_test_busy_start_and_advance()
	_test_busy_interrupt_boundaries()
	_test_skill_power_lpc_matrix()
	_test_skill_power_left_associated_truncation()
	_test_action_source_precedence()
	_test_higher_priority_provider_presence_failures()
	_test_action_failures_and_random_contract()
	_test_action_immutability_and_dead_fields()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_relationship_owner_and_local_transitions() -> void:
	var invalid: CombatRelationshipStateScript = CombatRelationshipStateScript.new()
	_assert_false(invalid.is_valid(), "empty owner ID is invalid")
	_assert_false(invalid.add_opponent(&"target"), "invalid owner cannot add opponent")

	var state: CombatRelationshipStateScript = CombatRelationshipStateScript.new(&"hero-1")
	_assert_true(state.is_valid(), "non-empty owner ID is valid")
	_assert_eq(state.owner_character_id, &"hero-1", "owner ID retained")
	_assert_false(state.is_fighting(), "new relationship has no opponents")
	_assert_false(state.add_opponent(&""), "empty opponent rejected")
	_assert_false(state.add_opponent(&"hero-1"), "self opponent rejected")
	_assert_true(state.add_opponent(&"bandit-1"), "ordinary opponent added")
	_assert_true(state.is_fighting(), "one opponent makes local state fighting")
	_assert_true(state.has_opponent(&"bandit-1"), "added opponent found")
	_assert_false(state.add_opponent(&"bandit-1"), "duplicate opponent is no-op")
	_assert_eq(state.opponent_ids().size(), 1, "duplicate does not duplicate")
	_assert_true(state.set_last_opponent(&"bandit-1"), "last opponent accepts valid ID")
	_assert_eq(state.last_opponent_id, &"bandit-1", "last opponent retained")
	state.set_guarding(true)
	_assert_true(state.guarding, "guarding can be set")
	state.set_guarding(false)
	_assert_false(state.guarding, "guarding can be cleared")
	_assert_true(state.remove_opponent(&"bandit-1"), "ordinary opponent removed")
	_assert_false(state.has_opponent(&"bandit-1"), "removed opponent absent")
	_assert_eq(
		state.last_opponent_id,
		&"bandit-1",
		"removing enemy does not invent LPC last-opponent cleanup",
	)
	state.clear_last_opponent()
	_assert_eq(state.last_opponent_id, &"", "last opponent explicitly cleared")


func _test_relationship_order_and_snapshot_isolation() -> void:
	var state: CombatRelationshipStateScript = CombatRelationshipStateScript.new(&"hero")
	state.add_opponent(&"third")
	state.add_opponent(&"first")
	state.add_opponent(&"second")
	var snapshot: Array[StringName] = state.opponent_ids()
	_assert_eq(snapshot, [&"third", &"first", &"second"], "enemy insertion order preserved")
	snapshot.reverse()
	_assert_eq(
		state.opponent_ids(),
		[&"third", &"first", &"second"],
		"returned opponent array is defensive copy",
	)
	_assert_true(state.remove_opponent(&"first"), "middle opponent can be removed")
	_assert_true(state.add_opponent(&"first"), "removed opponent can be re-added")
	_assert_eq(
		state.opponent_ids(),
		[&"third", &"second", &"first"],
		"re-added opponent occupies the newly appended position",
	)
	_assert_false(state.add_opponent(&"second"), "duplicate add remains a no-op")
	_assert_eq(
		state.opponent_ids(),
		[&"third", &"second", &"first"],
		"duplicate add does not reorder opponents",
	)
	var other: CombatRelationshipStateScript = CombatRelationshipStateScript.new(&"other")
	_assert_eq(other.opponent_ids().size(), 0, "relationship instances do not share opponents")


func _test_relationship_lethal_invariant() -> void:
	var state: CombatRelationshipStateScript = CombatRelationshipStateScript.new(&"hero")
	_assert_true(state.mark_lethal_target(&"target"), "kill marker adds local relationship")
	_assert_true(state.has_lethal_target(&"target"), "lethal marker stored")
	_assert_true(state.has_opponent(&"target"), "kill marker also ensures opponent")
	_assert_false(state.mark_lethal_target(&"target"), "duplicate kill marker is no-op")
	_assert_false(state.remove_opponent(&"target"), "lethal marker blocks remove_enemy")
	_assert_true(state.remove_lethal_relation(&"target"), "remove_killer transition succeeds")
	_assert_false(state.has_lethal_target(&"target"), "remove_killer clears marker")
	_assert_false(state.has_opponent(&"target"), "remove_killer also removes opponent")
	state.add_opponent(&"ordinary")
	_assert_true(
		state.remove_lethal_relation(&"ordinary"),
		"remove_killer without marker delegates to ordinary removal",
	)
	var lethal_snapshot: Array[StringName] = state.lethal_target_ids()
	lethal_snapshot.append(&"injected")
	_assert_false(state.has_lethal_target(&"injected"), "lethal ID array is defensive copy")


func _test_busy_start_and_advance() -> void:
	var state: ActionBusyStateScript = ActionBusyStateScript.new()
	_assert_false(state.is_busy(), "new busy state is idle")
	_assert_false(state.start_busy(0, 9), "start_busy zero is no-op")
	_assert_eq(state.busy_value, 0, "zero start preserves busy")
	_assert_eq(state.interrupt_threshold, 0, "zero start preserves interrupt")
	_assert_true(state.start_busy(2, 4), "positive busy starts")
	_assert_true(state.is_busy(), "positive value is busy")
	_assert_true(state.advance(), "two advances to one")
	_assert_eq(state.busy_value, 1, "busy 2 becomes 1")
	_assert_true(state.is_busy(), "busy 1 remains busy")
	_assert_true(state.advance(), "one advances to zero")
	_assert_eq(state.busy_value, 0, "busy 1 becomes 0")
	_assert_false(state.is_busy(), "zero is idle")
	_assert_eq(state.interrupt_threshold, 4, "positive decrement path leaves interrupt stored")
	_assert_false(state.try_interrupt(), "interrupt_me while idle is a no-op")
	_assert_eq(state.interrupt_threshold, 4, "idle interrupt preserves stale threshold")
	_assert_false(state.start_busy(0, 99), "zero start cannot replace stale threshold")
	_assert_eq(state.interrupt_threshold, 4, "zero start preserves stale threshold")
	_assert_true(state.advance(), "idle continuation clears stale interrupt")
	_assert_eq(state.interrupt_threshold, 0, "non-positive continuation clears interrupt")
	state.start_busy(-1, 8)
	_assert_true(state.is_busy(), "negative integer is busy")
	_assert_true(state.advance(), "negative busy advances through clear branch")
	_assert_eq(state.busy_value, 0, "negative advance clears busy")
	_assert_eq(state.interrupt_threshold, 0, "negative advance clears interrupt")
	state.start_busy(5, 7)
	state.start_busy(3, -2)
	_assert_eq(state.busy_value, 3, "new busy replaces old busy")
	_assert_eq(state.interrupt_threshold, -2, "new busy replaces old interrupt")
	_assert_false(state.start_busy(0, 99), "zero cannot overwrite active busy")
	_assert_eq(state.busy_value, 3, "zero overwrite leaves busy intact")
	_assert_eq(state.interrupt_threshold, -2, "zero overwrite leaves interrupt intact")


func _test_busy_interrupt_boundaries() -> void:
	var above: ActionBusyStateScript = ActionBusyStateScript.new()
	above.start_busy(4, 3)
	_assert_false(above.try_interrupt(), "busy above threshold does not interrupt")
	_assert_eq(above.busy_value, 4, "above-threshold busy unchanged")
	var equal: ActionBusyStateScript = ActionBusyStateScript.new()
	equal.start_busy(3, 3)
	_assert_false(equal.try_interrupt(), "equal threshold does not interrupt")
	_assert_eq(equal.busy_value, 3, "equal-threshold busy unchanged")
	var below: ActionBusyStateScript = ActionBusyStateScript.new()
	below.start_busy(2, 3)
	_assert_true(below.try_interrupt(), "strictly below threshold interrupts")
	_assert_eq(below.busy_value, 0, "interrupt clears busy")
	_assert_eq(below.interrupt_threshold, 3, "integer interrupt leaves threshold stored")
	var default_zero: ActionBusyStateScript = ActionBusyStateScript.new()
	default_zero.start_busy(2)
	_assert_false(default_zero.try_interrupt(), "positive busy is not below default zero")
	default_zero.start_busy(-1)
	_assert_true(default_zero.try_interrupt(), "negative busy is below default zero")
	var negative_no_clear: ActionBusyStateScript = ActionBusyStateScript.new()
	negative_no_clear.start_busy(-1, -2)
	_assert_false(negative_no_clear.try_interrupt(), "minus one is above minus two")
	var negative_clear: ActionBusyStateScript = ActionBusyStateScript.new()
	negative_clear.start_busy(-3, -2)
	_assert_true(negative_clear.try_interrupt(), "minus three is below minus two")


func _test_skill_power_lpc_matrix() -> void:
	_assert_skill_power(false, 5, 2, 99, 10, 10, 0, "non-living returns zero")
	_assert_skill_power(true, 2, -2, 5, 10, 10, 2, "L zero returns combat_exp divided by two")
	_assert_skill_power(true, 3, 0, 10, 0, 9, 19, "positive L without positive max_sen")
	_assert_skill_power(true, -2, 0, 10, 0, 9, 8, "negative nonzero L preserves signed cube")
	_assert_skill_power(true, 5, 0, 3, 10, 7, 31, "positive max_sen uses staged scaling")
	_assert_skill_power(true, 5, 0, 3, 0, 7, 44, "zero max_sen uses unscaled branch")
	_assert_skill_power(true, 5, 0, 3, -4, 7, 44, "negative max_sen uses unscaled branch")
	_assert_skill_power(true, 5, 0, 3, 10, 0, 3, "zero current sen removes scaled contribution")
	_assert_skill_power(true, 5, 0, 3, 10, -2, -5, "negative current sen is not clamped")
	_assert_skill_power(true, 2, 3, 3, 10, 7, 31, "positive attack usage bonus is added")
	_assert_skill_power(true, 7, -2, 3, 10, 7, 31, "negative attack usage bonus is added")
	_assert_skill_power(true, 1, 2, 10, 0, 0, 19, "positive defense usage bonus is added")
	_assert_skill_power(true, 5, -2, 10, 0, 0, 19, "negative defense usage bonus is added")
	_assert_skill_power(true, 0, 0, -5, 0, 0, -2, "negative combat_exp truncates toward zero")


func _test_skill_power_left_associated_truncation() -> void:
	var input: CombatSkillPowerInputScript = CombatSkillPowerInputScript.new(
		true,
		5,
		0,
		0,
		7,
		6,
	)
	_assert_eq(CombatMathScript.skill_power(input), 30, "LPC computes (125/3)/7*6 as 30")
	_assert_true(
		CombatMathScript.skill_power(input) != 35,
		"formula is not algebraically rearranged to 125*6/(3*7)",
	)


func _test_action_source_precedence() -> void:
	var mapped: CombatActionSetScript = _action_set([_action(&"mapped-0"), _action(&"mapped-1")])
	var weapon: CombatActionSetScript = _action_set([_action(&"weapon-0")])
	var defaults: CombatActionSetScript = _action_set([_action(&"default-0")])
	var mapped_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([1])
	var mapped_result: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(true, mapped, true, weapon, defaults),
		mapped_rng,
	)
	_assert_true(mapped_result.succeeded, "mapped provider selection succeeds")
	_assert_eq(
		mapped_result.source_kind,
		CombatActionSelectionResultScript.SourceKind.MAPPED_MARTIAL,
		"mapped provider has first precedence",
	)
	_assert_eq(mapped_result.selected_action.action_id, &"mapped-1", "mapped indexed action selected")
	_assert_eq(mapped_rng.call_count(), 1, "mapped selection consumes exactly one draw")
	_assert_eq(mapped_rng.requested_bounds(), [2], "draw bound is mapped action count")

	var weapon_result: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(false, null, true, weapon, defaults),
		ScriptedCombatRandomSourceScript.new([0]),
	)
	_assert_eq(
		weapon_result.source_kind,
		CombatActionSelectionResultScript.SourceKind.PRIMARY_WEAPON,
		"primary weapon precedes default actions",
	)
	_assert_eq(weapon_result.selected_action.action_id, &"weapon-0", "weapon action selected")

	var secondary_only: CombatActionSetScript = _action_set([_action(&"secondary-action")])
	_assert_true(secondary_only.is_valid(), "synthetic secondary set itself is valid")
	var default_result: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(false, null, false, null, defaults),
		ScriptedCombatRandomSourceScript.new([0]),
	)
	_assert_eq(
		default_result.source_kind,
		CombatActionSelectionResultScript.SourceKind.DEFAULT_ACTIONS,
		"no secondary source channel participates in ordinary selection",
	)
	_assert_eq(default_result.selected_action.action_id, &"default-0", "default action selected")


func _test_higher_priority_provider_presence_failures() -> void:
	var weapon: CombatActionSetScript = _action_set([_action(&"weapon")])
	var defaults: CombatActionSetScript = _action_set([_action(&"default")])
	var mapped_missing_rng: ScriptedCombatRandomSourceScript = (
		ScriptedCombatRandomSourceScript.new([0])
	)
	var mapped_missing: CombatActionSelectionResultScript = (
		CombatActionSelectorScript.select_action(
			CombatActionSelectionInputScript.new(
				true,
				null,
				true,
				weapon,
				defaults,
			),
			mapped_missing_rng,
		)
	)
	_assert_eq(
		mapped_missing.outcome,
		CombatActionSelectionResultScript.Outcome.MAPPED_ACTION_DATA_UNAVAILABLE,
		"mapped skill with unavailable data fails at mapped provider",
	)
	_assert_eq(
		mapped_missing.source_kind,
		CombatActionSelectionResultScript.SourceKind.MAPPED_MARTIAL,
		"mapped unavailable result retains selected source kind",
	)
	_assert_eq(mapped_missing_rng.call_count(), 0, "mapped unavailable data consumes no RNG")
	_assert_true(mapped_missing.selected_action == null, "mapped unavailable data selects no fallback")

	var weapon_missing_rng: ScriptedCombatRandomSourceScript = (
		ScriptedCombatRandomSourceScript.new([0])
	)
	var weapon_missing: CombatActionSelectionResultScript = (
		CombatActionSelectorScript.select_action(
			CombatActionSelectionInputScript.new(
				false,
				null,
				true,
				null,
				defaults,
			),
			weapon_missing_rng,
		)
	)
	_assert_eq(
		weapon_missing.outcome,
		CombatActionSelectionResultScript.Outcome.PRIMARY_WEAPON_ACTION_DATA_UNAVAILABLE,
		"primary weapon with unavailable data fails at weapon provider",
	)
	_assert_eq(
		weapon_missing.source_kind,
		CombatActionSelectionResultScript.SourceKind.PRIMARY_WEAPON,
		"weapon unavailable result retains selected source kind",
	)
	_assert_eq(weapon_missing_rng.call_count(), 0, "weapon unavailable data consumes no RNG")
	_assert_true(weapon_missing.selected_action == null, "weapon unavailable data selects no default")

	var stale_mapped_set: CombatActionSetScript = _action_set([_action(&"stale-mapped")])
	var mapped_absent: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(
			false,
			stale_mapped_set,
			true,
			weapon,
			defaults,
		),
		ScriptedCombatRandomSourceScript.new([0]),
	)
	_assert_eq(
		mapped_absent.selected_action.action_id,
		&"weapon",
		"mapped presence fact, not an incidental set reference, controls precedence",
	)


func _test_action_failures_and_random_contract() -> void:
	var lower_priority: CombatActionSetScript = _action_set([_action(&"lower-priority")])
	var no_source_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0])
	var no_source: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(),
		no_source_rng,
	)
	_assert_eq(no_source.outcome, CombatActionSelectionResultScript.Outcome.NO_ACTION_SOURCE, "no source typed failure")
	_assert_eq(no_source_rng.call_count(), 0, "missing source fails before random")

	var empty_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0])
	var empty_result: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(
			true,
			CombatActionSetScript.new(),
			true,
			lower_priority,
			lower_priority,
		),
		empty_rng,
	)
	_assert_eq(empty_result.outcome, CombatActionSelectionResultScript.Outcome.EMPTY_ACTION_SET, "empty set typed failure")
	_assert_eq(empty_rng.call_count(), 0, "empty set fails before random")

	var invalid_set: CombatActionSetScript = _action_set([_action(&"")])
	var invalid_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0])
	var invalid_result: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(
			true,
			invalid_set,
			true,
			lower_priority,
			lower_priority,
		),
		invalid_rng,
	)
	_assert_eq(invalid_result.outcome, CombatActionSelectionResultScript.Outcome.INVALID_ACTION_SET, "empty action ID invalidates set")
	_assert_eq(invalid_rng.call_count(), 0, "invalid set fails before random")

	var valid: CombatActionSetScript = _action_set([_action(&"one"), _action(&"two")])
	var bad_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([2])
	var bad_draw: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(true, valid),
		bad_rng,
	)
	_assert_eq(bad_draw.outcome, CombatActionSelectionResultScript.Outcome.RANDOM_DRAW_OUT_OF_RANGE, "upper-bound draw rejected")
	_assert_eq(bad_draw.selected_index, 2, "invalid scripted index exposed deterministically")
	_assert_eq(bad_rng.call_count(), 1, "invalid draw still consumes exactly one request")
	var negative_draw: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(true, valid),
		ScriptedCombatRandomSourceScript.new([-1]),
	)
	_assert_eq(negative_draw.outcome, CombatActionSelectionResultScript.Outcome.RANDOM_DRAW_OUT_OF_RANGE, "negative draw rejected")
	var missing_rng: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(true, valid),
		null,
	)
	_assert_eq(missing_rng.outcome, CombatActionSelectionResultScript.Outcome.RANDOM_SOURCE_MISSING, "missing RNG typed failure")


func _test_action_immutability_and_dead_fields() -> void:
	var action: CombatActionDefinitionScript = CombatActionDefinitionScript.new(
		&"slash",
		25,
		10,
		&"cut",
		&"combat.action.slash",
		"$N挥出一式",
		"$w",
		&"throw-stack",
	)
	var caller_actions: Array[CombatActionDefinition] = [action]
	var action_set: CombatActionSetScript = CombatActionSetScript.new(caller_actions)
	caller_actions.clear()
	_assert_eq(action_set.size(), 1, "action set copies caller array")
	var returned: Array[CombatActionDefinition] = action_set.actions()
	returned.clear()
	_assert_eq(action_set.size(), 1, "returned action array cannot mutate set")
	var selected: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(true, action_set),
		ScriptedCombatRandomSourceScript.new([0]),
	)
	var first_snapshot: CombatActionDefinitionScript = selected.selected_action
	var second_snapshot: CombatActionDefinitionScript = selected.selected_action
	_assert_true(first_snapshot != second_snapshot, "selection result returns action snapshots")
	_assert_eq(first_snapshot.action_id, &"slash", "action ID retained")
	_assert_eq(first_snapshot.damage_percent, 25, "damage percent retained without clamp")
	_assert_eq(first_snapshot.force_percent, 10, "force percent retained without clamp")
	_assert_eq(first_snapshot.damage_type, &"cut", "damage tag retained")
	_assert_eq(first_snapshot.presentation_key, &"combat.action.slash", "presentation key retained")
	_assert_eq(first_snapshot.legacy_action_text, "$N挥出一式", "legacy action text is metadata")
	_assert_eq(first_snapshot.displayed_weapon_or_body_token, "$w", "display token retained")
	_assert_eq(first_snapshot.post_action_policy_id, &"throw-stack", "policy ID retained without Callable")
	first_snapshot._action_id = &"mutated-result"
	_assert_eq(
		selected.selected_action.action_id,
		&"slash",
		"mutating a returned snapshot cannot alter result state",
	)
	action._action_id = &"mutated-source"
	_assert_eq(action_set.action_at(0).action_id, &"slash", "set snapshots source definitions")
	var duplicate_ids: CombatActionSetScript = _action_set([_action(&"same"), _action(&"same")])
	_assert_false(duplicate_ids.is_valid(), "duplicate stable action IDs invalidate collection")
	var duplicate_rng: ScriptedCombatRandomSourceScript = ScriptedCombatRandomSourceScript.new([0])
	var duplicate_result: CombatActionSelectionResultScript = CombatActionSelectorScript.select_action(
		CombatActionSelectionInputScript.new(true, duplicate_ids),
		duplicate_rng,
	)
	_assert_eq(
		duplicate_result.outcome,
		CombatActionSelectionResultScript.Outcome.INVALID_ACTION_SET,
		"duplicate action IDs fail as invalid data",
	)
	_assert_eq(duplicate_rng.call_count(), 0, "duplicate IDs fail before RNG")
	var property_names: Array[StringName] = []
	for property: Dictionary in first_snapshot.get_property_list():
		property_names.append(StringName(property["name"]))
	_assert_false(property_names.has(&"dodge"), "dead legacy dodge field is not active model state")
	_assert_false(property_names.has(&"parry"), "dead legacy parry field is not active model state")


func _assert_skill_power(
	living: bool,
	effective_level: int,
	usage_bonus: int,
	combat_experience: int,
	maximum_spirit: int,
	current_spirit: int,
	expected: int,
	message: String,
) -> void:
	var input: CombatSkillPowerInputScript = CombatSkillPowerInputScript.new(
		living,
		effective_level,
		usage_bonus,
		combat_experience,
		maximum_spirit,
		current_spirit,
	)
	_assert_eq(CombatMathScript.skill_power(input), expected, message)


func _action(action_id: StringName) -> CombatActionDefinition:
	return CombatActionDefinitionScript.new(action_id)


func _action_set(actions: Array[CombatActionDefinition]) -> CombatActionSet:
	return CombatActionSetScript.new(actions)


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
