class_name CombatSliceOpportunityExecutor
extends RefCounted


static func initiate_lethal_combat(
	initiator: CombatSliceCharacterBinding,
	target: CombatSliceCharacterBinding,
) -> CombatSliceInitiationResult:
	var result: CombatSliceInitiationResult = CombatSliceInitiationResult.new()
	if initiator != null:
		result._initiator_id = initiator.character_id
		result._initiator_exists = initiator.exists_in_encounter
	if target != null:
		result._target_id = target.character_id
		result._target_exists = target.exists_in_encounter
	if initiator == null or target == null or not initiator.is_valid() or not target.is_valid():
		return result
	result._ids_differ = initiator.character_id != target.character_id
	result._same_location = initiator.location_id == target.location_id
	result._target_dead = target.life_status == CombatSliceLifeStatus.Value.DEAD
	if not initiator.exists_in_encounter:
		result._outcome = CombatSliceInitiationResult.Outcome.INITIATOR_NOT_AVAILABLE
		return result
	if not target.exists_in_encounter:
		result._outcome = CombatSliceInitiationResult.Outcome.TARGET_NOT_AVAILABLE
		return result
	if not result._ids_differ:
		result._outcome = CombatSliceInitiationResult.Outcome.SELF_TARGET_REJECTED
		return result
	if not _bindings_are_independent(initiator, target):
		return result
	if not result._same_location:
		result._outcome = CombatSliceInitiationResult.Outcome.DIFFERENT_LOCATION
		return result
	if result._target_dead:
		result._outcome = CombatSliceInitiationResult.Outcome.TARGET_DEAD
		return result

	result._first_mutation_attempted = true
	result._first_mutation_changed = initiator.relationship.mark_lethal_target(
		target.character_id
	)
	result._first_mutation_succeeded = (
		initiator.relationship.has_lethal_target(target.character_id)
		and initiator.relationship.has_opponent(target.character_id)
	)
	if not result._first_mutation_succeeded:
		result._outcome = CombatSliceInitiationResult.Outcome.FIRST_RELATIONSHIP_FAILED
		return result

	result._second_mutation_attempted = true
	result._second_mutation_changed = target.relationship.mark_lethal_target(
		initiator.character_id
	)
	result._second_mutation_succeeded = (
		target.relationship.has_lethal_target(initiator.character_id)
		and target.relationship.has_opponent(initiator.character_id)
	)
	if not result._second_mutation_succeeded:
		result._outcome = CombatSliceInitiationResult.Outcome.SECOND_RELATIONSHIP_FAILED
		return result
	result._outcome = CombatSliceInitiationResult.Outcome.COMPLETED
	return result


