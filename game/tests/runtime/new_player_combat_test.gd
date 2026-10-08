extends RefCounted

## New-player combat in Snow: the 切磋 entry (cmds/std/fight.c with npc.c and the
## NPCs' own accept_fight), spars driven to their end, armed spars that wound and
## kill, NPCs healing and coming to between fights, and a failed fight that ends
## instead of freezing. Every fight here runs until the encounter is gone.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SESSION := preload("res://scenes/world/oldpine/oldpine_world_session.tscn")
const TRAINEE: StringName = &"snow.school2.trainee.1.character"
const FIST_TRAINER: StringName = &"snow.school2.fist_trainer.1.character"
const GUARD: StringName = &"snow.school1.guard.1.character"
const SCAVENGER: StringName = &"snow.mstreet2.scavenger.1.character"
const DOG: StringName = &"snow.eroad2.dog.1.character"
const KEEPER: StringName = &"snow.temple.keeper.1.character"

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	# ES2's own numbers end to end: the pacing knobs at ES2's pace (Es2Pacing).
	var pacing: PacingDefinition = Es2Pacing.use()
	await _who_spars(tree)
	await _spar_runs_to_its_end(tree)
	await _npc_heals_and_spars_again(tree)
	await _knocked_out_npc_comes_to_after_continue(tree)
	await _killed_after_knockout_still_saves(tree)
	await _armed_spar_death_reincarnation_and_continue(tree)
	await _failed_fight_ends_instead_of_freezing(tree)
	Es2Pacing.restore(pacing)
	return {"assertions": assertions, "failures": failures}


func _who_spars(tree: SceneTree) -> void:
	var fixture: Array = await _snow(tree)
	var session: WorldSessionController = fixture[0]
	var map: WorldMapController = fixture[1]
	var hud: SharedGameplayUI = session.shared_ui()
	var lines: Array[String] = _spar(map, SCAVENGER, &"snow.mstreet2", &"snow.mstreet2.drunk.1")
	check(lines == ["你对著收破烂的说道：小女子雪工，领教壮士的高招！", "收破烂的说道：小姑娘饶命！小的这就离开！", "看起来收破烂的并不想跟你较量。"], "收破烂的 begs off (scavenger.c accept_fight) %s" % str(lines))
	check(not session.combat_encounter_coordinator().has_active_encounter(), "a refusal starts nothing")
	lines = _spar(map, FIST_TRAINER, &"snow.school2", &"snow.school2.trainee.6")
	check(lines.slice(1) == ["李火狮说道：馆主吩咐过，不许和来这里的客人过招。", "看起来李火狮并不想跟你较量。"], "李火狮 will not spar with a guest %s" % str(lines))
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	trainee.character_state.vitality.current = trainee.character_state.vitality.maximum / 2
	lines = _spar(map, TRAINEE, &"snow.school2", &"snow.school2.trainee.6")
	check(lines.slice(1) == ["看起来武馆弟子并不想跟你较量。"], "a hurt NPC refuses without a word (npc.c < 90%%) %s" % str(lines))
	trainee.character_state.vitality.current = trainee.character_state.vitality.maximum
	trainee.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	check(_spar(map, TRAINEE, &"snow.school2", &"snow.school2.trainee.6") == ["武馆弟子已经无法战斗了。"], "fight.c: 已经无法战斗了")
	trainee.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	trainee.relationship.add_opponent(session.player_runtime().character_id)
	check(_spar(map, TRAINEE, &"snow.school2", &"snow.school2.trainee.6") == ["加油！加油！加油！"], "fight.c: already fighting you")
	trainee.relationship.remove_opponent(session.player_runtime().character_id)
	# Someone else's fight mark on the player: the encounter cannot hold a third
	# party, so the trainee's yes would start nothing. It reads as a refusal.
	session.player_runtime().relationship.add_opponent(SCAVENGER)
	lines = _spar(map, TRAINEE, &"snow.school2", &"snow.school2.trainee.6")
	check(lines.slice(1) == ["看起来武馆弟子并不想跟你较量。"] and not session.combat_encounter_coordinator().has_active_encounter(), "no acceptance into nothing %s" % str(lines))
	session.player_runtime().relationship.remove_opponent(SCAVENGER)
	check(_spar(map, KEEPER, &"snow.temple", &"snow.temple.keeper.1") == ["这里禁止战斗。"], "fight.c in a no_fight room")
	check(_spar(map, TRAINEE, &"snow.square", &"snow.square.inn_entry") == ["你想攻击谁？"], "fight.c: the one asked must be here")
	map.relocate_player(&"snow.eroad2", &"snow.eroad2.dog.2")
	map.select_npc(DOG)
	hud.refresh_exploration()
	check(hud.attack_is_enabled() and not hud.spar_is_enabled() and not hud.spar_button.visible, "a beast can be attacked but not asked to spar")
	var before: int = hud.log_lines().size()
	check(map.spar_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED and hud.log_lines().size() == before, "nor does spar_selected() ask it")
	session.player_runtime().state.family = FamilyState.new(&"family.fonxan", 14)
	lines = _spar(map, FIST_TRAINER, &"snow.school2", &"snow.school2.trainee.6")
	check(lines.slice(1) == ["李火狮点了点头。", "李火狮说道：进招吧。"] and session.combat_encounter_coordinator().has_active_encounter(), "李火狮 spars with 封山剑派 members %s" % str(lines))
	_run(session)
	check(not session.combat_encounter_coordinator().has_active_encounter(), "that spar ends too")
	await _close(tree, session)


