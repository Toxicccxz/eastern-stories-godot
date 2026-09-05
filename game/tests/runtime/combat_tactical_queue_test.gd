extends RefCounted

const Fixtures := preload("res://tests/runtime/combat_encounter_scheduler_test.gd")
const Probe := preload("res://tests/support/cxr5_probe_policy.gd")
const Code := CombatTacticalResult.Code
const Kind := CombatTacticalEvent.Kind
const Category := CombatTacticalRequest.Category
const Target := CombatTacticalRequest.TargetRule
const Status := CombatQueuedAction.Status
const PLAYER: StringName = Fixtures.ACTOR_ID
const ENEMY: StringName = Fixtures.TARGET_ID
const THIRD: StringName = Fixtures.THIRD_ID
const ID: StringName = Fixtures.ENCOUNTER_ID

var _assertions: int = 0
var _failures: Array[String] = []

class RequestOnlyProbe extends Probe:
	func validate_execution(_context: CombatTacticalContext) -> int:
		return Code.PREREQUISITE_FAILED

class BusyProbe extends Probe:
	func execute(context: CombatTacticalContext, random_source: CombatRandomSource) -> CombatTacticalExecutionResult:
		var result: CombatTacticalExecutionResult = super.execute(context, random_source)
		context.actor.busy.start_busy(2)
		return result


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_requests_and_registry()
	_test_one_slot_and_execution()
	_test_replace_cancel_and_duplicate()
	_test_busy_pause_and_order()
	_test_revalidation()
	_test_targets_and_authorities()
	_test_empty_queue_and_delta_partition()
	_test_completion_and_execution_failure()
	_test_additional_boundary_safety()
	await _test_real_session(tree)
	return {"assertions": _assertions, "failures": _failures}


func _fixture() -> Fixtures.SchedulerFixture:
	var f: Fixtures.SchedulerFixture = Fixtures.new()._fixture(true)
	var registry := CombatTacticalActionRegistry.new()
	registry.register_policy(Probe.new())
	registry.register_policy(Probe.new(&"qa.current", Target.CURRENT_HOSTILE))
	registry.register_policy(Probe.new(&"qa.self", Target.SELF))
	registry.register_policy(Probe.new(&"qa.none", Target.NONE))
	registry.register_policy(Probe.new(&"qa.fail", Target.NONE, Category.FLEE, true, true))
	registry.register_policy(Probe.new(&"qa.item", Target.NONE, Category.ITEM, false))
	f.scheduler.configure_player_tactics(PLAYER, registry)
	Probe.prepare(f.bindings[0].state)
	f.encounter.set_current_target(PLAYER, ENEMY)
	return f


func _request(
	id: StringName = &"A", action: StringName = &"qa.probe",
	target: StringName = THIRD, actor: StringName = PLAYER,
	category: int = Category.MARTIAL_SPECIAL,
) -> CombatTacticalRequest:
	return CombatTacticalRequest.new(id, ID, actor, action, category, target)


func _submit(f: Fixtures.SchedulerFixture, request: CombatTacticalRequest) -> CombatTacticalResult:
	return f.scheduler.player_tactics().submit(request, true, ID, f.bindings)


func _advance(f: Fixtures.SchedulerFixture, delta: float = 0.0, active: bool = true) -> CombatSchedulerAdvanceResult:
	return f.scheduler.advance(delta, active, ID, f.bindings, f.random, f.effects)


func _force(f: Fixtures.SchedulerFixture) -> int:
	return f.bindings[0].state.recovery.inner_force.current


