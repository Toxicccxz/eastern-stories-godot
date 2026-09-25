class_name CombatAttackChainCompletionService
extends RefCounted

const UNARMED_SKILL_ID: StringName = &"unarmed"
const FORCE_SKILL_ID: StringName = &"force"

## Completes one closed forward result and, only when requested, one direct
## QUICK/RIPOSTE do_attack-equivalent reverse body. It never calls fight().
static func complete(
	forward_result: CombatSingleAttackExecutionResult,
	reverse_projection: CombatReverseAttackProjection,
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry = null,
) -> CombatAttackChainResult:
	var result: CombatAttackChainResult = CombatAttackChainResult.new()
	if forward_result != null:
		result._forward_result = forward_result.duplicate_snapshot()
	result._reached_stage = CombatAttackChainResult.ReachedStage.FORWARD_INSPECTED

	if _is_forward_complete_without_reverse(forward_result):
		return _finish(
			result,
			CombatAttackChainResult.Outcome.FORWARD_COMPLETE_NO_REVERSE,
			CombatAttackChainResult.FailureStage.NONE,
			CombatAttackChainResult.ReachedStage.COMPLETED,
			forward_result.partial_mutation_preserved,
		)
	if not _is_reverse_terminal(forward_result):
		return _finish(
			result,
			CombatAttackChainResult.Outcome.FORWARD_INCOMPLETE,
			CombatAttackChainResult.FailureStage.FORWARD_RESULT,
			CombatAttackChainResult.ReachedStage.FORWARD_INSPECTED,
			forward_result != null and forward_result.partial_mutation_preserved,
		)

	result._reverse_required = true
	result._reached_stage = CombatAttackChainResult.ReachedStage.FORWARD_COMPLETE
	var request: CombatRiposteRequest = forward_result.riposte_request
	if request != null:
		result._reverse_request = request.duplicate_snapshot()
		result._reverse_attacker_id = request.attacker_id
		result._reverse_victim_id = request.victim_id
		result._reverse_attack_type = request.attack_type
	if not _is_coherent_request(forward_result, request):
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_REQUEST_INCOHERENT,
			CombatAttackChainResult.FailureStage.REVERSE_REQUEST,
			CombatAttackChainResult.ReachedStage.FORWARD_COMPLETE,
			forward_result.partial_mutation_preserved,
		)

	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_REQUEST_VALIDATED
	if not CombatLiveProjectionValidation.matches(request.attacker_id, request.victim_id, reverse_projection):
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_CONTEXT_INVALID,
			CombatAttackChainResult.FailureStage.REVERSE_CONTEXT,
			CombatAttackChainResult.ReachedStage.REVERSE_REQUEST_VALIDATED,
			forward_result.partial_mutation_preserved,
		)

	var attacker_authority: CombatCharacterAuthority = (
		reverse_projection.attacker_authority()
	)
	var defender_authority: CombatCharacterAuthority = (
		reverse_projection.defender_authority()
	)
	var attacker: CharacterState = attacker_authority.state()
	var defender: CharacterState = defender_authority.state()
	var attack_template: CombatAttackInput = reverse_projection.attack_input_template()
	var projected_attacker: CombatAttackerSnapshot = attack_template.attacker
	var current_weapon: EquippedWeaponRef = attacker.equipment.primary_weapon()
	result._reverse_weapon_present = current_weapon != null
	if current_weapon != null:
		result._reverse_weapon_instance_id = current_weapon.instance_id
		result._reverse_weapon_profile_id = current_weapon.weapon_id

	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_CONTEXT_VALIDATED
	result._reverse_execution_reached = true
	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_ACTION_SELECTION
	var selection: CombatActionSelectionResult = CombatActionSelector.select_action(
		reverse_projection.action_selection_input(),
		random_source,
	)
	result._reverse_action_selection_result = selection.duplicate_snapshot()
	if not selection.succeeded:
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_ACTION_SELECTION_FAILED,
			CombatAttackChainResult.FailureStage.REVERSE_ACTION_SELECTION,
			CombatAttackChainResult.ReachedStage.REVERSE_ACTION_SELECTION,
			_prior_mutation(result),
		)

	var selected_action: CombatActionDefinition = selection.selected_action
	result._reverse_selected_action_id = selected_action.action_id
	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_ACTION_SELECTED
	if not _matches_attack_projection(selected_action, attack_template):
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_ACTION_PROJECTION_MISMATCH,
			CombatAttackChainResult.FailureStage.REVERSE_ACTION_PROJECTION,
			CombatAttackChainResult.ReachedStage.REVERSE_ACTION_SELECTED,
			_prior_mutation(result),
		)

	var attack_input: CombatAttackInput = CombatAttackInput.new(
		projected_attacker,
		attack_template.defender,
		selected_action,
	)
	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_ORDINARY
	var ordinary: CombatOrdinaryAttackResult = CombatAttackCompletionService.resolve(
		attack_input,
		attacker,
		defender,
		reverse_projection.attacker_facts(),
		reverse_projection.defender_facts(),
		reverse_projection.defender_busy_projection(),
		reverse_projection.defender_busy_state(),
		random_source,
		effect_registry,
	)
	result._reverse_ordinary_result = CombatAttackChainResult._copy_ordinary(ordinary)
	if ordinary.outcome != CombatOrdinaryAttackResult.Outcome.COMPLETED:
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_ORDINARY_FAILED,
			CombatAttackChainResult.FailureStage.REVERSE_ORDINARY,
			CombatAttackChainResult.ReachedStage.REVERSE_ORDINARY,
			_prior_mutation(result),
		)

	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_ORDINARY_COMPLETED
	result._has_reverse_legacy_damage = true
	result._reverse_legacy_damage = _legacy_damage_for(ordinary.base_result)
	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_LEGACY_DAMAGE

	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_RELATIONSHIP
	var relationship: CombatPostRelationshipResult = CombatPostRelationshipService.apply(
		ordinary,
		request.attacker_id,
		request.victim_id,
		reverse_projection.attacker_relationship(),
		reverse_projection.defender_relationship(),
		random_source,
	)
	result._reverse_relationship_result = CombatAttackChainResult._copy_relationship(
		relationship
	)
	if relationship.failure_stage != CombatPostRelationshipResult.FailureStage.NONE:
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_RELATIONSHIP_FAILED,
			CombatAttackChainResult.FailureStage.REVERSE_RELATIONSHIP,
			CombatAttackChainResult.ReachedStage.REVERSE_RELATIONSHIP,
			_prior_mutation(result),
		)

	result._reverse_post_action_reached = true
	result._reverse_post_action_policy_id = selected_action.post_action_policy_id
	result._reverse_post_action_policy_present = (
		not result._reverse_post_action_policy_id.is_empty()
	)
	result._reached_stage = CombatAttackChainResult.ReachedStage.REVERSE_POST_ACTION
	if result._reverse_post_action_policy_present:
		return _finish(
			result,
			CombatAttackChainResult.Outcome.REVERSE_POST_ACTION_UNAVAILABLE,
			CombatAttackChainResult.FailureStage.REVERSE_POST_ACTION,
			CombatAttackChainResult.ReachedStage.REVERSE_POST_ACTION,
			_prior_mutation(result),
		)

	## QUICK/RIPOSTE are both non-REGULAR, so the source's final guarding
	## predicate is false without reading or mutating reverse-victim guarding.
	return _finish(
		result,
		CombatAttackChainResult.Outcome.REVERSE_COMPLETE,
		CombatAttackChainResult.FailureStage.NONE,
		CombatAttackChainResult.ReachedStage.COMPLETED,
		_prior_mutation(result),
	)


