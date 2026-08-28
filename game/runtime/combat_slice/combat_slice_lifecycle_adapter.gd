class_name CombatSliceLifecycleAdapter
extends RefCounted


func execute(
	opportunity: CombatSliceOpportunityResult,
	victim: CombatSliceCharacterBinding,
	participants: Array[CombatSliceCharacterBinding],
	killer: CombatSliceCharacterBinding,
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	corpse_item_instance_id: StringName,
	arena_destination: InventoryTransferDestination,
	item_facts: Array[DeathItemFacts],
	policy_registry: DeathItemPolicyRegistry,
	rewear_registry: DeathRewearPolicyRegistry,
) -> CombatSliceLifecycleResult:
	var result: CombatSliceLifecycleResult = CombatSliceLifecycleResult.new()
	if opportunity == null or victim == null:
		return result
	result._victim_id = victim.character_id
	result._old_life_status = victim.life_status
	result._new_life_status = victim.life_status
	if not _input_is_coherent(opportunity, victim, participants):
		result._outcome = CombatSliceLifecycleResult.Outcome.INCOHERENT_INPUT
		return result
	if opportunity.outcome == CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS:
		result._requested_kind = CombatSliceLifecycleResult.RequestedKind.UNCONSCIOUS
	elif opportunity.outcome == CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH:
		result._requested_kind = CombatSliceLifecycleResult.RequestedKind.DEATH
	else:
		return result

	result._partial_stage = CombatSliceLifecycleResult.PartialStage.PRE_RELATIONSHIP_CLEANUP
	var cleanup_ok: bool = _remove_all_enemy(victim, participants, result)
	if result._requested_kind == CombatSliceLifecycleResult.RequestedKind.UNCONSCIOUS:
		## Native life status is the slice's narrow equivalent of disable_player,
		## which precedes the three current-resource assignments in damage.c.
		victim.set_life_status(CombatSliceLifeStatus.Value.UNCONSCIOUS)
		result._new_life_status = victim.life_status
		_zero_current_resources(victim.state)
		result._resources_zeroed = true
		result._partial_stage = CombatSliceLifecycleResult.PartialStage.RESOURCE_TRANSITION
		result._partial_stage = CombatSliceLifecycleResult.PartialStage.COMPLETE
		result._outcome = (
			CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE
			if cleanup_ok
			else CombatSliceLifecycleResult.Outcome.RELATIONSHIP_CLEANUP_FAILED
		)
		return result

	result._partial_stage = CombatSliceLifecycleResult.PartialStage.DEATH_INVENTORY
	var death_execution: CombatSliceDeathExecutionResult = CombatSliceDeathAdapter.new().execute(
		victim,
		killer,
		inventory,
		stacks,
		corpse_item_instance_id,
		arena_destination,
		item_facts,
		policy_registry,
		rewear_registry,
	)
	result._death_inventory_result = death_execution.death_inventory_result
	result._second_corpse_placement_result = death_execution.second_placement_result
	if result._death_inventory_result != null:
		result._corpse_item_instance_id = result._death_inventory_result.corpse_item_instance_id
	if result._death_inventory_result == null:
		result._outcome = CombatSliceLifecycleResult.Outcome.DEATH_INVENTORY_FAILED
		return result
	match result._death_inventory_result.completion_status:
		DeathInventoryResult.CompletionStatus.COMPLETED:
			pass
		DeathInventoryResult.CompletionStatus.BLOCKED_INCOMPLETE:
			result._outcome = CombatSliceLifecycleResult.Outcome.DEATH_INVENTORY_BLOCKED
			return result
		_:
			result._outcome = CombatSliceLifecycleResult.Outcome.DEATH_INVENTORY_FAILED
			return result
	## feature/damage.c performs this second move before remove_all_killer().
	## A failed move therefore preserves all preceding inventory/corpse mutation
	## without committing the terminal encounter transition.
	if (
		result._second_corpse_placement_result == null
		or not result._second_corpse_placement_result.succeeded
	):
		result._outcome = CombatSliceLifecycleResult.Outcome.DEATH_INVENTORY_FAILED
		return result

	result._partial_stage = CombatSliceLifecycleResult.PartialStage.FINAL_RELATIONSHIP_CLEANUP
	result._final_lethal_cleanup_complete = _clear_explicit_lethal_relations(
		victim,
		participants,
	)
	if not cleanup_ok or not result._final_lethal_cleanup_complete:
		result._outcome = CombatSliceLifecycleResult.Outcome.RELATIONSHIP_CLEANUP_FAILED
		return result
	victim.set_life_status(CombatSliceLifeStatus.Value.DEAD)
	victim.set_exists_in_encounter(false)
	result._new_life_status = victim.life_status
	result._outcome = CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE
	result._partial_stage = CombatSliceLifecycleResult.PartialStage.COMPLETE
	return result


func _input_is_coherent(
	opportunity: CombatSliceOpportunityResult,
	victim: CombatSliceCharacterBinding,
	participants: Array[CombatSliceCharacterBinding],
) -> bool:
	if not victim.is_valid() or opportunity.actor_id != victim.character_id:
		return false
	var victim_count: int = 0
	for participant: CombatSliceCharacterBinding in participants:
		if participant == null or not participant.is_valid():
			return false
		if participant.character_id == victim.character_id:
			victim_count += 1
	return victim_count == 1


func _remove_all_enemy(
	victim: CombatSliceCharacterBinding,
	participants: Array[CombatSliceCharacterBinding],
	result: CombatSliceLifecycleResult,
) -> bool:
	var all_resolved: bool = true
	for opponent_id: StringName in victim.relationship.opponent_ids():
		result._reciprocal_cleanup_attempts += 1
		var opponent: CombatSliceCharacterBinding = _find_participant(participants, opponent_id)
		if opponent == null:
			all_resolved = false
			continue
		if opponent.relationship.remove_opponent(victim.character_id):
			result._reciprocal_cleanup_successes += 1
		## Refusal is source-valid when the reciprocal side keeps lethal intent.
	victim.relationship.clear_opponents_preserving_lethal_targets()
	result._local_opponents_cleared = not victim.relationship.is_fighting()
	return all_resolved and result._local_opponents_cleared


func _clear_explicit_lethal_relations(
	victim: CombatSliceCharacterBinding,
	participants: Array[CombatSliceCharacterBinding],
) -> bool:
	var complete: bool = true
	for participant: CombatSliceCharacterBinding in participants:
		if participant == victim:
			continue
		if victim.relationship.has_lethal_target(participant.character_id):
			victim.relationship.remove_lethal_relation(participant.character_id)
		if participant.relationship.has_lethal_target(victim.character_id):
			participant.relationship.remove_lethal_relation(victim.character_id)
		complete = complete and not victim.relationship.has_lethal_target(participant.character_id)
		complete = complete and not participant.relationship.has_lethal_target(victim.character_id)
		complete = complete and not participant.relationship.has_opponent(victim.character_id)
	return complete


func _zero_current_resources(state: CharacterState) -> void:
	state.essence.current = 0
	state.vitality.current = 0
	state.spirit.current = 0


func _find_participant(
	participants: Array[CombatSliceCharacterBinding],
	character_id: StringName,
) -> CombatSliceCharacterBinding:
	for participant: CombatSliceCharacterBinding in participants:
		if participant.character_id == character_id:
			return participant
	return null
