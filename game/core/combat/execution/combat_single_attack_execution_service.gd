class_name CombatSingleAttackExecutionService
extends RefCounted

## Composes exactly one already-decided REGULAR/QUICK attack opportunity.
## A riposte is returned as immutable evidence; this service never executes it.


static func execute(
	fight_decision: CombatFightDecisionResult,
	action_selection_input: CombatActionSelectionInput,
	attack_input_template: CombatAttackInput,
	attacker: CharacterState,
	defender: CharacterState,
	attacker_raw_composure: CombatRawComposureAuthority,
	attacker_facts: CombatProgressionFacts,
	defender_facts: CombatProgressionFacts,
	defender_busy_projection: CombatBusyInterruptProjection,
	defender_busy_state: ActionBusyState,
	attacker_relationship: CombatRelationshipState,
	defender_relationship: CombatRelationshipState,
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry = null,
) -> CombatSingleAttackExecutionResult:
	var result: CombatSingleAttackExecutionResult = CombatSingleAttackExecutionResult.new()
	if fight_decision != null:
		result._fight_decision_result = fight_decision.duplicate_snapshot()
		result._attacker_id = fight_decision.attacker_id
		result._victim_id = fight_decision.victim_id
		result._attack_type = fight_decision.attack_type
	if not _is_valid_attack_intent(fight_decision):
		if _is_completed_non_attack_decision(fight_decision):
			return _finish(
				result,
				CombatSingleAttackExecutionResult.Outcome.UPSTREAM_NOT_APPLICABLE,
				CombatSingleAttackExecutionResult.FailureStage.NONE,
				CombatSingleAttackExecutionResult.ReachedStage.UPSTREAM_VALIDATED,
				_prior_mutation(result),
			)
		return _finish(
			result,
			CombatSingleAttackExecutionResult.Outcome.INVALID_UPSTREAM_RESULT,
			CombatSingleAttackExecutionResult.FailureStage.UPSTREAM_FIGHT_DECISION,
			CombatSingleAttackExecutionResult.ReachedStage.NONE,
			_prior_mutation(result),
		)

	result._reached_stage = CombatSingleAttackExecutionResult.ReachedStage.UPSTREAM_VALIDATED
	if not _has_coherent_authorities(
		fight_decision,
		attack_input_template,
		attacker,
		defender,
		attacker_raw_composure,
		attacker_facts,
		defender_facts,
		attacker_relationship,
		defender_relationship,
	):
		return _finish(
			result,
			CombatSingleAttackExecutionResult.Outcome.CALLER_AUTHORITY_MISMATCH,
			CombatSingleAttackExecutionResult.FailureStage.CALLER_AUTHORITY_BINDING,
			CombatSingleAttackExecutionResult.ReachedStage.UPSTREAM_VALIDATED,
			_prior_mutation(result),
		)
	result._reached_stage = CombatSingleAttackExecutionResult.ReachedStage.ACTION_SELECTION
	var selection: CombatActionSelectionResult = CombatActionSelector.select_action(
		action_selection_input,
		random_source,
	)
	result._action_selection_result = selection.duplicate_snapshot()
	if not selection.succeeded:
		return _finish(
			result,
			CombatSingleAttackExecutionResult.Outcome.ACTION_SELECTION_FAILED,
			CombatSingleAttackExecutionResult.FailureStage.ACTION_SELECTION,
			CombatSingleAttackExecutionResult.ReachedStage.ACTION_SELECTION,
			_prior_mutation(result),
		)

	var selected_action: CombatActionDefinition = selection.selected_action
	result._selected_action_id = selected_action.action_id
	result._reached_stage = CombatSingleAttackExecutionResult.ReachedStage.ACTION_SELECTED
	if not _matches_attack_projection(
		fight_decision,
		selected_action,
		attack_input_template,
	):
		return _finish(
			result,
			CombatSingleAttackExecutionResult.Outcome.SELECTED_ACTION_PROJECTION_MISMATCH,
			CombatSingleAttackExecutionResult.FailureStage.SELECTED_ACTION_PROJECTION,
			CombatSingleAttackExecutionResult.ReachedStage.ACTION_SELECTED,
			_prior_mutation(result),
		)

	var projected_attacker: CombatAttackerSnapshot = attack_input_template.attacker
	var projected_defender: CombatDefenderSnapshot = attack_input_template.defender
	var attack_input: CombatAttackInput = CombatAttackInput.new(
		projected_attacker,
		projected_defender,
		selected_action,
	)
	result._reached_stage = CombatSingleAttackExecutionResult.ReachedStage.ORDINARY_ATTACK
	var ordinary: CombatOrdinaryAttackResult = CombatAttackCompletionService.resolve(
		attack_input,
		attacker,
		defender,
		attacker_facts,
		defender_facts,
		defender_busy_projection,
		defender_busy_state,
		random_source,
		effect_registry,
	)
	result._ordinary_attack_result = CombatSingleAttackExecutionResult._copy_ordinary(
		ordinary
	)
	if ordinary.outcome != CombatOrdinaryAttackResult.Outcome.COMPLETED:
		return _finish(
			result,
			CombatSingleAttackExecutionResult.Outcome.ORDINARY_ATTACK_FAILED,
			CombatSingleAttackExecutionResult.FailureStage.ORDINARY_ATTACK,
			CombatSingleAttackExecutionResult.ReachedStage.ORDINARY_ATTACK,
			_prior_mutation(result),
		)

	result._reached_stage = CombatSingleAttackExecutionResult.ReachedStage.ORDINARY_COMPLETED
	var base_result: CombatAttackResult = ordinary.base_result
	result._has_legacy_damage = true
	result._legacy_damage = _legacy_damage_for(base_result)
	result._reached_stage = CombatSingleAttackExecutionResult.ReachedStage.LEGACY_DAMAGE

	result._reached_stage = CombatSingleAttackExecutionResult.ReachedStage.POST_RELATIONSHIP
	var post_relationship: CombatPostRelationshipResult = CombatPostRelationshipService.apply(
		ordinary,
		result._attacker_id,
		result._victim_id,
		attacker_relationship,
		defender_relationship,
		random_source,
	)
	result._post_relationship_result = (
		CombatSingleAttackExecutionResult._copy_post_relationship(post_relationship)
	)
	if post_relationship.failure_stage != CombatPostRelationshipResult.FailureStage.NONE:
		return _finish(
			result,
			CombatSingleAttackExecutionResult.Outcome.POST_RELATIONSHIP_FAILED,
			CombatSingleAttackExecutionResult.FailureStage.POST_RELATIONSHIP,
			CombatSingleAttackExecutionResult.ReachedStage.POST_RELATIONSHIP,
			_prior_mutation(result),
		)

	result._post_action_reached = true
	result._post_action_policy_id = selected_action.post_action_policy_id
	result._post_action_policy_present = not result._post_action_policy_id.is_empty()
	result._post_action_weapon_present = projected_attacker.has_weapon
	if result._post_action_weapon_present:
		result._post_action_weapon_id = projected_attacker.weapon_profile.weapon_id
	result._reached_stage = CombatSingleAttackExecutionResult.ReachedStage.POST_ACTION
	if result._post_action_policy_present:
		return _finish(
			result,
			CombatSingleAttackExecutionResult.Outcome.AUTHORED_POST_ACTION_POLICY_UNAVAILABLE,
			CombatSingleAttackExecutionResult.FailureStage.POST_ACTION,
			CombatSingleAttackExecutionResult.ReachedStage.POST_ACTION,
			_prior_mutation(result),
		)

	result._riposte_evaluation_reached = true
	result._victim_guarding_observed = defender_relationship.guarding
	result._riposte_eligible = (
		fight_decision.attack_type == CombatAttackType.Value.REGULAR
		and result._legacy_damage < 1
		and result._victim_guarding_observed
	)
	result._reached_stage = CombatSingleAttackExecutionResult.ReachedStage.RIPOSTE_EVALUATION
	if not result._riposte_eligible:
		return _finish(
			result,
			CombatSingleAttackExecutionResult.Outcome.COMPLETED_WITHOUT_RIPOSTE,
			CombatSingleAttackExecutionResult.FailureStage.NONE,
			CombatSingleAttackExecutionResult.ReachedStage.COMPLETED,
			_prior_mutation(result),
		)

	result._riposte_guard_clear_attempted = true
	result._victim_guarding_before_clear = defender_relationship.guarding
	defender_relationship.set_guarding(false)
	result._victim_guarding_after_clear = defender_relationship.guarding
	result._reached_stage = CombatSingleAttackExecutionResult.ReachedStage.RIPOSTE_GUARD_CLEARED
	result._riposte_random_reached = true
	result._riposte_random_bound = attacker_raw_composure.current_raw_composure()
	if result._riposte_random_bound <= 0:
		return _finish(
			result,
			CombatSingleAttackExecutionResult.Outcome.INVALID_RIPOSTE_RANDOM_BOUND,
			CombatSingleAttackExecutionResult.FailureStage.RIPOSTE_RANDOM_BOUND,
			CombatSingleAttackExecutionResult.ReachedStage.RIPOSTE_GUARD_CLEARED,
			true,
		)
	if random_source == null:
		return _finish(
			result,
			CombatSingleAttackExecutionResult.Outcome.RIPOSTE_RANDOM_SOURCE_MISSING,
			CombatSingleAttackExecutionResult.FailureStage.RIPOSTE_RANDOM,
			CombatSingleAttackExecutionResult.ReachedStage.RIPOSTE_GUARD_CLEARED,
			true,
		)
	result._riposte_random_attempted = true
	result._riposte_random_draw = random_source.next_below(result._riposte_random_bound)
	result._reached_stage = CombatSingleAttackExecutionResult.ReachedStage.RIPOSTE_RANDOM
	if (
		result._riposte_random_draw < 0
		or result._riposte_random_draw >= result._riposte_random_bound
	):
		return _finish(
			result,
			CombatSingleAttackExecutionResult.Outcome.RIPOSTE_RANDOM_DRAW_OUT_OF_RANGE,
			CombatSingleAttackExecutionResult.FailureStage.RIPOSTE_RANDOM,
			CombatSingleAttackExecutionResult.ReachedStage.RIPOSTE_RANDOM,
			true,
		)

	var reverse_attack_type: int = (
		CombatAttackType.Value.QUICK
		if result._riposte_random_draw < 5
		else CombatAttackType.Value.RIPOSTE
	)
	result._riposte_request = CombatRiposteRequest.new(
		true,
		result._victim_id,
		result._attacker_id,
		reverse_attack_type,
		result._selected_action_id,
		result._legacy_damage,
		result._riposte_random_bound,
		result._riposte_random_draw,
	)
	return _finish(
		result,
		CombatSingleAttackExecutionResult.Outcome.REVERSE_ATTACK_REQUIRED,
		CombatSingleAttackExecutionResult.FailureStage.NONE,
		CombatSingleAttackExecutionResult.ReachedStage.COMPLETED,
		true,
	)


