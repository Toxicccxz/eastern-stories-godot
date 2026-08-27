extends RefCounted

const CharacterStateScript := preload("res://core/characters/character_state.gd")
const CharacterResourceScript := preload(
	"res://core/characters/character_resource_state.gd"
)
const ActionDefinitionScript := preload(
	"res://core/combat/action/combat_action_definition.gd"
)
const ActionSetScript := preload("res://core/combat/action/combat_action_set.gd")
const SelectionInputScript := preload(
	"res://core/combat/action/combat_action_selection_input.gd"
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
const WeaponProfileScript := preload(
	"res://core/combat/resolution/weapon_combat_profile.gd"
)
const HitPolicyStatusScript := preload(
	"res://core/combat/resolution/combat_hit_policy_status.gd"
)
const ProgressionFactsScript := preload(
	"res://core/combat/completion/combat_progression_facts.gd"
)
const BusyProjectionScript := preload(
	"res://core/combat/completion/combat_busy_interrupt_projection.gd"
)
const RelationshipScript := preload(
	"res://core/combat/relationship/combat_relationship_state.gd"
)
const FailingRelationshipScript := preload(
	"res://tests/support/failing_combat_relationship_state.gd"
)
const FightFactsScript := preload(
	"res://core/combat/fight/combat_fight_decision_facts.gd"
)
const FightServiceScript := preload(
	"res://core/combat/fight/combat_fight_decision_service.gd"
)
const AttackTypeScript := preload("res://core/combat/fight/combat_attack_type.gd")
const RawComposureAuthorityScript := preload(
	"res://core/combat/execution/combat_raw_composure_authority.gd"
)
const ForwardServiceScript := preload(
	"res://core/combat/execution/combat_single_attack_execution_service.gd"
)
const ForwardResultScript := preload(
	"res://core/combat/execution/combat_single_attack_execution_result.gd"
)
const CharacterAuthorityScript := preload(
	"res://core/combat/execution/combat_character_authority.gd"
)
const ReverseProjectionScript := preload(
	"res://core/combat/execution/combat_reverse_attack_projection.gd"
)
const ReverseModifierProjectionScript := preload(
	"res://core/combat/execution/combat_reverse_modifier_projection.gd"
)
const ChainResultScript := preload(
	"res://core/combat/execution/combat_attack_chain_result.gd"
)
const ChainServiceScript := preload(
	"res://core/combat/execution/combat_attack_chain_completion_service.gd"
)
const ScriptedRandomScript := preload(
	"res://tests/support/scripted_combat_random_source.gd"
)
const WeaponDefinitionScript := preload("res://core/equipment/weapon_definition.gd")
const EquippedWeaponRefScript := preload("res://core/equipment/equipped_weapon_ref.gd")

const ATTACKER_ID: StringName = &"forward-attacker"
const VICTIM_ID: StringName = &"forward-victim"
const LIVE_EXP: int = -2147483648

enum ForwardBranch {
	DODGE_QUICK,
	PARRY_RIPOSTE,
}

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_forward_contract_and_request_coherence()
	_test_live_progression_freshness_and_continuous_rng()
	_test_live_identity_threshold_and_relationship_independence()
	_test_live_weapon_and_action_source()
	_test_primary_secondary_weapon_semantics()
	_test_reverse_outcomes_and_no_second_riposte()
	_test_failure_partial_mutations_and_post_action()
	_test_result_immutability_and_scope()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_forward_contract_and_request_coherence() -> void:
	var no_reverse: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[],
		false,
		false,
	)
	var no_reverse_result: CombatAttackChainResult = ChainServiceScript.complete(
		no_reverse["forward"], null, null
	)
	_assert_eq(no_reverse_result.outcome, ChainResultScript.Outcome.FORWARD_COMPLETE_NO_REVERSE, "completed forward without request completes lazily")
	_assert_false(no_reverse_result.reverse_required, "no-request forward requires no reverse projection")
	_assert_false(no_reverse_result.reverse_execution_reached, "no-request forward reaches no reverse execution")
	_assert_eq(no_reverse_result.combined_random_upper_bounds(), no_reverse["forward"].combined_random_upper_bounds(), "no-request chain preserves forward RNG exactly")

	var incomplete_forward: CombatSingleAttackExecutionResult = ForwardResultScript.new()
	var incomplete_result: CombatAttackChainResult = ChainServiceScript.complete(
		incomplete_forward, null, null
	)
	_assert_eq(incomplete_result.outcome, ChainResultScript.Outcome.FORWARD_INCOMPLETE, "incomplete forward masks no later failure")
	_assert_eq(incomplete_result.failure_stage, ChainResultScript.FailureStage.FORWARD_RESULT, "incomplete forward has exact stage")
	_assert_false(incomplete_result.reverse_required, "incomplete forward inspects no reverse context")
	var lazy_rng: ScriptedCombatRandomSource = ScriptedRandomScript.new([0])
	var malformed_ignored: CombatAttackChainResult = ChainServiceScript.complete(
		incomplete_forward,
		ReverseProjectionScript.new(),
		lazy_rng,
	)
	_assert_eq(malformed_ignored.outcome, ChainResultScript.Outcome.FORWARD_INCOMPLETE, "malformed reverse projection cannot mask forward failure")
	_assert_eq(lazy_rng.call_count(), 0, "forward failure never consumes reverse RNG")

	var invalid_request_bundle: Dictionary = _forward_bundle(ForwardBranch.DODGE_QUICK)
	var corrupted: CombatSingleAttackExecutionResult = invalid_request_bundle["forward"].duplicate_snapshot()
	var bad_request: CombatRiposteRequest = corrupted.riposte_request
	bad_request._attack_type = AttackTypeScript.Value.REGULAR
	corrupted._riposte_request = bad_request
	var calls_before: int = invalid_request_bundle["rng"].call_count()
	var invalid_request_result: CombatAttackChainResult = ChainServiceScript.complete(
		corrupted, null, invalid_request_bundle["rng"]
	)
	_assert_eq(invalid_request_result.outcome, ChainResultScript.Outcome.REVERSE_REQUEST_INCOHERENT, "REGULAR reverse request is rejected")
	_assert_eq(invalid_request_result.failure_stage, ChainResultScript.FailureStage.REVERSE_REQUEST, "request contradiction has exact stage")
	_assert_eq(invalid_request_bundle["rng"].call_count(), calls_before, "request contradiction consumes no reverse RNG")

	var action_mismatch: CombatSingleAttackExecutionResult = invalid_request_bundle["forward"].duplicate_snapshot()
	var mismatched_request: CombatRiposteRequest = action_mismatch.riposte_request
	mismatched_request._triggering_forward_action_id = &"other-forward-action"
	action_mismatch._riposte_request = mismatched_request
	var action_mismatch_result: CombatAttackChainResult = ChainServiceScript.complete(
		action_mismatch, null, invalid_request_bundle["rng"]
	)
	_assert_eq(action_mismatch_result.outcome, ChainResultScript.Outcome.REVERSE_REQUEST_INCOHERENT, "request action evidence must match forward result")
	_assert_eq(invalid_request_bundle["rng"].call_count(), calls_before, "immutable evidence mismatch consumes no reverse RNG")

	var damage_mismatch: CombatSingleAttackExecutionResult = invalid_request_bundle["forward"].duplicate_snapshot()
	var mismatched_damage_request: CombatRiposteRequest = damage_mismatch.riposte_request
	mismatched_damage_request._triggering_legacy_damage = 0
	damage_mismatch._riposte_request = mismatched_damage_request
	var damage_mismatch_result: CombatAttackChainResult = ChainServiceScript.complete(
		damage_mismatch, null, invalid_request_bundle["rng"]
	)
	_assert_eq(damage_mismatch_result.outcome, ChainResultScript.Outcome.REVERSE_REQUEST_INCOHERENT, "request legacy damage evidence must match forward result")
	_assert_eq(invalid_request_bundle["rng"].call_count(), calls_before, "damage evidence mismatch consumes no reverse RNG")

	var random_mismatch: CombatSingleAttackExecutionResult = invalid_request_bundle["forward"].duplicate_snapshot()
	var mismatched_random_request: CombatRiposteRequest = random_mismatch.riposte_request
	mismatched_random_request._random_bound += 1
	random_mismatch._riposte_request = mismatched_random_request
	var random_mismatch_result: CombatAttackChainResult = ChainServiceScript.complete(
		random_mismatch, null, invalid_request_bundle["rng"]
	)
	_assert_eq(random_mismatch_result.outcome, ChainResultScript.Outcome.REVERSE_REQUEST_INCOHERENT, "request random evidence must match forward result")
	_assert_eq(invalid_request_bundle["rng"].call_count(), calls_before, "random evidence mismatch consumes no reverse RNG")

	var request_id_mismatch: CombatSingleAttackExecutionResult = invalid_request_bundle["forward"].duplicate_snapshot()
	var mismatched_id_request: CombatRiposteRequest = request_id_mismatch.riposte_request
	mismatched_id_request._attacker_id = &"wrong-original-victim"
	request_id_mismatch._riposte_request = mismatched_id_request
	var request_id_result: CombatAttackChainResult = ChainServiceScript.complete(
		request_id_mismatch, null, invalid_request_bundle["rng"]
	)
	_assert_eq(request_id_result.outcome, ChainResultScript.Outcome.REVERSE_REQUEST_INCOHERENT, "request IDs must be the exact forward victim/attacker swap")
	_assert_eq(invalid_request_bundle["rng"].call_count(), calls_before, "request ID mismatch consumes no reverse RNG")

	var winner_mismatch: CombatSingleAttackExecutionResult = invalid_request_bundle["forward"].duplicate_snapshot()
	var contradictory_relationship: CombatPostRelationshipResult = (
		winner_mismatch.post_relationship_result
	)
	contradictory_relationship._winner_selection_reached = true
	winner_mismatch._post_relationship_result = contradictory_relationship
	var winner_mismatch_result: CombatAttackChainResult = ChainServiceScript.complete(
		winner_mismatch, null, invalid_request_bundle["rng"]
	)
	_assert_eq(winner_mismatch_result.outcome, ChainResultScript.Outcome.REVERSE_REQUEST_INCOHERENT, "forward winner evidence cannot coexist with a nonpositive riposte request")
	_assert_eq(invalid_request_bundle["rng"].call_count(), calls_before, "forward winner contradiction consumes no reverse RNG")

	var identity_bundle: Dictionary = _forward_bundle(ForwardBranch.DODGE_QUICK)
	var identity_action: CombatActionDefinition = _action(&"identity-reverse")
	var bad_identity: CombatReverseAttackProjection = _projection(
		identity_bundle,
		_reverse_input(identity_bundle, identity_action),
		_default_selection(identity_action),
	)
	bad_identity._attacker_authority = CharacterAuthorityScript.new(
		&"wrong-reverse-attacker", identity_bundle["victim"]
	)
	var identity_calls: int = identity_bundle["rng"].call_count()
	var identity_result: CombatAttackChainResult = ChainServiceScript.complete(
		identity_bundle["forward"], bad_identity, identity_bundle["rng"]
	)
	_assert_eq(identity_result.outcome, ChainResultScript.Outcome.REVERSE_CONTEXT_INVALID, "reverse authority IDs must match swapped request IDs")
	_assert_eq(identity_bundle["rng"].call_count(), identity_calls, "reverse identity mismatch precedes action selection RNG")

	var swapped_bundle: Dictionary = _forward_bundle(ForwardBranch.DODGE_QUICK)
	var swapped_action: CombatActionDefinition = _action(&"swapped-authority")
	var swapped_projection: CombatReverseAttackProjection = _projection(
		swapped_bundle,
		_reverse_input(swapped_bundle, swapped_action),
		_default_selection(swapped_action),
	)
	swapped_projection._attacker_authority = CharacterAuthorityScript.new(
		ATTACKER_ID, swapped_bundle["attacker"]
	)
	swapped_projection._defender_authority = CharacterAuthorityScript.new(
		VICTIM_ID, swapped_bundle["victim"]
	)
	var swapped_calls: int = swapped_bundle["rng"].call_count()
	var swapped_result: CombatAttackChainResult = ChainServiceScript.complete(
		swapped_bundle["forward"], swapped_projection, swapped_bundle["rng"]
	)
	_assert_eq(swapped_result.outcome, ChainResultScript.Outcome.REVERSE_CONTEXT_INVALID, "forward-oriented CharacterState authorities cannot pass as reverse authorities")
	_assert_eq(swapped_bundle["rng"].call_count(), swapped_calls, "swapped authorities fail before reverse RNG")

	var modifier_bundle: Dictionary = _forward_bundle(ForwardBranch.DODGE_QUICK)
	var modifier_action: CombatActionDefinition = _action(&"foreign-modifiers")
	var modifier_projection: CombatReverseAttackProjection = _projection(
		modifier_bundle,
		_reverse_input(modifier_bundle, modifier_action),
		_default_selection(modifier_action),
	)
	var foreign_modifiers: CombatReverseModifierProjection = (
		modifier_projection.modifier_projection()
	)
	foreign_modifiers._attacker_character_id = &"another-character"
	modifier_projection._modifier_projection = foreign_modifiers
	var modifier_calls: int = modifier_bundle["rng"].call_count()
	var modifier_result: CombatAttackChainResult = ChainServiceScript.complete(
		modifier_bundle["forward"], modifier_projection, modifier_bundle["rng"]
	)
	_assert_eq(modifier_result.outcome, ChainResultScript.Outcome.REVERSE_CONTEXT_INVALID, "foreign scalar modifier ownership is rejected")
	_assert_eq(modifier_bundle["rng"].call_count(), modifier_calls, "modifier owner mismatch fails before reverse RNG")

	var stale_scalar_bundle: Dictionary = _forward_bundle(ForwardBranch.DODGE_QUICK)
	var stale_scalar_action: CombatActionDefinition = _action(&"stale-apply-damage")
	var stale_scalar_projection: CombatReverseAttackProjection = _projection(
		stale_scalar_bundle,
		_reverse_input(stale_scalar_bundle, stale_scalar_action),
		_default_selection(stale_scalar_action),
	)
	var stale_scalars: CombatReverseModifierProjection = (
		stale_scalar_projection.modifier_projection()
	)
	stale_scalars._attacker_apply_damage = 99
	stale_scalar_projection._modifier_projection = stale_scalars
	var stale_scalar_calls: int = stale_scalar_bundle["rng"].call_count()
	var stale_scalar_result: CombatAttackChainResult = ChainServiceScript.complete(
		stale_scalar_bundle["forward"],
		stale_scalar_projection,
		stale_scalar_bundle["rng"],
	)
	_assert_eq(stale_scalar_result.outcome, ChainResultScript.Outcome.REVERSE_CONTEXT_INVALID, "attack input and separately owned apply scalar must agree")
	_assert_eq(stale_scalar_bundle["rng"].call_count(), stale_scalar_calls, "scalar disagreement fails before reverse RNG")


