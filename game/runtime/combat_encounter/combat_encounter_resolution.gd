class_name CombatEncounterResolution
extends CombatOpportunityBoundary

enum Failure { NONE, INCOMPLETE_ATTACK_CHAIN, OPPORTUNITY_FAILED, LIFECYCLE_FAILED, WORLD_COMPLETION_FAILED, PARTICIPANT_STATE_INVALID }

## Outcomes that would repeat every round if the fight went on: abort instead.
const FAILED_OPPORTUNITIES: Array[int] = [
	CombatSliceOpportunityResult.Outcome.INVALID_INPUT,
	CombatSliceOpportunityResult.Outcome.OPPONENT_SELECTION_FAILED,
	CombatSliceOpportunityResult.Outcome.FIGHT_DECISION_FAILED,
]

var _session: WorldSessionController
var _encounter: CombatEncounter
var _failure: Failure = Failure.NONE
var _result: CombatEncounterResult
var _lifecycles: Array[CombatSliceLifecycleResult] = []
var _failed_special: SpecialReport
var _departure: StringName

var failure: Failure:
	get: return _failure
var result: CombatEncounterResult:
	get: return null if _result == null else _result.duplicate_snapshot()
## The special whose attack did not finish, when that failed the fight.
var failed_special: SpecialReport:
	get: return _failed_special
## The room a spell took the player to as they left the fight (dun.c), or empty.
var departure: StringName:
	get: return _departure

func _init(session: WorldSessionController, encounter: CombatEncounter) -> void:
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
	_departure = value.departure
	_result = CombatEncounterResult.new(_encounter.encounter_id, _encounter.mode,
		CombatEncounterResultKind.Value.FLED, [], [], [_session.player_runtime().character_id])

## Those who turn on the player's side: roar.c's kill_ob()s (the player), an NPC's
## ask_for_help() and its soldier's invocation() (CombatJoin). One already in the fight
## now kills its targets; one in the room but not in it comes in on the side against the
## player, killing its targets, each fighting it back (an NPC killed back by a soldier
## kills it back). Then the soldiers the player called come in on the player's side. A
## spar goes on to the death. Someone who cannot fight here (gone, not available) stays out.
func admit(bindings: Array[CombatSliceCharacterBinding], tactical: CombatTacticalExecutionResult) -> void:
	if _failure != Failure.NONE or _result != null or _encounter.phase != CombatEncounterLifecycle.Value.ACTIVE or tactical == null:
		return
	var player_id: StringName = _session.player_runtime().character_id
	var player: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, player_id)
	var player_participant: CombatParticipant = _encounter.participant_for(player_id)
	if player == null or player_participant == null:
		return
	var enemy_side: StringName = &""
	for side_id: StringName in _encounter.side_ids():
		if side_id != player_participant.side_id:
			enemy_side = side_id
			break
	var map: WorldMapController = _session.active_map() as WorldMapController
	var coordinator: CombatEncounterCoordinator = _session.combat_encounter_coordinator()
	var joins: Array[CombatJoin] = []
	for joiner_id: StringName in tactical.joiners:
		joins.append(CombatJoin.new(joiner_id, [player_id]))
	joins.append_array(tactical.joins)
	var warnings: Array[String] = []
	var turned: bool = false
	for join: CombatJoin in joins:
		if _admit_join(bindings, join, player_id, enemy_side, map):
			turned = true
			if join.target_ids.has(player_id):
				warnings.append(coordinator.kill_warning(join.joiner_id))
	coordinator.note_warnings(warnings)
	var allied: bool = false
	for ally_id: StringName in tactical.allies:
		allied = _admit_ally(bindings, ally_id, player, player_participant.side_id, map) or allied
	if turned or allied:
		_encounter.escalate_to_lethal()


