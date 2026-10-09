class_name OldPineSaveEligibility
extends RefCounted

const Result := preload(
	"res://runtime/persistence/oldpine_save_eligibility_result.gd"
)


static func inspect(
	session: WorldSessionController,
) -> OldPineSaveEligibilityResult:
	if (
		session == null
		or not session.is_inside_tree()
		or not session.is_initialized()
		or session.process_mode == Node.PROCESS_MODE_DISABLED
		or session.active_map() == null
		or session.active_map().process_mode == Node.PROCESS_MODE_DISABLED
		or session.active_map_child_count() != 1
	):
		return Result.block(Result.Outcome.SESSION_NOT_READY)
	if session.is_restore_candidate_staged():
		return Result.block(Result.Outcome.RESTORE_STAGED)
	if session.combat_encounter_coordinator().has_active_encounter() or not session.world_simulation_gate().is_open():
		return Result.block(Result.Outcome.ACTIVE_COMBAT_ENCOUNTER)
	if session.is_session_swap_suspended():
		return Result.block(Result.Outcome.SESSION_SWAP_ACTIVE)
	# dun.c took the player away; the move to its room comes a frame after the fight.
	if session.is_transitioning() or not session.combat_encounter_coordinator().pending_departure().is_empty():
		return Result.block(Result.Outcome.MAP_HANDOFF_ACTIVE)
	var handoff: OldPineMapHandoffResult = session.last_map_handoff_result()
	if handoff != null and handoff.has_committed_partial_transition():
		return Result.block(Result.Outcome.MAP_HANDOFF_PARTIAL)
	if session.passage_request_pending():
		return Result.block(Result.Outcome.PASSAGE_PENDING)
	# The player cannot act while unconscious or dead (disable_player/ghost);
	# waking up and the way back from death are short and are not saved.
	if session.player_life_flow().is_active():
		return Result.block(
			Result.Outcome.INCOMPLETE_LIFECYCLE,
			session.player_runtime().character_id,
			"player is unconscious or dead",
		)
	var maps: Array[WorldMapController] = session.world_maps()
	if maps.is_empty():
		return Result.block(Result.Outcome.SESSION_NOT_READY)
	for map: WorldMapController in maps:
		if map.lifecycle_is_pending():
			return Result.block(Result.Outcome.INCOMPLETE_LIFECYCLE)
		if map.aggression_adapter().pending_count() != 0:
			return Result.block(Result.Outcome.PENDING_AGGRESSION)
		for corpse: CorpseState in map.corpse_states():
			if corpse.decay_stage == CorpseState.Stage.FINAL:
				return Result.block(
					Result.Outcome.INCOMPLETE_LIFECYCLE,
					corpse.corpse_item_instance_id,
					"live corpse has reached FINAL without completed destruction",
				)

	var player: WorldPlayerRuntimeState = session.player_runtime()
	var player_result: OldPineSaveEligibilityResult = _inspect_character(
		player.character_id if player != null else &"",
		player.state if player != null else null,
		player.relationship if player != null else null,
		player.busy if player != null else null,
		player.life_status if player != null else -1,
		player.exists_in_world if player != null else false,
	)
	if not player_result.allowed():
		return player_result
	for npc: NpcRuntimeState in session.world_npcs():
		if left_out(npc):
			continue
		# A summoned NPC lives only as long as the fight it came into (SummonedNpc): a save
		# holds none.
		if SummonedNpc.is_summoned(npc.character_id):
			return Result.block(Result.Outcome.ACTIVE_COMBAT_ENCOUNTER, npc.character_id)
		var npc_result: OldPineSaveEligibilityResult = _inspect_character(
			npc.character_id,
			npc.character_state,
			npc.relationship,
			npc.busy,
			npc.life_status,
			npc.exists_in_map,
			_summoned(npc),
		)
		if not npc_result.allowed():
			return npc_result
	return Result.allow()


## A conjured NPC still standing (the 观想虫 of a practice: NpcConjuring) does not stop
## a save; the save leaves it out, and Continue starts without it and without the
## player's set_temp("mind_bug"), as ES2's relogin (DECISIONS 茅山 C). It carries nothing.
## Nor does a raised one (the zombie of 驱尸: NpcRaising), whose master is gone after a
## relogin, so it would dispell (DECISIONS 茅山 A); a corpse it left is kept.
static func left_out(npc: NpcRuntimeState) -> bool:
	if not SummonedNpc.is_summoned(npc.character_id):
		return false
	if npc.definition().raising() != null:
		return true
	return npc.definition().conjuring() != null and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD


static func _summoned(npc: NpcRuntimeState) -> bool:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(npc.spawn_id)
	return spawn != null and spawn.starts_absent


static func _inspect_character(
	character_id: StringName,
	state: CharacterState,
	relationship: CombatRelationshipState,
	busy: ActionBusyState,
	life_status: int,
	exists_in_world: bool,
	may_be_absent: bool = false,
) -> OldPineSaveEligibilityResult:
	if (
		character_id.is_empty()
		or state == null
		or relationship == null
		or busy == null
		or not CharacterRuntimeLifeStatus.is_valid(life_status)
	):
		return Result.block(Result.Outcome.SESSION_NOT_READY, character_id)
	if not relationship.opponent_ids().is_empty():
		return Result.block(Result.Outcome.OPPONENT_RELATIONSHIP, character_id)
	if not relationship.lethal_target_ids().is_empty():
		return Result.block(Result.Outcome.LETHAL_MARKER, character_id)
	if busy.busy_value != 0:
		return Result.block(Result.Outcome.BUSY, character_id)
	if busy.interrupt_threshold != 0:
		return Result.block(Result.Outcome.INTERRUPT_THRESHOLD, character_id)
	if relationship.guarding:
		return Result.block(Result.Outcome.GUARDING, character_id)
	# A summoned NPC is alive and not in the world until its room calls it in (a drawn
	# one until its room's reset draws it).
	if (life_status == CharacterRuntimeLifeStatus.Value.DEAD and exists_in_world) or (life_status != CharacterRuntimeLifeStatus.Value.DEAD and not exists_in_world and not may_be_absent):
		return Result.block(
			Result.Outcome.LIFE_EXISTENCE_CONTRADICTION,
			character_id,
		)
	if _has_unrepresented_attribute_modifier(state.attributes):
		return Result.block(
			Result.Outcome.UNREPRESENTED_ATTRIBUTE_MODIFIER,
			character_id,
		)
	return Result.allow()


static func _has_unrepresented_attribute_modifier(
	attributes: CharacterBaseAttributes,
) -> bool:
	return (
		attributes == null
		or attributes.strength_modifier != 0
		or attributes.courage_modifier != 0
		or attributes.intelligence_modifier != 0
		or attributes.spirituality_modifier != 0
		or attributes.composure_modifier != 0
		or attributes.personality_modifier != 0
		or attributes.constitution_modifier != 0
		or attributes.karma_modifier != 0
	)
