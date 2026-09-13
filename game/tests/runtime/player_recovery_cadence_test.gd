extends RefCounted

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Food := preload("res://tests/runtime/snow_dumpling_test.gd")
const Encounter := preload("res://tests/runtime/combat_encounter_lifecycle_test.gd")
const Route := preload("res://tests/runtime/snow_outdoor_route_test.gd")
const SESSION: PackedScene = preload("res://scenes/world/oldpine/oldpine_world_session.tscn")
var assertions: int = 0
var failures: Array[String] = []

class RandomSequence extends RecoveryCadenceRandomSource:
	var values: Array[int] = [5]
	var calls: int = 0
	var observed_character: CharacterState
	var foods_at_draw: Array[int] = []
	func _init(sequence: Array[int] = [5]) -> void:
		values = sequence.duplicate()
	func draw_reset_tick() -> int:
		if observed_character != null: foods_at_draw.append(observed_character.recovery.food)
		var value: int = values[mini(calls, values.size() - 1)]
		calls += 1
		return value


static func create_session(tree: SceneTree, random: RecoveryCadenceRandomSource) -> OldPineWorldSessionController:
	var session: OldPineWorldSessionController = SESSION.instantiate()
	session.configure_source_entry("雪息", CharacterState.GENDER_FEMALE)
	session.configure_recovery_random_source(random)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	# Tests drive exact delta synchronously; this does not disable production eligibility.
	session.set_process(false)
	return session


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	trace_tests(tree)
	resource_tests(tree)
	freeze_tests(tree)
	map_combat_tests(tree)
	restore_tests(tree)
	var profile: String = "s5b-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	for mode: String in ["write", "read"]:
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/run_snow_recovery_cold_process.gd", "--", mode, profile], output, true)
		check(code == 0 and str(output).contains("S5B cold PASS") and not str(output).contains("SCRIPT ERROR"), "cold " + mode + ": " + str(output))
	return {"assertions": assertions, "failures": failures}


func trace_tests(tree: SceneTree) -> void:
	check(PlayerRecoveryCadence.BASE_PULSE_SECONDS == 2.0, "owner Type B 2s, not proven source period")
	for initial: int in [5, 6, 14]:
		var random: RandomSequence = RandomSequence.new([initial, 6, 14])
		var session: OldPineWorldSessionController = create_session(tree, random)
		var cadence: PlayerRecoveryCadence = session.player_recovery_cadence()
		var state: CharacterState = session.player_runtime().state
		random.observed_character = state
		check(random.calls == 1 and cadence.source_tick == initial and cadence.accumulated_seconds == 0.0, "one initial draw " + str(initial))
		check(session.initialize_session() and random.calls == 1, "idempotent initialize no reroll")
		check(not session.configure_recovery_random_source(RandomSequence.new()), "cannot replace initialized authority")
		for pulse: int in range(1, initial + 1):
			var step: PlayerRecoveryCadenceResult = session.advance_player_recovery(2.0)
			check(step.pulses == 1 and step.opportunities == 0 and cadence.source_tick == initial - pulse and random.calls == 1, "postdecrement trace %d/%d" % [initial, pulse])
		var due: PlayerRecoveryCadenceResult = session.advance_player_recovery(2.0)
		check(due.opportunities == 1 and due.last_update_count == 2 and cadence.source_tick == 6 and random.calls == 2, "old0 resets before one recovery on pulse " + str(initial+1))
		check(random.foods_at_draw == [400] and state.recovery.food == 399 and state.recovery.water == 399, "RNG observes prerecovery food400")
		check(state.essence.current == 100 and state.vitality.current == 100 and state.spirit.current == 100, "full primaries unchanged")
		check(session.advance_player_recovery(14.0).opportunities == 1 and cadence.source_tick == 14 and random.calls == 3, "next reset6 takes7 pulses")
		session.free()
	var random: RandomSequence = RandomSequence.new()
	var session: OldPineWorldSessionController = create_session(tree, random)
	var cadence: PlayerRecoveryCadence = session.player_recovery_cadence()
	for delta: float in [1.0, 0.75]: check(session.advance_player_recovery(delta).pulses == 0, "partial no pulse")
	check(session.advance_player_recovery(0.25).pulses == 1 and cadence.accumulated_seconds == 0.0 and cadence.source_tick == 4, "exact2s pulse")
	check(session.advance_player_recovery(5.0).pulses == 2 and cadence.accumulated_seconds == 1.0, "5s two pulses/remainder1")
	for delta: float in [-1.0, INF, NAN, 1.0e300]:
		check(session.advance_player_recovery(delta).outcome == PlayerRecoveryCadenceResult.Outcome.INVALID_INPUT and cadence.accumulated_seconds == 1.0 and cadence.source_tick == 2, "invalid/unrepresentable time rejected")
	check(session.advance_player_recovery(5.0).opportunities == 1 and random.calls == 2, "remaining3 pulses reach due")
	var other: OldPineWorldSessionController = create_session(tree, RandomSequence.new())
	check(other.player_recovery_cadence() != cadence and other.player_runtime().state.recovery.food == 400, "independent states/RNG")
	check(other.advance_player_recovery(12.0).opportunities == 1, "large delta processes all6 pulses")
	other.free()
	session.free()
	var invalid: PlayerRecoveryCadence = PlayerRecoveryCadence.new(RandomSequence.new([4]))
	check(not invalid.is_valid(), "invalid initial draw no clamp")
	random = RandomSequence.new([5, 15])
	session = create_session(tree, random)
	check(session.advance_player_recovery(12.0).outcome == PlayerRecoveryCadenceResult.Outcome.INVALID_RANDOM and random.calls == 2 and session.player_runtime().state.recovery.food == 400, "bad reached reset consumed without healing/retry")
	check(session.advance_player_recovery(12.0).outcome == PlayerRecoveryCadenceResult.Outcome.INVALID_INPUT and random.calls == 2, "failed cadence does not reroll")
	session.free()