func _test_live_progression_freshness_and_continuous_rng() -> void:
	var stale_bundle: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 0],
		true,
	)
	_assert_eq(stale_bundle["victim"].progression.combat_experience, 2, "forward DODGE progression changes future reverse attacker exp")
	var reverse_action: CombatActionDefinition = _action(&"reverse-default")
	var stale_input: CombatAttackInput = _reverse_input(
		stale_bundle, reverse_action, 1
	)
	var stale_projection: CombatReverseAttackProjection = _projection(
		stale_bundle,
		stale_input,
		_default_selection(reverse_action),
		true,
		true,
	)
	var calls_after_forward: int = stale_bundle["rng"].call_count()
	var stale_result: CombatAttackChainResult = ChainServiceScript.complete(
		stale_bundle["forward"], stale_projection, stale_bundle["rng"]
	)
	_assert_eq(stale_result.outcome, ChainResultScript.Outcome.REVERSE_CONTEXT_INVALID, "stale pre-forward reverse combat_exp is rejected")
	_assert_eq(stale_bundle["rng"].call_count(), calls_after_forward, "stale exp is rejected before reverse action RNG")
	_assert_false(stale_result.reverse_execution_reached, "stale context never starts reverse action selection")
	_assert_false(stale_bundle["victim_relationship"].guarding, "forward guard clear remains committed after stale context failure")

	var fresh_bundle: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 0],
		true,
	)
	var fresh_input: CombatAttackInput = _reverse_input(fresh_bundle, reverse_action)
	var fresh_result: CombatAttackChainResult = ChainServiceScript.complete(
		fresh_bundle["forward"],
		_projection(fresh_bundle, fresh_input, _default_selection(reverse_action), true, true),
		fresh_bundle["rng"],
	)
	_assert_eq(fresh_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "fresh post-forward combat_exp projection is accepted")
	_assert_eq(fresh_result.reverse_attack_type, AttackTypeScript.Value.QUICK, "draw below five carries QUICK into normal reverse body")
	_assert_eq(fresh_result.reverse_attacker_id, VICTIM_ID, "reverse attacker is exact original victim")
	_assert_eq(fresh_result.reverse_victim_id, ATTACKER_ID, "reverse victim is exact original attacker")
	_assert_eq(fresh_result.reverse_legacy_damage, -1, "fresh reverse DODGE keeps legacy sentinel")
	_assert_eq(fresh_result.combined_random_upper_bounds(), [18, 1, 2, 13, 120, 6, 1, 2, 14], "continuous RNG bounds append reverse action/ordinary after complete forward history")
	_assert_eq(fresh_result.combined_random_draws(), [0, 0, 0, 0, 51, 4, 0, 0, 0], "continuous RNG draws contain every call exactly once")
	_assert_eq(fresh_bundle["rng"].call_count(), 9, "same RNG source continues without reset")

	var stale_attribute_bundle: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK, [0, 0, 0]
	)
	stale_attribute_bundle["victim"].attributes.strength = 8
	var stale_attribute_action: CombatActionDefinition = _action(&"stale-attribute")
	var stale_attribute_result: CombatAttackChainResult = ChainServiceScript.complete(
		stale_attribute_bundle["forward"],
		_projection(
			stale_attribute_bundle,
			_reverse_input(stale_attribute_bundle, stale_attribute_action, LIVE_EXP, 10, 6),
			_default_selection(stale_attribute_action)
		),
		stale_attribute_bundle["rng"],
	)
	_assert_eq(stale_attribute_result.outcome, ChainResultScript.Outcome.REVERSE_CONTEXT_INVALID, "stale pre-forward strength projection is rejected")

	var fresh_attribute_bundle: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK, [0, 0, 0]
	)
	fresh_attribute_bundle["victim"].attributes.strength = 8
	var fresh_attribute_action: CombatActionDefinition = _action(&"fresh-attribute")
	var fresh_attribute_result: CombatAttackChainResult = ChainServiceScript.complete(
		fresh_attribute_bundle["forward"],
		_projection(
			fresh_attribute_bundle,
			_reverse_input(fresh_attribute_bundle, fresh_attribute_action, LIVE_EXP, 10, 8),
			_default_selection(fresh_attribute_action)
		),
		fresh_attribute_bundle["rng"],
	)
	_assert_eq(fresh_attribute_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "fresh post-forward strength projection is accepted")

	var stale_skill_bundle: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK, [0, 0, 0]
	)
	var stale_skill_action: CombatActionDefinition = _action(&"stale-skill")
	var pre_change_skill_input: CombatAttackInput = _reverse_input(
		stale_skill_bundle, stale_skill_action
	)
	stale_skill_bundle["victim"].skills.set_raw_level(&"unarmed", 8)
	var stale_skill_result: CombatAttackChainResult = ChainServiceScript.complete(
		stale_skill_bundle["forward"],
		_projection(
			stale_skill_bundle,
			pre_change_skill_input,
			_default_selection(stale_skill_action)
		),
		stale_skill_bundle["rng"],
	)
	_assert_eq(stale_skill_result.outcome, ChainResultScript.Outcome.REVERSE_CONTEXT_INVALID, "stale pre-forward effective attack skill is rejected")

	var fresh_skill_bundle: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK, [0, 0, 0]
	)
	fresh_skill_bundle["victim"].skills.set_raw_level(&"unarmed", 8)
	var fresh_skill_action: CombatActionDefinition = _action(&"fresh-skill")
	var fresh_skill_result: CombatAttackChainResult = ChainServiceScript.complete(
		fresh_skill_bundle["forward"],
		_projection(
			fresh_skill_bundle,
			_reverse_input(fresh_skill_bundle, fresh_skill_action),
			_default_selection(fresh_skill_action)
		),
		fresh_skill_bundle["rng"],
	)
	_assert_eq(fresh_skill_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "fresh post-forward effective attack skill is accepted")