func _test_requests_and_registry() -> void:
	_check(not CombatTacticalRequest.new().is_valid(), "empty request rejected")
	for category: int in Category.values():
		_check(_request(&"A", &"action", THIRD, PLAYER, category).is_valid(), "six categories structural only")
	_check(not _request(&"A", &"action", THIRD, PLAYER, 99).is_valid(), "unknown category invalid")
	var registry := CombatTacticalActionRegistry.new()
	_check(registry.find(&"force") == null, "production registry has no invented force action")
	_check(not registry.register_policy(CombatTacticalActionPolicy.new()), "invalid policy rejected")
	_check(registry.register_policy(Probe.new()), "typed explicit registration")
	_check(not registry.register_policy(Probe.new()), "duplicate policy cannot replace behavior")
	var f: Fixtures.SchedulerFixture = _fixture()
	_eq(_submit(f, _request(&"unknown", &"force")).code, Code.UNKNOWN_ACTION, "unknown production action")
	_eq(_submit(f, _request(&"wrong-category", &"qa.probe", THIRD, PLAYER, Category.SPELL)).code, Code.CATEGORY_MISMATCH, "category must match registration")
	_eq(_submit(f, _request(&"npc", &"qa.probe", PLAYER, ENEMY)).code, Code.NOT_PLAYER, "NPC cannot submit player intent")
	_eq(_submit(f, CombatTacticalRequest.new(&"foreign", &"other", PLAYER, &"qa.probe", Category.MARTIAL_SPECIAL, THIRD)).code, Code.INACTIVE, "wrong encounter")
	_eq(f.scheduler.player_tactics().submit(_request(&"paused"), false, ID, f.bindings).code, Code.APPLICATION_BLOCKED, "paused request rejected")
	_eq(f.scheduler.player_tactics().submit(_request(&"gate"), true, &"wrong", f.bindings).code, Code.WORLD_GATE_MISMATCH, "gate rechecked at input")
	_eq(f.random.call_count(), 0, "all rejected validation RNG-free")
	_eq(_force(f), 10, "all rejected validation cost-free")
	_check(f.encounter.queued_player_action() == null, "no rejected input occupies slot")
	var raw := CombatTacticalActionRegistry.new()
	raw.register_policy(CombatTacticalActionPolicy.new(&"deferred", Category.SPELL, Target.NONE))
	var base: Fixtures.SchedulerFixture = Fixtures.new()._fixture()
	base.scheduler.configure_player_tactics(PLAYER, raw)
	_eq(_submit(base, _request(&"deferred", &"deferred", &"", PLAYER, Category.SPELL)).code, Code.POLICY_UNSUPPORTED, "base/deferred policy never silently succeeds")


func _test_one_slot_and_execution() -> void:
	var f: Fixtures.SchedulerFixture = _fixture()
	var request: CombatTacticalRequest = _request()
	var accepted: CombatTacticalResult = _submit(f, request)
	_eq(accepted.code, Code.ACCEPTED, "valid request accepted")
	_eq(accepted.sequence, 1, "monotonic internal sequence starts at one")
	_eq(_force(f), 10, "submit is NOT synchronous execution")
	_eq(f.random.call_count(), 0, "submit consumes zero RNG")
	_eq(f.scheduler.player_tactics().queue_status(), Status.READY, "free actor queued READY")
	var snapshot: CombatQueuedAction = f.encounter.queued_player_action()
	_check(snapshot.request != request, "request copied into queue")
	_check(snapshot != f.encounter.queued_player_action(), "defensive queue snapshot")
	snapshot._resolved_target_id = ENEMY
	_eq(f.encounter.queued_player_action().resolved_target_id, THIRD, "snapshot mutation cannot change target")
	_advance(f)
	_eq(_force(f), 9, "next valid zero-delta boundary executes once")
	_eq(f.random.call_count(), 1, "execution alone draws exactly one QA RNG")
	_eq(f.bindings[2].state.recovery.atman.current, 1, "exact explicit Enemy2 authority mutated")
	_eq(f.bindings[1].state.recovery.atman.current, 0, "Enemy1 not substituted")
	_check(f.encounter.participant_for(PLAYER).binding.state == f.bindings[0].state, "exact actor object")
	_check(f.encounter.participant_for(THIRD).binding.state == f.bindings[2].state, "exact target object")
	_check(f.encounter.queued_player_action() == null, "slot consumed before/after execute")
	_advance(f)
	_eq(_force(f), 9, "another boundary does not repeat execution")
	_eq(_submit(f, request).code, Code.DUPLICATE_REQUEST, "completed request ID cannot execute twice")
	_eq(_count(f, Kind.EXECUTION_STARTED), 1, "one started event")
	_eq(_count(f, Kind.RESOLVED), 1, "one result event")
	_eq(f.scheduler.player_tactics().events()[-1].execution.effect_id, &"qa.applied", "typed semantic effect")
	var independent: Fixtures.SchedulerFixture = _fixture()
	_eq(_force(independent), 10, "independent state untouched")
	_eq(_submit(independent, _request()).sequence, 1, "independent request namespace")
	_eq(independent.random.call_count(), 0, "independent RNG untouched")


