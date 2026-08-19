extends RefCounted

const CharacterAttributesScript := preload(
	"res://core/characters/character_base_attributes.gd"
)
const CharacterResourceScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const CharacterInternalResourceScript := preload(
	"res://core/characters/character_internal_resource_state.gd"
)
const CharacterRecoveryStateScript := preload(
	"res://core/characters/character_recovery_state.gd"
)
const RecoverySkillLevelsScript := preload(
	"res://core/characters/recovery_skill_levels.gd"
)
const CharacterRecoveryScript := preload(
	"res://core/characters/character_recovery.gd"
)
const CharacterStateScript := preload("res://core/characters/character_state.gd")
const ConditionIdsScript := preload("res://core/conditions/condition_ids.gd")
const ConditionUpdateFlagsScript := preload(
	"res://core/conditions/condition_update_flags.gd"
)
const DurationConditionPayloadScript := preload(
	"res://core/conditions/duration_condition_payload.gd"
)
const PoisonConditionPayloadScript := preload(
	"res://core/conditions/poison_condition_payload.gd"
)
const ConditionSystemScript := preload("res://core/conditions/condition_system.gd")
const ConditionUpdateResultScript := preload(
	"res://core/conditions/condition_update_result.gd"
)
const NoHealConditionEffectScript := preload(
	"res://tests/support/no_heal_condition_effect.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_default_condition_state_is_not_shared()
	_test_add_replace_query_and_remove()
	_test_observed_mapping_payload_is_typed()
	_test_snake_poison_continuation_and_expiration()
	_test_snake_poison_zero_and_negative_boundaries()
	_test_bandaged_curing_and_expiration()
	_test_bandaged_negative_duration_continues()
	_test_bandaged_full_resource_still_continues()
	_test_multiple_conditions_use_stable_order()
	_test_no_heal_flag_aggregation_and_recovery_boundary()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_default_condition_state_is_not_shared() -> void:
	var state: CharacterStateScript = CharacterStateScript.new()
	var other_state: CharacterStateScript = CharacterStateScript.new()
	_assert_eq(state.conditions.size(), 0, "default condition collection is empty")
	_assert_true(state.conditions != other_state.conditions, "condition collections are not shared")
	var empty_result: ConditionUpdateResultScript = ConditionSystemScript.new().update_once(state)
	_assert_eq(empty_result.combined_flags, 0, "empty update has no flags")
	_assert_false(empty_result.no_heal_up, "empty update permits recovery")
	state.conditions.add_or_replace_duration(ConditionIdsScript.SNAKE_POISON, 20)
	_assert_eq(state.conditions.size(), 1, "condition added to one character")
	_assert_eq(other_state.conditions.size(), 0, "other character remains unchanged")


func _test_add_replace_query_and_remove() -> void:
	var state: CharacterStateScript = CharacterStateScript.new()
	state.conditions.add_or_replace_duration(ConditionIdsScript.SNAKE_POISON, 20)
	_assert_true(state.conditions.has_condition(ConditionIdsScript.SNAKE_POISON), "added ID exists")
	_assert_eq(state.conditions.size(), 1, "adding creates one entry")
	_assert_duration(state, ConditionIdsScript.SNAKE_POISON, 20, "added duration")

	state.conditions.add_or_replace_duration(ConditionIdsScript.SNAKE_POISON, 5)
	_assert_eq(state.conditions.size(), 1, "applying existing ID replaces in place")
	_assert_duration(state, ConditionIdsScript.SNAKE_POISON, 5, "replacement duration")
	_assert_true(state.conditions.remove_condition(ConditionIdsScript.SNAKE_POISON), "remove reports success")
	_assert_false(state.conditions.has_condition(ConditionIdsScript.SNAKE_POISON), "removed ID is absent")
	_assert_false(state.conditions.remove_condition(ConditionIdsScript.SNAKE_POISON), "missing remove reports false")


func _test_observed_mapping_payload_is_typed() -> void:
	var state: CharacterStateScript = CharacterStateScript.new()
	var payload: PoisonConditionPayloadScript = PoisonConditionPayloadScript.new(
		12,
		4,
		"legacy poison message",
	)
	state.conditions.add_or_replace(ConditionIdsScript.POISON, payload)
	var stored: PoisonConditionPayloadScript = (
		state.conditions.get_condition(ConditionIdsScript.POISON)
		as PoisonConditionPayloadScript
	)
	_assert_true(stored != null, "mapping-shaped poison payload remains typed")
	_assert_eq(stored.damage, 12, "typed poison damage")
	_assert_eq(stored.remaining, 4, "typed poison duration")
	_assert_eq(stored.legacy_message, "legacy poison message", "typed poison message")


func _test_snake_poison_continuation_and_expiration() -> void:
	var state: CharacterStateScript = _full_state()
	var system: ConditionSystemScript = ConditionSystemScript.new()
	state.conditions.add_or_replace_duration(ConditionIdsScript.SNAKE_POISON, 1)

	var first_result: ConditionUpdateResultScript = system.update_once(state)
	_assert_eq(first_result.combined_flags, ConditionUpdateFlagsScript.CONTINUE, "duration one continues")
	_assert_resource(state.vitality, 90, 90, 100, "snake poison first kee wound")
	_assert_resource(state.spirit, 90, 100, 100, "snake poison first sen damage")
	_assert_duration(state, ConditionIdsScript.SNAKE_POISON, 0, "snake duration becomes zero")

	var second_result: ConditionUpdateResultScript = system.update_once(state)
	_assert_eq(second_result.combined_flags, 0, "duration zero update returns no flags")
	_assert_resource(state.vitality, 80, 80, 100, "snake poison zero tick still wounds")
	_assert_resource(state.spirit, 80, 100, 100, "snake poison zero tick still damages")
	_assert_false(state.conditions.has_condition(ConditionIdsScript.SNAKE_POISON), "snake poison expires after zero tick")


func _test_snake_poison_zero_and_negative_boundaries() -> void:
	var system: ConditionSystemScript = ConditionSystemScript.new()
	var zero_state: CharacterStateScript = _full_state()
	zero_state.conditions.add_or_replace_duration(ConditionIdsScript.SNAKE_POISON, 0)
	_assert_eq(system.update_once(zero_state).combined_flags, 0, "zero snake duration expires")
	_assert_resource(zero_state.vitality, 90, 90, 100, "zero duration still wounds once")
	_assert_resource(zero_state.spirit, 90, 100, 100, "zero duration still damages once")

	var negative_state: CharacterStateScript = _full_state()
	negative_state.conditions.add_or_replace_duration(ConditionIdsScript.SNAKE_POISON, -1)
	_assert_eq(system.update_once(negative_state).combined_flags, 0, "negative snake duration expires")
	_assert_resource(negative_state.vitality, 90, 90, 100, "negative duration still wounds once")
	_assert_false(
		negative_state.conditions.has_condition(ConditionIdsScript.SNAKE_POISON),
		"negative snake duration is removed",
	)


func _test_bandaged_curing_and_expiration() -> void:
	var state: CharacterStateScript = _full_state()
	state.vitality.effective = 98
	state.vitality.current = 40
	state.conditions.add_or_replace_duration(ConditionIdsScript.BANDAGED, 0)
	var result: ConditionUpdateResultScript = ConditionSystemScript.new().update_once(state)
	_assert_eq(result.combined_flags, 0, "zero bandaged duration expires")
	_assert_resource(state.vitality, 40, 100, 100, "bandaged cure caps at max_kee")
	_assert_false(state.conditions.has_condition(ConditionIdsScript.BANDAGED), "bandaged removed at zero")


func _test_bandaged_negative_duration_continues() -> void:
	var state: CharacterStateScript = _full_state()
	state.vitality.effective = 90
	state.vitality.current = 40
	state.conditions.add_or_replace_duration(ConditionIdsScript.BANDAGED, -1)
	var result: ConditionUpdateResultScript = ConditionSystemScript.new().update_once(state)
	_assert_eq(
		result.combined_flags,
		ConditionUpdateFlagsScript.CONTINUE,
		"negative bandaged duration continues because LPC tests !duration",
	)
	_assert_resource(state.vitality, 40, 93, 100, "negative duration still cures")
	_assert_duration(state, ConditionIdsScript.BANDAGED, -2, "negative duration decrements")


func _test_bandaged_full_resource_still_continues() -> void:
	var state: CharacterStateScript = _full_state()
	state.conditions.add_or_replace_duration(ConditionIdsScript.BANDAGED, 1)
	var result: ConditionUpdateResultScript = ConditionSystemScript.new().update_once(state)
	_assert_eq(
		result.combined_flags,
		ConditionUpdateFlagsScript.CONTINUE,
		"bandaged continues when no curing is needed",
	)
	_assert_resource(state.vitality, 100, 100, 100, "full vitality is unchanged")
	_assert_duration(state, ConditionIdsScript.BANDAGED, 0, "full-resource duration decrements")


func _test_multiple_conditions_use_stable_order() -> void:
	var state: CharacterStateScript = _full_state()
	state.vitality.effective = 80
	state.vitality.current = 80
	## Add in reverse lexical order; the system still updates bandaged first.
	state.conditions.add_or_replace_duration(ConditionIdsScript.SNAKE_POISON, 1)
	state.conditions.add_or_replace_duration(ConditionIdsScript.BANDAGED, 1)

	var result: ConditionUpdateResultScript = ConditionSystemScript.new().update_once(state)
	_assert_eq(result.combined_flags, ConditionUpdateFlagsScript.CONTINUE, "continue flags combine by OR")
	_assert_resource(state.vitality, 73, 73, 100, "bandaged then snake poison exact result")
	_assert_resource(state.spirit, 90, 100, 100, "snake poison also damages spirit")
	_assert_duration(state, ConditionIdsScript.BANDAGED, 0, "bandaged updated once")
	_assert_duration(state, ConditionIdsScript.SNAKE_POISON, 0, "snake poison updated once")


func _test_no_heal_flag_aggregation_and_recovery_boundary() -> void:
	var state: CharacterStateScript = _full_state()
	state.recovery = CharacterRecoveryStateScript.new(
		CharacterInternalResourceScript.new(20, 100),
		CharacterInternalResourceScript.new(30, 100),
		CharacterInternalResourceScript.new(10, 100),
		5,
		5,
	)
	state.essence.current = 50
	state.conditions.add_or_replace_duration(ConditionIdsScript.SNAKE_POISON, 1)
	state.conditions.add_or_replace_duration(NoHealConditionEffectScript.TEST_CONDITION_ID, 1)
	var system: ConditionSystemScript = ConditionSystemScript.new()
	system.register_effect(NoHealConditionEffectScript.new())

	var result: ConditionUpdateResultScript = system.update_once(state)
	_assert_eq(
		result.combined_flags,
		ConditionUpdateFlagsScript.CONTINUE | ConditionUpdateFlagsScript.NO_HEAL_UP,
		"multiple flags aggregate with bitwise OR",
	)
	_assert_true(result.no_heal_up, "typed result exposes current no-heal decision")
	var essence_after_conditions: int = state.essence.current
	var recovery_updates: int = CharacterRecoveryScript.apply_tick(
		state,
		RecoverySkillLevelsScript.new(20, 20, 20),
		true,
		result.no_heal_up,
	)
	_assert_eq(recovery_updates, 0, "caller passes no-heal result to recovery")
	_assert_eq(state.recovery.food, 5, "blocked recovery consumes no food")
	_assert_eq(state.recovery.water, 5, "blocked recovery consumes no water")
	_assert_eq(state.essence.current, essence_after_conditions, "blocked recovery changes no essence")
	state.conditions.remove_condition(NoHealConditionEffectScript.TEST_CONDITION_ID)
	var next_result: ConditionUpdateResultScript = system.update_once(state)
	_assert_false(next_result.no_heal_up, "no-heal does not persist beyond an update result")


func _full_state() -> CharacterStateScript:
	return CharacterStateScript.new(
		CharacterAttributesScript.new(0, 0, 0, 0, 0, 0, 30),
		CharacterResourceScript.new(100, 100, 100),
		CharacterResourceScript.new(100, 100, 100),
		CharacterResourceScript.new(100, 100, 100),
	)


func _assert_duration(
	state: CharacterStateScript,
	condition_id: StringName,
	expected: int,
	label: String,
) -> void:
	var payload: DurationConditionPayloadScript = (
		state.conditions.get_condition(condition_id) as DurationConditionPayloadScript
	)
	_assert_true(payload != null, label + " payload type")
	if payload != null:
		_assert_eq(payload.remaining, expected, label)


func _assert_resource(
	resource: CharacterResourceScript,
	expected_current: int,
	expected_effective: int,
	expected_maximum: int,
	label: String,
) -> void:
	_assert_eq(resource.current, expected_current, label + " current")
	_assert_eq(resource.effective, expected_effective, label + " effective")
	_assert_eq(resource.maximum, expected_maximum, label + " maximum")
	_assert_true(resource.has_valid_invariants(), label + " invariants")


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