static func _is_valid_attack_intent(result: CombatFightDecisionResult) -> bool:
	if result == null:
		return false
	if (
		result.failure_stage != CombatFightDecisionResult.FailureStage.NONE
		or result.reached_stage != CombatFightDecisionResult.ReachedStage.COMPLETED
		or not result.has_attack_intent
	):
		return false
	return (
		(
			result.attack_type == CombatAttackType.Value.REGULAR
			and result.outcome == CombatFightDecisionResult.Outcome.REGULAR_ATTACK
		)
		or (
			result.attack_type == CombatAttackType.Value.QUICK
			and result.outcome == CombatFightDecisionResult.Outcome.QUICK_ATTACK
		)
	)


static func _is_completed_non_attack_decision(
	result: CombatFightDecisionResult,
) -> bool:
	if (
		result == null
		or result.failure_stage != CombatFightDecisionResult.FailureStage.NONE
		or result.has_attack_intent
		or result.attack_type != -1
	):
		return false
	if result.outcome == CombatFightDecisionResult.Outcome.ATTACKER_NOT_LIVING:
		return (
			result.reached_stage
			== CombatFightDecisionResult.ReachedStage.ATTACKER_LIVING
		)
	return (
		result.reached_stage == CombatFightDecisionResult.ReachedStage.COMPLETED
		and result.outcome in [
			CombatFightDecisionResult.Outcome.TARGET_NOT_PERCEIVED,
			CombatFightDecisionResult.Outcome.ENTERED_GUARDING,
			CombatFightDecisionResult.Outcome.REMAIN_GUARDING,
		]
	)


