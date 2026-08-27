class_name CombatPostRelationshipService
extends RefCounted

const WINNER_PRESENTATION_COUNT: int = 6


static func apply(
	ordinary_attack_result: CombatOrdinaryAttackResult,
	attacker_id: StringName,
	defender_id: StringName,
	attacker_relationship: CombatRelationshipState,
	defender_relationship: CombatRelationshipState,
	random_source: CombatRandomSource,
) -> CombatPostRelationshipResult:
	var result: CombatPostRelationshipResult = CombatPostRelationshipResult.new(
		ordinary_attack_result
	)
	if (
		ordinary_attack_result == null
		or attacker_relationship == null
		or defender_relationship == null
		or attacker_id.is_empty()
		or defender_id.is_empty()
		or attacker_id == defender_id
		or not attacker_relationship.is_valid()
		or not defender_relationship.is_valid()
	):
		return result
	result._attacker_id = attacker_id
	result._defender_id = defender_id
	if (
		attacker_relationship.owner_character_id != attacker_id
		or defender_relationship.owner_character_id != defender_id
	):
		result._outcome = (
			CombatPostRelationshipResult.Outcome.ATTACK_RELATIONSHIP_PROJECTION_MISMATCH
		)
		result._failure_stage = (
			CombatPostRelationshipResult.FailureStage.ATTACK_RELATIONSHIP_PROJECTION
		)
		return result
	if ordinary_attack_result.has_base_result:
		var projected_base: CombatAttackResult = ordinary_attack_result.base_result
		if (
			projected_base.attacker_id != attacker_id
			or projected_base.defender_id != defender_id
		):
			result._outcome = (
				CombatPostRelationshipResult.Outcome.ATTACK_RELATIONSHIP_PROJECTION_MISMATCH
			)
			result._failure_stage = (
				CombatPostRelationshipResult.FailureStage.ATTACK_RELATIONSHIP_PROJECTION
			)
			return result
	if ordinary_attack_result.outcome != CombatOrdinaryAttackResult.Outcome.COMPLETED:
		result._outcome = CombatPostRelationshipResult.Outcome.PRIOR_ATTACK_INCOMPLETE
		result._failure_stage = CombatPostRelationshipResult.FailureStage.PRIOR_ATTACK
		return result
	if not ordinary_attack_result.has_base_result:
		result._outcome = (
			CombatPostRelationshipResult.Outcome.ATTACK_RELATIONSHIP_PROJECTION_MISMATCH
		)
		result._failure_stage = (
			CombatPostRelationshipResult.FailureStage.ATTACK_RELATIONSHIP_PROJECTION
		)
		return result

	var base_result: CombatAttackResult = ordinary_attack_result.base_result
	result._requested_damage = base_result.calculation.requested_damage
	result._positive_hit_gate_matched = (
		base_result.outcome == CombatAttackResult.Outcome.HIT
		and result._requested_damage > 0
	)
	if not result._positive_hit_gate_matched:
		result._outcome = CombatPostRelationshipResult.Outcome.NOT_POSITIVE_HIT
		result._failure_stage = CombatPostRelationshipResult.FailureStage.NONE
		return result

	result._attacker_is_lethal = attacker_relationship.has_lethal_target(defender_id)
	result._defender_is_lethal = defender_relationship.has_lethal_target(attacker_id)
	result._attacker_is_fighting = attacker_relationship.has_opponent(defender_id)
	result._defender_is_fighting = defender_relationship.has_opponent(attacker_id)
	result._friendly_stop_predicate_matched = (
		not result._attacker_is_lethal
		and not result._defender_is_lethal
		and result._attacker_is_fighting
		and result._defender_is_fighting
	)
	if not result._friendly_stop_predicate_matched:
		result._outcome = CombatPostRelationshipResult.Outcome.FRIENDLY_STOP_NOT_MATCHED
		result._failure_stage = CombatPostRelationshipResult.FailureStage.NONE
		return result

	result._attacker_removal_attempted = true
	result._attacker_removal_succeeded = attacker_relationship.remove_opponent(defender_id)
	if not result._attacker_removal_succeeded:
		result._outcome = CombatPostRelationshipResult.Outcome.RELATIONSHIP_INVARIANT_FAILURE
		result._failure_stage = (
			CombatPostRelationshipResult.FailureStage.ATTACKER_RELATION_REMOVAL
		)
		return result

	result._defender_removal_attempted = true
	result._defender_removal_succeeded = defender_relationship.remove_opponent(attacker_id)
	if not result._defender_removal_succeeded:
		result._outcome = CombatPostRelationshipResult.Outcome.RELATIONSHIP_INVARIANT_FAILURE
		result._failure_stage = (
			CombatPostRelationshipResult.FailureStage.DEFENDER_RELATION_REMOVAL
		)
		return result

	result._winner_selection_reached = true
	result._winner_random_bound = WINNER_PRESENTATION_COUNT
	if random_source == null:
		result._outcome = CombatPostRelationshipResult.Outcome.WINNER_RANDOM_SOURCE_MISSING
		result._failure_stage = (
			CombatPostRelationshipResult.FailureStage.WINNER_PRESENTATION_SELECTION
		)
		return result
	result._winner_random_attempted = true
	result._winner_random_upper_bounds.append(WINNER_PRESENTATION_COUNT)
	var draw: int = random_source.next_below(WINNER_PRESENTATION_COUNT)
	result._winner_random_draw = draw
	result._winner_random_draws.append(draw)
	if draw < 0 or draw >= WINNER_PRESENTATION_COUNT:
		result._outcome = CombatPostRelationshipResult.Outcome.WINNER_RANDOM_DRAW_OUT_OF_RANGE
		result._failure_stage = (
			CombatPostRelationshipResult.FailureStage.WINNER_PRESENTATION_SELECTION
		)
		return result
	result._winner_presentation_index = draw
	result._outcome = CombatPostRelationshipResult.Outcome.COMPLETED
	result._failure_stage = CombatPostRelationshipResult.FailureStage.NONE
	return result
