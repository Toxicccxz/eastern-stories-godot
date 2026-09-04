extends RefCounted

const SessionScene := preload(
	"res://scenes/world/oldpine/oldpine_world_session.tscn"
)

const ACTOR_ID: StringName = CombatSliceDemoFactory.PLAYER_ID
const TARGET_ID: StringName = CombatSliceDemoFactory.ENEMY_ID
const THIRD_ID: StringName = &"combat-slice-third"
const SIDE_A: StringName = &"side:a"
const SIDE_B: StringName = &"side:b"
const ENCOUNTER_ID: StringName = &"encounter:cxr4.fixture"

var _assertion_count: int = 0
var _failures: Array[String] = []

class SchedulerFixture extends RefCounted:
	var encounter: CombatEncounter
	var scheduler: CombatEncounterScheduler
	var bindings: Array[CombatSliceCharacterBinding] = []
	var random: ScriptedCombatRandomSource
	var effects: SkillImprovementEffectRegistry


class EncounterAttackFavoringRandomSource extends CombatRandomSource:
	var _calls: int = 0

	func next_below(exclusive_upper_bound: int) -> int:
		_calls += 1
		if exclusive_upper_bound <= 0:
			return -1
		## Encounter targeting removes the legacy random-opponent draw. Keep the
		## first three ordinary draws low, then favor failed defenses and damage.
		return 0 if _calls <= 3 else exclusive_upper_bound - 1

	func call_count() -> int:
		return _calls


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_scheduler_config_and_inert_boundaries()
	_test_due_opportunity_uses_exact_authorities()
	_test_existing_combat_mutates_exact_character_state()
	_test_delta_partition_is_deterministic()
	_test_seeded_rng_delta_partition_is_deterministic()
	_test_busy_and_application_pause_semantics()
	_test_stable_multi_participant_ordering()
	_test_stale_target_and_invalid_authority_fail_closed()
	_test_completed_encounter_is_inert()
	await _test_real_session_scheduler_world_freeze(tree)
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_scheduler_config_and_inert_boundaries() -> void:
	_assert_false(CombatSchedulerConfig.new().is_valid(), "zero interval is invalid")
	_assert_false(CombatSchedulerConfig.new(-1.0).is_valid(), "negative interval is invalid")
	_assert_true(CombatSchedulerConfig.new(1.0).is_valid(), "positive finite interval is valid")
	var random := ScriptedCombatRandomSource.new([0])
	var invalid := CombatEncounterScheduler.new()
	var result: CombatSchedulerAdvanceResult = invalid.advance(
		99.0,
		true,
		&"anything",
		[],
		random,
		SkillImprovementEffectRegistry.new(),
	)
	_assert_eq(result.outcome, CombatSchedulerAdvanceResult.Outcome.INERT, "missing encounter is inert")
	_assert_eq(random.call_count(), 0, "inert scheduler consumes no RNG")

	var fixture: SchedulerFixture = _fixture()
	var vitality_before: int = fixture.bindings[1].state.vitality.current
	var early: CombatSchedulerAdvanceResult = fixture.scheduler.advance(
		0.999,
		true,
		ENCOUNTER_ID,
		fixture.bindings,
		fixture.random,
		fixture.effects,
	)
	_assert_eq(early.outcome, CombatSchedulerAdvanceResult.Outcome.ADVANCED_NO_OPPORTUNITY, "sub-interval delta accumulates without opportunity")
	_assert_eq(fixture.random.call_count(), 0, "sub-interval delta consumes no RNG")
	_assert_eq(fixture.bindings[1].state.vitality.current, vitality_before, "sub-interval delta mutates no character")
	var wrong_gate: CombatSchedulerAdvanceResult = fixture.scheduler.advance(
		100.0,
		true,
		&"encounter:wrong",
		fixture.bindings,
		fixture.random,
		fixture.effects,
	)
	_assert_eq(wrong_gate.outcome, CombatSchedulerAdvanceResult.Outcome.WORLD_GATE_MISMATCH, "wrong freeze owner is inert")
	_assert_eq(fixture.random.call_count(), 0, "wrong freeze owner consumes no RNG")
	var bad_delta: CombatSchedulerAdvanceResult = fixture.scheduler.advance(
		-1.0,
		true,
		ENCOUNTER_ID,
		fixture.bindings,
		fixture.random,
		fixture.effects,
	)
	_assert_eq(bad_delta.outcome, CombatSchedulerAdvanceResult.Outcome.INVALID_DELTA, "negative delta is rejected")