func _test_replace_cancel_and_duplicate() -> void:
	var f: Fixtures.SchedulerFixture = _fixture()
	_submit(f, _request())
	_eq(_submit(f, _request()).code, Code.DUPLICATE_REQUEST, "pending duplicate rejected")
	_eq(_submit(f, _request(&"bad", &"missing")).code, Code.UNKNOWN_ACTION, "invalid replacement fails")
	_eq(f.encounter.queued_player_action().request.request_id, &"A", "invalid replacement preserves old slot")
	_eq(f.encounter.queued_player_action().sequence, 1, "invalid replacement preserves sequence")
	_eq(_submit(f, _request(&"B")).sequence, 3, "rejection has ordered sequence; duplicate doesn't allocate")
	_eq(f.encounter.queued_player_action().request.request_id, &"B", "valid B replaces A")
	_eq(f.scheduler.player_tactics().cancel(&"A", true, ID).code, Code.STALE_CANCEL, "stale cancel cannot erase B")
	_eq(_submit(f, _request()).code, Code.DUPLICATE_REQUEST, "replaced A tombstone retained")
	_advance(f)
	_eq(_force(f), 9, "only B executed")
	_eq(_count(f, Kind.REPLACED), 1, "single replaced event")
	_submit(f, _request(&"C"))
	_eq(f.scheduler.player_tactics().cancel(&"C", true, ID).code, Code.CANCELLED, "explicit current cancel")
	_eq(f.scheduler.player_tactics().cancel(&"C", true, ID).code, Code.STALE_CANCEL, "cancel cannot repeat")
	_advance(f)
	_eq(_force(f), 9, "cancelled C never executes")
	_eq(f.random.call_count(), 1, "replace and cancel RNG-free")
	var previous: int = 0
	for event: CombatTacticalEvent in f.scheduler.player_tactics().events():
		_check(event.progression_order > previous, "tactical order strictly increasing")
		previous = event.progression_order


func _test_busy_pause_and_order() -> void:
	var f: Fixtures.SchedulerFixture = _fixture()
	f.bindings[0].busy.start_busy(2)
	_submit(f, _request())
	_eq(f.scheduler.player_tactics().queue_status(), Status.WAITING_FOR_BUSY, "busy accepted into SAME slot")
	var event_count: int = f.scheduler.player_tactics().events().size()
	_advance(f, 100.0, false)
	_eq(f.bindings[0].busy.busy_value, 2, "pause does not decrement busy")
	_eq(f.scheduler.logical_cycle, 0, "pause does not accumulate")
	_eq(f.random.call_count(), 0, "pause RNG-free")
	_eq(f.scheduler.player_tactics().events().size(), event_count, "pause emits no action events")
	_check(f.encounter.queued_player_action() != null, "pause preserves queue")
	_advance(f, 1.0)
	_eq(f.bindings[0].busy.busy_value, 1, "first ordinary opportunity decrements 2 to 1")
	_eq(_count(f, Kind.RESOLVED), 0, "busy actor cannot execute")
	_check(f.scheduler.events().size() == 3, "other participants still get ordinary opportunities")
	_advance(f, 1.0)
	_eq(f.bindings[0].busy.busy_value, 0, "second ordinary opportunity decrements 1 to 0")
	_eq(_count(f, Kind.RESOLVED), 0, "clearing busy opportunity already consumed")
	_check(f.encounter.queued_player_action() != null, "queue remains until NEXT boundary")
	_eq(f.scheduler.logical_cycle, 2, "resume has no catchup")
	var before: int = _force(f)
	_advance(f)
	_eq(_force(f), before - 1, "following boundary executes queued action")
	_eq(_count(f, Kind.RESOLVED), 1, "exactly one queued busy execution")
	var result_order: int = f.scheduler.player_tactics().events()[-1].progression_order
	_check(result_order > f.scheduler.events()[-1].progression_order, "execution after consumed busy cycles")
	_submit(f, _request(&"B"))
	_advance(f, 1.0)
	result_order = f.scheduler.player_tactics().events()[-1].progression_order
	_check(result_order < f.scheduler.events()[-3].progression_order, "tactical result before same-call ordinary cycles")
	var item: Fixtures.SchedulerFixture = _fixture()
	item.bindings[0].busy.start_busy(2)
	_submit(item, _request(&"item", &"qa.item", &"", PLAYER, Category.ITEM))
	_advance(item)
	_eq(_force(item), 9, "test-only ITEM explicit policy can bypass busy")
	_eq(item.bindings[0].busy.busy_value, 2, "item exception does not advance busy itself")


