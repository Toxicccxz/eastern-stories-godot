class_name CombatEncounterResolution
extends CombatOpportunityBoundary

enum Failure { NONE, INCOMPLETE_ATTACK_CHAIN, LIFECYCLE_FAILED, SPAR_MORTAL_WOUND, WORLD_COMPLETION_FAILED, PARTICIPANT_STATE_INVALID }

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

func inspect(bindings: Array[CombatSliceCharacterBinding], event: CombatSchedulerEvent = null) -> bool:
	if _failure != Failure.NONE or _result != null:
		return false
	if event != null and event.resolution != null and event.resolution.outcome == CombatSliceOpportunityResult.Outcome.ATTACK_CHAIN_INCOMPLETE:
		fail(Failure.INCOMPLETE_ATTACK_CHAIN)
		return false
	for victim: CombatSliceCharacterBinding in bindings:
		if (not victim.exists_in_encounter and victim.life_status != CombatSliceLifeStatus.Value.DEAD) or (victim.life_status == CombatSliceLifeStatus.Value.ACTIVE and not victim.combat_available):
			fail(Failure.PARTICIPANT_STATE_INVALID)
			return false
		var required: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.inspect_lifecycle(victim)
		if required == null:
			continue
		## Source permits armed friendly mortal wounds. Do not clamp, invent revival,
		## or manufacture a corpse in non-corpse SPAR. Explicit unresolved policy.
		if _encounter.mode == CombatEncounterMode.Value.SPAR and required.outcome == CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH:
			fail(Failure.SPAR_MORTAL_WOUND)
			return false
		var receipt: CombatSliceLifecycleResult = _session.outdoor_map().execute_encounter_lifecycle(victim, required, bindings)
		_lifecycles.append(receipt)
		if receipt == null or not receipt.completed():
			fail(Failure.LIFECYCLE_FAILED)
			return false
	_derive_result(bindings)
	return _result == null

func _derive_result(bindings: Array[CombatSliceCharacterBinding]) -> void:
	var player_id: StringName = _session.player_runtime().character_id
	var player: CombatParticipant = _encounter.participant_for(player_id)
	if player == null:
		return
	var player_active: bool = false
	var any_hostile_active: bool = false
	var any_fight: bool = false
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
	if _encounter.mode == CombatEncounterMode.Value.SPAR:
		# combatd.c: positive friendly damage removes reciprocal enemies; no HP score.
		if any_fight and player_active and any_hostile_active:
			return
		_result = CombatEncounterResult.new(_encounter.encounter_id, _encounter.mode, CombatEncounterResultKind.Value.SPAR_CONCLUDED, [], [], subjects)
		return
	if player_active and any_hostile_active:
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

## Completion-only encounter relationship reconciliation, never Save-side cleanup.
func reconcile_relationships() -> void:
	for actor: CombatParticipant in _encounter.participants():
		for target: CombatParticipant in _encounter.participants():
			if actor.participant_id != target.participant_id:
				actor.binding.relationship.remove_lethal_relation(target.participant_id)
		if not actor.binding.relationship.is_fighting():
			actor.binding.relationship.set_guarding(false)