func _test_live_identity_threshold_and_relationship_independence() -> void:
	var unrelated: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 0],
	)
	_assert_true(unrelated["victim_relationship"].remove_opponent(ATTACKER_ID), "test removes reverse attacker relation after forward")
	_assert_true(unrelated["attacker_relationship"].remove_opponent(VICTIM_ID), "test removes reverse defender relation after forward")
	var unrelated_action: CombatActionDefinition = _action(&"no-relationship-required")
	var unrelated_result: CombatAttackChainResult = ChainServiceScript.complete(
		unrelated["forward"],
		_projection(
			unrelated,
			_reverse_input(unrelated, unrelated_action),
			_default_selection(unrelated_action),
		),
		unrelated["rng"],
	)
	_assert_eq(unrelated_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "direct reverse do_attack requires no bilateral fighting precondition")
	_assert_false(unrelated["victim_relationship"].has_opponent(ATTACKER_ID), "reverse does not invent attacker reciprocal relation")
	_assert_false(unrelated["attacker_relationship"].has_opponent(VICTIM_ID), "reverse does not invent defender reciprocal relation")

	var threshold: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 0],
		false,
		true,
		null,
		101,
	)
	_assert_eq(threshold["victim"].life_threshold(), CharacterStateScript.LifeThreshold.UNCONSCIOUS, "post-forward reverse attacker has an unconscious threshold candidate")
	_assert_eq(threshold["forward"].outcome, ForwardResultScript.Outcome.REVERSE_ATTACK_REQUIRED, "synchronous forward still emits reverse request before heartbeat lifecycle")
	var threshold_action: CombatActionDefinition = _action(&"still-living-threshold")
	var threshold_result: CombatAttackChainResult = ChainServiceScript.complete(
		threshold["forward"],
		_projection(
			threshold,
			_reverse_input(threshold, threshold_action),
			_default_selection(threshold_action),
		),
		threshold["rng"],
	)
	_assert_eq(threshold_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "threshold candidate does not replace explicit still-living reverse projection")
	_assert_eq(threshold["victim"].vitality.current, -1, "B2B executes no unconscious lifecycle or recovery")

	var reverse_threshold: Dictionary = _forward_bundle(
		ForwardBranch.PARRY_RIPOSTE,
		[0, 0, 3, 10, 0, 0, 0, 4],
	)
	reverse_threshold["attacker"].vitality.apply_damage(95)
	var reverse_threshold_action: CombatActionDefinition = _action(&"reverse-threshold-tail")
	var reverse_threshold_result: CombatAttackChainResult = ChainServiceScript.complete(
		reverse_threshold["forward"],
		_projection(
			reverse_threshold,
			_reverse_input(reverse_threshold, reverse_threshold_action),
			_default_selection(reverse_threshold_action),
		),
		reverse_threshold["rng"],
	)
	_assert_eq(reverse_threshold_result.reverse_ordinary_result.base_result.threshold_candidate, CombatAttackResult.ThresholdCandidate.UNCONSCIOUS, "reverse ordinary reports but does not execute unconscious lifecycle")
	_assert_true(reverse_threshold_result.reverse_relationship_result.friendly_stop_predicate_matched, "reverse threshold candidate does not suppress friendly-stop tail")
	_assert_true(reverse_threshold_result.reverse_post_action_reached, "reverse threshold candidate still reaches post_action source position")
	_assert_eq(reverse_threshold_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "reverse threshold candidate completes the synchronous do_attack tail")