func _spar_runs_to_its_end(tree: SceneTree) -> void:
	var fixture: Array = await _snow(tree)
	var session: WorldSessionController = fixture[0]
	var map: WorldMapController = fixture[1]
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	var lines: Array[String] = _spar(map, TRAINEE, &"snow.school2", &"snow.school2.trainee.6")
	check(lines == ["你对著武馆弟子说道：小女子雪工，领教小兄弟的高招！", "武馆弟子说道：既然小姑娘赐教，在下只好奉陪。"], "npc.c accepts, in rankd.c's words %s" % str(lines))
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	check(coordinator.has_active_encounter() and coordinator.active_encounter().mode == CombatEncounterMode.Value.SPAR, "a spar, not a kill")
	check(not player.relationship.has_lethal_target(trainee.character_id) and not trainee.relationship.has_lethal_target(player.character_id), "fight_ob both ways, no kill marks")
	var rounds: int = _run(session)
	check(not coordinator.has_active_encounter() and rounds < 300, "the spar ends (%d rounds)" % rounds)
	check(coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.SPAR_CONCLUDED, "concluded as a spar")
	var hit: bool = player.state.vitality.current < player.state.vitality.maximum or trainee.character_state.vitality.current < trainee.character_state.vitality.maximum
	check(hit, "it ended on a blow that drew kee (combatd.c: first damage > 0)")
	check(player.state.vitality.effective == player.state.vitality.maximum and trainee.character_state.vitality.effective == trainee.character_state.vitality.maximum, "bare hands leave no wound")
	check(not player.relationship.is_fighting() and not trainee.relationship.is_fighting(), "both sides stop")
	check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and map.corpse_states().is_empty(), "nobody falls")
	check(OldPineSaveEligibility.inspect(session).allowed(), "Save is open again")
	check(CombatEncounterCoordinator.take_aborted_total() == 0, "no abort")
	await _close(tree, session)


func _npc_heals_and_spars_again(tree: SceneTree) -> void:
	var fixture: Array = await _snow(tree)
	var session: WorldSessionController = fixture[0]
	var map: WorldMapController = fixture[1]
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	var kee: CharacterResourceState = trainee.character_state.vitality
	kee.current = 100
	check(_spar(map, TRAINEE, &"snow.school2", &"snow.school2.trainee.6").back() == "看起来武馆弟子并不想跟你较量。", "kee 100/200 refuses")
	var seconds: float = 0.0
	var accepted: bool = false
	while seconds < 600.0 and not accepted:
		session.advance_npc_heartbeat(2.0)
		seconds += 2.0
		if kee.current * 100 / kee.maximum >= 90:
			accepted = _spar(map, TRAINEE, &"snow.school2", &"snow.school2.trainee.6").size() == 2 and session.combat_encounter_coordinator().has_active_encounter()
	check(accepted, "heal_up brings the trainee back to 90%% and it accepts again (%d s)" % int(seconds))
	check(seconds >= 12.0, "heal_up waits for the char.c tick")
	_run(session)
	check(not session.combat_encounter_coordinator().has_active_encounter(), "the second spar ends")
	trainee.busy.start_busy(2)
	session.advance_npc_heartbeat(4.0)
	check(not trainee.busy.is_busy(), "outside a fight an NPC's busy wears off on its heart beat (continue_action())")
	await _close(tree, session)