func _test_due_opportunity_uses_exact_authorities() -> void:
	var fixture: SchedulerFixture = _fixture()
	var actor_state: CharacterState = fixture.encounter.participant_for(ACTOR_ID).binding.state
	var target_state: CharacterState = fixture.encounter.participant_for(TARGET_ID).binding.state
	var result: CombatSchedulerAdvanceResult = fixture.scheduler.advance(
		1.0,
		true,
		ENCOUNTER_ID,
		fixture.bindings,
		fixture.random,
		fixture.effects,
	)
	_assert_true(result.progressed(), "exact interval produces one logical cycle")
	_assert_eq(result.cycles_processed, 1, "one exact interval processes one cycle")
	_assert_eq(result.events().size(), 2, "one cycle visits both participants")
	_assert_eq(fixture.scheduler.logical_cycle, 1, "logical cycle increments exactly once")
	_assert_eq(fixture.scheduler.logical_time_seconds, 1.0, "logical time derives from cycle and injected interval")
	_assert_eq(fixture.encounter.current_target_for(ACTOR_ID), TARGET_ID, "first eligible hostile becomes actor target")
	_assert_eq(fixture.encounter.current_target_for(TARGET_ID), ACTOR_ID, "reverse side receives its own target")
	_assert_true(fixture.random.call_count() > 0, "real ordinary resolution consumes injected combat RNG")
	_assert_true(actor_state == fixture.bindings[0].state, "actor authority remains the exact encounter CharacterState")
	_assert_true(target_state == fixture.bindings[1].state, "target authority remains the exact encounter CharacterState")
	for event: CombatSchedulerEvent in result.events():
		_assert_true(event.is_valid(), "scheduler event is typed and valid")
		_assert_eq(event.logical_cycle, 1, "event carries logical cycle")
		_assert_eq(event.kind, CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED, "active participants resolve ordinary opportunities")
		_assert_true(event.resolution != null, "resolved event carries typed combat result")
	_assert_eq(
		fixture.random.call_count(),
		_sum_random_draws(result.events()),
		"event result evidence accounts for every combat RNG draw",
	)


func _test_existing_combat_mutates_exact_character_state() -> void:
	var fixture: SchedulerFixture = _fixture()
	fixture.random = ScriptedCombatRandomSource.new(_hit_then_zero_draws())
	var actor_state: CharacterState = fixture.encounter.participant_for(ACTOR_ID).binding.state
	var target_state: CharacterState = fixture.encounter.participant_for(TARGET_ID).binding.state
	var before: Array[Array] = [
		_combat_state_snapshot(actor_state),
		_combat_state_snapshot(target_state),
	]
	var result: CombatSchedulerAdvanceResult = fixture.scheduler.advance(
		1.0,
		true,
		ENCOUNTER_ID,
		fixture.bindings,
		fixture.random,
		fixture.effects,
	)
	_assert_true(result.progressed(), "source-derived HIT opportunity completes one scheduler cycle")
	_assert_eq(result.events()[0].kind, CombatSchedulerEvent.Kind.ORDINARY_OPPORTUNITY_RESOLVED, "HIT actor resolves through the ordinary opportunity executor")
	_assert_true(
		[
			_combat_state_snapshot(actor_state),
			_combat_state_snapshot(target_state),
		] != before,
		"existing combat core mutates an exact encounter CharacterState",
	)


func _test_delta_partition_is_deterministic() -> void:
	var fine: SchedulerFixture = _fixture()
	var coarse: SchedulerFixture = _fixture()
	for _index: int in range(60):
		fine.scheduler.advance(
			1.0 / 60.0,
			true,
			ENCOUNTER_ID,
			fine.bindings,
			fine.random,
			fine.effects,
		)
	for _index: int in range(10):
		coarse.scheduler.advance(
			0.1,
			true,
			ENCOUNTER_ID,
			coarse.bindings,
			coarse.random,
			coarse.effects,
		)
	_assert_eq(fine.scheduler.logical_cycle, 1, "60 frame slices produce one cycle")
	_assert_eq(coarse.scheduler.logical_cycle, 1, "10 coarse slices produce one cycle")
	_assert_eq(_event_signatures(fine.scheduler.events()), _event_signatures(coarse.scheduler.events()), "delta partitions produce identical event order/results")
	_assert_eq(fine.random.requested_bounds(), coarse.random.requested_bounds(), "delta partitions consume identical RNG calls in order")
	_assert_eq(_bindings_state_snapshot(fine.bindings), _bindings_state_snapshot(coarse.bindings), "delta partitions produce identical character state")