static func _is_forward_complete_without_reverse(
	forward: CombatSingleAttackExecutionResult,
) -> bool:
	return (
		forward != null
		and forward.outcome
		== CombatSingleAttackExecutionResult.Outcome.COMPLETED_WITHOUT_RIPOSTE
		and forward.failure_stage == CombatSingleAttackExecutionResult.FailureStage.NONE
		and forward.reached_stage == CombatSingleAttackExecutionResult.ReachedStage.COMPLETED
		and not forward.has_riposte_request
	)


static func _is_reverse_terminal(
	forward: CombatSingleAttackExecutionResult,
) -> bool:
	return (
		forward != null
		and forward.outcome
		== CombatSingleAttackExecutionResult.Outcome.REVERSE_ATTACK_REQUIRED
		and forward.failure_stage == CombatSingleAttackExecutionResult.FailureStage.NONE
		and forward.reached_stage == CombatSingleAttackExecutionResult.ReachedStage.COMPLETED
	)


static func _is_coherent_request(
	forward: CombatSingleAttackExecutionResult,
	request: CombatRiposteRequest,
) -> bool:
	if (
		request == null
		or not forward.has_riposte_request
		or not request.is_valid()
		or forward.attack_type != CombatAttackType.Value.REGULAR
		or not forward.has_legacy_damage
		or forward.legacy_damage >= 1
		or not forward.riposte_eligible
		or not forward.riposte_guard_clear_attempted
		or not forward.victim_guarding_before_clear
		or forward.victim_guarding_after_clear
		or not forward.riposte_random_reached
		or not forward.riposte_random_attempted
		or not forward.post_action_reached
		or forward.post_action_policy_present
	):
		return false
	var ordinary: CombatOrdinaryAttackResult = forward.ordinary_attack_result
	var relationship: CombatPostRelationshipResult = forward.post_relationship_result
	if (
		ordinary == null
		or ordinary.outcome != CombatOrdinaryAttackResult.Outcome.COMPLETED
		or relationship == null
		or relationship.failure_stage != CombatPostRelationshipResult.FailureStage.NONE
		or relationship.winner_selection_reached
		or relationship.winner_random_attempted
	):
		return false
	return (
		request.attacker_id == forward.victim_id
		and request.victim_id == forward.attacker_id
		and request.triggering_forward_action_id == forward.selected_action_id
		and request.triggering_legacy_damage == forward.legacy_damage
		and request.random_bound == forward.riposte_random_bound
		and request.random_draw == forward.riposte_random_draw
		and (
			request.attack_type == CombatAttackType.Value.QUICK
			or request.attack_type == CombatAttackType.Value.RIPOSTE
		)
	)


