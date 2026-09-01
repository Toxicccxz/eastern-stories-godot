class_name OldPineSaveEligibility
extends RefCounted

const Result := preload(
	"res://runtime/persistence/oldpine_save_eligibility_result.gd"
)


static func inspect(
	session: OldPineWorldSessionController,
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
	if session.is_session_swap_suspended():
		return Result.block(Result.Outcome.SESSION_SWAP_ACTIVE)
	if session.is_transitioning():
		return Result.block(Result.Outcome.MAP_HANDOFF_ACTIVE)
	var handoff: OldPineMapHandoffResult = session.last_map_handoff_result()
	if handoff != null and handoff.has_committed_partial_transition():
		return Result.block(Result.Outcome.MAP_HANDOFF_PARTIAL)
	var cave: OldPineCavePassageController = session.cave_map()
	if cave != null and cave.exit_request_pending():
		return Result.block(Result.Outcome.CAVE_EXIT_PENDING)
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	if outdoor == null:
		return Result.block(Result.Outcome.SESSION_NOT_READY)
	if outdoor.lifecycle_is_pending():
		return Result.block(Result.Outcome.INCOMPLETE_LIFECYCLE)
	if outdoor.aggression_adapter().pending_count() != 0:
		return Result.block(Result.Outcome.PENDING_AGGRESSION)
	if outdoor.cadence_is_running():
		return Result.block(Result.Outcome.COMBAT_CADENCE_ACTIVE)
	for corpse: CorpseState in outdoor.corpse_states():
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
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		var npc_result: OldPineSaveEligibilityResult = _inspect_character(
			npc.character_id,
			npc.character_state,
			npc.relationship,
			npc.busy,
			npc.life_status,
			npc.exists_in_map,
		)
		if not npc_result.allowed():
			return npc_result
	return Result.allow()


static func _inspect_character(
	character_id: StringName,
	state: CharacterState,
	relationship: CombatRelationshipState,
	busy: ActionBusyState,
	life_status: int,
	exists_in_world: bool,
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
	if (life_status == CharacterRuntimeLifeStatus.Value.DEAD) == exists_in_world:
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