func _test_live_weapon_and_action_source() -> void:
	var stale_weapon_bundle: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 0],
	)
	_equip_weapon(stale_weapon_bundle["victim"], &"current-instance", &"current-sword", &"sword")
	var weapon_action: CombatActionDefinition = _action(&"weapon-action")
	var stale_profile: WeaponCombatProfile = WeaponProfileScript.new(
		&"old-sword", &"sword", HitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT
	)
	var stale_input: CombatAttackInput = _reverse_input(
		stale_weapon_bundle, weapon_action, LIVE_EXP, 10, 6, stale_profile
	)
	var stale_projection: CombatReverseAttackProjection = _projection(
		stale_weapon_bundle,
		stale_input,
		_weapon_selection(weapon_action),
	)
	var calls_before: int = stale_weapon_bundle["rng"].call_count()
	var stale_result: CombatAttackChainResult = ChainServiceScript.complete(
		stale_weapon_bundle["forward"], stale_projection, stale_weapon_bundle["rng"]
	)
	_assert_eq(stale_result.outcome, ChainResultScript.Outcome.REVERSE_CONTEXT_INVALID, "stale pre-forward weapon profile is rejected")
	_assert_eq(stale_weapon_bundle["rng"].call_count(), calls_before, "stale weapon is rejected before reverse action RNG")

	var live_bundle: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 0],
	)
	_equip_weapon(live_bundle["victim"], &"live-instance", &"live-sword", &"sword")
	live_bundle["victim"].skills.set_raw_level(&"mapped-sword", 1)
	_assert_true(live_bundle["victim"].skills.map_skill(&"sword", &"mapped-sword"), "test establishes current mapped sword source")
	var mapped_action: CombatActionDefinition = _action(&"mapped-current-action")
	var current_profile: WeaponCombatProfile = WeaponProfileScript.new(
		&"live-sword", &"sword", HitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT
	)
	var current_input: CombatAttackInput = _reverse_input(
		live_bundle, mapped_action, LIVE_EXP, 10, 6, current_profile
	)
	var selection: CombatActionSelectionInput = SelectionInputScript.new(
		true,
		ActionSetScript.new([mapped_action]),
		true,
		ActionSetScript.new([weapon_action]),
		ActionSetScript.new([_action(&"default-old-action")]),
	)
	var live_result: CombatAttackChainResult = ChainServiceScript.complete(
		live_bundle["forward"],
		_projection(live_bundle, current_input, selection),
		live_bundle["rng"],
	)
	_assert_eq(live_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "current mapped/weapon projection executes")
	_assert_eq(live_result.reverse_selected_action_id, &"mapped-current-action", "reverse selector reacquires current mapped source before weapon/default")
	_assert_true(live_result.reverse_weapon_present, "reverse call records current primary weapon presence")
	_assert_eq(live_result.reverse_weapon_instance_id, &"live-instance", "reverse call records exact current weapon instance identity")
	_assert_eq(live_result.reverse_weapon_profile_id, &"live-sword", "reverse call records exact current weapon profile identity")
	_assert_eq(live_result.reverse_ordinary_result.base_result.calculation.attack_skill_type, &"sword", "current weapon skill drives reverse ordinary math")
	var request_properties: Array[StringName] = _property_names(live_bundle["forward"].riposte_request)
	_assert_false(request_properties.has(&"weapon"), "closed forward request still contains no weapon")
	_assert_false(request_properties.has(&"weapon_profile"), "closed forward request is not enriched with live weapon state")