func _knocked_out_npc_comes_to_after_continue(tree: SceneTree) -> void:
	var fixture: Array = await _snow(tree)
	var session: WorldSessionController = fixture[0]
	var map: WorldMapController = fixture[1]
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	_spar(map, TRAINEE, &"snow.school2", &"snow.school2.trainee.6")
	trainee.character_state.vitality.current = -1
	_run(session)
	check(trainee.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and map.corpse_states().is_empty(), "kee < 0 knocks the trainee out (char.c heart_beat)")
	check(trainee.revive_in_ms >= 30_000 and trainee.revive_in_ms < 130_000, "damage.c: revive in random(100 - con) + 30 s (%d ms)" % trainee.revive_in_ms)
	check(not session.combat_encounter_coordinator().has_active_encounter(), "the spar is over")
	session.advance_npc_heartbeat(10.0)
	var pending: int = trainee.revive_in_ms
	check(OldPineSaveEligibility.inspect(session).allowed(), "Save is allowed with an NPC out cold")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	check(encoded.succeeded() and encoded.text.contains("\"revive_in_ms\""), "the pending revive is saved")
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	check(decoded.succeeded(), "and read back")
	session.free()
	await tree.process_frame
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	check(restored.succeeded(), "Continue rebuilds the world")
	if not restored.succeeded():
		return
	var fresh: WorldSessionController = restored.candidate
	check(fresh.activate_restore_candidate(), "Continue activates")
	fresh.set_process(false)
	var again: NpcRuntimeState = (fresh.active_map() as WorldMapController).find_resident_npc(TRAINEE)
	check(again.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS and again.revive_in_ms == pending, "still out cold with the same countdown")
	check(GameSaveJsonCodec.encode(Work.capture(fresh)).text == encoded.text, "Save after Continue is the same file")
	var before: int = fresh.shared_ui().log_lines().size()
	fresh.advance_npc_heartbeat(float(pending) / 1000.0 - 1.0)
	check(again.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS, "not before its time")
	fresh.advance_npc_heartbeat(1.0)
	check(again.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and again.revive_in_ms == 0, "comes to when the call_out is due")
	check(fresh.shared_ui().log_lines().slice(before) == ["武馆弟子慢慢睁开眼睛，清醒了过来。"], "combatd.c announce(revive)")
	var kee: int = again.character_state.vitality.current
	for step: int in range(30):
		fresh.advance_npc_heartbeat(2.0)
	check(again.character_state.vitality.current > kee, "then heals")
	fresh.free()
	await tree.process_frame


## A kill goes through unconsciousness first; the dead keep no pending revive
## (die() destructs the object and its call_out), so Save still works.
func _killed_after_knockout_still_saves(tree: SceneTree) -> void:
	var fixture: Array = await _snow(tree)
	var session: WorldSessionController = fixture[0]
	var map: WorldMapController = fixture[1]
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	map.relocate_player(&"snow.school2", &"snow.school2.trainee.6")
	map.select_npc(TRAINEE)
	check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "attack the trainee")
	trainee.character_state.vitality.current = -1
	_run(session)
	var outcomes: Array[int] = []
	for receipt: CombatSliceLifecycleResult in map.last_lifecycle_results():
		outcomes.append(receipt.outcome)
	check(outcomes == [CombatSliceLifecycleResult.Outcome.UNCONSCIOUS_COMPLETE, CombatSliceLifecycleResult.Outcome.DEATH_COMPLETE], "knocked out, then killed")
	check(trainee.life_status == CharacterRuntimeLifeStatus.Value.DEAD and trainee.revive_in_ms == 0, "the dead wait for no revive")
	check(OldPineSaveEligibility.inspect(session).allowed() and Work.capture(session) != null, "Save works after the kill")
	await _close(tree, session)


## An armed spar wounds; a second one while wounded kills. The death runs the
## whole way: killer_reward from last_damage_from, the gargoyle, the temple, then
## Save and Continue.
func _armed_spar_death_reincarnation_and_continue(tree: SceneTree) -> void:
	var fixture: Array = await _snow(tree)
	var session: WorldSessionController = fixture[0]
	var map: WorldMapController = fixture[1]
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var guard: NpcRuntimeState = map.find_resident_npc(GUARD)
	var kee: CharacterResourceState = player.state.vitality
	var lines: Array[String] = _spar(map, GUARD, &"snow.school1", guard.spawn_point_id)
	check(lines.back() == "刀剑无眼，持兵刃比试可能真的受伤。" and session.combat_encounter_coordinator().has_active_encounter(), "刘安禄 accepts; a blade brings the native warning %s" % str(lines))
	_run(session)
	check(not session.combat_encounter_coordinator().has_active_encounter(), "the armed spar ends")
	check(kee.effective < kee.maximum and player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "the blade left a wound (eff kee %d/%d)" % [kee.effective, kee.maximum])
	player.state.progression.combat_experience = 1000
	kee.effective = 5
	kee.current = 5
	_spar(map, GUARD, &"snow.school1", guard.spawn_point_id)
	_run(session)
	check(not session.combat_encounter_coordinator().has_active_encounter(), "the second armed spar ends")
	check(player.life_status == CharacterRuntimeLifeStatus.Value.DEAD and map.corpse_states().size() == 1, "a wounded player dies of the next cut")
	var flow: PlayerLifeFlow = session.player_life_flow()
	# The last blow may still have taught the victim one point before it died.
	var experience: int = player.state.progression.combat_experience
	var at_death: int = experience + flow.death_result.combat_experience_lost
	check(flow.phase == PlayerLifeFlow.Phase.DEATH_SEQUENCE and flow.death_result.penalized and at_death in [1000, 1001] and flow.death_result.combat_experience_lost == at_death / 10, "killer_reward (exp / 10): last_damage_from is the killer even in a spar")
	for second: int in range(25):
		session._process(1.0)
	check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and player.world_location().zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID, "back at the temple")
	check(OldPineSaveEligibility.inspect(session).allowed(), "Save is open after reincarnation")
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(Work.capture(session))
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	check(encoded.succeeded() and decoded.succeeded(), "saved and read back")
	session.free()
	await tree.process_frame
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(decoded.snapshot, tree.root)
	check(restored.succeeded() and restored.candidate.activate_restore_candidate(), "Continue")
	if not restored.succeeded():
		return
	var fresh: WorldSessionController = restored.candidate
	fresh.set_process(false)
	var back: WorldPlayerRuntimeState = fresh.player_runtime()
	check(back.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and back.world_location().zone_id == SnowWorldDefinitions.TEMPLE_ZONE_ID and back.state.progression.combat_experience == experience, "the reincarnated player continues at the temple")
	check((fresh.active_map() as WorldMapController).corpse_states().size() == 1, "with the corpse still in the school")
	check(GameSaveJsonCodec.encode(Work.capture(fresh)).text == encoded.text, "Save after Continue is the same file")
	fresh.free()
	await tree.process_frame


