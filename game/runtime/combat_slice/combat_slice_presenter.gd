class_name CombatSlicePresenter
extends RefCounted


func describe_opportunity(
	result: CombatSliceOpportunityResult,
	actor_name: String,
	victim_name: String,
) -> Array[String]:
	var lines: Array[String] = []
	if result == null:
		lines.append("Invalid combat result")
		return lines
	match result.outcome:
		CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS:
			lines.append("Lifecycle pending: unconscious (%s)" % actor_name)
			return lines
		CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH:
			lines.append("Lifecycle pending: death (%s)" % actor_name)
			return lines
		CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED:
			lines.append("%s remains busy" % actor_name)
			return lines
		CombatSliceOpportunityResult.Outcome.ENTERED_GUARDING:
			lines.append("%s enters guarding" % actor_name)
			return lines
		CombatSliceOpportunityResult.Outcome.NO_OPPONENT:
			lines.append("%s has no opponent" % actor_name)
			return lines
		CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_INCOMPLETE:
			lines.append("Combat action incomplete (%s)" % actor_name)
		CombatSliceOpportunityResult.Outcome.INVALID_INPUT:
			lines.append("Typed combat failure (%s)" % actor_name)
		CombatSliceOpportunityResult.Outcome.OPPONENT_SELECTION_FAILED:
			lines.append("Typed combat failure (%s)" % actor_name)
		CombatSliceOpportunityResult.Outcome.FIGHT_DECISION_FAILED:
			lines.append("Typed combat failure (%s)" % actor_name)

	var forward: CombatSingleAttackExecutionResult = result.forward_result
	if forward == null:
		return lines
	if forward.attack_type == CombatAttackType.Value.QUICK:
		lines.append("%s launches a quick attack" % actor_name)
	if not forward.selected_action_id.is_empty():
		lines.append("%s uses slash against %s" % [actor_name, victim_name])
	_append_base_outcome(lines, forward.ordinary_attack_result, actor_name, victim_name)
	var chain: CombatAttackChainResult = result.chain_result
	if chain != null and chain.reverse_execution_reached:
		lines.append("%s launches a riposte" % victim_name)
		_append_base_outcome(
			lines,
			chain.reverse_ordinary_result,
			victim_name,
			actor_name,
		)
	return lines


func _append_base_outcome(
	lines: Array[String],
	ordinary: CombatOrdinaryAttackResult,
	attacker_name: String,
	defender_name: String,
) -> void:
	if ordinary == null or not ordinary.has_base_result:
		return
	var base: CombatAttackResult = ordinary.base_result
	match base.outcome:
		CombatAttackResult.Outcome.DODGE:
			lines.append("%s dodges %s" % [defender_name, attacker_name])
		CombatAttackResult.Outcome.PARRY:
			lines.append("%s parries %s" % [defender_name, attacker_name])
		CombatAttackResult.Outcome.HIT:
			lines.append(
				"%s hits %s for %d damage"
				% [attacker_name, defender_name, base.resource_mutation.requested_damage]
			)