func _test_revalidation() -> void:
	for invalidation: int in range(11):
		var f: Fixtures.SchedulerFixture = _fixture()
		_submit(f, _request())
		match invalidation:
			0: f.bindings[0].state.recovery.inner_force.current = 0
			1: f.bindings[0].state.skills.unmap_skill(&"qa.use")
			2: f.bindings[0].state.skills.set_raw_level(&"qa.tactical", 0)
			3: f.bindings[0].state.equipment.unwield(f.bindings[0].state.equipment.primary_weapon().instance_id)
			4: f.bindings[2].set_combat_available(false)
			5: f.bindings[2].set_exists_in_encounter(false)
			6: f.bindings[2].set_location_id(&"elsewhere")
			7: f.bindings[0].set_combat_available(false)
			8: f.bindings[0].relationship.remove_opponent(THIRD)
			9: f.bindings[2].set_life_status(CombatSliceLifeStatus.Value.DEAD)
			10: f.bindings[0].set_life_status(CombatSliceLifeStatus.Value.UNCONSCIOUS)
		var before: int = _force(f)
		_advance(f)
		_eq(_force(f), before, "failed revalidation cost-free %d" % invalidation)
		_eq(f.random.call_count(), 0, "failed revalidation RNG-free %d" % invalidation)
		_check(f.encounter.queued_player_action() == null, "invalid action cancelled %d" % invalidation)
		_eq(_count(f, Kind.CANCELLED), 1, "typed cancellation %d" % invalidation)
		_eq(_count(f, Kind.EXECUTION_STARTED), 0, "invalidated action never starts %d" % invalidation)
		_eq(f.scheduler.events().size(), 0, "no ordinary attack substitution %d" % invalidation)
	var f: Fixtures.SchedulerFixture = _fixture()
	_submit(f, _request())
	f.scheduler.advance(100.0, true, &"wrong", f.bindings, f.random, f.effects)
	f.scheduler.advance(-1.0, true, ID, f.bindings, f.random, f.effects)
	f.scheduler.advance(1.0, true, ID, [f.bindings[0]], f.random, f.effects)
	_eq(_count(f, Kind.EXECUTION_STARTED), 0, "invalid scheduler gates are not command boundaries")
	_check(f.encounter.queued_player_action() != null, "invalid advance preserves request")
	_eq(f.random.call_count(), 0, "invalid advance uses zero RNG")


func _test_targets_and_authorities() -> void:
	var f: Fixtures.SchedulerFixture = _fixture()
	_submit(f, _request(&"current", &"qa.current", &""))
	_eq(f.encounter.queued_player_action().resolved_target_id, ENEMY, "CURRENT resolves at acceptance")
	f.encounter.set_current_target(PLAYER, THIRD)
	_advance(f)
	_eq(f.bindings[1].state.recovery.atman.current, 1, "queued current retains concrete Enemy1")
	_eq(f.bindings[2].state.recovery.atman.current, 0, "later target selection never redirects")
	_eq(_submit(f, _request(&"invalid", &"qa.probe", PLAYER)).code, Code.TARGET_INVALID, "hostile rule rejects SELF")
	_eq(_submit(f, _request(&"absent", &"qa.probe", &"missing")).code, Code.TARGET_INVALID, "missing explicit target rejected")
	_submit(f, _request(&"self", &"qa.self", &""))
	_advance(f)
	_eq(f.bindings[0].state.recovery.atman.current, 1, "SELF resolves exact actor")
	_submit(f, _request(&"none", &"qa.none", &""))
	_advance(f)
	_eq(_count(f, Kind.RESOLVED), 3, "NONE needs no phantom target")
	var shadow: Fixtures.SchedulerFixture = _fixture()
	f.bindings[0] = shadow.bindings[0]
	_eq(_submit(f, _request(&"shadow")).code, Code.AUTHORITY_INVALID, "equal semantic ID shadow state rejected")