func resource_tests(tree: SceneTree) -> void:
	for works: int in [1, 2, 3]:
		var session: OldPineWorldSessionController = create_session(tree, RandomSequence.new())
		var state: CharacterState = session.player_runtime().state
		for i: int in range(works): check(Work.work(session).succeeded(), "actual Work service")
		var rng: Array[int] = Work.rng_state(session)
		check(state.essence.current == 100 - works*30 and state.spirit.current == 100 - works*30, "source Work costs before time")
		check(session.advance_player_recovery(12.0).opportunities == 1 and state.essence.current == 110-works*30 and state.spirit.current == 110-works*30, "Work70/40/10 ->80/50/20")
		if works == 2:
			check(session.advance_player_recovery(60.0).opportunities == 5 and state.essence.current == 100 and state.spirit.current == 100, "six heals40->100")
		if works == 3:
			check(Work.work(session).outcome == SnowWorkResult.Outcome.TOO_TIRED, "20 still tired")
			check(session.advance_player_recovery(12.0).opportunities == 1 and state.essence.current == 30 and state.spirit.current == 30, "second heal restores30")
			check(Work.work(session).succeeded() and state.essence.current == 0 and state.spirit.current == 0, "Work allowed exactly30")
		check(Work.rng_state(session) == rng, "three persisted RNG streams unchanged")
		session.free()
	var session: OldPineWorldSessionController = create_session(tree, RandomSequence.new())
	check(Food.earn_and_exchange(session), "Work twice + Bank")
	var product: DumplingPurchaseResult = Food.purchase(session)
	var state: CharacterState = session.player_runtime().state
	check(product.delivered and state.recovery.food == 400, "real product no hunger injection")
	check(session.advance_player_recovery(12.0).opportunities == 1 and state.recovery.food == 399, "natural first metabolism")
	check(Food.eat(session, product.item_id).outcome == FoodUseResult.Outcome.ATE and state.recovery.food == 459, "399->459 actual Eat")
	check(session.food_collection().state(product.item_id).remaining_portions == 2 and session.food_collection().state(product.item_id).current_value == 0, "portions2/value0")
	var rng: Array[int] = Work.rng_state(session)
	check(session.advance_player_recovery(59*12.0).opportunities == 59 and state.recovery.food == 400, "59 overshoot metabolism no clamp")
	check(Food.eat(session, product.item_id).outcome == FoodUseResult.Outcome.TOO_FULL, "400 still full")
	check(session.advance_player_recovery(12.0).opportunities == 1 and state.recovery.food == 399, "60th permits eating")
	check(Food.eat(session, product.item_id).outcome == FoodUseResult.Outcome.ATE and state.recovery.food == 459 and state.recovery.water == 339, "second bite no water refill")
	check(Work.rng_state(session) == rng, "substantial cadence RNG isolation")
	session.free()
	# Explicit boundary fixtures (not the natural economy journey).
	for water_edge: bool in [true, false]:
		session = create_session(tree, RandomSequence.new())
		state = session.player_runtime().state
		Work.work(session)
		state.recovery.water = 1 if water_edge else 2
		state.recovery.food = 400 if water_edge else 1
		state.recovery.inner_force.maximum = 100
		state.skills.set_raw_level(&"force", 5)
		session.advance_player_recovery(12.0)
		check(state.recovery.water == (0 if water_edge else 1) and state.recovery.food == (399 if water_edge else 0), "decrement before gates")
		check(state.essence.current == (70 if water_edge else 80) and state.recovery.inner_force.current == 0, "water blocks primary; food only internal")
		session.free()
	session = create_session(tree, RandomSequence.new())
	state = session.player_runtime().state
	for id: StringName in [&"magic", &"force", &"spells"]: state.skills.set_raw_level(id, 3)
	state.skills.set_raw_level(&"special", 999)
	state.skills.map_skill(&"force", &"special")
	state.recovery.atman.maximum = 100
	state.recovery.inner_force.maximum = 100
	state.recovery.mana.maximum = 100
	session.advance_player_recovery(12.0)
	check(state.recovery.atman.current == 1 and state.recovery.inner_force.current == 1 and state.recovery.mana.current == 1, "raw3/2 each, NOT effective/mapped999")
	state.skills.set_raw_level(&"force", 9)
	session.advance_player_recovery(12.0)
	check(state.recovery.inner_force.current == 5, "re-read skill at each actual opportunity")
	state.recovery.food = 0
	state.recovery.water = 0
	check(session.advance_player_recovery(24.0).opportunities == 2 and state.recovery.food == 0 and state.recovery.water == 0, "update_count0 never stops Player cadence; no thirst damage")
	session.free()


