class_name CombatEncounterResolution
extends CombatOpportunityBoundary

enum Failure { NONE, INCOMPLETE_ATTACK_CHAIN, OPPORTUNITY_FAILED, LIFECYCLE_FAILED, WORLD_COMPLETION_FAILED, PARTICIPANT_STATE_INVALID }

## Outcomes that would repeat every round if the fight went on: abort instead.
const FAILED_OPPORTUNITIES: Array[int] = [
	CombatSliceOpportunityResult.Outcome.INVALID_INPUT,
	CombatSliceOpportunityResult.Outcome.OPPONENT_SELECTION_FAILED,
	CombatSliceOpportunityResult.Outcome.FIGHT_DECISION_FAILED,
]

var _session: OldPineWorldSessionController
var _encounter: CombatEncounter
var _failure: Failure = Failure.NONE
var _result: CombatEncounterResult
var _lifecycles: Array[CombatSliceLifecycleResult] = []

var failure: Failure:
	get: return _failure
var result: CombatEncounterResult:
	get: return null if _result == null else _result.duplicate_snapshot()

func _init(session: OldPineWorldSessionController, encounter: CombatEncounter) -> void:
	_session = session
	_encounter = encounter

func lifecycles() -> Array[CombatSliceLifecycleResult]:
	return _lifecycles.duplicate()

func fail(value: Failure) -> void:
	if _failure == Failure.NONE:
		_failure = value

func accept_tactical(value: CombatTacticalExecutionResult) -> void:
	if _failure != Failure.NONE or _result != null or _encounter.phase != CombatEncounterLifecycle.Value.ACTIVE:
		return
	if value == null or value.outcome != CombatTacticalExecutionResult.Outcome.DISENGAGED:
		return
	if _encounter.mode not in [CombatEncounterMode.Value.LETHAL, CombatEncounterMode.Value.SPAR]:
		return
	_result = CombatEncounterResult.new(_encounter.encounter_id, _encounter.mode,
		CombatEncounterResultKind.Value.FLED, [], [], [_session.player_runtime().character_id])

func inspect(bindings: Array[CombatSliceCharacterBinding], event: CombatSchedulerEvent = null) -> bool:
	if _failure != Failure.NONE or _result != null:
		return false
	if event != null and event.resolution != null and event.resolution.outcome == CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_INCOMPLETE:
		fail(Failure.INCOMPLETE_ATTACK_CHAIN)
		return false
	if event != null and event.resolution != null and event.resolution.outcome in FAILED_OPPORTUNITIES:
		fail(Failure.OPPORTUNITY_FAILED)
		return false
	for victim: CombatSliceCharacterBinding in bindings:
		if (not victim.exists_in_encounter and victim.life_status != CombatSliceLifeStatus.Value.DEAD) or (victim.life_status == CombatSliceLifeStatus.Value.ACTIVE and not victim.combat_available):
			fail(Failure.PARTICIPANT_STATE_INVALID)
			return false
		var required: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.inspect_lifecycle(victim)
		if required == null:
			continue
		# char.c heart_beat falls or dies whatever the fight: an armed spar's
		# wound can kill (combatd.c wounds on `is_killing || weapon`).
		var map: WorldMapController = _session.active_map() as WorldMapController
		var receipt: CombatSliceLifecycleResult = null if map == null else map.execute_encounter_lifecycle(victim, required, bindings, last_hitter(event, victim.character_id))
		_lifecycles.append(receipt)
		if receipt == null or not receipt.completed():
			fail(Failure.LIFECYCLE_FAILED)
			return false
	_derive_result(bindings)
	return _result == null

## damage.c last_damage_from: who hit the victim last in this opportunity (the
## riposte comes after the forward blow) or NPC chat (a spell), or empty when
## nobody did.
static func last_hitter(event: CombatSchedulerEvent, victim_id: StringName) -> StringName:
	if event != null and event.chat != null:
		return event.actor_id if event.chat.damaged(victim_id) else &""
	if event == null or event.resolution == null:
		return &""
	var opportunity: CombatSliceOpportunityResult = event.resolution
	var chain: CombatAttackChainResult = opportunity.chain_result
	if chain != null and chain.reverse_execution_reached and chain.reverse_victim_id == victim_id and _hit(chain.reverse_ordinary_result):
		return chain.reverse_attacker_id
	var forward: CombatSingleAttackExecutionResult = opportunity.forward_result
	if forward != null and event.target_id == victim_id and _hit(forward.ordinary_attack_result):
		return event.actor_id
	return &""