static func _matches_attack_projection(
	selected: CombatActionDefinition,
	template: CombatAttackInput,
) -> bool:
	if selected == null or template == null or not template.is_valid():
		return false
	return template.accepts_action(selected)


static func _legacy_damage_for(base_result: CombatAttackResult) -> int:
	if base_result.outcome == CombatAttackResult.Outcome.DODGE:
		return -1
	if base_result.outcome == CombatAttackResult.Outcome.PARRY:
		return -2
	return base_result.calculation.requested_damage


static func _prior_mutation(result: CombatAttackChainResult) -> bool:
	var mutated: bool = (
		result._forward_result != null
		and result._forward_result.partial_mutation_preserved
	)
	if result._reverse_ordinary_result != null:
		mutated = mutated or _ordinary_mutated(result._reverse_ordinary_result)
	if result._reverse_relationship_result != null:
		mutated = (
			mutated
			or result._reverse_relationship_result.attacker_removal_succeeded
			or result._reverse_relationship_result.defender_removal_succeeded
		)
	return mutated


static func _ordinary_mutated(result: CombatOrdinaryAttackResult) -> bool:
	if result.partial_mutation_preserved:
		return true
	if result.has_base_result:
		var base: CombatAttackResult = result.base_result
		var mutation: CombatResourceMutationResult = base.resource_mutation
		if mutation.damage_transition_completed or mutation.wound_transition_completed:
			return true
		if base.has_standard_force_result:
			if (
				base.standard_force_result.reached_stage
				>= StandardForceHitResult.ReachedStage.FORCE_DEDUCTED
			):
				return true
	var progression: CombatProgressionResult = result.progression_result
	return (
		progression.attacker_combat_experience_incremented()
		or progression.defender_combat_experience_incremented()
		or progression.attacker_potential_incremented()
		or progression.defender_potential_incremented()
		or progression.attacker_skill_improvement_attempted
		or progression.defender_skill_improvement_attempted
	)


static func _finish(
	result: CombatAttackChainResult,
	outcome: int,
	failure_stage: int,
	reached_stage: int,
	partial_mutation_preserved: bool,
) -> CombatAttackChainResult:
	result._outcome = outcome
	result._failure_stage = failure_stage
	result._reached_stage = reached_stage
	result._partial_mutation_preserved = partial_mutation_preserved
	result._rebuild_combined_random_evidence()
	return result
