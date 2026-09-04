extends RefCounted

const SessionScene := preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)

var _assertion_count: int = 0
var _failures: Array[String] = []

class CountingCombatRandomSource extends CombatRandomSource:
	var calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		calls += 1
		return 0 if exclusive_upper_bound > 0 else -1


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_world_simulation_gate_ownership()
	await _test_rejected_establishment_is_transactional(tree)
	await _test_session_owned_encounter_freezes_and_thaws_same_world(tree)
	await _test_pause_is_independent_and_movement_requires_fresh_input(tree)
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_world_simulation_gate_ownership() -> void:
	var gate := WorldSimulationGate.new()
	_assert_true(gate.is_open(), "new world gate is open")
	_assert_false(gate.acquire(&""), "empty freeze owner is rejected")
	_assert_true(gate.acquire(&"encounter:a"), "first encounter acquires world gate")
	_assert_true(gate.is_frozen(), "acquired gate is frozen")
	_assert_eq(gate.freeze_owner_id(), &"encounter:a", "gate records exact owner")
	_assert_false(gate.acquire(&"encounter:b"), "second owner cannot replace active owner")
	_assert_false(gate.release(&"encounter:b"), "wrong owner cannot thaw world")
	_assert_true(gate.is_frozen(), "wrong release preserves freeze")
	_assert_true(gate.release(&"encounter:a"), "exact owner releases world gate")
	_assert_true(gate.is_open(), "released world gate is open")