func _failed_fight_ends_instead_of_freezing(tree: SceneTree) -> void:
	var fixture: Array = await _snow(tree)
	var session: WorldSessionController = fixture[0]
	var map: WorldMapController = fixture[1]
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var trainee: NpcRuntimeState = map.find_resident_npc(TRAINEE)
	_spar(map, TRAINEE, &"snow.school2", &"snow.school2.trainee.6")
	trainee.character_state.vitality.current = 150
	# A source that answers every draw out of range breaks the first opportunity.
	var broken: ScriptedCombatRandomSource = ScriptedCombatRandomSource.new([])
	var working: CombatRandomSource = session.combat_random_source()
	session.configure_combat_random_source(broken)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	coordinator.advance_scheduler(1.0)
	session.configure_combat_random_source(working)
	check(CombatEncounterCoordinator.take_aborted_total() == 1, "the failure aborts the fight")
	check(not coordinator.has_active_encounter() and session.world_simulation_gate().is_open(), "nothing is left running; the world moves again")
	check(coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.ABORTED, "an aborted result, not a victory")
	check(BattleFeedbackReader.completion_text(coordinator.last_completion(), player.life_status) == "战斗出错，已中止。", "one line for the player")
	check(coordinator.last_abort_detail().begins_with("failure=OPPORTUNITY_FAILED") and coordinator.last_abort_detail().contains("selection="), "the cause is kept for development: " + coordinator.last_abort_detail())
	check(trainee.character_state.vitality.current == 150, "damage already dealt stays")
	check(not player.relationship.is_fighting() and not trainee.relationship.is_fighting(), "both sides disengage")
	check(OldPineSaveEligibility.inspect(session).allowed(), "Save works")
	trainee.character_state.vitality.current = trainee.character_state.vitality.maximum
	_spar(map, TRAINEE, &"snow.school2", &"snow.school2.trainee.6")
	_run(session)
	check(not coordinator.has_active_encounter() and coordinator.last_completion().terminal_result.kind == CombatEncounterResultKind.Value.SPAR_CONCLUDED, "the next spar runs normally")
	await _close(tree, session)


## [session, Snow outdoor map]; the session is driven by hand.
func _snow(tree: SceneTree) -> Array:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "fixture walks out to the square")
	for frame: int in range(5):
		await tree.process_frame
	return [session, session.active_map() as WorldMapController]


## Stands by the NPC, asks for a spar and returns the lines it printed.
func _spar(map: WorldMapController, npc_id: StringName, zone_id: StringName, spawn_point_id: StringName) -> Array[String]:
	map.relocate_player(zone_id, spawn_point_id)
	map.select_npc(npc_id)
	var hud: SharedGameplayUI = map.session.shared_ui()
	var before: int = hud.log_lines().size()
	map.spar_selected()
	return hud.log_lines().slice(before)


## Advances the encounter one combat round at a time until it is gone.
func _run(session: WorldSessionController) -> int:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 300:
		var advanced: CombatSchedulerAdvanceResult = coordinator.advance_scheduler(1.0)
		rounds += 1
		if advanced.cycles_processed == 0 and coordinator.has_active_encounter():
			check(false, "the fight stalled after %d rounds" % rounds)
			break
	return rounds


func _close(tree: SceneTree, session: WorldSessionController) -> void:
	session.free()
	await tree.process_frame


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append("new-player combat: " + label)