## One join: whether its kill_ob()s were made (and it is in the fight now).
func _admit_join(
	bindings: Array[CombatSliceCharacterBinding], join: CombatJoin, player_id: StringName, enemy_side: StringName,
	map: WorldMapController,
) -> bool:
	var targets: Array[CombatSliceCharacterBinding] = []
	for target_id: StringName in join.target_ids:
		var target: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, target_id)
		if target != null:
			targets.append(target)
	if targets.is_empty():
		return false
	var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, join.joiner_id)
	if binding != null:
		for target: CombatSliceCharacterBinding in targets:
			binding.relationship.mark_lethal_target(target.character_id)
			if join.killed_back and target.character_id != player_id:
				target.relationship.mark_lethal_target(binding.character_id)
		return true
	binding = null if map == null else map.combat_binding_for(join.joiner_id)
	var authority: CombatEncounterAuthorityBinding = _session.resolve_encounter_binding(join.joiner_id)
	if binding == null or authority == null or enemy_side.is_empty() or not _session.encounter_participant_is_available(join.joiner_id):
		return false
	var saved: Array[Array] = [[binding.relationship.opponent_ids(), binding.relationship.lethal_target_ids()]]
	for target: CombatSliceCharacterBinding in targets:
		saved.append([target.relationship.opponent_ids(), target.relationship.lethal_target_ids()])
	var engaged: bool = true
	for target: CombatSliceCharacterBinding in targets:
		# The player only fights back (fight_ob()); an NPC kills back when the joiner's
		# invocation() says so.
		var mutual: bool = join.killed_back and target.character_id != player_id
		var receipt: CombatSliceInitiationResult = (
			CombatSliceOpportunityExecutor.initiate_lethal_combat(binding, target) if mutual
			else CombatSliceOpportunityExecutor.initiate_directed_kill(binding, target)
		)
		engaged = engaged and receipt.outcome == CombatSliceInitiationResult.Outcome.COMPLETED
	if not engaged or not _encounter.admit(CombatParticipant.new(join.joiner_id, enemy_side, authority)):
		_restore(binding.relationship, saved[0][0], saved[0][1])
		for index: int in targets.size():
			_restore(targets[index].relationship, saved[index + 1][0], saved[index + 1][1])
		return false
	bindings.append(binding)
	return true


## heaven_soldier.c invocation() for the player: the soldier kill_ob()s each of the
## player's enemies that is living() (from the last, `while(i--)`), each of them an NPC
## that kill_ob()s it back, and it comes in on the player's side. False (nothing
## changed) when it cannot fight here or nobody of theirs stands.
func _admit_ally(
	bindings: Array[CombatSliceCharacterBinding], ally_id: StringName, player: CombatSliceCharacterBinding,
	side_id: StringName, map: WorldMapController,
) -> bool:
	if CombatSliceProjectionBuilder.find_binding(bindings, ally_id) != null:
		return false
	var binding: CombatSliceCharacterBinding = null if map == null else map.combat_binding_for(ally_id)
	var authority: CombatEncounterAuthorityBinding = _session.resolve_encounter_binding(ally_id)
	if binding == null or authority == null or not _session.encounter_participant_is_available(ally_id):
		return false
	var enemies: Array[CombatSliceCharacterBinding] = []
	for enemy_id: StringName in player.relationship.opponent_ids():
		var enemy: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(bindings, enemy_id)
		if (
			enemy != null and enemy.exists_in_encounter and enemy.combat_available
			and enemy.life_status == CombatSliceLifeStatus.Value.ACTIVE and _encounter.is_hostile(player.character_id, enemy_id)
		):
			enemies.append(enemy)
	enemies.reverse()
	if enemies.is_empty():
		return false
	var saved: Array[Array] = [[binding.relationship.opponent_ids(), binding.relationship.lethal_target_ids()]]
	for enemy: CombatSliceCharacterBinding in enemies:
		saved.append([enemy.relationship.opponent_ids(), enemy.relationship.lethal_target_ids()])
	var engaged: bool = true
	for enemy: CombatSliceCharacterBinding in enemies:
		engaged = engaged and CombatSliceOpportunityExecutor.initiate_lethal_combat(binding, enemy).outcome == CombatSliceInitiationResult.Outcome.COMPLETED
	if not engaged or not _encounter.admit(CombatParticipant.new(ally_id, side_id, authority)):
		_restore(binding.relationship, saved[0][0], saved[0][1])
		for index: int in enemies.size():
			_restore(enemies[index].relationship, saved[index + 1][0], saved[index + 1][1])
		return false
	bindings.append(binding)
	return true


## A relationship back as it was (an admission that could not be completed).
static func _restore(state: CombatRelationshipState, opponents: Array, lethal: Array) -> void:
	for target_id: StringName in state.lethal_target_ids():
		if not lethal.has(target_id):
			state.remove_lethal_relation(target_id)
	for target_id: StringName in state.opponent_ids():
		if not opponents.has(target_id):
			state.remove_opponent(target_id)