func _test_empty_queue_and_delta_partition() -> void:
	var with_tactics: Fixtures.SchedulerFixture = Fixtures.new()._fixture(true)
	var original: Fixtures.SchedulerFixture = Fixtures.new()._fixture(true)
	with_tactics.scheduler.configure_player_tactics(PLAYER, CombatTacticalActionRegistry.new())
	for index: int in range(60):
		_advance(with_tactics, 1.0 / 60.0)
	for index: int in range(10):
		_advance(original, 0.1)
	_eq(with_tactics.random.call_count(), original.random.call_count(), "empty queue delta partition RNG unchanged")
	_eq(with_tactics.random.requested_bounds(), original.random.requested_bounds(), "empty queue exact RNG bounds/order unchanged")
	_eq(_ordinary_signature(with_tactics), _ordinary_signature(original), "empty queue CXR4 events/order unchanged")
	_check(is_equal_approx(with_tactics.scheduler.remainder_seconds, original.scheduler.remainder_seconds), "empty queue remainder unchanged within CXR4 float precision")
	var fine: Fixtures.SchedulerFixture = _fixture()
	var coarse: Fixtures.SchedulerFixture = _fixture()
	_submit(fine, _request())
	_submit(coarse, _request())
	for index: int in range(60):
		_advance(fine, 1.0 / 60.0)
	for index: int in range(10):
		_advance(coarse, 0.1)
	_eq(_ordinary_signature(fine), _ordinary_signature(coarse), "same request schedule deterministic ordinary ordering")
	_eq(fine.random.call_count(), coarse.random.call_count(), "same schedule same RNG count")
	_eq(fine.random.requested_bounds(), coarse.random.requested_bounds(), "same schedule exact RNG bounds/order")
	_eq(_force(fine), _force(coarse), "same schedule same live mutation")
	_eq(_count(fine, Kind.RESOLVED), 1, "sixty boundaries execute once")
	_eq(_count(coarse, Kind.RESOLVED), 1, "ten boundaries execute once")


func _test_completion_and_execution_failure() -> void:
	var f: Fixtures.SchedulerFixture = _fixture()
	_submit(f, _request(&"failure", &"qa.fail", &"", PLAYER, Category.FLEE))
	_advance(f)
	_eq(f.scheduler.player_tactics().events()[-1].execution.outcome, CombatTacticalExecutionResult.Outcome.FAILED, "typed execute failure not success")
	_advance(f)
	_eq(_count(f, Kind.EXECUTION_STARTED), 1, "failed execution not retried")
	_submit(f, _request(&"end"))
	f.encounter.begin_resolving()
	f.encounter.complete(Fixtures.new()._scripted_result())
	_check(f.encounter.queued_player_action() == null, "completion clears queue authority")
	_eq(_advance(f, 100.0).outcome, CombatSchedulerAdvanceResult.Outcome.INERT, "completed scheduler inert")
	_eq(_submit(f, _request(&"late")).code, Code.INACTIVE, "completed runtime rejects input")
	_eq(f.random.call_count(), 0, "failed/completed paths no RNG")


