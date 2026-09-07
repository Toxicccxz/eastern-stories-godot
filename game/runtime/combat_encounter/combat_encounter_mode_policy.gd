class_name CombatEncounterModePolicy
extends RefCounted

## Establishment of already-authorized relationship facts only, NOT command consent,
## aggression detection, faction/vendetta discovery, or terminal outcome generation.
static func supports(trigger: CombatTrigger) -> bool:
	match trigger.cause:
		CombatTriggerCause.Value.SCRIPTED:
			return trigger.requested_mode == CombatEncounterMode.Value.SCRIPTED
		CombatTriggerCause.Value.PLAYER_SPAR:
			return trigger.requested_mode == CombatEncounterMode.Value.SPAR
		CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK, CombatTriggerCause.Value.NPC_AGGRESSION, CombatTriggerCause.Value.VENDETTA_HOSTILITY:
			return trigger.requested_mode == CombatEncounterMode.Value.LETHAL
	return false


static func relationships_match(trigger: CombatTrigger, participants: Array[CombatParticipant], player_id: StringName) -> bool:
	if trigger.cause == CombatTriggerCause.Value.SCRIPTED:
		return true # Preserve CXR3 controlled authored topology boundary.
	if trigger.cause in [CombatTriggerCause.Value.PLAYER_SPAR, CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK] and trigger.initiator_id != player_id:
		return false
	if trigger.cause == CombatTriggerCause.Value.NPC_AGGRESSION and trigger.initiator_id == player_id:
		return false
	var initiator_fact: bool = false
	for actor: CombatParticipant in participants:
		for target: CombatParticipant in participants:
			if actor.participant_id == target.participant_id:
				continue
			var relationship: CombatRelationshipState = actor.binding.relationship
			var fighting: bool = relationship.has_opponent(target.participant_id)
			var lethal: bool = relationship.has_lethal_target(target.participant_id)
			# Contradictory side declarations must not silently suppress a real fight.
			if actor.side_id == target.side_id:
				if fighting or lethal:
					return false
				continue
			if trigger.requested_mode == CombatEncounterMode.Value.SPAR:
				# fight.c speaking/accepted branch: reciprocal fight, no lethal marks.
				# The non-speaking reverse-kill branch is NOT a supported SPAR.
				if lethal or (fighting and not target.binding.relationship.has_opponent(actor.participant_id)):
					return false
				if actor.participant_id == trigger.initiator_id and fighting:
					initiator_fact = true
			elif actor.participant_id == trigger.initiator_id and fighting and lethal:
				# kill.c / combatd start_aggressive,start_vendetta: directed kill_ob.
				# auto_fight excludes NPC-vs-NPC; no reciprocal lethal requirement.
				if trigger.cause in [CombatTriggerCause.Value.NPC_AGGRESSION, CombatTriggerCause.Value.VENDETTA_HOSTILITY] and player_id not in [actor.participant_id, target.participant_id]:
					continue
				initiator_fact = true
	return initiator_fact