func inspect(
	bindings: Array[CombatSliceCharacterBinding], event: CombatSchedulerEvent = null,
	tactical: CombatTacticalExecutionResult = null,
) -> bool:
	if _failure != Failure.NONE or _result != null:
		return false
	if event != null and event.resolution != null and event.resolution.outcome == CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_INCOMPLETE:
		fail(Failure.INCOMPLETE_ATTACK_CHAIN)
		return false
	var special: SpecialReport = _special_of(event, tactical)
	if special != null and not special.is_complete():
		_failed_special = special
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
		var hitter: StringName = special.last_hitter(victim.character_id) if special != null else last_hitter(event, victim.character_id)
		var receipt: CombatSliceLifecycleResult = null if map == null else map.execute_encounter_lifecycle(victim, required, bindings, hitter)
		_lifecycles.append(receipt)
		if receipt == null or not receipt.completed():
			fail(Failure.LIFECYCLE_FAILED)
			return false
	_derive_result(bindings)
	return _result == null

## What a special file did since the last check: a timed apply's remove_effect()
## (the event) or the player's perform (the tactical result).
static func _special_of(event: CombatSchedulerEvent, tactical: CombatTacticalExecutionResult) -> SpecialReport:
	if event != null and event.special != null:
		return event.special
	return null if tactical == null else tactical.special


## damage.c last_damage_from: who hit the victim last in this opportunity (the
## riposte comes after the forward blow), NPC chat (a spell) or special (its
## attacks), or empty when nobody did.
static func last_hitter(event: CombatSchedulerEvent, victim_id: StringName) -> StringName:
	if event != null and event.special != null:
		return event.special.last_hitter(victim_id)
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
			and _side_kills(bindings, player, binding.character_id)
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
	# Nobody standing still fights someone it can strike (roar.c's spar partner who
	# withstood it stops after the first blow, as any spar): the fight is over.
	if (player_active and any_hostile_active and _anyone_engaged(bindings)) or player_being_finished:
		return
	if player_unconscious and _ally_engaged(bindings, player):
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

## The player kills `victim_id`, or one standing on the player's side does (the soldier
## they called finishes an enemy that fell, as a killer does).
func _side_kills(bindings: Array[CombatSliceCharacterBinding], player: CombatParticipant, victim_id: StringName) -> bool:
	if player.binding.relationship.has_lethal_target(victim_id):
		return true
	for ally: CombatSliceCharacterBinding in bindings:
		var participant: CombatParticipant = _encounter.participant_for(ally.character_id)
		if (
			participant != null and participant.side_id == player.side_id and ally.character_id != player.participant_id
			and ally.exists_in_encounter and ally.combat_available and ally.life_status == CombatSliceLifeStatus.Value.ACTIVE
			and ally.relationship.has_lethal_target(victim_id)
		):
			return true
	return false


## One standing on the player's side (the soldier they called) still fights someone of
## the other side, or is fought by one standing: the fight goes on while the player lies
## there, as it does in ES2 around anyone who fell.
func _ally_engaged(bindings: Array[CombatSliceCharacterBinding], player: CombatParticipant) -> bool:
	for ally: CombatSliceCharacterBinding in bindings:
		var side: CombatParticipant = _encounter.participant_for(ally.character_id)
		if side == null or side.side_id != player.side_id or ally.character_id == player.participant_id or not _standing(ally):
			continue
		for other: CombatSliceCharacterBinding in bindings:
			var other_side: CombatParticipant = _encounter.participant_for(other.character_id)
			if other_side == null or other_side.side_id == player.side_id or not other.exists_in_encounter:
				continue
			var downed_victim: bool = other.life_status == CombatSliceLifeStatus.Value.UNCONSCIOUS and ally.relationship.has_lethal_target(other.character_id)
			if ally.relationship.has_opponent(other.character_id) and (_standing(other) or downed_victim):
				return true
			if _standing(other) and other.relationship.has_opponent(ally.character_id):
				return true
	return false


static func _standing(binding: CombatSliceCharacterBinding) -> bool:
	return binding.exists_in_encounter and binding.combat_available and binding.life_status == CombatSliceLifeStatus.Value.ACTIVE


## Someone standing fights someone the scheduler could give it: a standing one, or
## an unconscious one it kills.
static func _anyone_engaged(bindings: Array[CombatSliceCharacterBinding]) -> bool:
	for actor: CombatSliceCharacterBinding in bindings:
		if not actor.exists_in_encounter or actor.life_status != CombatSliceLifeStatus.Value.ACTIVE or not actor.combat_available:
			continue
		for other: CombatSliceCharacterBinding in bindings:
			if other == actor or not other.exists_in_encounter or not actor.relationship.has_opponent(other.character_id):
				continue
			if other.life_status == CombatSliceLifeStatus.Value.ACTIVE or (
				other.life_status == CombatSliceLifeStatus.Value.UNCONSCIOUS and actor.relationship.has_lethal_target(other.character_id)
			):
				return true
	return false


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