func _test_additional_boundary_safety() -> void:
	var f: Fixtures.SchedulerFixture = _fixture()
	f.bindings[0].busy.start_busy(2)
	_submit(f, _request())
	_submit(f, _request(&"B"))
	_eq(f.encounter.queued_player_action().request.request_id, &"B", "WAITING replacement uses same slot")
	_eq(f.scheduler.player_tactics().cancel(&"A", true, ID).code, Code.STALE_CANCEL, "WAITING stale cancellation safe")
	_eq(f.scheduler.player_tactics().cancel(&"B", true, ID).code, Code.CANCELLED, "WAITING cancellation allowed")
	_eq(f.bindings[0].busy.busy_value, 2, "cancel does not mutate busy")
	_eq(f.random.call_count(), 0, "busy replace/cancel no RNG")
	var replacement: CombatTacticalEvent = f.scheduler.player_tactics().events()[4]
	_eq(replacement.kind, Kind.REPLACED, "replacement event shape")
	_eq(replacement.action.request.request_id, &"A", "replacement names old correlation")
	_eq(replacement.replacement_request_id, &"B", "replacement names new correlation")
	_eq(replacement.replacement_sequence, 2, "replacement names new sequence")
	var after: Fixtures.SchedulerFixture = _fixture()
	_advance(after, 1.0)
	var ordinary_order: int = after.scheduler.events()[-1].progression_order
	_submit(after, _request())
	_eq(_count(after, Kind.RESOLVED), 0, "input AFTER boundary waits for next boundary")
	_check(after.scheduler.player_tactics().events()[0].progression_order > ordinary_order, "post-boundary input ordered after ordinary")
	_advance(after)
	_eq(_count(after, Kind.RESOLVED), 1, "next boundary executes post-boundary input")
	for category: int in Category.values():
		var registry := CombatTacticalActionRegistry.new()
		var policy := Probe.new(&"qa.category", Target.NONE, category, true)
		registry.register_policy(policy)
		var fixture: Fixtures.SchedulerFixture = Fixtures.new()._fixture()
		fixture.scheduler.configure_player_tactics(PLAYER, registry)
		Probe.prepare(fixture.bindings[0].state)
		fixture.bindings[0].busy.start_busy(2)
		_submit(fixture, _request(&"category", &"qa.category", &"", PLAYER, category))
		_advance(fixture)
		_eq(_force(fixture), 10, "category waits on busy, no invented cooldown")
		_eq(fixture.random.call_count(), 0, "category waiting uses no tactical RNG")
	var distinct: Fixtures.SchedulerFixture = Fixtures.new()._fixture()
	var registry := CombatTacticalActionRegistry.new()
	registry.register_policy(RequestOnlyProbe.new())
	distinct.scheduler.configure_player_tactics(PLAYER, registry)
	Probe.prepare(distinct.bindings[0].state)
	_eq(_submit(distinct, _request(&"split", &"qa.probe", ENEMY)).code, Code.ACCEPTED, "request validator independently accepts")
	_advance(distinct)
	_eq(_count(distinct, Kind.EXECUTION_REJECTED), 1, "execution validator independently rejects")
	_eq(distinct.random.call_count(), 0, "separate execution validation RNG-free")
	var commitment: Fixtures.SchedulerFixture = Fixtures.new()._fixture()
	registry = CombatTacticalActionRegistry.new()
	registry.register_policy(BusyProbe.new())
	commitment.scheduler.configure_player_tactics(PLAYER, registry)
	Probe.prepare(commitment.bindings[0].state)
	_submit(commitment, _request(&"commit", &"qa.probe", ENEMY))
	_advance(commitment, 1.0)
	_eq(commitment.bindings[0].busy.busy_value, 1, "policy sets exact busy2; ordinary consumes 2->1")
	_eq(commitment.scheduler.events()[0].resolution.outcome, CombatSliceOpportunityResult.Outcome.BUSY_ADVANCED, "commitment uses existing ordinary busy gate")
	_eq(_count(commitment, Kind.RESOLVED), 1, "commitment policy executes once")
	var newly_busy: Fixtures.SchedulerFixture = _fixture()
	_submit(newly_busy, _request())
	newly_busy.bindings[0].busy.start_busy(1)
	_advance(newly_busy)
	_eq(newly_busy.scheduler.player_tactics().queue_status(), Status.WAITING_FOR_BUSY, "READY dynamically becomes WAITING on exact busy authority")
	_eq(_force(newly_busy), 10, "new busy prevents previously ready request execution")
	var overflow: Fixtures.SchedulerFixture = _fixture()
	overflow.scheduler.player_tactics()._next_request_sequence = 9223372036854775807
	_eq(_submit(overflow, _request()).code, Code.SEQUENCE_EXHAUSTED, "request sequence exhausts without wrap")
	_check(overflow.encounter.queued_player_action() == null, "sequence failure cannot queue")
	var shared_policy := Probe.new()
	var shared_registry := CombatTacticalActionRegistry.new()
	shared_registry.register_policy(shared_policy)
	var left: Fixtures.SchedulerFixture = Fixtures.new()._fixture()
	var right: Fixtures.SchedulerFixture = Fixtures.new()._fixture()
	for fixture: Fixtures.SchedulerFixture in [left, right]:
		fixture.scheduler.configure_player_tactics(PLAYER, shared_registry)
		Probe.prepare(fixture.bindings[0].state)
		_submit(fixture, _request(&"same-correlation", &"qa.probe", ENEMY))
	_advance(left)
	_eq(_force(right), 10, "shared stateless registered policy cannot alias independent characters")
	_advance(right)
	_eq(_force(left), 9, "second character execution leaves first unchanged")
	_eq(_force(right), 9, "same registered policy executes against second exact graph")