func _test_seeded_rng_delta_partition_is_deterministic() -> void:
	var fine: SchedulerFixture = _fixture()
	var coarse: SchedulerFixture = _fixture()
	var fine_random := GodotCombatRandomSource.new(40_404, true)
	var coarse_random := GodotCombatRandomSource.new(40_404, true)
	for _index: int in range(60):
		fine.scheduler.advance(
			1.0 / 60.0,
			true,
			ENCOUNTER_ID,
			fine.bindings,
			fine_random,
			fine.effects,
		)
	for _index: int in range(10):
		coarse.scheduler.advance(
			0.1,
			true,
			ENCOUNTER_ID,
			coarse.bindings,
			coarse_random,
			coarse.effects,
		)
	_assert_eq(_event_signatures(fine.scheduler.events()), _event_signatures(coarse.scheduler.events()), "same seeded RNG preserves event order across delta partitions")
	_assert_eq(_event_random_timelines(fine.scheduler.events()), _event_random_timelines(coarse.scheduler.events()), "same seeded RNG preserves exact combat draw timeline across delta partitions")
	_assert_eq(_bindings_state_snapshot(fine.bindings), _bindings_state_snapshot(coarse.bindings), "same seeded RNG preserves exact character result across delta partitions")


func _test_busy_and_application_pause_semantics() -> void:
	var busy_fixture: SchedulerFixture = _fixture(false, false)
	busy_fixture.bindings[0].busy.start_busy(1)
	var busy: CombatSchedulerAdvanceResult = busy_fixture.scheduler.advance(
		1.0,
		true,
		ENCOUNTER_ID,
		busy_fixture.bindings,
		busy_fixture.random,
		busy_fixture.effects,
	)
	_assert_eq(busy_fixture.bindings[0].busy.busy_value, 0, "busy advances exactly once on actor opportunity")
	_assert_eq(busy.events()[0].resolution.outcome, CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED, "busy actor does not execute ordinary attack")
	_assert_eq(busy_fixture.random.call_count(), 0, "busy plus non-hostile reverse side consumes zero RNG")
	var next: CombatSchedulerAdvanceResult = busy_fixture.scheduler.advance(
		1.0,
		true,
		ENCOUNTER_ID,
		busy_fixture.bindings,
		busy_fixture.random,
		busy_fixture.effects,
	)
	_assert_true(next.progressed(), "actor receives next opportunity after busy clears")
	_assert_true(busy_fixture.random.call_count() > 0, "post-busy ordinary action uses combat RNG")

	var paused: SchedulerFixture = _fixture()
	var paused_result: CombatSchedulerAdvanceResult = paused.scheduler.advance(
		30.0,
		false,
		ENCOUNTER_ID,
		paused.bindings,
		paused.random,
		paused.effects,
	)
	_assert_eq(paused_result.outcome, CombatSchedulerAdvanceResult.Outcome.APPLICATION_PAUSED, "application pause blocks scheduler")
	_assert_eq(paused.scheduler.logical_cycle, 0, "paused elapsed wall time is not accumulated")
	_assert_eq(paused.random.call_count(), 0, "application pause consumes zero RNG")
	paused.scheduler.advance(0.999, true, ENCOUNTER_ID, paused.bindings, paused.random, paused.effects)
	_assert_eq(paused.scheduler.logical_cycle, 0, "resume continues from prior remainder without catch-up")
	paused.scheduler.advance(0.001, true, ENCOUNTER_ID, paused.bindings, paused.random, paused.effects)
	_assert_eq(paused.scheduler.logical_cycle, 1, "only fresh foreground delta reaches opportunity")


func _test_stable_multi_participant_ordering() -> void:
	var fixture: SchedulerFixture = _fixture(true)
	var result: CombatSchedulerAdvanceResult = fixture.scheduler.advance(
		1.0,
		true,
		ENCOUNTER_ID,
		fixture.bindings,
		fixture.random,
		fixture.effects,
	)
	var events: Array[CombatSchedulerEvent] = result.events()
	_assert_eq(events.size(), 3, "three-participant cycle visits every participant")
	_assert_eq([events[0].actor_id, events[1].actor_id, events[2].actor_id], [ACTOR_ID, TARGET_ID, THIRD_ID], "same-cycle actor order follows stable encounter participant order")
	_assert_eq(events[0].target_id, TARGET_ID, "side-A actor deterministically chooses first eligible side-B participant")
	_assert_eq(events[1].target_id, ACTOR_ID, "first side-B participant targets side A")
	_assert_eq(events[2].target_id, ACTOR_ID, "second side-B participant independently targets side A")
	for index: int in range(events.size()):
		_assert_eq(events[index].sequence, index + 1, "scheduler sequence is monotonic across participant collection")