static func execute_opportunity(
	actor: CombatSliceCharacterBinding,
	participants: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
	required_target_id: StringName = &"",
) -> CombatSliceOpportunityResult:
	var result: CombatSliceOpportunityResult = CombatSliceOpportunityResult.new()
	if actor != null:
		result._actor_id = actor.character_id
	if (
		actor == null
		or not actor.is_valid()
	):
		return result

	result._life_status_observed = actor.life_status
	result._life_threshold_observed = actor.state.life_threshold()
	result._reached_stage = CombatSliceOpportunityResult.ReachedStage.LIFECYCLE_GATE
	var lifecycle_outcome: int = _required_lifecycle_outcome(actor)
	if lifecycle_outcome != -1:
		return _finish(result, lifecycle_outcome)

	result._reached_stage = CombatSliceOpportunityResult.ReachedStage.ACTOR_AVAILABILITY
	if not actor.exists_in_encounter:
		return _finish(result, CombatSliceOpportunityResult.Outcome.ACTOR_NOT_AVAILABLE)
	if actor.life_status != CombatSliceLifeStatus.Value.ACTIVE:
		return _finish(result, CombatSliceOpportunityResult.Outcome.ACTOR_NOT_ACTIVE)
	if not actor.combat_available:
		return _finish(result, CombatSliceOpportunityResult.Outcome.COMBAT_NOT_AVAILABLE)

	result._reached_stage = CombatSliceOpportunityResult.ReachedStage.BUSY_GATE
	result._busy_before = actor.busy.busy_value
	result._busy_after = actor.busy.busy_value
	if actor.busy.is_busy():
		result._busy_advance_attempted = true
		result._busy_advance_changed = actor.busy.advance()
		result._busy_after = actor.busy.busy_value
		return _finish(result, CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED)
	if not _participants_are_coherent(actor, participants):
		return result

	result._reached_stage = CombatSliceOpportunityResult.ReachedStage.OPPONENT_SELECTION
	var availability: Array[CombatOpponentAvailabilityFacts] = (
		CombatSliceProjectionBuilder.build_opponent_availability(actor, participants)
	)
	var selection: CombatOpponentSelectionResult = (
		CombatOpponentSelectionService.prepare(
			actor.relationship,
			availability,
			random_source,
		)
		if required_target_id.is_empty()
		else CombatOpponentSelectionService.prepare_specific(
			actor.relationship,
			availability,
			required_target_id,
		)
	)
	result._opponent_selection_result = selection.duplicate_snapshot()
	if selection.outcome == CombatOpponentSelectionResult.Outcome.NO_OPPONENT:
		return _finish(result, CombatSliceOpportunityResult.Outcome.NO_OPPONENT)
	if selection.outcome != CombatOpponentSelectionResult.Outcome.SELECTED:
		return _finish(
			result,
			CombatSliceOpportunityResult.Outcome.OPPONENT_SELECTION_FAILED,
		)
	var victim: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(
		participants,
		selection.selected_opponent_id,
	)
	if victim == null:
		return _finish(
			result,
			CombatSliceOpportunityResult.Outcome.OPPONENT_SELECTION_FAILED,
		)

	result._reached_stage = CombatSliceOpportunityResult.ReachedStage.FIGHT_DECISION
	var fight_facts: CombatFightDecisionFacts = CombatSliceProjectionBuilder.build_fight_facts(
		actor,
		victim,
	)
	var fight: CombatFightDecisionResult = CombatFightDecisionService.decide(
		fight_facts,
		actor.relationship,
		victim.relationship,
		random_source,
	)
	result._fight_decision_result = fight.duplicate_snapshot()
	if fight.failure_stage != CombatFightDecisionResult.FailureStage.NONE:
		return _finish(result, CombatSliceOpportunityResult.Outcome.FIGHT_DECISION_FAILED)
	if fight.outcome == CombatFightDecisionResult.Outcome.ENTERED_GUARDING:
		return _finish(result, CombatSliceOpportunityResult.Outcome.ENTERED_GUARDING)
	if not fight.has_attack_intent:
		return _finish(result, CombatSliceOpportunityResult.Outcome.FIGHT_NO_ACTION)

	result._reached_stage = CombatSliceOpportunityResult.ReachedStage.FORWARD_ATTACK
	var primary: EquippedWeaponRef = actor.state.equipment.primary_weapon()
	var action: CombatActionDefinition = actor.content.attack_template_for(primary)
	var forward: CombatSingleAttackExecutionResult = (
		CombatSingleAttackExecutionService.execute(
			fight,
			CombatSliceProjectionBuilder.build_action_selection_input(actor),
			CombatSliceProjectionBuilder.build_attack_input(actor, victim, action),
			actor.state,
			victim.state,
			CombatRawComposureAuthority.new(actor.character_id, actor.state.attributes),
			CombatSliceProjectionBuilder.build_progression_facts(actor),
			CombatSliceProjectionBuilder.build_progression_facts(victim),
			CombatSliceProjectionBuilder.build_busy_projection(victim),
			victim.busy if victim.busy.is_busy() else null,
			actor.relationship,
			victim.relationship,
			random_source,
			effect_registry,
		)
	)
	result._forward_result = forward.duplicate_snapshot()
	var reverse_projection: CombatReverseAttackProjection = null
	if forward.outcome == CombatSingleAttackExecutionResult.Outcome.REVERSE_ATTACK_REQUIRED:
		var request: CombatRiposteRequest = forward.riposte_request
		var reverse_attacker: CombatSliceCharacterBinding = (
			CombatSliceProjectionBuilder.find_binding(participants, request.attacker_id)
		)
		var reverse_defender: CombatSliceCharacterBinding = (
			CombatSliceProjectionBuilder.find_binding(participants, request.victim_id)
		)
		if reverse_attacker != null and reverse_defender != null:
			result._reached_stage = (
				CombatSliceOpportunityResult.ReachedStage.REVERSE_PROJECTION
			)
			result._reverse_attacker_experience_at_projection = (
				reverse_attacker.state.progression.combat_experience
			)
			reverse_projection = CombatSliceProjectionBuilder.build_reverse_projection(
				reverse_attacker,
				reverse_defender,
				request,
			)
			result._reverse_projection_built = reverse_projection != null

	result._reached_stage = CombatSliceOpportunityResult.ReachedStage.CHAIN_COMPLETION
	var chain: CombatAttackChainResult = CombatAttackChainCompletionService.complete(
		forward,
		reverse_projection,
		random_source,
		effect_registry,
	)
	result._chain_result = chain.duplicate_snapshot()
	if chain.outcome in [
		CombatAttackChainResult.Outcome.FORWARD_COMPLETE_NO_REVERSE,
		CombatAttackChainResult.Outcome.REVERSE_COMPLETE,
	]:
		return _finish(result, CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_COMPLETE)
	return _finish(result, CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_INCOMPLETE)


static func _required_lifecycle_outcome(
	actor: CombatSliceCharacterBinding,
) -> int:
	if actor.life_status == CombatSliceLifeStatus.Value.DEAD:
		return -1
	if actor.state.is_death_threshold_reached():
		return CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH
	if actor.state.is_unconscious_threshold_reached():
		if actor.life_status == CombatSliceLifeStatus.Value.UNCONSCIOUS:
			return CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH
		return CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS
	return -1


static func _participants_are_coherent(
	actor: CombatSliceCharacterBinding,
	participants: Array[CombatSliceCharacterBinding],
) -> bool:
	var actor_found: bool = false
	for index: int in range(participants.size()):
		var participant: CombatSliceCharacterBinding = participants[index]
		if participant == null or not participant.is_valid():
			return false
		if participant == actor:
			actor_found = true
		for other_index: int in range(index):
			var other: CombatSliceCharacterBinding = participants[other_index]
			if (
				participant.character_id == other.character_id
				or not _bindings_are_independent(participant, other)
			):
				return false
	return actor_found


static func _bindings_are_independent(
	left: CombatSliceCharacterBinding,
	right: CombatSliceCharacterBinding,
) -> bool:
	return (
		left.state != right.state
		and left.state.attributes != right.state.attributes
		and left.state.essence != right.state.essence
		and left.state.vitality != right.state.vitality
		and left.state.spirit != right.state.spirit
		and left.state.recovery != right.state.recovery
		and left.state.skills != right.state.skills
		and left.state.progression != right.state.progression
		and left.state.equipment != right.state.equipment
		and left.relationship != right.relationship
		and left.busy != right.busy
		and left.armor != right.armor
	)


static func _finish(
	result: CombatSliceOpportunityResult,
	outcome: int,
) -> CombatSliceOpportunityResult:
	result._outcome = outcome
	return result
