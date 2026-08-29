class_name OldPineVineTraversalAdapter
extends RefCounted

const DODGE_SKILL_ID: StringName = &"dodge"


func traverse(
	player: WorldPlayerRuntimeState,
	body: WorldCharacterBody2D,
	session: OldPineWorldSessionController,
	outdoor: OldPineOutdoorController,
	selected_target: WorldInteractionTarget,
	definition: OldPineVineInteractionDefinition,
	random_source: WorldInteractionRandomSource,
	hud: OldPineOutdoorHud,
	same_map_adapter: OldPinePortalTraversalAdapter,
) -> OldPineVineTraversalResult:
	var result: OldPineVineTraversalResult = OldPineVineTraversalResult.new()
	if player != null:
		result._player_id = player.character_id
	if definition != null:
		result._interaction_id = definition.interaction_id
	if (
		player == null
		or body == null
		or session == null
		or outdoor == null
		or definition == null
		or not definition.is_valid()
		or random_source == null
		or hud == null
		or same_map_adapter == null
	):
		return result
	if not player.is_valid() or not player.exists_in_world or body.character_id != player.character_id:
		result._outcome = OldPineVineTraversalResult.Outcome.PLAYER_NOT_AVAILABLE
		return result
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		result._outcome = OldPineVineTraversalResult.Outcome.PLAYER_NOT_ACTIVE
		return result
	if session.is_transitioning() or session.active_map_id() != outdoor.map_id():
		result._outcome = OldPineVineTraversalResult.Outcome.TRANSITION_IN_PROGRESS
		return result
	if (
		selected_target == null
		or selected_target.kind != WorldInteractionTarget.Kind.LANDMARK
		or selected_target.target_id != definition.interaction_id
	):
		result._outcome = OldPineVineTraversalResult.Outcome.INVALID_SELECTED_TARGET
		return result

	var source: WorldLocationState = player.world_location()
	result._source_location = null if source == null else source.duplicate_snapshot()
	if (
		source == null
		or source.region_id != OldPineWorldDefinitions.REGION_ID
		or source.map_id != OldPineWorldDefinitions.OUTDOOR_MAP_ID
		or source.zone_id != OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID
		or source.combat_location_id != OldPineWorldDefinitions.EAST_BRIDGE_ZONE_ID
	):
		result._outcome = OldPineVineTraversalResult.Outcome.SOURCE_LOCATION_MISMATCH
		return result

	# epath2.c emits source-room presentation before reading dodge/random.
	hud.append_log_lines([definition.source_player_presentation])
	result._source_presentation_reached = true
	result._reached_stage = OldPineVineTraversalResult.ReachedStage.SOURCE_PRESENTATION
	var armor_dodge: int = player.armor.aggregate_numeric_modifiers().dodge
	result._effective_dodge = player.state.skills.effective_level(
		DODGE_SKILL_ID,
		armor_dodge,
	)
	var policy: VineTraversalPolicy = VineTraversalPolicy.new(
		definition.waterfall_portal_id,
		definition.passage_portal_id,
	)
	result._policy_result = policy.evaluate(result._effective_dodge, random_source)
	result._reached_stage = OldPineVineTraversalResult.ReachedStage.POLICY
	if (
		result._policy_result.outcome
		== VineTraversalPolicyResult.Outcome.LEGACY_RANDOM_BOUND_AMBIGUITY
	):
		result._outcome = OldPineVineTraversalResult.Outcome.POLICY_AMBIGUITY
		return result
	if (
		result._policy_result.outcome
		== VineTraversalPolicyResult.Outcome.INVALID_RANDOM_DRAW
	):
		result._outcome = OldPineVineTraversalResult.Outcome.POLICY_INVALID_DRAW
		return result
	if not result._policy_result.branch_selected():
		return result

	result._selected_portal_id = result._policy_result.selected_portal_id
	var branch_text: String = (
		definition.waterfall_player_presentation
		if result._policy_result.selected_branch
		== VineTraversalPolicyResult.Branch.WATERFALL
		else definition.passage_player_presentation
	)
	# Branch presentation precedes both direct move destinations in epath2.c.
	hud.append_log_lines([branch_text])
	result._branch_presentation_reached = true
	result._reached_stage = OldPineVineTraversalResult.ReachedStage.BRANCH_PRESENTATION
	var portal: PortalDefinition = OldPineWorldDefinitions.portal_by_id(
		result._selected_portal_id
	)
	result._reached_stage = OldPineVineTraversalResult.ReachedStage.MOVEMENT
	if result._policy_result.selected_branch == VineTraversalPolicyResult.Branch.WATERFALL:
		var marker: WorldSpawnMarker2D = (
			null if portal == null else outdoor.resolve_spawn_marker(
				portal.destination_spawn_point_id
			)
		)
		var destination: WorldLocationState = (
			null if portal == null else outdoor.resolve_location(
				portal.destination_zone_id,
				portal.destination_zone_id,
			)
		)
		result._same_map_result = same_map_adapter.traverse(
			player,
			body,
			portal,
			marker,
			destination,
		)
		result._movement_location_committed = result._same_map_result.completed()
		if not result._movement_location_committed:
			result._outcome = (
				OldPineVineTraversalResult.Outcome.SAME_MAP_TRAVERSAL_FAILED
			)
			return result
		result._outcome = OldPineVineTraversalResult.Outcome.COMPLETED_WATERFALL
	else:
		if portal == null:
			result._outcome = OldPineVineTraversalResult.Outcome.MAP_HANDOFF_FAILED
			return result
		var destination_zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(
			portal.destination_zone_id
		)
		if destination_zone == null:
			result._outcome = OldPineVineTraversalResult.Outcome.MAP_HANDOFF_FAILED
			return result
		result._map_handoff_result = session.handoff_to(
			portal.destination_map_id,
			portal.destination_zone_id,
			destination_zone.combat_location_id,
			portal.destination_spawn_point_id,
		)
		result._movement_location_committed = (
			result._map_handoff_result.location_committed
		)
		if not result._map_handoff_result.succeeded():
			result._outcome = OldPineVineTraversalResult.Outcome.MAP_HANDOFF_FAILED
			return result
		result._outcome = OldPineVineTraversalResult.Outcome.COMPLETED_PASSAGE
	result._reached_stage = OldPineVineTraversalResult.ReachedStage.COMPLETED
	return result