static func _has_coherent_authorities(
	fight_decision: CombatFightDecisionResult,
	attack_input_template: CombatAttackInput,
	attacker: CharacterState,
	defender: CharacterState,
	attacker_raw_composure: CombatRawComposureAuthority,
	attacker_facts: CombatProgressionFacts,
	defender_facts: CombatProgressionFacts,
	attacker_relationship: CombatRelationshipState,
	defender_relationship: CombatRelationshipState,
) -> bool:
	if (
		attack_input_template == null
		or attacker == null
		or defender == null
		or attacker == defender
		or attacker_raw_composure == null
		or not attacker_raw_composure.is_valid()
		or not attacker_raw_composure.is_bound_to(attacker)
		or attacker_facts == null
		or defender_facts == null
		or attacker_relationship == null
		or defender_relationship == null
		or attacker_relationship == defender_relationship
	):
		return false
	var projected_attacker: CombatAttackerSnapshot = attack_input_template.attacker
	var projected_defender: CombatDefenderSnapshot = attack_input_template.defender
	if projected_attacker == null or projected_defender == null:
		return false
	return (
		projected_attacker.character_id == fight_decision.attacker_id
		and projected_defender.character_id == fight_decision.victim_id
		and attacker_raw_composure.character_id == fight_decision.attacker_id
		and attacker_facts.character_id == fight_decision.attacker_id
		and defender_facts.character_id == fight_decision.victim_id
		and attacker_relationship.is_valid()
		and defender_relationship.is_valid()
		and (
			attacker_relationship.owner_character_id
			== fight_decision.attacker_id
		)
		and (
			defender_relationship.owner_character_id
			== fight_decision.victim_id
		)
	)