func _test_primary_secondary_weapon_semantics() -> void:
	var old_ref: EquippedWeaponRef = _weapon_ref(
		&"old-instance", &"same-sword", &"sword"
	)
	var changed: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 0],
		false,
		true,
		old_ref,
	)
	_assert_true(changed["victim"].equipment.unwield(&"old-instance").succeeded, "test removes old reverse primary after forward")
	var new_ref: EquippedWeaponRef = _weapon_ref(
		&"new-instance", &"same-sword", &"sword"
	)
	_assert_true(changed["victim"].equipment.wield(new_ref, false).succeeded, "test equips new reverse primary after forward")
	var changed_action: CombatActionDefinition = _action(&"changed-current-primary")
	var changed_profile: WeaponCombatProfile = WeaponProfileScript.new(
		&"same-sword", &"sword", HitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT
	)
	var changed_result: CombatAttackChainResult = ChainServiceScript.complete(
		changed["forward"],
		_projection(
			changed,
			_reverse_input(changed, changed_action, LIVE_EXP, 10, 6, changed_profile),
			_weapon_selection(changed_action),
		),
		changed["rng"],
	)
	_assert_eq(changed_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "post-forward replacement primary executes")
	_assert_eq(changed_result.reverse_weapon_instance_id, &"new-instance", "reverse call uses current primary instance even when definition ID is unchanged")

	var removed_ref: EquippedWeaponRef = _weapon_ref(
		&"removed-instance", &"removed-sword", &"sword"
	)
	var now_empty: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 0],
		false,
		true,
		removed_ref,
	)
	_assert_true(now_empty["victim"].equipment.unwield(&"removed-instance").succeeded, "test leaves current primary empty")
	var empty_action: CombatActionDefinition = _action(&"current-unarmed")
	var empty_result: CombatAttackChainResult = ChainServiceScript.complete(
		now_empty["forward"],
		_projection(
			now_empty,
			_reverse_input(now_empty, empty_action),
			_default_selection(empty_action),
		),
		now_empty["rng"],
	)
	_assert_false(empty_result.reverse_weapon_present, "removed pre-reverse primary is not reused")
	_assert_eq(empty_result.reverse_ordinary_result.base_result.calculation.attack_skill_type, &"unarmed", "current empty primary executes unarmed")

	var secondary_attacker: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 0],
	)
	var secondary_ref: EquippedWeaponRef = _weapon_ref(
		&"secondary-instance", &"secondary-sword", &"sword", true
	)
	_assert_true(secondary_attacker["victim"].equipment._restore_weapons(null, secondary_ref), "test restores source-reachable secondary-only reverse attacker")
	var secondary_action: CombatActionDefinition = _action(&"secondary-remains-unarmed")
	var secondary_result: CombatAttackChainResult = ChainServiceScript.complete(
		secondary_attacker["forward"],
		_projection(
			secondary_attacker,
			_reverse_input(secondary_attacker, secondary_action),
			_default_selection(secondary_action),
		),
		secondary_attacker["rng"],
	)
	_assert_eq(secondary_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "secondary-only reverse attacker executes")
	_assert_false(secondary_result.reverse_weapon_present, "secondary-only state supplies null reverse weapon parameter")
	_assert_eq(secondary_result.reverse_action_selection_result.source_kind, CombatActionSelectionResult.SourceKind.DEFAULT_ACTIONS, "secondary weapon is not a primary action provider")
	_assert_eq(secondary_result.reverse_ordinary_result.base_result.calculation.attack_skill_type, &"unarmed", "secondary-only attacker uses unarmed attack skill")
	_assert_eq(secondary_attacker["victim"].equipment.secondary_weapon().instance_id, &"secondary-instance", "secondary weapon remains equipped without promotion")

	var secondary_defender: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 3, 5],
	)
	var defender_secondary_ref: EquippedWeaponRef = _weapon_ref(
		&"defender-secondary", &"defender-sword", &"sword", true
	)
	_assert_true(secondary_defender["attacker"].equipment._restore_weapons(null, defender_secondary_ref), "test restores source-reachable secondary-only reverse defender")
	var defender_action: CombatActionDefinition = _action(&"defender-secondary-parry")
	var defender_result: CombatAttackChainResult = ChainServiceScript.complete(
		secondary_defender["forward"],
		_projection(
			secondary_defender,
			_reverse_input(secondary_defender, defender_action),
			_default_selection(defender_action),
		),
		secondary_defender["rng"],
	)
	_assert_eq(defender_result.reverse_legacy_damage, -2, "secondary-only defender follows unarmed parry branch")
	_assert_eq(defender_result.reverse_ordinary_result.base_result.calculation.parry_power, 10, "secondary defender does not supply primary-weapon parry power")
	_assert_eq(secondary_defender["attacker"].equipment.secondary_weapon().instance_id, &"defender-secondary", "defender secondary weapon remains unpromoted")


func _test_reverse_outcomes_and_no_second_riposte() -> void:
	var cases: Array = [
		["QUICK dodge", ForwardBranch.DODGE_QUICK, [0, 0, 0], _action(&"quick-dodge"), 10, 6, -1],
		["QUICK parry", ForwardBranch.DODGE_QUICK, [0, 0, 3, 0], _action(&"quick-parry"), 10, 6, -2],
		["QUICK zero hit", ForwardBranch.DODGE_QUICK, [0, 0, 3, 10, 0, 0], _action(&"quick-zero"), 1, 0, 0],
		["RIPOSTE dodge", ForwardBranch.PARRY_RIPOSTE, [0, 0, 0], _action(&"riposte-dodge"), 10, 6, -1],
	]
	for case: Array in cases:
		var draws: Array[int] = []
		draws.assign(case[2])
		var bundle: Dictionary = _forward_bundle(case[1], draws)
		bundle["attacker_relationship"].set_guarding(true)
		bundle["victim"].attributes.strength = case[5]
		var action: CombatActionDefinition = case[3]
		var input: CombatAttackInput = _reverse_input(
			bundle, action, LIVE_EXP, case[4], case[5]
		)
		var result: CombatAttackChainResult = ChainServiceScript.complete(
			bundle["forward"],
			_projection(bundle, input, _default_selection(action)),
			bundle["rng"],
		)
		_assert_eq(result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "%s completes normal reverse body" % case[0])
		_assert_eq(result.reverse_legacy_damage, case[6], "%s preserves exact reverse legacy damage" % case[0])
		_assert_true(bundle["attacker_relationship"].guarding, "%s never inspects or clears reverse-victim guard" % case[0])
		_assert_true(bundle["victim_relationship"].has_opponent(ATTACKER_ID), "%s does not friendly-stop reverse attacker relation" % case[0])
		_assert_true(bundle["attacker_relationship"].has_opponent(VICTIM_ID), "%s does not friendly-stop reverse defender relation" % case[0])
		_assert_eq(result.combined_random_upper_bounds().size(), bundle["rng"].call_count(), "%s RNG evidence contains each actual draw once" % case[0])

	var positive: Dictionary = _forward_bundle(
		ForwardBranch.PARRY_RIPOSTE,
		[0, 0, 3, 10, 0, 0, 0, 4],
	)
	positive["attacker_relationship"].set_guarding(true)
	var positive_action: CombatActionDefinition = _action(&"riposte-positive")
	var positive_result: CombatAttackChainResult = ChainServiceScript.complete(
		positive["forward"],
		_projection(
			positive,
			_reverse_input(positive, positive_action),
			_default_selection(positive_action)
		),
		positive["rng"],
	)
	_assert_eq(positive_result.outcome, ChainResultScript.Outcome.REVERSE_COMPLETE, "RIPOSTE positive HIT completes normal body")
	_assert_eq(positive_result.reverse_attack_type, AttackTypeScript.Value.RIPOSTE, "draw five carries RIPOSTE type externally")
	_assert_eq(positive_result.reverse_legacy_damage, 8, "reverse HIT stores requested D rather than resource delta")
	_assert_eq(positive["attacker"].vitality.current, 92, "reverse positive HIT mutates original attacker vitality")
	_assert_true(positive_result.reverse_relationship_result.friendly_stop_predicate_matched, "reverse positive bilateral HIT reaches friendly-stop")
	_assert_true(positive_result.reverse_relationship_result.attacker_removal_succeeded, "reverse attacker relation is removed first")
	_assert_true(positive_result.reverse_relationship_result.defender_removal_succeeded, "reverse defender relation is removed second")
	_assert_eq(positive_result.reverse_relationship_result.winner_random_bound, 6, "reverse friendly winner uses exact bound six")
	_assert_eq(positive_result.reverse_relationship_result.winner_random_draw, 4, "reverse friendly winner preserves exact draw")
	_assert_true(positive["attacker_relationship"].guarding, "positive reverse also leaves reverse-victim guard untouched")
	_assert_eq(positive_result.combined_random_upper_bounds()[-1], 6, "winner draw is terminal chain RNG")

	var winner_failure: Dictionary = _forward_bundle(
		ForwardBranch.PARRY_RIPOSTE,
		[0, 0, 3, 10, 0, 0, 0, 6],
	)
	var winner_action: CombatActionDefinition = _action(&"winner-failure")
	var winner_result: CombatAttackChainResult = ChainServiceScript.complete(
		winner_failure["forward"],
		_projection(
			winner_failure,
			_reverse_input(winner_failure, winner_action),
			_default_selection(winner_action)
		),
		winner_failure["rng"],
	)
	_assert_eq(winner_result.outcome, ChainResultScript.Outcome.REVERSE_RELATIONSHIP_FAILED, "invalid reverse winner draw is a relationship-stage failure")
	_assert_true(winner_result.reverse_relationship_result.attacker_removal_succeeded, "winner failure preserves first relationship removal")
	_assert_true(winner_result.reverse_relationship_result.defender_removal_succeeded, "winner failure preserves second relationship removal")
	_assert_false(winner_failure["victim_relationship"].has_opponent(ATTACKER_ID), "winner failure does not restore reverse attacker relation")
	_assert_false(winner_failure["attacker_relationship"].has_opponent(VICTIM_ID), "winner failure does not restore reverse defender relation")
	_assert_false(winner_result.reverse_post_action_reached, "winner failure stops before reverse post_action")