func frozen(session: OldPineWorldSessionController, random: RandomSequence, label: String) -> void:
	var cadence: PlayerRecoveryCadence = session.player_recovery_cadence()
	var remainder: float = cadence.accumulated_seconds
	var tick: int = cadence.source_tick
	var calls: int = random.calls
	var food: int = session.player_runtime().state.recovery.food
	check(session.advance_player_recovery(300.0).outcome == PlayerRecoveryCadenceResult.Outcome.FROZEN, label + " frozen")
	check(cadence.accumulated_seconds == remainder and cadence.source_tick == tick and random.calls == calls and session.player_runtime().state.recovery.food == food, label + " no time/count/RNG/metabolism")


func freeze_tests(tree: SceneTree) -> void:
	var random: RandomSequence = RandomSequence.new()
	var session: OldPineWorldSessionController = create_session(tree, random)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	session.advance_player_recovery(1.0)
	tree.paused = true
	frozen(session, random, "Pause")
	tree.paused = false
	check(session.advance_player_recovery(1.0).pulses == 1, "Resume same1s remainder")
	player.busy.start_busy(1)
	check(session.advance_player_recovery(5.0).busy_pulses == 2 and session.player_recovery_cadence().source_tick == 4 and player.busy.busy_value == 1, "busy consumes2 pulses not countdown or busy advancement")
	player.busy.advance()
	check(session.advance_player_recovery(1.0).pulses == 1 and session.player_recovery_cadence().source_tick == 3, "external busy owner clears; resume countdown")
	for id: StringName in [&"snake_poison", &"bandaged", &"unsupported"]:
		for duration: int in [0, -1, 9]:
			player.state.conditions.add_or_replace_duration(id, duration)
			frozen(session, random, "condition " + String(id))
			check((player.state.conditions.get_condition(id) as DurationConditionPayload).remaining == duration and player.state.vitality.effective == 100, "no handler/expiry/damage")
			player.state.conditions.remove_condition(id)
	player.relationship.add_opponent(&"test.opponent")
	frozen(session, random, "fighting without encounter")
	player.relationship.remove_opponent(&"test.opponent")
	for status: int in [CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, CharacterRuntimeLifeStatus.Value.DEAD]:
		player.set_life_status(status)
		frozen(session, random, "life")
		check(player.life_status == status, "no revive")
	player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	player.set_exists_in_world(false)
	frozen(session, random, "not in world")
	player.set_exists_in_world(true)
	session.world_simulation_gate().acquire(&"test.noncombat")
	frozen(session, random, "noncombat gate")
	session.world_simulation_gate().release(&"test.noncombat")
	check(session.suspend_for_session_swap(), "suspend existing owner")
	frozen(session, random, "swap")
	check(session.resume_after_failed_session_swap(), "rollback resumes same owner")
	session._transitioning = true # Typed boundary fixture, no fake physical traversal claim.
	frozen(session, random, "partial handoff")
	session._transitioning = false
	var failed_handoff: OldPineMapHandoffResult = OldPineMapHandoffResult.new()
	failed_handoff._outcome = OldPineMapHandoffResult.Outcome.LOCATION_COMMIT_FAILED
	failed_handoff._source_detached = true
	session._last_map_handoff = failed_handoff
	frozen(session, random, "failed location commit AND failed source restoration")
	failed_handoff._source_restored = true
	check(session.player_recovery_time_allowed(), "successfully restored old owner resumes")
	failed_handoff._location_committed = true
	frozen(session, random, "location committed but destination activation incomplete")
	session._last_map_handoff = null
	check(session.advance_player_recovery(2.0).pulses == 1 and random.calls == 1, "all freezes retain source phase")
	session.free()
	var technical: OldPineWorldSessionController = SESSION.instantiate()
	tree.root.add_child(technical)
	check(technical.player_recovery_cadence() == null and technical.advance_player_recovery(1000.0).outcome == PlayerRecoveryCadenceResult.Outcome.FROZEN, "technical profile has no cadence")
	technical.free()


