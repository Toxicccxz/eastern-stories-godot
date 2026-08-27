class_name CombatFightDecisionService
extends RefCounted

const GUARD_PRESENTATION_COUNT: int = 5


static func decide(
	facts: CombatFightDecisionFacts,
	attacker_relationship: CombatRelationshipState,
	victim_relationship: CombatRelationshipState,
	random_source: CombatRandomSource,
) -> CombatFightDecisionResult:
	var result: CombatFightDecisionResult = CombatFightDecisionResult.new()
	if facts != null:
		result._attacker_id = facts.attacker_id
		result._victim_id = facts.victim_id
	if (
		facts == null
		or attacker_relationship == null
		or victim_relationship == null
		or not facts.has_valid_identity()
		or attacker_relationship == victim_relationship
		or not attacker_relationship.is_valid()
		or not victim_relationship.is_valid()
	):
		return result
	if (
		attacker_relationship.owner_character_id != facts.attacker_id
		or victim_relationship.owner_character_id != facts.victim_id
	):
		result._failure_stage = CombatFightDecisionResult.FailureStage.RELATIONSHIP_PROJECTION
		return result

	result._reached_stage = CombatFightDecisionResult.ReachedStage.INPUT_VALIDATED
	result._guarding_before = attacker_relationship.guarding
	result._guarding_after = attacker_relationship.guarding
	result._reached_stage = CombatFightDecisionResult.ReachedStage.ATTACKER_LIVING
	if not facts.attacker_living:
		result._outcome = CombatFightDecisionResult.Outcome.ATTACKER_NOT_LIVING
		result._failure_stage = CombatFightDecisionResult.FailureStage.NONE
		return result

	result._reached_stage = CombatFightDecisionResult.ReachedStage.VISIBILITY
	result._visibility_evaluated = true
	result._target_visible = facts.target_visible
	if not facts.target_visible:
		var perception: CombatPerceptionSkillProjection = facts.perception
		if perception == null or not perception.is_valid():
			result._outcome = CombatFightDecisionResult.Outcome.INVALID_SOURCE_STATE
			result._failure_stage = (
				CombatFightDecisionResult.FailureStage.PERCEPTION_SKILL_PROJECTION
			)
			return result
		result._perception_skill_id = perception.skill_id
		result._effective_perception = perception.effective_level
		result._perception_random_reached = true
		result._reached_stage = CombatFightDecisionResult.ReachedStage.PERCEPTION_RANDOM
		result._perception_random_bound = 100 + perception.effective_level
		if result._perception_random_bound <= 0:
			result._outcome = CombatFightDecisionResult.Outcome.INVALID_RANDOM_BOUND
			result._failure_stage = CombatFightDecisionResult.FailureStage.PERCEPTION_RANDOM_BOUND
			return result
		if random_source == null:
			result._outcome = CombatFightDecisionResult.Outcome.RANDOM_SOURCE_MISSING
			result._failure_stage = CombatFightDecisionResult.FailureStage.PERCEPTION_RANDOM
			return result
		result._perception_random_attempted = true
		result._random_upper_bounds.append(result._perception_random_bound)
		var perception_draw: int = random_source.next_below(result._perception_random_bound)
		result._perception_random_draw = perception_draw
		result._random_draws.append(perception_draw)
		if perception_draw < 0 or perception_draw >= result._perception_random_bound:
			result._outcome = CombatFightDecisionResult.Outcome.RANDOM_DRAW_OUT_OF_RANGE
			result._failure_stage = CombatFightDecisionResult.FailureStage.PERCEPTION_RANDOM
			return result
		result._perception_comparison_evaluated = true
		result._perception_check_passed = perception_draw >= 100
		if not result._perception_check_passed:
			result._outcome = CombatFightDecisionResult.Outcome.TARGET_NOT_PERCEIVED
			result._failure_stage = CombatFightDecisionResult.FailureStage.NONE
			result._reached_stage = CombatFightDecisionResult.ReachedStage.COMPLETED
			return result

	if facts.victim_busy or not facts.victim_living:
		result._reached_stage = CombatFightDecisionResult.ReachedStage.QUICK_BRANCH
		return _prepare_attack_intent(
			result,
			CombatAttackType.Value.QUICK,
			attacker_relationship,
			victim_relationship,
		)

	result._courage_random_reached = true
	result._reached_stage = CombatFightDecisionResult.ReachedStage.COURAGE_RANDOM
	result._courage_random_bound = facts.victim_raw_composure * 3
	if result._courage_random_bound <= 0:
		result._outcome = CombatFightDecisionResult.Outcome.INVALID_RANDOM_BOUND
		result._failure_stage = CombatFightDecisionResult.FailureStage.COURAGE_RANDOM_BOUND
		return result
	if random_source == null:
		result._outcome = CombatFightDecisionResult.Outcome.RANDOM_SOURCE_MISSING
		result._failure_stage = CombatFightDecisionResult.FailureStage.COURAGE_RANDOM
		return result
	result._courage_random_attempted = true
	result._random_upper_bounds.append(result._courage_random_bound)
	var courage_draw: int = random_source.next_below(result._courage_random_bound)
	result._courage_random_draw = courage_draw
	result._random_draws.append(courage_draw)
	if courage_draw < 0 or courage_draw >= result._courage_random_bound:
		result._outcome = CombatFightDecisionResult.Outcome.RANDOM_DRAW_OUT_OF_RANGE
		result._failure_stage = CombatFightDecisionResult.FailureStage.COURAGE_RANDOM
		return result
	@warning_ignore("integer_division")
	var bellicosity_component: int = facts.attacker_raw_bellicosity / 50
	result._courage_threshold = facts.attacker_raw_courage + bellicosity_component
	result._courage_comparison_evaluated = true
	result._courage_check_passed = courage_draw < result._courage_threshold
	if result._courage_check_passed:
		result._reached_stage = CombatFightDecisionResult.ReachedStage.REGULAR_BRANCH
		return _prepare_attack_intent(
			result,
			CombatAttackType.Value.REGULAR,
			attacker_relationship,
			victim_relationship,
		)

	result._reached_stage = CombatFightDecisionResult.ReachedStage.GUARD_BRANCH
	if attacker_relationship.guarding:
		result._outcome = CombatFightDecisionResult.Outcome.REMAIN_GUARDING
		result._failure_stage = CombatFightDecisionResult.FailureStage.NONE
		result._reached_stage = CombatFightDecisionResult.ReachedStage.COMPLETED
		return result

	attacker_relationship.set_guarding(true)
	result._guarding_after = true
	result._guarding_mutated = true
	result._guard_random_reached = true
	result._guard_random_bound = GUARD_PRESENTATION_COUNT
	result._reached_stage = CombatFightDecisionResult.ReachedStage.GUARD_PRESENTATION_RANDOM
	if random_source == null:
		result._outcome = CombatFightDecisionResult.Outcome.RANDOM_SOURCE_MISSING
		result._failure_stage = CombatFightDecisionResult.FailureStage.GUARD_PRESENTATION_RANDOM
		return result
	result._guard_random_attempted = true
	result._random_upper_bounds.append(GUARD_PRESENTATION_COUNT)
	var guard_draw: int = random_source.next_below(GUARD_PRESENTATION_COUNT)
	result._guard_random_draw = guard_draw
	result._random_draws.append(guard_draw)
	if guard_draw < 0 or guard_draw >= GUARD_PRESENTATION_COUNT:
		result._outcome = CombatFightDecisionResult.Outcome.RANDOM_DRAW_OUT_OF_RANGE
		result._failure_stage = CombatFightDecisionResult.FailureStage.GUARD_PRESENTATION_RANDOM
		return result
	result._guard_presentation_index = guard_draw
	result._outcome = CombatFightDecisionResult.Outcome.ENTERED_GUARDING
	result._failure_stage = CombatFightDecisionResult.FailureStage.NONE
	result._reached_stage = CombatFightDecisionResult.ReachedStage.COMPLETED
	return result