func _test_stale_target_and_invalid_authority_fail_closed() -> void:
	var stale: SchedulerFixture = _fixture(false)
	_assert_true(stale.encounter.set_current_target(ACTOR_ID, TARGET_ID), "fixture installs semantic current target")
	stale.bindings[1].set_combat_available(false)
	var stale_result: CombatSchedulerAdvanceResult = stale.scheduler.advance(
		1.0,
		true,
		ENCOUNTER_ID,
		stale.bindings,
		stale.random,
		stale.effects,
	)
	_assert_eq(stale_result.events()[0].skip_reason, CombatSchedulerEvent.SkipReason.TARGET_UNAVAILABLE, "stale current target fails closed")
	_assert_eq(stale.encounter.current_target_for(ACTOR_ID), TARGET_ID, "stale target is not silently replaced")
	_assert_eq(stale.random.call_count(), 0, "stale target consumes no RNG")

	var invalid: SchedulerFixture = _fixture()
	var incomplete: Array[CombatSliceCharacterBinding] = [invalid.bindings[0]]
	var invalid_result: CombatSchedulerAdvanceResult = invalid.scheduler.advance(
		10.0,
		true,
		ENCOUNTER_ID,
		incomplete,
		invalid.random,
		invalid.effects,
	)
	_assert_eq(invalid_result.outcome, CombatSchedulerAdvanceResult.Outcome.AUTHORITY_INVALID, "missing live authority projection fails closed")
	_assert_eq(invalid.scheduler.logical_cycle, 0, "invalid projection accumulates no combat time")
	_assert_eq(invalid.random.call_count(), 0, "invalid projection consumes no RNG")


func _test_completed_encounter_is_inert() -> void:
	var fixture: SchedulerFixture = _fixture()
	_assert_true(fixture.encounter.begin_resolving(), "fixture enters resolving")
	_assert_true(fixture.encounter.complete(_scripted_result()), "fixture completes with typed result")
	var state_before: Array[Array] = _bindings_state_snapshot(fixture.bindings)
	var result: CombatSchedulerAdvanceResult = fixture.scheduler.advance(
		100.0,
		true,
		ENCOUNTER_ID,
		fixture.bindings,
		fixture.random,
		fixture.effects,
	)
	_assert_eq(result.outcome, CombatSchedulerAdvanceResult.Outcome.INERT, "completed encounter scheduler is inert")
	_assert_eq(fixture.random.call_count(), 0, "completed scheduler consumes no RNG")
	_assert_eq(_bindings_state_snapshot(fixture.bindings), state_before, "completed scheduler mutates no CharacterState")
	_assert_true(fixture.scheduler.events().is_empty(), "completed scheduler emits no progression events")


