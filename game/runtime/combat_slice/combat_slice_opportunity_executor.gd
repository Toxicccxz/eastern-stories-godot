class_name CombatSliceOpportunityExecutor
extends RefCounted


static func initiate_lethal_combat(
	initiator: CombatSliceCharacterBinding,
	target: CombatSliceCharacterBinding,
) -> CombatSliceInitiationResult:
	return _initiate(initiator, target, true)


## cmds/std/fight.c, accepted: me->fight_ob(obj); obj->fight_ob(me). No kill marks.
static func initiate_spar(
	initiator: CombatSliceCharacterBinding,
	target: CombatSliceCharacterBinding,
) -> CombatSliceInitiationResult:
	return _initiate(initiator, target, false)


## A spar answered with kill_ob() (annihir.c accept_fight(), then fight.c): the
## killer marks its challenger to the death; the challenger only fights back.
static func initiate_directed_kill(
	killer: CombatSliceCharacterBinding,
	challenger: CombatSliceCharacterBinding,
) -> CombatSliceInitiationResult:
	return _initiate(killer, challenger, true, false)


static func _initiate(
	initiator: CombatSliceCharacterBinding,
	target: CombatSliceCharacterBinding,
	lethal: bool,
	target_lethal: bool = lethal,
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
	result._first_mutation_changed = _engage(initiator.relationship, target.character_id, lethal)
	result._first_mutation_succeeded = (
		(not lethal or initiator.relationship.has_lethal_target(target.character_id))
		and initiator.relationship.has_opponent(target.character_id)
	)
	if not result._first_mutation_succeeded:
		result._outcome = CombatSliceInitiationResult.Outcome.FIRST_RELATIONSHIP_FAILED
		return result

	result._second_mutation_attempted = true
	result._second_mutation_changed = _engage(target.relationship, initiator.character_id, target_lethal)
	result._second_mutation_succeeded = (
		(not target_lethal or target.relationship.has_lethal_target(initiator.character_id))
		and target.relationship.has_opponent(initiator.character_id)
	)
	if not result._second_mutation_succeeded:
		result._outcome = CombatSliceInitiationResult.Outcome.SECOND_RELATIONSHIP_FAILED
		return result
	result._outcome = CombatSliceInitiationResult.Outcome.COMPLETED
	return result


## kill_ob() marks a kill target (and fights it); fight_ob() only fights.
static func _engage(relationship: CombatRelationshipState, target_id: StringName, lethal: bool) -> bool:
	return relationship.mark_lethal_target(target_id) if lethal else relationship.add_opponent(target_id)


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

	return _attack(result, fight, actor, victim, participants, random_source, effect_registry)


## combatd.c do_attack(actor, victim, actor's weapon) called straight by a special
## file (swordjab.c, fakefault.c): TYPE_REGULAR, no fight() first (no guarding, no
## courage draw), whoever is busy; the victim may still riposte. Both must be in the
## fight; the actor conscious, the victim conscious or not (an unconscious one's
## skill_power() is 0). A kee below zero falls only on the next lifecycle check, as
## char.c heart_beat() does.
static func execute_direct_attack(
	actor: CombatSliceCharacterBinding,
	victim: CombatSliceCharacterBinding,
	participants: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSliceOpportunityResult:
	var result: CombatSliceOpportunityResult = CombatSliceOpportunityResult.new()
	if actor == null or not actor.is_valid():
		return result
	result._actor_id = actor.character_id
	result._life_status_observed = actor.life_status
	result._life_threshold_observed = actor.state.life_threshold()
	result._reached_stage = CombatSliceOpportunityResult.ReachedStage.ACTOR_AVAILABILITY
	if not actor.exists_in_encounter:
		return _finish(result, CombatSliceOpportunityResult.Outcome.ACTOR_NOT_AVAILABLE)
	if actor.life_status != CombatSliceLifeStatus.Value.ACTIVE:
		return _finish(result, CombatSliceOpportunityResult.Outcome.ACTOR_NOT_ACTIVE)
	if not actor.combat_available:
		return _finish(result, CombatSliceOpportunityResult.Outcome.COMBAT_NOT_AVAILABLE)
	result._busy_before = actor.busy.busy_value
	result._busy_after = actor.busy.busy_value
	if (
		victim == null or not victim.is_valid() or not victim.exists_in_encounter
		or victim.life_status == CombatSliceLifeStatus.Value.DEAD
		or not _participants_are_coherent(actor, participants) or not participants.has(victim) or victim == actor
	):
		return _finish(result, CombatSliceOpportunityResult.Outcome.OPPONENT_SELECTION_FAILED)
	return _attack(result, CombatFightDecisionResult.direct(actor.character_id, victim.character_id), actor, victim, participants, random_source, effect_registry)


## The decided attack of `actor` on `victim` and, when the victim answers, its
## riposte (do_attack() from step (1) on).
static func _attack(
	result: CombatSliceOpportunityResult,
	fight: CombatFightDecisionResult,
	actor: CombatSliceCharacterBinding,
	victim: CombatSliceCharacterBinding,
	participants: Array[CombatSliceCharacterBinding],
	random_source: CombatRandomSource,
	effect_registry: SkillImprovementEffectRegistry,
) -> CombatSliceOpportunityResult:
	result._reached_stage = CombatSliceOpportunityResult.ReachedStage.FORWARD_ATTACK
	var live: CombatReverseAttackProjection = CombatSliceProjectionBuilder.build_live_projection(actor, victim)
	var forward: CombatSingleAttackExecutionResult = (
		CombatSingleAttackExecutionService.execute(
			fight,
			CombatSliceProjectionBuilder.build_action_selection_input(actor),
			live.attack_input_template() if live != null else null,
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
			live.modifier_projection() if live != null else null,
		)
	)
	result._forward_result = forward.duplicate_snapshot()
	if _landed(forward.ordinary_attack_result):
		victim.relationship.set_last_damage_from(actor.character_id)
	# combatd.c: the action's post_action runs before the victim may riposte.
	if forward.post_action_reached and forward.post_action_policy_present:
		result._post_action_lines.append_array(_run_post_action(actor, forward.post_action_policy_id))
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
	if chain.reverse_execution_reached and _landed(chain.reverse_ordinary_result):
		var reverse_victim: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(participants, forward.riposte_request.victim_id)
		if reverse_victim != null:
			reverse_victim.relationship.set_last_damage_from(forward.riposte_request.attacker_id)
	if chain.reverse_post_action_reached and chain.reverse_post_action_policy_present:
		result._reverse_post_action_lines.append_array(_run_post_action(CombatSliceProjectionBuilder.find_binding(participants, forward.riposte_request.attacker_id), chain.reverse_post_action_policy_id))
	if chain.outcome in [
		CombatAttackChainResult.Outcome.FORWARD_COMPLETE_NO_REVERSE,
		CombatAttackChainResult.Outcome.REVERSE_COMPLETE,
	]:
		return _finish(result, CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_COMPLETE)
	return _finish(result, CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_INCOMPLETE)


## What the post_action told the attacker, when the attacker is the player.
static func _run_post_action(attacker: CombatSliceCharacterBinding, policy_id: StringName) -> Array[String]:
	var shown: Array[String] = []
	if attacker == null or attacker.post_actions == null:
		return shown
	var told: Array[String] = attacker.post_actions.run(attacker, policy_id)
	if attacker.is_user:
		shown.assign(told)
	return shown


## combatd.c (6): a blow that landed calls receive_damage("kee", damage, me), which
## sets last_damage_from whatever the damage, 0 too.
static func _landed(ordinary: CombatOrdinaryAttackResult) -> bool:
	return (
		ordinary != null and ordinary.has_base_result
		and ordinary.base_result.outcome == CombatAttackResult.Outcome.HIT
	)


## Read-only reuse of the audited lifecycle gate. Does not execute an attack.
static func inspect_lifecycle(actor: CombatSliceCharacterBinding) -> CombatSliceOpportunityResult:
	if actor == null or not actor.is_valid():
		return null
	var outcome: int = _required_lifecycle_outcome(actor)
	if outcome == -1:
		return null
	var result := CombatSliceOpportunityResult.new()
	result._actor_id = actor.character_id
	result._life_status_observed = actor.life_status
	result._life_threshold_observed = actor.state.life_threshold()
	result._reached_stage = CombatSliceOpportunityResult.ReachedStage.LIFECYCLE_GATE
	return _finish(result, outcome)


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