func _test_failure_partial_mutations_and_post_action() -> void:
	var selection_failure: Dictionary = _forward_bundle(ForwardBranch.DODGE_QUICK)
	var action: CombatActionDefinition = _action(&"unused")
	var selection_calls: int = selection_failure["rng"].call_count()
	var selection_result: CombatAttackChainResult = ChainServiceScript.complete(
		selection_failure["forward"],
		_projection(
			selection_failure,
			_reverse_input(selection_failure, action),
			SelectionInputScript.new()
		),
		selection_failure["rng"],
	)
	_assert_eq(selection_result.outcome, ChainResultScript.Outcome.REVERSE_ACTION_SELECTION_FAILED, "reverse action source failure is typed")
	_assert_eq(selection_failure["rng"].call_count(), selection_calls, "missing reverse action source consumes no RNG")
	_assert_false(selection_failure["victim_relationship"].guarding, "action failure preserves forward guard clear")
	_assert_eq(selection_failure["attacker"].vitality.current, 100, "action failure applies no reverse ordinary mutation")

	var mismatch: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK, [0]
	)
	var selected: CombatActionDefinition = _action(&"selected-reverse")
	var mismatch_result: CombatAttackChainResult = ChainServiceScript.complete(
		mismatch["forward"],
		_projection(
			mismatch,
			_reverse_input(mismatch, _action(&"projected-reverse")),
			_default_selection(selected)
		),
		mismatch["rng"],
	)
	_assert_eq(mismatch_result.outcome, ChainResultScript.Outcome.REVERSE_ACTION_PROJECTION_MISMATCH, "selected reverse action must equal executed projection")
	_assert_eq(mismatch["attacker"].vitality.current, 100, "reverse action mismatch stops before resolver mutation")

	var late_failure: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 3, 10, 0, 0, 0],
	)
	var hit_action: CombatActionDefinition = _action(&"late-hit")
	var late_result: CombatAttackChainResult = ChainServiceScript.complete(
		late_failure["forward"],
		_projection(
			late_failure,
			_reverse_input(late_failure, hit_action),
			_default_selection(hit_action),
			true,
			false
		),
		late_failure["rng"],
	)
	_assert_eq(late_result.outcome, ChainResultScript.Outcome.REVERSE_ORDINARY_FAILED, "late reverse progression failure stops chain")
	_assert_true(late_result.partial_mutation_preserved, "late reverse failure reports committed mutations")
	_assert_eq(late_failure["attacker"].vitality.current, 92, "damage before late progression failure remains committed")
	_assert_false(late_result.reverse_post_action_reached, "ordinary failure reaches no relationship/post_action")

	var relationship_failure: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 3, 10, 0, 0, 0],
	)
	var failing_defender: CombatRelationshipState = FailingRelationshipScript.new(ATTACKER_ID)
	failing_defender.add_opponent(VICTIM_ID)
	failing_defender.fail_remove_id = VICTIM_ID
	var relation_action: CombatActionDefinition = _action(&"relation-hit")
	var relation_result: CombatAttackChainResult = ChainServiceScript.complete(
		relationship_failure["forward"],
		_projection(
			relationship_failure,
			_reverse_input(relationship_failure, relation_action),
			_default_selection(relation_action),
			true,
			true,
			null,
			failing_defender
		),
		relationship_failure["rng"],
	)
	_assert_eq(relation_result.outcome, ChainResultScript.Outcome.REVERSE_RELATIONSHIP_FAILED, "reverse friendly second-removal failure is typed")
	_assert_true(relation_result.reverse_relationship_result.attacker_removal_succeeded, "first reverse relationship removal remains committed")
	_assert_false(relation_result.reverse_relationship_result.defender_removal_succeeded, "injected second reverse removal fails")
	_assert_false(relationship_failure["victim_relationship"].has_opponent(ATTACKER_ID), "reverse attacker side stays removed after failure")
	_assert_true(failing_defender.has_opponent(VICTIM_ID), "reverse defender side remains after failed removal")
	_assert_false(relation_result.reverse_post_action_reached, "relationship failure reaches no reverse post_action")

	var post_bundle: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 0],
	)
	_equip_weapon(post_bundle["victim"], &"post-instance", &"post-sword", &"sword")
	var post_action: CombatActionDefinition = _action(&"reverse-post", &"future-bash")
	var post_profile: WeaponCombatProfile = WeaponProfileScript.new(
		&"post-sword", &"sword", HitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT
	)
	var post_result: CombatAttackChainResult = ChainServiceScript.complete(
		post_bundle["forward"],
		_projection(
			post_bundle,
			_reverse_input(post_bundle, post_action, LIVE_EXP, 10, 6, post_profile),
			_weapon_selection(post_action)
		),
		post_bundle["rng"],
	)
	_assert_eq(post_result.outcome, ChainResultScript.Outcome.REVERSE_POST_ACTION_UNAVAILABLE, "reverse authored post_action stops at exact seam")
	_assert_eq(post_result.failure_stage, ChainResultScript.FailureStage.REVERSE_POST_ACTION, "reverse post_action has exact stage")
	_assert_eq(post_result.reverse_post_action_policy_id, &"future-bash", "reverse policy ID is retained without Callable")
	_assert_eq(post_result.reverse_weapon_instance_id, &"post-instance", "post_action evidence keeps reverse call starting weapon instance")
	_assert_eq(post_result.reverse_weapon_profile_id, &"post-sword", "post_action evidence keeps reverse call starting weapon profile")
	_assert_true(post_result.partial_mutation_preserved, "unavailable post_action preserves forward and reverse mutations")

	var nonpositive_post_cases: Array = [
		["PARRY", [0, 0, 3, 0], _action(&"parry-post", &"future-parry-policy"), 10, 6, -2],
		["HIT zero", [0, 0, 3, 10, 0, 0], _action(&"zero-post", &"future-zero-policy"), 1, 0, 0],
	]
	for case: Array in nonpositive_post_cases:
		var case_draws: Array[int] = []
		case_draws.assign(case[1])
		var case_bundle: Dictionary = _forward_bundle(
			ForwardBranch.DODGE_QUICK,
			case_draws,
		)
		case_bundle["victim"].attributes.strength = case[4]
		var case_action: CombatActionDefinition = case[2]
		var case_result: CombatAttackChainResult = ChainServiceScript.complete(
			case_bundle["forward"],
			_projection(
				case_bundle,
				_reverse_input(case_bundle, case_action, LIVE_EXP, case[3], case[4]),
				_default_selection(case_action),
			),
			case_bundle["rng"],
		)
		_assert_eq(case_result.reverse_legacy_damage, case[5], "%s reaches exact reverse legacy damage before post_action" % case[0])
		_assert_eq(case_result.outcome, ChainResultScript.Outcome.REVERSE_POST_ACTION_UNAVAILABLE, "%s reaches unavailable post_action seam" % case[0])
		_assert_false(case_result.reverse_relationship_result.friendly_stop_predicate_matched, "%s does not invent friendly-stop" % case[0])

	var positive_post_bundle: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 3, 10, 0, 0, 0, 4],
	)
	var positive_post_action: CombatActionDefinition = _action(
		&"positive-reverse-post", &"future-throw"
	)
	var positive_post_result: CombatAttackChainResult = ChainServiceScript.complete(
		positive_post_bundle["forward"],
		_projection(
			positive_post_bundle,
			_reverse_input(positive_post_bundle, positive_post_action),
			_default_selection(positive_post_action)
		),
		positive_post_bundle["rng"],
	)
	_assert_eq(positive_post_result.outcome, ChainResultScript.Outcome.REVERSE_POST_ACTION_UNAVAILABLE, "positive reverse reaches post_action only after friendly-stop")
	_assert_eq(positive_post_bundle["attacker"].vitality.current, 92, "positive reverse damage remains before unavailable post_action")
	_assert_true(positive_post_result.reverse_relationship_result.attacker_removal_succeeded, "positive post_action boundary preserves first friendly removal")
	_assert_true(positive_post_result.reverse_relationship_result.defender_removal_succeeded, "positive post_action boundary preserves second friendly removal")
	_assert_eq(positive_post_result.reverse_relationship_result.winner_random_bound, 6, "winner selection precedes positive reverse post_action")
	_assert_eq(positive_post_result.reverse_post_action_policy_id, &"future-throw", "positive reverse retains unavailable policy ID")