func map_combat_tests(tree: SceneTree) -> void:
	var random: RandomSequence = RandomSequence.new()
	var session: OldPineWorldSessionController = create_session(tree, random)
	session.advance_player_recovery(3.0)
	var cadence: PlayerRecoveryCadence = session.player_recovery_cadence()
	var rejected: Route.RejectPreparation = Route.RejectPreparation.new()
	session.register_resident_map(rejected)
	check(not session.handoff_to(&"test.reject", &"test.zone", &"test.zone", &"marker").succeeded() and session.player_recovery_time_allowed(), "failed handoff returns valid old owner")
	session._resident_maps.erase(rejected.map_id())
	rejected.free()
	var portals: Array[PortalDefinition] = [SnowWorldDefinitions.portal_by_id(SnowWorldDefinitions.INN_EXIT_PORTAL_ID), SnowOldPineConnectionDefinitions.to_oldpine(), SnowOldPineConnectionDefinitions.to_snow(), SnowWorldDefinitions.portal_by_id(SnowWorldDefinitions.INN_RETURN_PORTAL_ID)]
	for portal: PortalDefinition in portals:
		var result: OldPineMapHandoffResult = session.handoff_to(portal.destination_map_id, portal.destination_zone_id, portal.destination_zone_id, portal.destination_spawn_point_id)
		check(result.succeeded(), "boundary handoff " + String(portal.destination_map_id))
		check(session.player_recovery_cadence() == cadence and cadence.source_tick == 4 and cadence.accumulated_seconds == 1.0 and random.calls == 1, "same phase/RNG after handoff")
	# Controlled scripted combat using existing coordinator, no scheduler modifications.
	var portal: PortalDefinition = SnowOldPineConnectionDefinitions.to_oldpine()
	check(session.handoff_to(portal.destination_map_id, portal.destination_zone_id, portal.destination_zone_id, portal.destination_spawn_point_id).succeeded(), "combat fixture enters Old Pine")
	var npc: NpcRuntimeState = session.outdoor_map().npc_runtimes()[0]
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.set_world_location(npc.world_location())
	player.relationship.add_opponent(npc.character_id)
	var fixture: Encounter = Encounter.new()
	var started: CombatEncounterStartResult = session.combat_encounter_coordinator().start(fixture._trigger(session, npc, CombatTriggerCause.Value.SCRIPTED))
	check(started.succeeded(), "legitimate coordinator encounter")
	frozen(session, random, "active encounter")
	check(session.combat_encounter_coordinator().complete(fixture._scripted_result(started.encounter_id, player.character_id, npc.character_id)).succeeded(), "legitimate completion")
	player.relationship.remove_opponent(npc.character_id)
	check(session.advance_player_recovery(1.0).pulses == 1 and cadence.source_tick == 3 and random.calls == 1, "postcombat same phase")
	session.free()