static func _prepare_attack_intent(
	result: CombatFightDecisionResult,
	attack_type: int,
	attacker_relationship: CombatRelationshipState,
	victim_relationship: CombatRelationshipState,
) -> CombatFightDecisionResult:
	attacker_relationship.set_guarding(false)
	result._guarding_after = false
	result._guarding_mutated = result._guarding_before
	result._reciprocal_opponent_existed = victim_relationship.has_opponent(
		result._attacker_id
	)
	if not result._reciprocal_opponent_existed:
		result._reciprocal_add_attempted = true
		if not victim_relationship.add_opponent(result._attacker_id):
			result._outcome = CombatFightDecisionResult.Outcome.RELATIONSHIP_INVARIANT_FAILURE
			result._failure_stage = CombatFightDecisionResult.FailureStage.RECIPROCAL_RELATION
			return result
		result._reciprocal_opponent_added = true
	result._attack_type = attack_type
	result._outcome = (
		CombatFightDecisionResult.Outcome.QUICK_ATTACK
		if attack_type == CombatAttackType.Value.QUICK
		else CombatFightDecisionResult.Outcome.REGULAR_ATTACK
	)
	result._failure_stage = CombatFightDecisionResult.FailureStage.NONE
	result._reached_stage = CombatFightDecisionResult.ReachedStage.COMPLETED
	return result
