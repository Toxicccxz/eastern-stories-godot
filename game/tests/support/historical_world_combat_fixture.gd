extends CombatEncounterCoordinator

## Explicit historical-only adapter for pre-CXR8 movement/loot regression fixtures.
## Never registered in production. Keeps their old manual cadence subjects intact:
## a pair entry marks the map's cadence as running and tick() runs one manual
## round exactly as the retired map-local process_cadence_tick() did, so their
## recorded random draws still hold. CXR8 production entry/resolution is
## covered separately, without this adapter.
const RUNNING: StringName = &"historical_cadence_running"
const ORDER: StringName = &"historical_tick_order"


static func install(session: OldPineWorldSessionController) -> void:
	session._combat_encounter_coordinator = load("res://tests/support/historical_world_combat_fixture.gd").new(session, session.world_simulation_gate())


func start_production(initiator: CombatSliceCharacterBinding, target: CombatSliceCharacterBinding, _cause: int, _directed_kill: bool = false) -> CombatSliceInitiationResult:
	var result: CombatSliceInitiationResult = CombatSliceOpportunityExecutor.initiate_lethal_combat(initiator, target)
	if result.outcome == CombatSliceInitiationResult.Outcome.COMPLETED:
		set_running(_session.active_map() as WorldMapController, true)
	return result


static func cadence_running(map: WorldMapController) -> bool:
	return map != null and bool(map.get_meta(RUNNING, false))


static func set_running(map: WorldMapController, value: bool) -> void:
	map.set_meta(RUNNING, value)


static func last_tick_order(map: WorldMapController) -> Array[StringName]:
	var order: Array[StringName] = []
	order.assign(map.get_meta(ORDER, []))
	return order


## One manual round: every fighting participant in stable order acts once.
static func tick(map: WorldMapController) -> Array[CombatSliceOpportunityResult]:
	var results: Array[CombatSliceOpportunityResult] = []
	if not map.gameplay_open():
		return results
	var order: Array[StringName] = []
	map.set_meta(ORDER, order)
	map._last_lifecycle_results.clear()
	if map.lifecycle_is_pending():
		return results
	var presenter: CombatSlicePresenter = CombatSlicePresenter.new()
	var hud: SharedGameplayUI = map.session.shared_ui()
	var participants: Array[CombatSliceCharacterBinding] = map._build_participants()
	for actor: CombatSliceCharacterBinding in participants:
		if not actor.exists_in_encounter or not actor.relationship.is_fighting():
			continue
		order.append(actor.character_id)
		var opportunity: CombatSliceOpportunityResult = CombatSliceOpportunityExecutor.execute_opportunity(
			actor, participants, map.combat_random_source(), map.encounter_skill_effect_registry(),
		)
		results.append(opportunity)
		if opportunity.outcome in [
			CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_UNCONSCIOUS,
			CombatSliceOpportunityResult.Outcome.LIFECYCLE_REQUIRED_DEATH,
		]:
			var lifecycle: CombatSliceLifecycleResult = map.execute_encounter_lifecycle(actor, opportunity, participants)
			hud.append_log_lines(presenter.describe_lifecycle(lifecycle, _display_name(map, actor.character_id)))
			if not lifecycle.completed():
				set_running(map, false)
				break
		else:
			hud.append_log_lines(presenter.describe_opportunity(
				opportunity, _display_name(map, actor.character_id), _display_name(map, _selected_opponent_id(opportunity, actor)),
			))
	if not _has_active_relationships(map):
		set_running(map, false)
	hud.refresh_live_state()
	return results


static func _selected_opponent_id(result: CombatSliceOpportunityResult, actor: CombatSliceCharacterBinding) -> StringName:
	var selection: CombatOpponentSelectionResult = result.opponent_selection_result
	if selection != null and selection.has_selected_opponent:
		return selection.selected_opponent_id
	var ids: Array[StringName] = actor.relationship.opponent_ids()
	return &"" if ids.is_empty() else ids[0]


static func _display_name(map: WorldMapController, character_id: StringName) -> String:
	var player: WorldPlayerRuntimeState = map.player_runtime()
	if character_id == player.character_id:
		return player.facts.display_name
	var npc: NpcRuntimeState = map.find_resident_npc(character_id)
	return "Unknown" if npc == null else npc.definition().display_name


static func _has_active_relationships(map: WorldMapController) -> bool:
	var player: WorldPlayerRuntimeState = map.player_runtime()
	if player.exists_in_world and player.relationship.is_fighting():
		return true
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.exists_in_map and npc.relationship.is_fighting():
			return true
	return false
