class_name VineLandmarkPolicy
extends WorldLandmarkPolicy

## epath2.c do_hold_vine(): after the hold message, `random(dodge) < 5` drops
## the player into the waterfall pool (portals[0]); otherwise they climb down
## the vine to the passage behind it (portals[1]).
const DODGE_SKILL_ID: StringName = &"dodge"


func keeps_selection() -> bool:
	return false


func use(map: WorldMapController, landmark: WorldLandmarkDefinition) -> RefCounted:
	var result: VineTraversalResult = VineTraversalResult.new()
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var body: WorldCharacterBody2D = map.player_body
	var session: OldPineWorldSessionController = map.session
	var random_source: WorldInteractionRandomSource = map.world_interaction_random_source()
	if player != null:
		result._player_id = player.character_id
	if landmark != null:
		result._interaction_id = landmark.landmark_id
	if player == null or body == null or session == null or landmark == null or not landmark.is_valid() or random_source == null:
		return result
	if not player.is_valid() or not player.exists_in_world or body.character_id != player.character_id:
		result._outcome = VineTraversalResult.Outcome.PLAYER_NOT_AVAILABLE
		return result
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		result._outcome = VineTraversalResult.Outcome.PLAYER_NOT_ACTIVE
		return result
	if session.is_transitioning() or session.active_map_id() != map.map_id():
		result._outcome = VineTraversalResult.Outcome.TRANSITION_IN_PROGRESS
		return result
	var selected: WorldInteractionTarget = map.selected_interaction_target()
	if selected == null or selected.kind != WorldInteractionTarget.Kind.LANDMARK or selected.target_id != landmark.landmark_id:
		result._outcome = VineTraversalResult.Outcome.INVALID_SELECTED_TARGET
		return result

	var source: WorldLocationState = player.world_location()
	var zone: ZoneDefinition = GameContent.catalog().zone(landmark.zone_id)
	result._source_location = null if source == null else source.duplicate_snapshot()
	if source == null or zone == null or source.map_id != map.map_id() or source.zone_id != zone.zone_id or source.combat_location_id != zone.combat_location_id:
		result._outcome = VineTraversalResult.Outcome.SOURCE_LOCATION_MISMATCH
		return result

	var hud: SharedGameplayUI = session.shared_ui()
	# epath2.c emits the hold message before reading dodge/random.
	hud.append_log_lines([landmark.message("hold")])
	result._source_presentation_reached = true
	result._reached_stage = VineTraversalResult.ReachedStage.SOURCE_PRESENTATION
	var armor_dodge: int = player.armor.aggregate_numeric_modifiers().dodge
	result._effective_dodge = player.state.skills.effective_level(DODGE_SKILL_ID, armor_dodge)
	var portals: Array[StringName] = landmark.portal_ids()
	result._policy_result = VineTraversalPolicy.new(portals[0], portals[1]).evaluate(
		result._effective_dodge, random_source,
	)
	result._reached_stage = VineTraversalResult.ReachedStage.POLICY
	if result._policy_result.outcome == VineTraversalPolicyResult.Outcome.INVALID_RANDOM_DRAW:
		result._outcome = VineTraversalResult.Outcome.POLICY_INVALID_DRAW
		return result
	if not result._policy_result.branch_selected():
		return result

	result._selected_portal_id = result._policy_result.selected_portal_id
	var waterfall: bool = result._policy_result.selected_branch == VineTraversalPolicyResult.Branch.WATERFALL
	# The branch message precedes both moves in epath2.c.
	hud.append_log_lines([landmark.message("fall" if waterfall else "climb")])
	result._branch_presentation_reached = true
	result._reached_stage = VineTraversalResult.ReachedStage.BRANCH_PRESENTATION
	var portal: PortalDefinition = GameContent.catalog().portal(result._selected_portal_id)
	result._reached_stage = VineTraversalResult.ReachedStage.MOVEMENT
	var moved: RefCounted = move_through(map, portal)
	if moved is WorldPortalTraversalResult:
		result._same_map_result = moved
		result._movement_location_committed = result._same_map_result.completed()
		if not result._movement_location_committed:
			result._outcome = VineTraversalResult.Outcome.SAME_MAP_TRAVERSAL_FAILED
			return result
	else:
		result._map_handoff_result = moved
		result._movement_location_committed = result._map_handoff_result.location_committed
		if not result._map_handoff_result.succeeded():
			result._outcome = VineTraversalResult.Outcome.MAP_HANDOFF_FAILED
			return result
	result._outcome = VineTraversalResult.Outcome.COMPLETED_WATERFALL if waterfall else VineTraversalResult.Outcome.COMPLETED_PASSAGE
	result._reached_stage = VineTraversalResult.ReachedStage.COMPLETED
	return result