func restore_tests(tree: SceneTree) -> void:
	var random: RandomSequence = RandomSequence.new()
	var session: OldPineWorldSessionController = create_session(tree, random)
	Work.work(session)
	session.advance_player_recovery(15.0)
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var encoded: String = GameSaveJsonCodec.encode(snapshot).text
	var json: Dictionary = JSON.parse_string(encoded)
	var rng_keys: Array = json.rng.keys()
	rng_keys.sort()
	check(rng_keys == ["combat", "npc_initialization", "world_interaction"] and json.size() == 9 and json.metadata.schema_version == 2 and json.items.schema_version == 2, "strict unchanged root/item/RNG schema")
	check(not encoded.contains("cadence") and not encoded.contains("countdown") and not encoded.contains("accumulator"), "no transient Save fields")
	check(session.player_recovery_cadence().source_tick == 4 and session.player_recovery_cadence().accumulated_seconds == 1.0 and random.calls == 2, "capture preserves phase")
	var preparation: OldPineWorldRestoreResult = OldPineWorldRestoreComposition.prepare(snapshot)
	check(preparation.preparation != null, "valid reconstruction")
	var restored: OldPineWorldSessionController = SESSION.instantiate()
	var fresh_random: RandomSequence = RandomSequence.new([14])
	check(restored.configure_restore(preparation.preparation) and restored.configure_recovery_random_source(fresh_random), "fresh restore injection before stage")
	tree.root.add_child(restored)
	check(restored.is_restore_candidate_staged() and fresh_random.calls == 0 and restored.player_recovery_cadence() == null, "stage has no cadence authority/draw")
	check(restored.advance_player_recovery(999.0).outcome == PlayerRecoveryCadenceResult.Outcome.FROZEN, "candidate cannot tick")
	check(restored.activate_restore_candidate(), "valid candidate activation")
	check(fresh_random.calls == 1 and restored.player_recovery_cadence().source_tick == 14 and restored.player_recovery_cadence().accumulated_seconds == 0.0, "Continue NEW phase14/0 not old4/1")
	check(restored.player_runtime() != session.player_runtime() and restored.player_recovery_cadence() != session.player_recovery_cadence(), "fresh runtime authorities")
	check(GameSaveJsonCodec.encode(Work.capture(restored)).text == encoded, "ENTIRE persisted state exact after fresh activation")
	check(Work.rng_state(restored) == Work.rng_state(session), "existing RNG restore zero draws")
	check(OldPineSaveEligibility.inspect(restored).allowed(), "ordinary cadence does not block Save")
	restored.free()
	session.free()


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append("S5B: " + label)