func _test_result_immutability_and_scope() -> void:
	var bundle: Dictionary = _forward_bundle(
		ForwardBranch.DODGE_QUICK,
		[0, 0, 0],
	)
	var action: CombatActionDefinition = _action(&"immutable-reverse")
	var result: CombatAttackChainResult = ChainServiceScript.complete(
		bundle["forward"],
		_projection(bundle, _reverse_input(bundle, action), _default_selection(action)),
		bundle["rng"],
	)
	var bounds: Array[int] = result.combined_random_upper_bounds()
	bounds.clear()
	_assert_false(result.combined_random_upper_bounds().is_empty(), "chain RNG evidence is defensive")
	var returned_forward: CombatSingleAttackExecutionResult = result.forward_result
	returned_forward._legacy_damage = 99
	_assert_eq(result.forward_result.legacy_damage, -1, "returned forward result cannot mutate chain evidence")
	var returned_request: CombatRiposteRequest = result.reverse_request
	returned_request._random_draw = 99
	_assert_eq(result.reverse_request.random_draw, 4, "returned request cannot mutate chain evidence")
	var returned_selection: CombatActionSelectionResult = result.reverse_action_selection_result
	returned_selection._random_draw = 99
	_assert_eq(result.reverse_action_selection_result.random_draw, 0, "returned reverse selection cannot mutate chain evidence")
	var properties: Array[StringName] = _property_names(result)
	for forbidden: StringName in [
		&"attacker_state", &"defender_state", &"character_authority",
		&"relationship_state", &"random_source", &"attack_input",
		&"equipment_state", &"raw_composure_authority", &"second_riposte_request",
	]:
		_assert_false(properties.has(forbidden), "chain result retains no mutable authority: %s" % forbidden)
	_assert_false(properties.has(&"reverse_reverse_request"), "chain result has no nested continuation")


func _forward_bundle(
	branch: int,
	reverse_draws: Array[int] = [],
	progression: bool = false,
	guarding: bool = true,
	victim_primary_before: EquippedWeaponRef = null,
	victim_vitality_damage_before: int = 0,
) -> Dictionary:
	var attacker: CharacterState = _character(1)
	var victim: CharacterState = _character(1)
	if victim_primary_before != null:
		_assert_true(victim.equipment.wield(victim_primary_before, false).succeeded, "test equips pre-forward victim primary")
	if victim_vitality_damage_before != 0:
		victim.vitality.apply_damage(victim_vitality_damage_before)
	var attacker_relationship: CombatRelationshipState = RelationshipScript.new(ATTACKER_ID)
	var victim_relationship: CombatRelationshipState = RelationshipScript.new(VICTIM_ID)
	attacker_relationship.add_opponent(VICTIM_ID)
	victim_relationship.set_guarding(guarding)
	var draws: Array[int] = []
	if branch == ForwardBranch.PARRY_RIPOSTE:
		draws.assign([0, 0, 0, 3, 0, 5])
	elif progression:
		draws.assign([0, 0, 0, 0, 51, 4])
	else:
		draws.assign([0, 0, 0, 0])
		if guarding:
			draws.append(4)
	draws.append_array(reverse_draws)
	var rng: ScriptedCombatRandomSource = ScriptedRandomScript.new(draws)
	var decision: CombatFightDecisionResult = FightServiceScript.decide(
		FightFactsScript.new(
			ATTACKER_ID, true, true, null, attacker.attributes.courage,
			attacker.attributes.bellicosity, VICTIM_ID, true, false,
			victim.attributes.composure,
		),
		attacker_relationship,
		victim_relationship,
		rng,
	)
	var action: CombatActionDefinition = _action(&"forward-action")
	var forward: CombatSingleAttackExecutionResult = ForwardServiceScript.execute(
		decision,
		_default_selection(action),
		_attack_input(ATTACKER_ID, VICTIM_ID, attacker, victim, action),
		attacker,
		victim,
		RawComposureAuthorityScript.new(ATTACKER_ID, attacker.attributes),
		_facts(ATTACKER_ID, attacker, &"unarmed", true),
		_facts(VICTIM_ID, victim, &"unarmed", not progression),
		_not_busy(),
		null,
		attacker_relationship,
		victim_relationship,
		rng,
	)
	return {
		"attacker": attacker,
		"victim": victim,
		"attacker_relationship": attacker_relationship,
		"victim_relationship": victim_relationship,
		"rng": rng,
		"forward": forward,
	}