static func _hit(ordinary: CombatOrdinaryAttackResult) -> bool:
	return ordinary != null and ordinary.has_base_result and ordinary.base_result.outcome == CombatAttackResult.Outcome.HIT


func _derive_result(bindings: Array[CombatSliceCharacterBinding]) -> void:
	var player_id: StringName = _session.player_runtime().character_id
	var player: CombatParticipant = _encounter.participant_for(player_id)
	if player == null:
		return
	var player_active: bool = false
	var any_hostile_active: bool = false
	var any_fight: bool = false
	var player_binding: CombatSliceCharacterBinding = null
	for binding: CombatSliceCharacterBinding in bindings:
		if binding.character_id == player_id:
			player_binding = binding
	var player_unconscious: bool = (
		player_binding != null and player_binding.exists_in_encounter
		and player_binding.combat_available
		and player_binding.life_status == CombatSliceLifeStatus.Value.UNCONSCIOUS
	)
	var player_being_finished: bool = false
	var winners: Array[StringName] = []
	var losers: Array[StringName] = []
	var subjects: Array[StringName] = []
	for binding: CombatSliceCharacterBinding in bindings:
		var active: bool = binding.exists_in_encounter and binding.life_status == CombatSliceLifeStatus.Value.ACTIVE and binding.combat_available
		if binding.character_id == player_id:
			player_active = active
		if not active:
			subjects.append(binding.character_id)
		var hostile_present: bool = active or (
			_encounter.mode == CombatEncounterMode.Value.LETHAL and binding.exists_in_encounter
			and binding.life_status == CombatSliceLifeStatus.Value.UNCONSCIOUS
			and player.binding.relationship.has_lethal_target(binding.character_id)
		)
		if hostile_present and (_encounter.is_hostile(player_id, binding.character_id) or _encounter.is_hostile(binding.character_id, player_id)):
			any_hostile_active = true
		for other: CombatSliceCharacterBinding in bindings:
			any_fight = any_fight or binding.relationship.has_opponent(other.character_id)
		# feature/attack.c remove_enemy(): a killer keeps an unconscious victim as
		# its enemy and std/char.c kills it on the next wound. The fight goes on
		# only while the scheduler could actually give that killer the player.
		if (
			active
			and binding.character_id != player_id
			and _encounter.mode == CombatEncounterMode.Value.LETHAL
			and player_unconscious
			and binding.location_id == player_binding.location_id
			and _encounter.is_hostile(binding.character_id, player_id)
			and binding.relationship.has_lethal_target(player_id)
			and binding.relationship.has_opponent(player_id)
		):
			player_being_finished = true
	if _encounter.mode == CombatEncounterMode.Value.SPAR:
		# combatd.c: positive friendly damage removes reciprocal enemies; no HP score.
		if any_fight and player_active and any_hostile_active:
			return
		_result = CombatEncounterResult.new(_encounter.encounter_id, _encounter.mode, CombatEncounterResultKind.Value.SPAR_CONCLUDED, [], [], subjects)
		return
	if (player_active and any_hostile_active) or player_being_finished:
		return
	for side: StringName in _encounter.side_ids():
		var side_active: bool = false
		for binding: CombatSliceCharacterBinding in bindings:
			if _encounter.participant_for(binding.character_id).side_id == side:
				side_active = side_active or (binding.exists_in_encounter and binding.life_status == CombatSliceLifeStatus.Value.ACTIVE and binding.combat_available)
		if side_active:
			winners.append(side)
		else:
			losers.append(side)
	_result = CombatEncounterResult.new(_encounter.encounter_id, _encounter.mode,
		CombatEncounterResultKind.Value.VICTORY if player_active else CombatEncounterResultKind.Value.DEFEAT,
		winners, losers, subjects)

## Abort: every participant stops fighting and stops hunting every other
## participant (remove_killer + remove_enemy both ways), so nobody resumes it.
func disengage_all() -> void:
	for actor: CombatParticipant in _encounter.participants():
		for target: CombatParticipant in _encounter.participants():
			if actor.participant_id != target.participant_id:
				actor.binding.relationship.remove_lethal_relation(target.participant_id)
		actor.binding.relationship.set_guarding(false)


## Completion-only encounter relationship reconciliation, never Save-side cleanup.
func reconcile_relationships() -> void:
	for actor: CombatParticipant in _encounter.participants():
		for target: CombatParticipant in _encounter.participants():
			if actor.participant_id != target.participant_id:
				actor.binding.relationship.remove_lethal_relation(target.participant_id)
		if not actor.binding.relationship.is_fighting():
			actor.binding.relationship.set_guarding(false)