func _test_rejected_establishment_is_transactional(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _instantiate_session(tree, 13_001, 13_002)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var gate: WorldSimulationGate = session.world_simulation_gate()
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var npc: NpcRuntimeState = outdoor.npc_runtimes()[0]
	var invalid: CombatEncounterStartResult = coordinator.start(CombatTrigger.new())
	_assert_eq(invalid.outcome, CombatEncounterStartResult.Outcome.INVALID_TRIGGER, "invalid trigger is rejected before world mutation")
	_assert_true(gate.is_open(), "invalid trigger leaves world open")
	var missing_candidates: Array[CombatTriggerCandidate] = [
		CombatTriggerCandidate.new(session.player_runtime().character_id, &"side:player"),
		CombatTriggerCandidate.new(&"missing.character", &"side:missing"),
	]
	var missing_trigger := CombatTrigger.new(
		&"cxr3.missing",
		CombatTriggerCause.Value.SCRIPTED,
		CombatEncounterMode.Value.SCRIPTED,
		session.player_runtime().character_id,
		missing_candidates,
		session.player_runtime().world_location(),
		&"cxr3.controlled_proof",
	)
	var missing: CombatEncounterStartResult = coordinator.start(missing_trigger)
	_assert_eq(missing.outcome, CombatEncounterStartResult.Outcome.PARTICIPANT_NOT_FOUND, "missing Session participant is rejected")
	_assert_true(gate.is_open(), "missing participant leaves world open")

	var unsupported: CombatEncounterStartResult = coordinator.start(
		_trigger(session, npc, CombatTriggerCause.Value.PLAYER_LETHAL_ATTACK)
	)
	_assert_eq(unsupported.outcome, CombatEncounterStartResult.Outcome.UNSUPPORTED_CAUSE, "production lethal trigger is explicitly deferred")
	_assert_false(coordinator.has_active_encounter(), "unsupported trigger publishes no encounter")
	_assert_true(gate.is_open(), "unsupported trigger leaves world open")

	var mismatched: CombatEncounterStartResult = coordinator.start(
		_trigger(session, npc, CombatTriggerCause.Value.SCRIPTED)
	)
	_assert_eq(mismatched.outcome, CombatEncounterStartResult.Outcome.LOCATION_MISMATCH, "different combat locations fail revalidation")
	_assert_true(gate.is_open(), "location failure leaves world open")

	_assert_true(session.player_runtime().set_world_location(npc.world_location()), "fixture aligns controlled scripted participants")
	var no_relationship: CombatEncounterStartResult = coordinator.start(
		_trigger(session, npc, CombatTriggerCause.Value.SCRIPTED)
	)
	_assert_eq(no_relationship.outcome, CombatEncounterStartResult.Outcome.RELATIONSHIP_TOPOLOGY_MISSING, "missing existing relationship topology is typed")
	_assert_true(gate.is_open(), "relationship failure leaves world open")

	_assert_true(session.player_runtime().relationship.add_opponent(npc.character_id), "fixture establishes one directed participant relationship")
	npc.set_combat_available(false)
	var unavailable: CombatEncounterStartResult = coordinator.start(
		_trigger(session, npc, CombatTriggerCause.Value.SCRIPTED)
	)
	_assert_eq(unavailable.outcome, CombatEncounterStartResult.Outcome.PARTICIPANT_UNAVAILABLE, "unavailable participant is rejected")
	_assert_true(gate.is_open(), "availability failure leaves world open")
	npc.set_combat_available(true)

	outdoor._initialized = false
	var freeze_failure: CombatEncounterStartResult = coordinator.start(
		_trigger(session, npc, CombatTriggerCause.Value.SCRIPTED)
	)
	outdoor._initialized = true
	_assert_eq(freeze_failure.outcome, CombatEncounterStartResult.Outcome.WORLD_FREEZE_FAILED, "map freeze commit failure is typed")
	_assert_false(coordinator.has_active_encounter(), "freeze failure publishes no encounter")
	_assert_true(gate.is_open(), "freeze failure rolls back acquired world gate")
	session.queue_free()
	await tree.process_frame


func _test_session_owned_encounter_freezes_and_thaws_same_world(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _instantiate_session(tree, 13_011, 13_012)
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var npc: NpcRuntimeState = outdoor.npc_runtimes()[0]
	_assert_true(player.set_world_location(npc.world_location()), "fixture aligns participant locations")
	_assert_true(player.relationship.add_opponent(npc.character_id), "fixture provides directed hostility fact")
	var player_opponents_before: Array[StringName] = player.relationship.opponent_ids()
	var npc_opponents_before: Array[StringName] = npc.relationship.opponent_ids()
	var session_identity: int = session.get_instance_id()
	var map_identity: int = outdoor.get_instance_id()
	var body_identity: int = outdoor.player_body.get_instance_id()
	var player_identity: int = player.get_instance_id()
	var player_state_identity: int = player.state.get_instance_id()
	var semantic_location_before: WorldLocationState = player.world_location()
	var physical_position_before: Vector2 = outdoor.player_body.global_position
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var random := CountingCombatRandomSource.new()
	_assert_true(session.configure_combat_random_source(random), "fixture installs observing combat RNG")
	var player_vitality_before: int = player.state.vitality.current
	var npc_vitality_before: int = npc.character_state.vitality.current
	outdoor.opportunity_timer.start(40.0)
	outdoor.aggression_adapter().enter_player_presence(npc, player, true)
	_assert_true(outdoor.aggression_adapter().pending_count() > 0, "fixture has pending aggression before freeze")

	var started: CombatEncounterStartResult = coordinator.start(
		_trigger(session, npc, CombatTriggerCause.Value.SCRIPTED)
	)
	_assert_true(started.succeeded(), "controlled scripted encounter starts")
	_assert_true(coordinator.has_active_encounter(), "Session coordinator owns one active encounter")
	var encounter: CombatEncounter = coordinator.active_encounter()
	_assert_eq(encounter.phase, CombatEncounterLifecycle.Value.ACTIVE, "encounter reaches ACTIVE")
	_assert_eq(encounter.events().size(), 1, "activation emits one establishment event")
	_assert_true(session.world_simulation_gate().is_frozen(), "encounter freezes world simulation")
	_assert_eq(session.world_simulation_gate().freeze_owner_id(), started.encounter_id, "freeze is owned by active encounter")
	_assert_true(outdoor.opportunity_timer.is_stopped(), "existing cadence timer is stopped")
	_assert_eq(outdoor.aggression_adapter().pending_count(), 0, "pending aggression is cleared rather than replayed")
	_assert_false(outdoor.select_npc(npc.character_id), "selection interaction is blocked while frozen")
	_assert_false(outdoor.open_player_inventory(), "inventory interaction is blocked while frozen")
	_assert_true(outdoor.process_cadence_tick().is_empty(), "manual cadence opportunity is blocked while frozen")
	_assert_eq(random.calls, 0, "frozen cadence consumes zero combat RNG")
	_assert_eq(player.state.vitality.current, player_vitality_before, "frozen cadence does not mutate player vitality")
	_assert_eq(npc.character_state.vitality.current, npc_vitality_before, "frozen cadence does not mutate NPC vitality")
	outdoor._on_cliffside_pine_exit_body_entered(outdoor.player_body)
	_assert_true(outdoor.last_cliffside_pine_traversal() == null, "frozen late portal contact is discarded")
	var blocked_handoff: OldPineMapHandoffResult = session.handoff_to(
		OldPineWorldDefinitions.CAVE_MAP_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.CAVE_VINE_LANDING_SPAWN_POINT_ID,
	)
	_assert_eq(blocked_handoff.outcome, OldPineMapHandoffResult.Outcome.WORLD_SIMULATION_FROZEN, "map handoff is blocked before mutation")
	_assert_eq(session.active_map_id(), OldPineWorldDefinitions.OUTDOOR_MAP_ID, "blocked handoff preserves active map")
	_assert_eq(session.get_instance_id(), session_identity, "freeze preserves Session identity")
	_assert_eq(outdoor.get_instance_id(), map_identity, "freeze preserves resident map identity")
	_assert_eq(outdoor.player_body.get_instance_id(), body_identity, "freeze preserves player body identity")
	_assert_true(encounter.has_directed_hostility(&"side:player", &"side:npc"), "relationship facts derive directed side hostility")
	_assert_false(encounter.has_directed_hostility(&"side:npc", &"side:player"), "missing reciprocal fact is not invented")
	var player_participant: CombatParticipant = encounter.participant_for(player.character_id)
	var npc_participant: CombatParticipant = encounter.participant_for(npc.character_id)
	_assert_true(player_participant.binding.state == player.state, "player binding uses exact CharacterState")
	_assert_true(player_participant.binding.relationship == player.relationship, "player binding uses exact relationship authority")
	_assert_true(player_participant.binding.busy == player.busy, "player binding uses exact busy authority")
	_assert_true(player_participant.binding.armor == player.armor, "player binding uses exact armor authority")
	_assert_true(npc_participant.binding.state == npc.character_state, "NPC binding uses exact CharacterState")
	_assert_true(npc_participant.binding.relationship == npc.relationship, "NPC binding uses exact relationship authority")

	var duplicate_start: CombatEncounterStartResult = coordinator.start(
		_trigger(session, npc, CombatTriggerCause.Value.SCRIPTED, &"cxr3.second")
	)
	_assert_eq(duplicate_start.outcome, CombatEncounterStartResult.Outcome.ENCOUNTER_ALREADY_ACTIVE, "second concurrent encounter is rejected")
	var wrong_kind := CombatEncounterResult.new(
		started.encounter_id,
		CombatEncounterMode.Value.SCRIPTED,
		CombatEncounterResultKind.Value.VICTORY,
	)
	var wrong_completion: CombatEncounterCompletionResult = coordinator.complete(wrong_kind)
	_assert_eq(wrong_completion.outcome, CombatEncounterCompletionResult.Outcome.RESULT_NOT_ALLOWED_FOR_MODE, "scripted encounter rejects lethal result kind")
	_assert_eq(encounter.phase, CombatEncounterLifecycle.Value.ACTIVE, "rejected result leaves encounter active")
	_assert_true(session.world_simulation_gate().is_frozen(), "rejected result leaves freeze owned")

	var completion: CombatEncounterCompletionResult = coordinator.complete(
		_scripted_result(started.encounter_id, player.character_id, npc.character_id)
	)
	_assert_true(completion.succeeded(), "typed scripted result completes encounter")
	_assert_eq(encounter.phase, CombatEncounterLifecycle.Value.COMPLETED, "encounter transitions through RESOLVING to COMPLETED")
	_assert_eq(encounter.events().size(), 3, "completion produces ordered establish/resolve/complete events")
	_assert_false(coordinator.has_active_encounter(), "completed encounter releases active binding")
	_assert_true(session.world_simulation_gate().is_open(), "completion thaws world")
	_assert_eq(session.get_instance_id(), session_identity, "thaw keeps exact Session")
	_assert_eq(session.active_map().get_instance_id(), map_identity, "thaw keeps exact resident map")
	_assert_eq(session.player_runtime().get_instance_id(), player_identity, "thaw keeps exact player runtime")
	_assert_eq(session.player_runtime().state.get_instance_id(), player_state_identity, "thaw keeps exact character authority")
	_assert_true(player.world_location().same_location(semantic_location_before), "encounter preserves semantic world location")
	_assert_eq(outdoor.player_body.global_position, physical_position_before, "encounter does not teleport physical body")
	_assert_eq(player.relationship.opponent_ids(), player_opponents_before, "encounter topology does not mutate player relationship facts")
	_assert_eq(npc.relationship.opponent_ids(), npc_opponents_before, "encounter topology does not invent NPC relationship facts")
	_assert_false(outdoor.opportunity_timer.is_stopped(), "previously running cadence is restored after thaw")
	_assert_true(outdoor.select_npc(npc.character_id), "normal interaction path reopens after completion")
	session.queue_free()
	await tree.process_frame


func _test_pause_is_independent_and_movement_requires_fresh_input(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = _instantiate_session(tree, 13_021, 13_022)
	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var npc: NpcRuntimeState = outdoor.npc_runtimes()[0]
	_assert_true(player.relationship.add_opponent(npc.character_id), "fixture establishes movement-test relation")
	var body: WorldCharacterBody2D = outdoor.player_body
	Input.action_press("move_right")
	await tree.physics_frame
	await tree.physics_frame
	var before_freeze: Vector2 = body.global_position
	_assert_true(npc.set_world_location(player.world_location()), "fixture aligns movement-test participants")
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var started: CombatEncounterStartResult = coordinator.start(
		_trigger(session, npc, CombatTriggerCause.Value.SCRIPTED)
	)
	_assert_true(started.succeeded(), "movement-test encounter starts")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(body.global_position, before_freeze, "held movement cannot move during encounter freeze")
	_assert_true(body.movement_input_quarantined(), "freeze quarantines held movement input")
	tree.paused = true
	_assert_true(coordinator.has_active_encounter(), "application pause does not end encounter")
	_assert_true(session.world_simulation_gate().is_frozen(), "application pause does not thaw world")
	tree.paused = false
	_assert_true(session.world_simulation_gate().is_frozen(), "application resume does not thaw encounter")
	var completion: CombatEncounterCompletionResult = coordinator.complete(
		_scripted_result(started.encounter_id, player.character_id, npc.character_id)
	)
	_assert_true(completion.succeeded(), "movement-test encounter completes")
	await tree.physics_frame
	await tree.physics_frame
	_assert_eq(body.global_position, before_freeze, "held pre-freeze input cannot leak across thaw")
	Input.action_release("move_right")
	await tree.physics_frame
	await tree.physics_frame
	_assert_false(body.movement_input_quarantined(), "full release rearms movement input")
	var before_fresh_press: Vector2 = body.global_position
	Input.action_press("move_right")
	await tree.physics_frame
	await tree.physics_frame
	Input.action_release("move_right")
	_assert_true(body.global_position.x > before_fresh_press.x, "fresh post-thaw press moves player")
	session.queue_free()
	await tree.process_frame


func _trigger(
	session: OldPineWorldSessionController,
	npc: NpcRuntimeState,
	cause: int,
	trigger_id: StringName = &"cxr3.scripted",
) -> CombatTrigger:
	var candidates: Array[CombatTriggerCandidate] = [
		CombatTriggerCandidate.new(session.player_runtime().character_id, &"side:player"),
		CombatTriggerCandidate.new(npc.character_id, &"side:npc"),
	]
	return CombatTrigger.new(
		trigger_id,
		cause,
		CombatEncounterMode.Value.SCRIPTED,
		session.player_runtime().character_id,
		candidates,
		session.player_runtime().world_location(),
		&"cxr3.controlled_proof",
	)


func _scripted_result(
	encounter_id: StringName,
	player_id: StringName,
	npc_id: StringName,
) -> CombatEncounterResult:
	var subjects: Array[StringName] = [player_id, npc_id]
	return CombatEncounterResult.new(
		encounter_id,
		CombatEncounterMode.Value.SCRIPTED,
		CombatEncounterResultKind.Value.SCRIPTED,
		[],
		[],
		subjects,
		&"cxr3.proof_completed",
	)


func _instantiate_session(
	tree: SceneTree,
	npc_seed: int,
	combat_seed: int,
) -> OldPineWorldSessionController:
	var session := SessionScene.instantiate() as OldPineWorldSessionController
	session.deterministic_npc_seed = true
	session.npc_seed = npc_seed
	session.deterministic_combat_seed = true
	session.combat_seed = combat_seed
	tree.root.add_child(session)
	return session


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [message, expected, actual])