func _projection(
	bundle: Dictionary,
	input: CombatAttackInput,
	selection: CombatActionSelectionInput,
	attacker_is_user: bool = true,
	defender_is_user: bool = true,
	attacker_relationship: CombatRelationshipState = null,
	defender_relationship: CombatRelationshipState = null,
) -> CombatReverseAttackProjection:
	var reverse_attacker: CharacterState = bundle["victim"]
	var reverse_defender: CharacterState = bundle["attacker"]
	var attack_skill: StringName = input.attacker.projected_attack_skill_type
	return ReverseProjectionScript.new(
		CharacterAuthorityScript.new(VICTIM_ID, reverse_attacker),
		CharacterAuthorityScript.new(ATTACKER_ID, reverse_defender),
		selection,
		input,
		_facts(VICTIM_ID, reverse_attacker, attack_skill, attacker_is_user),
		_facts(ATTACKER_ID, reverse_defender, &"unarmed", defender_is_user),
		_not_busy(),
		null,
		(
			attacker_relationship
			if attacker_relationship != null
			else bundle["victim_relationship"]
		),
		(
			defender_relationship
			if defender_relationship != null
			else bundle["attacker_relationship"]
		),
		_modifier_projection(input),
	)


func _reverse_input(
	bundle: Dictionary,
	action: CombatActionDefinition,
	attacker_exp_override: int = LIVE_EXP,
	apply_damage: int = 10,
	base_strength: int = 6,
	weapon: WeaponCombatProfile = null,
) -> CombatAttackInput:
	return _attack_input(
		VICTIM_ID,
		ATTACKER_ID,
		bundle["victim"],
		bundle["attacker"],
		action,
		attacker_exp_override,
		apply_damage,
		base_strength,
		weapon,
	)


func _attack_input(
	attacker_id: StringName,
	defender_id: StringName,
	attacker: CharacterState,
	defender: CharacterState,
	action: CombatActionDefinition,
	attacker_exp_override: int = LIVE_EXP,
	apply_damage: int = 10,
	base_strength: int = 6,
	weapon: WeaponCombatProfile = null,
) -> CombatAttackInput:
	var attack_skill: StringName = &"unarmed" if weapon == null else weapon.skill_type
	var mapped_attack: StringName = attacker.skills.mapped_skill(attack_skill)
	var mapped_force: StringName = attacker.skills.mapped_skill(&"force")
	var attacker_exp: int = attacker.progression.combat_experience
	if attacker_exp_override != LIVE_EXP:
		attacker_exp = attacker_exp_override
	return AttackInputScript.new(
		AttackerSnapshotScript.new(
			attacker_id,
			true,
			attacker_exp,
			attacker.spirit.current,
			attacker.spirit.maximum,
			attack_skill,
			attacker.skills.effective_level(attack_skill),
			0,
			apply_damage,
			StrengthProjectionScript.new(
				base_strength,
				attacker.attributes.force_factor,
				attacker.attributes.strength_modifier,
			),
			false,
			mapped_force,
			(
				HitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT
				if not mapped_force.is_empty()
				else HitPolicyStatusScript.Value.NOT_APPLICABLE
			),
			mapped_attack,
			(
				HitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT
				if not mapped_attack.is_empty()
				else HitPolicyStatusScript.Value.NOT_APPLICABLE
			),
			(
				HitPolicyStatusScript.Value.PROVEN_NO_AUTHORED_EFFECT
				if weapon == null
				else HitPolicyStatusScript.Value.NOT_APPLICABLE
			),
			weapon,
			&"force",
			attacker.skills.effective_level(&"force"),
		),
		DefenderSnapshotScript.new(
			defender_id,
			true,
			false,
			defender.progression.combat_experience,
			defender.spirit.current,
			defender.spirit.maximum,
			defender.skills.effective_level(&"dodge"),
			defender.skills.effective_level(&"parry"),
			defender.skills.effective_level(&"unarmed"),
			0,
			0,
			not defender.equipment.is_primary_hand_empty(),
			[&"头", &"右臂"],
			&"force",
			defender.skills.effective_level(&"force"),
			defender.recovery.inner_force.current,
			0,
		),
		action,
	)


func _facts(
	character_id: StringName,
	character: CharacterState,
	attack_skill: StringName,
	is_user: bool,
) -> CombatProgressionFacts:
	return ProgressionFactsScript.new(
		character_id,
		is_user,
		character.attributes.intelligence,
		character.attributes.spirituality,
		attack_skill,
		true,
	)


func _modifier_projection(
	input: CombatAttackInput,
) -> CombatReverseModifierProjection:
	var attacker: CombatAttackerSnapshot = input.attacker
	var defender: CombatDefenderSnapshot = input.defender
	return ReverseModifierProjectionScript.new(
		attacker.character_id,
		defender.character_id,
		0,
		0,
		0,
		0,
		0,
		0,
		attacker.attack_usage_bonus,
		defender.defense_usage_bonus,
		attacker.projected_apply_damage,
		defender.armor,
		defender.armor_vs_force,
	)


func _default_selection(action: CombatActionDefinition) -> CombatActionSelectionInput:
	return SelectionInputScript.new(
		false, null, false, null, ActionSetScript.new([action])
	)


func _weapon_selection(action: CombatActionDefinition) -> CombatActionSelectionInput:
	return SelectionInputScript.new(
		false, null, true, ActionSetScript.new([action]), null
	)


func _action(
	action_id: StringName,
	post_action_policy_id: StringName = &"",
) -> CombatActionDefinition:
	return ActionDefinitionScript.new(
		action_id,
		0,
		0,
		&"伤害",
		&"presentation",
		"legacy text",
		"$w",
		post_action_policy_id,
	)


func _not_busy() -> CombatBusyInterruptProjection:
	return BusyProjectionScript.new(
		BusyProjectionScript.BusyKind.NOT_BUSY,
		BusyProjectionScript.InterruptKind.INTEGER,
	)


func _character(combat_experience: int) -> CharacterState:
	var character: CharacterState = CharacterStateScript.new()
	character.attributes.strength = 6
	character.attributes.courage = 1
	character.attributes.intelligence = 20
	character.attributes.spirituality = 20
	character.attributes.composure = 6
	character.essence = CharacterResourceScript.new(100, 100, 100)
	character.vitality = CharacterResourceScript.new(100, 100, 100)
	character.spirit = CharacterResourceScript.new(0, 0, 0)
	character.progression.combat_experience = combat_experience
	character.skills.set_raw_level(&"unarmed", 6)
	character.skills.set_raw_level(&"sword", 6)
	character.skills.set_raw_level(&"dodge", 4)
	character.skills.set_raw_level(&"parry", 4)
	character.skills.set_raw_level(&"force", 0)
	return character


func _equip_weapon(
	character: CharacterState,
	instance_id: StringName,
	weapon_id: StringName,
	skill_type: StringName,
) -> void:
	var reference: EquippedWeaponRef = _weapon_ref(
		instance_id, weapon_id, skill_type
	)
	var transition: EquipmentTransitionResult = character.equipment.wield(
		reference, false
	)
	_assert_true(transition.succeeded, "test weapon setup succeeds")


func _weapon_ref(
	instance_id: StringName,
	weapon_id: StringName,
	skill_type: StringName,
	secondary: bool = false,
) -> EquippedWeaponRef:
	var definition: WeaponDefinition = WeaponDefinitionScript.new(
		weapon_id, skill_type, secondary, false, "legacy/test"
	)
	return EquippedWeaponRefScript.new(instance_id, definition)


func _property_names(value: Object) -> Array[StringName]:
	var names: Array[StringName] = []
	for property: Dictionary in value.get_property_list():
		names.append(StringName(property["name"]))
	return names


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