static func _matches_attack_projection(
	fight_decision: CombatFightDecisionResult,
	selected: CombatActionDefinition,
	template: CombatAttackInput,
) -> bool:
	if selected == null or template == null or not template.is_valid():
		return false
	var attacker_snapshot: CombatAttackerSnapshot = template.attacker
	var defender_snapshot: CombatDefenderSnapshot = template.defender
	if (
		attacker_snapshot.character_id != fight_decision.attacker_id
		or defender_snapshot.character_id != fight_decision.victim_id
	):
		return false
	var projected: CombatActionDefinition = template.selected_action
	return (
		selected.action_id == projected.action_id
		and selected.damage_percent == projected.damage_percent
		and selected.force_percent == projected.force_percent
		and selected.damage_type == projected.damage_type
		and selected.presentation_key == projected.presentation_key
		and selected.legacy_action_text == projected.legacy_action_text
		and (
			selected.displayed_weapon_or_body_token
			== projected.displayed_weapon_or_body_token
		)
		and selected.post_action_policy_id == projected.post_action_policy_id
	)


static func _legacy_damage_for(base_result: CombatAttackResult) -> int:
	if base_result.outcome == CombatAttackResult.Outcome.DODGE:
		return -1
	if base_result.outcome == CombatAttackResult.Outcome.PARRY:
		return -2
	return base_result.calculation.requested_damage


static func _prior_mutation(result: CombatSingleAttackExecutionResult) -> bool:
	var mutated: bool = false
	if result._fight_decision_result != null:
		mutated = (
			result._fight_decision_result.guarding_mutated
			or result._fight_decision_result.reciprocal_opponent_added
		)
	if result._ordinary_attack_result != null:
		mutated = mutated or _ordinary_mutated(result._ordinary_attack_result)
	if result._post_relationship_result != null:
		mutated = (
			mutated
			or result._post_relationship_result.attacker_removal_succeeded
			or result._post_relationship_result.defender_removal_succeeded
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
	result: CombatSingleAttackExecutionResult,
	outcome: int,
	failure_stage: int,
	reached_stage: int,
	partial_mutation_preserved: bool,
) -> CombatSingleAttackExecutionResult:
	result._outcome = outcome
	result._failure_stage = failure_stage
	result._reached_stage = reached_stage
	result._partial_mutation_preserved = partial_mutation_preserved
	result._rebuild_combined_random_evidence()
	return result