func _test_real_session_scheduler_world_freeze(tree: SceneTree) -> void:
	var session := SessionScene.instantiate() as OldPineWorldSessionController
	session.deterministic_npc_seed = true
	session.npc_seed = 14_001
	session.deterministic_combat_seed = true
	session.combat_seed = 14_002
	tree.root.add_child(session)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var no_encounter_rng := EncounterAttackFavoringRandomSource.new()
	_assert_true(session.configure_combat_random_source(no_encounter_rng), "real Session accepts deterministic combat RNG")
	_assert_eq(coordinator.advance_scheduler(10.0).outcome, CombatSchedulerAdvanceResult.Outcome.INERT, "Session drive is inert without encounter")
	_assert_eq(no_encounter_rng.call_count(), 0, "no-encounter Session drive consumes no RNG")

	var outdoor: OldPineOutdoorController = session.outdoor_map()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var npc: NpcRuntimeState = outdoor.npc_runtimes()[0]
	_assert_true(player.set_world_location(npc.world_location()), "fixture aligns real Session participants")
	_assert_true(player.relationship.add_opponent(npc.character_id), "player relationship supports controlled encounter")
	_assert_true(npc.relationship.add_opponent(player.character_id), "NPC relationship supports reverse ordinary opportunity")
	var started: CombatEncounterStartResult = coordinator.start(_session_trigger(session, npc))
	_assert_true(started.succeeded(), "controlled real Session encounter starts")
	_assert_true(session.world_simulation_gate().is_frozen(), "real world is encounter-frozen")
	_assert_true(outdoor.opportunity_timer.is_stopped(), "legacy OpportunityTimer remains stopped")
	var scheduler: CombatEncounterScheduler = coordinator.active_scheduler()
	_assert_true(scheduler != null and scheduler.is_valid(), "coordinator owns active scheduler")
	var player_state: CharacterState = player.state
	var npc_state: CharacterState = npc.character_state
	var before: Array[Array] = [_combat_state_snapshot(player_state), _combat_state_snapshot(npc_state)]
	var early: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(0.5)
	_assert_eq(early.outcome, CombatSchedulerAdvanceResult.Outcome.ADVANCED_NO_OPPORTUNITY, "real Session half interval does not attack")
	_assert_eq(no_encounter_rng.call_count(), 0, "real Session half interval consumes no RNG")
	var due: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(0.5)
	_assert_true(due.progressed(), "scheduler progresses inside frozen real Session")
	_assert_true(no_encounter_rng.call_count() > 0, "real Session opportunity uses Session-owned RNG")
	_assert_true([_combat_state_snapshot(player_state), _combat_state_snapshot(npc_state)] != before, "real bound CharacterState receives combat mutation")
	_assert_true(outdoor.opportunity_timer.is_stopped(), "legacy cadence never runs beside scheduler")

	var event_count_before_pause: int = scheduler.events().size()
	tree.paused = true
	var paused: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(20.0)
	_assert_eq(paused.outcome, CombatSchedulerAdvanceResult.Outcome.APPLICATION_PAUSED, "SceneTree application pause is observed at runtime boundary")
	_assert_eq(scheduler.events().size(), event_count_before_pause, "application pause emits no scheduler event")
	tree.paused = false
	_assert_true(session.world_simulation_gate().is_frozen(), "application resume does not thaw encounter world")
	var completion: CombatEncounterCompletionResult = coordinator.complete(
		CombatEncounterResult.new(
			started.encounter_id,
			CombatEncounterMode.Value.SCRIPTED,
			CombatEncounterResultKind.Value.SCRIPTED,
			[],
			[],
			[player.character_id, npc.character_id] as Array[StringName],
			&"cxr4.test_complete",
		)
	)
	_assert_true(completion.succeeded(), "real Session encounter completes")
	_assert_true(coordinator.active_scheduler() == null, "coordinator releases scheduler with encounter")
	_assert_true(session.world_simulation_gate().is_open(), "same world thaws after completion")
	var calls_after_complete: int = no_encounter_rng.call_count()
	_assert_eq(coordinator.advance_scheduler(20.0).outcome, CombatSchedulerAdvanceResult.Outcome.INERT, "coordinator is inert after completion")
	_assert_eq(no_encounter_rng.call_count(), calls_after_complete, "post-completion drive consumes no RNG")
	session.queue_free()
	await tree.process_frame


func _fixture(include_third: bool = false, symmetric: bool = true) -> SchedulerFixture:
	var fixture := SchedulerFixture.new()
	fixture.bindings = [
		CombatSliceDemoFactory.create_player(),
		CombatSliceDemoFactory.create_enemy(),
	]
	if include_third:
		fixture.bindings.append(_third_binding())
	fixture.bindings[0].relationship.add_opponent(TARGET_ID)
	if include_third:
		fixture.bindings[0].relationship.add_opponent(THIRD_ID)
	if symmetric:
		fixture.bindings[1].relationship.add_opponent(ACTOR_ID)
		if include_third:
			fixture.bindings[2].relationship.add_opponent(ACTOR_ID)
	var participants: Array[CombatParticipant] = []
	var candidates: Array[CombatTriggerCandidate] = []
	for index: int in range(fixture.bindings.size()):
		var binding: CombatSliceCharacterBinding = fixture.bindings[index]
		var side_id: StringName = SIDE_A if index == 0 else SIDE_B
		participants.append(
			CombatParticipant.new(
				binding.character_id,
				side_id,
				CombatEncounterAuthorityBinding.new(
					binding.character_id,
					binding.state,
					binding.relationship,
					binding.busy,
					binding.armor,
				),
			)
		)
		candidates.append(CombatTriggerCandidate.new(binding.character_id, side_id))
	var hostilities: Array[CombatDirectedHostility] = [
		CombatDirectedHostility.new(SIDE_A, SIDE_B),
	]
	if symmetric:
		hostilities.append(CombatDirectedHostility.new(SIDE_B, SIDE_A))
	var trigger := CombatTrigger.new(
		&"cxr4.fixture",
		CombatTriggerCause.Value.SCRIPTED,
		CombatEncounterMode.Value.SCRIPTED,
		ACTOR_ID,
		candidates,
		WorldLocationState.new(&"test", &"arena", &"arena", CombatSliceDemoFactory.ARENA_ID),
		&"cxr4.scheduler_test",
	)
	fixture.encounter = CombatEncounter.new(
		ENCOUNTER_ID,
		trigger,
		participants,
		hostilities,
	)
	fixture.encounter.activate()
	fixture.scheduler = CombatEncounterScheduler.new(
		fixture.encounter,
		CombatSchedulerConfig.new(1.0),
	)
	fixture.random = ScriptedCombatRandomSource.new(_zero_draws())
	fixture.effects = SkillImprovementEffectRegistry.new()
	fixture.effects.register_legacy_defaults()
	return fixture


