class_name CombatOpponentSelectionService
extends RefCounted

const MAX_OPPONENT_SELECTION: int = 4


static func prepare(
	relationship: CombatRelationshipState,
	availability_facts: Array[CombatOpponentAvailabilityFacts],
	random_source: CombatRandomSource,
) -> CombatOpponentSelectionResult:
	var result: CombatOpponentSelectionResult = CombatOpponentSelectionResult.new()
	if relationship == null or not relationship.is_valid():
		return result
	result._owner_character_id = relationship.owner_character_id
	result._original_opponent_ids = relationship.opponent_ids()
	result._last_opponent_before = relationship.last_opponent_id
	result._last_opponent_after = relationship.last_opponent_id
	if not _facts_match_snapshot(result._original_opponent_ids, availability_facts):
		result._outcome = (
			CombatOpponentSelectionResult.Outcome.INVALID_AVAILABILITY_PROJECTION
		)
		result._failure_stage = (
			CombatOpponentSelectionResult.FailureStage.AVAILABILITY_PROJECTION
		)
		result._resulting_opponent_ids = relationship.opponent_ids()
		return result

	for opponent_id: StringName in result._original_opponent_ids:
		var facts: CombatOpponentAvailabilityFacts = _find_facts(
			availability_facts,
			opponent_id,
		)
		var remove: bool = (
			not facts.exists
			or not facts.same_location
			or (
				not facts.living
				and not relationship.has_lethal_target(opponent_id)
			)
		)
		if remove:
			if not relationship._remove_opponent_for_cleanup(opponent_id):
				result._outcome = (
					CombatOpponentSelectionResult.Outcome.CLEANUP_INVARIANT_FAILURE
				)
				result._failure_stage = CombatOpponentSelectionResult.FailureStage.CLEANUP
				_finish_snapshot(result, relationship)
				return result
			result._removed_opponent_ids.append(opponent_id)
		else:
			result._retained_opponent_ids.append(opponent_id)

	result._cleanup_completed = true
	result._resulting_opponent_ids = relationship.opponent_ids()
	if result._resulting_opponent_ids.is_empty():
		result._outcome = CombatOpponentSelectionResult.Outcome.NO_OPPONENT
		result._failure_stage = CombatOpponentSelectionResult.FailureStage.NONE
		result._last_opponent_after = relationship.last_opponent_id
		return result

	result._selection_random_reached = true
	result._selection_random_bound = MAX_OPPONENT_SELECTION
	if random_source == null:
		result._outcome = CombatOpponentSelectionResult.Outcome.RANDOM_SOURCE_MISSING
		result._failure_stage = CombatOpponentSelectionResult.FailureStage.SELECTION_RANDOM
		result._last_opponent_after = relationship.last_opponent_id
		return result
	result._selection_random_attempted = true
	result._random_upper_bounds.append(MAX_OPPONENT_SELECTION)
	var draw: int = random_source.next_below(MAX_OPPONENT_SELECTION)
	result._selection_random_draw = draw
	result._random_draws.append(draw)
	if draw < 0 or draw >= MAX_OPPONENT_SELECTION:
		result._outcome = CombatOpponentSelectionResult.Outcome.RANDOM_DRAW_OUT_OF_RANGE
		result._failure_stage = CombatOpponentSelectionResult.FailureStage.SELECTION_RANDOM
		result._last_opponent_after = relationship.last_opponent_id
		return result
	var selected_index: int = draw if draw < result._resulting_opponent_ids.size() else 0
	var selected_id: StringName = result._resulting_opponent_ids[selected_index]
	result._selected_index = selected_index
	result._selected_opponent_id = selected_id
	if not relationship.set_last_opponent(selected_id):
		result._outcome = (
			CombatOpponentSelectionResult.Outcome.LAST_OPPONENT_INVARIANT_FAILURE
		)
		result._failure_stage = CombatOpponentSelectionResult.FailureStage.LAST_OPPONENT
		result._last_opponent_after = relationship.last_opponent_id
		return result
	result._last_opponent_after = relationship.last_opponent_id
	result._outcome = CombatOpponentSelectionResult.Outcome.SELECTED
	result._failure_stage = CombatOpponentSelectionResult.FailureStage.NONE
	return result


static func _facts_match_snapshot(
	opponent_ids: Array[StringName],
	facts: Array[CombatOpponentAvailabilityFacts],
) -> bool:
	if facts.size() != opponent_ids.size():
		return false
	var seen_ids: Array[StringName] = []
	for fact: CombatOpponentAvailabilityFacts in facts:
		if (
			fact == null
			or not fact.is_valid()
			or not opponent_ids.has(fact.opponent_id)
			or seen_ids.has(fact.opponent_id)
		):
			return false
		seen_ids.append(fact.opponent_id)
	return true


static func _find_facts(
	facts: Array[CombatOpponentAvailabilityFacts],
	opponent_id: StringName,
) -> CombatOpponentAvailabilityFacts:
	for fact: CombatOpponentAvailabilityFacts in facts:
		if fact.opponent_id == opponent_id:
			return fact
	return null


static func _finish_snapshot(
	result: CombatOpponentSelectionResult,
	relationship: CombatRelationshipState,
) -> void:
	result._resulting_opponent_ids = relationship.opponent_ids()
	result._last_opponent_after = relationship.last_opponent_id
