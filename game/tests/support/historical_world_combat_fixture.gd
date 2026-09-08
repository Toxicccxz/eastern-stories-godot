extends CombatEncounterCoordinator

## Explicit historical-only adapter for pre-CXR8 movement/loot regression fixtures.
## Never registered in production. Keeps their old manual cadence subjects intact;
## CXR8 production entry/resolution is covered separately, without this adapter.
static func install(session: OldPineWorldSessionController) -> void:
	session._combat_encounter_coordinator = load("res://tests/support/historical_world_combat_fixture.gd").new(session, session.world_simulation_gate())

func start_production(initiator: CombatSliceCharacterBinding, target: CombatSliceCharacterBinding, _cause: int) -> CombatSliceInitiationResult:
	var result: CombatSliceInitiationResult = CombatSliceOpportunityExecutor.initiate_lethal_combat(initiator, target)
	if result.outcome == CombatSliceInitiationResult.Outcome.COMPLETED and _session.outdoor_map().opportunity_timer.is_stopped():
		_session.outdoor_map().opportunity_timer.start()
	return result