func _third_binding() -> CombatSliceCharacterBinding:
	var source: CombatSliceCharacterBinding = CombatSliceDemoFactory.create_enemy()
	return CombatSliceCharacterBinding.new(
		THIRD_ID,
		source.state,
		CombatRelationshipState.new(THIRD_ID),
		source.busy,
		source.armor,
		source.content,
		source.location_id,
		true,
		CombatSliceLifeStatus.Value.ACTIVE,
		false,
		true,
	)


func _session_trigger(
	session: OldPineWorldSessionController,
	npc: NpcRuntimeState,
) -> CombatTrigger:
	return CombatTrigger.new(
		&"cxr4.session",
		CombatTriggerCause.Value.SCRIPTED,
		CombatEncounterMode.Value.SCRIPTED,
		session.player_runtime().character_id,
		[
			CombatTriggerCandidate.new(session.player_runtime().character_id, &"side:player"),
			CombatTriggerCandidate.new(npc.character_id, &"side:npc"),
		] as Array[CombatTriggerCandidate],
		session.player_runtime().world_location(),
		&"cxr4.controlled_proof",
	)


func _scripted_result() -> CombatEncounterResult:
	return CombatEncounterResult.new(
		ENCOUNTER_ID,
		CombatEncounterMode.Value.SCRIPTED,
		CombatEncounterResultKind.Value.SCRIPTED,
		[],
		[],
		[ACTOR_ID, TARGET_ID] as Array[StringName],
		&"cxr4.fixture_complete",
	)


func _zero_draws() -> Array[int]:
	var result: Array[int] = []
	result.resize(512)
	result.fill(0)
	return result


func _hit_then_zero_draws() -> Array[int]:
	## The encounter supplies the semantic target, so the ordinary-opportunity
	## timeline starts at fight selection rather than random opponent selection.
	## These first five source-derived draws force the same HIT path covered by
	## combat_slice_opportunity_integration_test; remaining draws stay valid zero.
	var result: Array[int] = _zero_draws()
	result[3] = 10
	result[4] = 10
	return result


func _combat_state_snapshot(state: CharacterState) -> Array[int]:
	return [
		state.essence.current,
		state.essence.effective,
		state.vitality.current,
		state.vitality.effective,
		state.spirit.current,
		state.spirit.effective,
		state.progression.combat_experience,
	]


func _bindings_state_snapshot(
	bindings: Array[CombatSliceCharacterBinding],
) -> Array[Array]:
	var result: Array[Array] = []
	for binding: CombatSliceCharacterBinding in bindings:
		result.append(_combat_state_snapshot(binding.state))
	return result


func _event_signatures(events: Array[CombatSchedulerEvent]) -> Array[Array]:
	var result: Array[Array] = []
	for event: CombatSchedulerEvent in events:
		result.append([
			event.sequence,
			event.logical_cycle,
			event.kind,
			event.skip_reason,
			event.actor_id,
			event.target_id,
			-1 if event.resolution == null else event.resolution.outcome,
		])
	return result


func _sum_random_draws(events: Array[CombatSchedulerEvent]) -> int:
	var total: int = 0
	for event: CombatSchedulerEvent in events:
		if event.resolution != null:
			total += event.resolution.random_draws().size()
	return total


func _event_random_timelines(events: Array[CombatSchedulerEvent]) -> Array[Array]:
	var result: Array[Array] = []
	for event: CombatSchedulerEvent in events:
		result.append(
			[]
			if event.resolution == null
			else [
				event.resolution.random_upper_bounds(),
				event.resolution.random_draws(),
			]
		)
	return result


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [message, expected, actual])