func _test_real_session(tree: SceneTree) -> void:
	var session: OldPineWorldSessionController = Fixtures.SessionScene.instantiate()
	tree.root.add_child(session)
	await tree.process_frame
	session.set_process(false)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var npc: NpcRuntimeState = session.outdoor_map().npc_runtimes()[0]
	Probe.prepare(player.state)
	npc.set_world_location(player.world_location())
	player.relationship.add_opponent(npc.character_id)
	npc.relationship.add_opponent(player.character_id)
	var random := ScriptedCombatRandomSource.new([0, 0, 0, 0])
	session.configure_combat_random_source(random)
	_check(coordinator.register_tactical_policy(Probe.new()), "typed QA registration before start")
	var started: CombatEncounterStartResult = coordinator.start(Fixtures.new()._session_trigger(session, npc))
	_check(started.succeeded(), "real Session scripted start")
	var request := CombatTacticalRequest.new(&"live", started.encounter_id, player.character_id, &"qa.probe", Category.MARTIAL_SPECIAL, npc.character_id)
	_eq(coordinator.submit_player_action(request).code, Code.ACCEPTED, "real current Session player accepted")
	_eq(player.state.recovery.inner_force.current, 10, "runtime submit doesn't execute")
	_check(session.world_simulation_gate().is_frozen(), "resident world frozen")
	_check(session.outdoor_map().opportunity_timer.is_stopped(), "legacy timer stopped")
	tree.paused = true
	coordinator.advance_scheduler(100.0)
	_eq(player.state.recovery.inner_force.current, 10, "SceneTree pause preserves queued state")
	_eq(coordinator.cancel_player_action(&"live").code, Code.APPLICATION_BLOCKED, "paused cancellation blocked")
	tree.paused = false
	coordinator.advance_scheduler(0.0)
	_eq(player.state.recovery.inner_force.current, 9, "exact Session player mutated")
	_eq(npc.character_state.recovery.atman.current, 1, "exact resident NPC mutated")
	_eq(random.call_count(), 1, "injected Session RNG one draw")
	_eq(coordinator.active_scheduler().logical_cycle, 0, "pause no catchup")
	var late := CombatTacticalRequest.new(&"late", started.encounter_id, player.character_id, &"qa.probe", Category.MARTIAL_SPECIAL, npc.character_id)
	coordinator.submit_player_action(late)
	var runtime: CombatTacticalRuntime = coordinator.active_scheduler().player_tactics()
	_check(coordinator.complete(CombatEncounterResult.new(started.encounter_id, CombatEncounterMode.Value.SCRIPTED, CombatEncounterResultKind.Value.SCRIPTED, [], [], [], &"qa.done")).succeeded(), "real completion")
	_eq(runtime.events()[-1].kind, Kind.CANCELLED, "completion emits queue cancellation")
	_check(session.world_simulation_gate().is_open(), "same world thaws")
	_eq(coordinator.submit_player_action(late).code, Code.INACTIVE, "disposed coordinator rejects request")
	_eq(coordinator.advance_scheduler(100.0).outcome, CombatSchedulerAdvanceResult.Outcome.INERT, "disposed coordinator inert")
	session.queue_free()
	await tree.process_frame


func _count(f: Fixtures.SchedulerFixture, kind: int) -> int:
	var count: int = 0
	for event: CombatTacticalEvent in f.scheduler.player_tactics().events():
		if event.kind == kind:
			count += 1
	return count


func _ordinary_signature(f: Fixtures.SchedulerFixture) -> Array[Array]:
	var result: Array[Array] = []
	for event: CombatSchedulerEvent in f.scheduler.events():
		result.append([event.sequence, event.progression_order, event.actor_id, event.target_id, event.kind, event.logical_cycle])
	return result


func _check(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures.append(message)


func _eq(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s: got %s expected %s" % [message, actual, expected])
